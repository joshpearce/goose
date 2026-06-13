---
phase: 70-haptic-primitive-breathe-screen
reviewed: 2026-06-13T00:00:00Z
depth: standard
files_reviewed: 17
files_reviewed_list:
  - GooseSwift/BreatheView.swift
  - GooseSwift/CoachView.swift
  - GooseSwift/GooseAppModel+NotificationPipeline.swift
  - GooseSwift/GooseBLEClient+Haptics.swift
  - GooseSwift/GooseBLEClient+HistoricalCommands.swift
  - GooseSwift/GooseBLEClient+HistoricalHandlers.swift
  - GooseSwift/GooseBLEClient+Parsing.swift
  - GooseSwift/HeartRateSeriesStores.swift
  - GooseSwift/MoreDataStore.swift
  - GooseSwift/MoreDebugViews.swift
  - GooseSwift/MoreRouteModels.swift
  - GooseSwift/MoreView.swift
  - Rust/core/src/bridge.rs
  - Rust/core/src/historical_sync.rs
  - Rust/core/src/storage_check.rs
  - Rust/core/src/store.rs
  - Rust/core/tests/protocol_tests.rs
findings:
  critical: 3
  warning: 6
  info: 3
  total: 12
status: issues_found
---

# Phase 70: Code Review Report

**Reviewed:** 2026-06-13
**Depth:** standard
**Files Reviewed:** 17
**Status:** issues_found

## Summary

Phase 70 added a breathing guidance screen (`BreatheView`), a raw BLE haptic primitive (`buzz(loops:)`), and new storage-check / debug surface plumbing in `MoreDataStore` and related files. The Rust side gained `imu_step_count_from_decoded_frames` and `storage.check` bridge methods. The protocol test file contains a new `V18History` decode path.

Key findings:

- The haptic command encoding is unframed and diverges from every other command written by this codebase. A code comment even acknowledges the risk but ships it anyway. This is a blocker because sending a malformed or wrong-characteristic write can cause erratic vibration patterns on the device or a silent failure with no way to distinguish from success.
- `gooseFrames` (frame reassembly) is declared `nonisolated` and modifies `frameReassemblyBuffers` — a dictionary marked `nonisolated(unsafe)` — from the `notificationIngestQueue` background thread without any lock. Concurrent BLE notifications for the same device/characteristic pair can corrupt the buffer.
- The `BreatheView` task is spawned `@MainActor` but the `stopSession()` method sets `isRunning = false` before cancelling the task. If SwiftUI calls `stopSession()` (via `.onDisappear`) while the `repeat` loop is between an `await` and the next `guard !Task.isCancelled` check, `isRunning` becomes `false` while the task is still alive and still calling `buzz()`.
- `HRVSeriesStore` is not marked `@unchecked Sendable` yet its mutable state (`samples`, `pendingWrite`, `lastNotificationAt`) is accessed from both the `stateLock`-protected read/write path and the `writeQueue` async closure without holding the lock for the `pendingWrite = nil` assignment.
- The `storage.check` self-test in `storage_check.rs` opens the database read-only then attempts to insert test rows. This will silently fail with SQLite error "attempt to write to read-only database" and report all self-test booleans as `false`, producing a misleading "FAIL" report on a valid database.

---

## Critical Issues

### CR-01: Haptic command sent without protocol framing — wrong write may reach strap

**File:** `GooseSwift/GooseBLEClient+Haptics.swift:21`

**Issue:** `buzz(loops:)` writes a bare 2-byte payload `[0x13, loops]` directly to `commandCharacteristic`. Every other command in this codebase (alarm, clock, sensor stream, historical) is wrapped with `buildCommandFrame` which prepends the `0xaa 0x01` header, declares a length, appends sequence, CRC-16 header checksum, and CRC-32 payload checksum before writing. The WHOOP GATT command characteristic expects framed packets. Sending an unframed payload is likely to be either silently discarded by the strap firmware, cause erratic behavior, or corrupt the strap's command parser state for subsequent framed commands (e.g., the next `writeHistoricalCommand` call issued after a breathing session ends).

The code comment at line 17–20 explicitly flags this uncertainty: "Verify via BTSnoop capture whether the WHOOP haptic characteristic accepts unframed commands before assuming this is correct." The comment acknowledges the risk but the code ships.

Additionally, `commandCharacteristic` is the same characteristic used by `writeHistoricalCommand`, `writeAlarmCommand`, and `writeClockCommand`. Issuing an unframed write during an active historical sync (possible since nothing prevents calling `buzz` while syncing) will interleave with the framed protocol stream.

**Fix:**
```swift
// Use buildCommandFrame exactly as writeHistoricalCommand and writeAlarmCommand do:
let sequence = nextCommandSequence() // or a dedicated haptic sequence counter
let frame = activeDeviceGeneration.buildCommandFrame(
    sequence: sequence,
    command: 0x13,
    data: [clamped]
)
activePeripheral.writeValue(frame, for: commandCharacteristic, type: writeType)
```
If a BTSnoop capture later proves the strap accepts unframed 0x13 commands on a *separate* haptic characteristic (not the main command characteristic), the fix is instead to resolve the correct characteristic UUID and write there — not to the shared command characteristic.

---

### CR-02: Data race on `frameReassemblyBuffers` accessed without synchronisation from background queue

**File:** `GooseSwift/GooseAppModel+NotificationPipeline.swift:802-858`

**Issue:** `gooseFrames(in:event:)` is `nonisolated` and is called from `notificationIngestQueue.async` (line 14 of the same file). It reads and writes `frameReassemblyBuffers` (declared in `GooseAppModel.swift:167` as `@ObservationIgnored nonisolated(unsafe) var frameReassemblyBuffers: [String: Data] = [:]`) with no lock. Swift's `nonisolated(unsafe)` does not add any synchronisation — it is the programmer's promise that they handle it externally. No `NSLock` or serial queue protection is present around the dictionary access.

Multiple BLE notification callbacks (each dispatched to `notificationIngestQueue`) can run concurrently if `notificationIngestQueue` is concurrent, or can interleave if the queue is serial but each task suspends at `await Task.sleep`. Concurrent dictionary reads/writes in Swift produce undefined behavior and can crash (EXC_BAD_ACCESS) or silently produce corrupted frames.

**Fix:**
```swift
// Option A: add a dedicated lock around buffer access
private let frameReassemblyLock = NSLock()

nonisolated func gooseFrames(in data: Data, event: GooseNotificationEvent) -> FrameReassemblyResult {
    let key = frameReassemblyKey(for: event)
    frameReassemblyLock.lock()
    defer { frameReassemblyLock.unlock() }
    // ... existing body unchanged ...
}
```
Or, option B: make `notificationIngestQueue` a serial queue (if it is already serial, document that guarantee alongside the `nonisolated(unsafe)` declaration so the safety contract is explicit and verifiable).

---

### CR-03: `storage.check` self-test always fails on an existing database — open_read_only then write

**File:** `Rust/core/src/storage_check.rs:89-96`, `229-340`

**Issue:** `check_storage_database` opens the store with `GooseStore::open_read_only` when `database_path.exists()` (line 92-93). The `run_storage_self_test` function then calls `store.insert_raw_evidence(...)` and `store.insert_decoded_frame(...)` (lines 265, 280, 310) on that read-only connection. SQLite will reject these writes with `SQLITE_READONLY`. The `match` arms on each insert return `false` or push an error to `issues`, so all self-test result booleans (`raw_inserted`, `raw_idempotent`, `decoded_inserted`, `foreign_key_rejected`) will be `false` and `issues` will contain error strings, causing `storage_self_test_ready` to return `false` and the overall `pass` to be `false`.

The user sees "storage check failed" for a perfectly valid database whenever they run the check after capture has already created the file. This is the most common case in production.

**Fix:**
```rust
// Open a writable in-memory clone or a separate temporary DB for the self-test,
// not the production read-only handle:
fn run_storage_self_test_writable(database_path: &Path) -> StorageSelfTestReport {
    // Open a fresh writable connection to an in-memory DB for insert tests
    let store = match GooseStore::open_in_memory() {
        Ok(s) => s,
        Err(e) => return StorageSelfTestReport { ran: false, issues: vec![e.to_string()], ... },
    };
    // ... rest of self-test unchanged ...
}
```
Alternatively, open the store read-write for the self-test and rollback / clean up test rows after. The current design cannot produce a `pass = true` self-test result on an existing database.

---

## Warnings

### WR-01: `BreatheView` — `isRunning = false` set before task cancellation; `buzz()` called after stop

**File:** `GooseSwift/BreatheView.swift:133-138`

**Issue:** `stopSession()` sets `isRunning = false` (line 136) then cancels `phaseTask` (line 134). In the interval between the `isRunning = false` assignment and the actual task cancellation taking effect, the task body is still running. If the task is between `try? await Task.sleep(...)` and `guard !Task.isCancelled else { break }`, it will advance to the next `currentPhase = .inhale / .hold / .exhale` assignment and call `model.ble.buzz(loops: 1)` on the next iteration, firing an extra haptic after the user pressed Stop.

Additionally, `guard !Task.isCancelled else { break }` uses `break` inside a `repeat-while` loop, which is correct Swift, but the `while !Task.isCancelled` at the bottom still evaluates after the `break`, because `break` exits the loop body — this is correct. However, the guard check after the `exhale` sleep at line 128 is missing: there is a guard after `inhale` (line 114) and after `hold` (line 119), but none after `exhale` sleep completes before looping back. When the task is cancelled exactly during the exhale sleep, the loop condition `!Task.isCancelled` prevents a new iteration, but the absence of a guard means a cancelled-then-resumed scenario goes undetected at that point.

**Fix:**
```swift
private func stopSession() {
    phaseTask?.cancel()
    phaseTask = nil
    isRunning = false   // set AFTER cancel so UI state trails the task lifecycle
    currentPhase = .inhale
    withAnimation(.easeInOut(duration: 0.4)) { circleScale = 0.6 }
}
```
And add the missing guard after the exhale sleep at line 128:
```swift
try? await Task.sleep(for: .seconds(BreathePhase.duration))
guard !Task.isCancelled else { break }
```

---

### WR-02: `HRVSeriesStore` mutable state accessed outside lock in `schedulePersist` closure

**File:** `GooseSwift/HeartRateSeriesStores.swift:526-538` (HRVSeriesStore), also lines 298-316 (HeartRateSeriesStore)

**Issue:** Both `schedulePersist` implementations dispatch a closure to `writeQueue` that:
1. Acquires `stateLock`
2. Sets `self.pendingWrite = nil`
3. Reads `self.samples`
4. Releases `stateLock`
5. Calls `Self.persist(payload:to:)` outside the lock

The `pendingWrite` nil assignment (step 2) is inside the lock, which is correct. However, `HRVSeriesStore` is not marked `@unchecked Sendable` (unlike `HeartRateSeriesStore` which is). This means passing it across actor/task boundaries will produce a Swift Sendability error or require an explicit marker. More concretely, the `writeQueue` closure captures `self` with `[weak self]`, and the `guard let self` re-captures it; the subsequent lock/unlock correctly guards `pendingWrite = nil` and the `samples` snapshot. This pattern is sound for `HeartRateSeriesStore` which has the `@unchecked Sendable` marker, but `HRVSeriesStore` lacks it, making Swift's Sendability checker unable to verify the pattern is correct.

**Fix:** Add `@unchecked Sendable` to `HRVSeriesStore`:
```swift
final class HRVSeriesStore: @unchecked Sendable {
```
This makes the safety promise explicit and consistent with `HeartRateSeriesStore`.

---

### WR-03: `shouldAutoConnectDiscoveredWhoop` logic inverted — connects when IDs *differ*

**File:** `GooseSwift/GooseBLEClient+Parsing.swift:402-408`

**Issue:**
```swift
func shouldAutoConnectDiscoveredWhoop(_ peripheral: CBPeripheral) -> Bool {
    autoReconnectTargetID != nil
      && rememberedDeviceLooksLikeWhoop
      && activePeripheral == nil
      && rememberedDeviceID != nil
      && peripheral.identifier != rememberedDeviceID  // <-- !=
}
```
The function returns `true` when the discovered peripheral's UUID does **not** match the remembered device UUID. This looks semantically inverted: auto-reconnect should presumably connect to the *remembered* device (where IDs match), not to any different device. If this is intentional (connecting to a *different* device to try pairing a new one when the remembered one isn't present), the function name and callers must document this; as named, it is misleading and likely wrong.

**Fix (if the intent is to reconnect the remembered device):**
```swift
&& peripheral.identifier == rememberedDeviceID
```

---

### WR-04: `performRawExport` captures `self` strongly inside `DispatchQueue.global` — retained across export

**File:** `GooseSwift/MoreDataStore.swift:545-621`

**Issue:** The export closure at line 545 uses `self` without a `[weak self]` capture. `MoreDataStore` is a `@MainActor ObservableObject` owned by `MoreView` via `@StateObject`. During a long export (potentially minutes for large databases), the closure holds a strong reference to `self`, preventing deallocation if the user navigates away. While not an immediate crash, this creates an unexpected object lifetime and can cause delayed UI mutations (`self.rawExportInProgress = false`, etc.) to fire on a store that is no longer attached to any view. The main-thread `DispatchQueue.main.async` callbacks still execute and mutate `@Published` properties on a detached store.

**Fix:**
```swift
DispatchQueue.global(qos: .userInitiated).async { [weak self] in
    guard let self else { return }
    do {
        // ... rest unchanged
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.rawExportInProgress = false
            // ...
        }
    } catch { ... }
}
```

---

### WR-05: `imu_step_count_from_decoded_frames` ignores V18History step counter — only reads K10 accelerometer

**File:** `Rust/core/src/bridge.rs:3340-3395`

**Issue:** The `imu_step_count_from_decoded_frames_bridge` function title promises to count steps from decoded frames. It iterates all `decoded_frames_between` and only acts on `DataPacketBodySummary::RawMotionK10` frames (line 3361). The V18History frames (WHOOP 5.0 historical packets) carry a `step_motion_counter` field that already encodes a cumulative step count — and the upload bridge at line 3739 correctly reads it. The IMU step count bridge ignores V18 entirely, so calling `metrics.imu_step_count_from_decoded_frames` on a WHOOP 5.0 device (Gen5 v18 path) returns a step count of zero regardless of actual activity. The phase title "fix IMU step count to read from decoded" implies this was the intended fix but the V18 branch was not added.

**Fix:** Add a V18History arm after the K10 block:
```rust
} else if let Some(ParsedPayload::DataPacket {
    body_summary: Some(DataPacketBodySummary::V18History {
        gravity_x: Some(x),
        gravity_y: Some(y),
        gravity_z: Some(z),
        ..
    }),
    ..
}) = parsed {
    gravity_samples.push([*x as f64, *y as f64, *z as f64]);
}
```
Or, for true step counter semantics, accumulate `step_motion_counter` deltas from V18History frames instead of rerunning the imu_step_count_v1 pedometer.

---

### WR-06: `DailyJournalStore.save` silently discards encode failures — journal entry lost

**File:** `GooseSwift/CoachView.swift:791-796`

**Issue:**
```swift
static func save(_ entry: DailyJournalEntry) {
    var all = load()
    all[entry.dateKey] = entry
    if let data = try? JSONEncoder().encode(all) {
        UserDefaults.standard.set(data, forKey: key)
    }
    // If encode fails: entry is in `all` dict in memory, but nothing is persisted.
    // User sees the sheet dismiss (dismiss() called after save()) with no error.
}
```
`JSONEncoder().encode` can fail for various reasons (e.g., non-encodable values after future type changes). The failure is silently swallowed; `DailyJournalSheet.save()` calls `dismiss()` immediately after, giving the user no indication their journal entry was lost.

**Fix:**
```swift
static func save(_ entry: DailyJournalEntry) throws {
    var all = load()
    all[entry.dateKey] = entry
    let data = try JSONEncoder().encode(all)
    UserDefaults.standard.set(data, forKey: key)
}
```
And handle the error in `DailyJournalSheet.save()` with an alert.

---

## Info

### IN-01: `BreathePhase.duration` is a `static let` on the enum, not per-case — hold phase duration hardcoded equal to inhale/exhale

**File:** `GooseSwift/BreatheView.swift:15`

**Issue:** The breathing pattern uses a single `BreathePhase.duration = 4.0` for all three phases (inhale, hold, exhale). Standard paced-breathing protocols use different durations (e.g., 4-7-8 or box breathing 4-4-4-4). While this is a design decision, the `BreathePhase` enum already has a per-case switch for `label`, suggesting per-case durations were anticipated. If different durations are ever needed, the static constant must become a per-case computed property — at which point all callers need updating. Naming the constant on the enum type (rather than a per-case property) makes the mismatch subtle.

**Fix:** Use a per-case property from the start:
```swift
var duration: TimeInterval {
    switch self {
    case .inhale: 4.0
    case .hold:   4.0
    case .exhale: 4.0
    }
}
```

---

### IN-02: `CoachView` `init` creates a duplicate `CoachProviderRegistry` that is immediately thrown away

**File:** `GooseSwift/CoachView.swift:14-19`

**Issue:**
```swift
init(healthStore: HealthDataStore) {
    self.healthStore = healthStore
    let registry = CoachProviderRegistry()       // temporary — discarded
    self._registry = State(initialValue: registry)
    self._chat = State(initialValue: CoachChatModel(registry: registry))
}
```
`@State private var registry = CoachProviderRegistry()` at line 7 also initialises a `CoachProviderRegistry` that is overwritten in `init`. The initialiser at line 7 runs the default initialiser, then `init` overwrites it. This is idiomatic Swift but creates two `CoachProviderRegistry` objects on view init (the `@State` default and then the `let registry` in the body). Both are initialised and the first is discarded. This is a minor efficiency note, not a crash.

**Fix:** Remove the inline default initialiser from the property declaration if the `init` always overrides it:
```swift
@State private var registry: CoachProviderRegistry
```
(Then Swift requires the explicit init assignment, which is already present.)

---

### IN-03: `storage_check.rs` self-test uses hardcoded `DeviceType::Goose` — not portable to other device types

**File:** `Rust/core/src/storage_check.rs:232`

**Issue:** `parse_frame_hex(DeviceType::Goose, GET_HELLO_FRAME)` hardcodes the device type for the synthetic self-test frame. The self-test's purpose is to verify storage insert/query/roundtrip — the device type only matters for the parser, and using `Goose` is fine as a synthetic fixture. But the constant `GET_HELLO_FRAME` is also defined identically in `Rust/core/tests/protocol_tests.rs:8`, creating two sources of truth for the same byte sequence. If the test frame changes (parser update), one definition may be updated without the other.

**Fix:** Move `GET_HELLO_FRAME` to a shared test-fixture module or expose it as a `pub(crate)` constant from `storage_check.rs` and import it in the test file.

---

_Reviewed: 2026-06-13_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
