---
phase: 50-morning-band-sleep-sync
reviewed: 2026-06-10T12:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - GooseSwift/GooseAppModel+SleepSync.swift
  - GooseSwift/GooseAppModel+Lifecycle.swift
  - GooseSwift/GooseAppModel.swift
  - GooseSwift/AppShellView.swift
  - GooseSwift/HealthDataStore.swift
  - Rust/core/src/bridge.rs
  - Rust/core/tests/bridge_tests.rs
findings:
  critical: 1
  warning: 4
  info: 2
  total: 7
status: issues_found
---

# Phase 50: Code Review Report

**Reviewed:** 2026-06-10T12:00:00Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Phase 50 introduces morning band sleep sync: a polling loop that triggers BLE historical sync on reconnect, extracts gravity data from V24History frames, runs sleep staging, and inserts an external sleep session. The Rust side (gravity extraction, sleep import, duplicate prevention) is structurally sound. The Swift orchestration layer has one critical logic error that makes the BLE sync path always report timeout, plus several warnings around concurrency, API inconsistency, and test coverage gaps.

---

## Critical Issues

### CR-01: Poll loop checks `"complete"` but `historicalSyncStatus` never takes that value — BLE sync path always times out

**File:** `GooseSwift/GooseAppModel+SleepSync.swift:108`

**Issue:** The polling loop in `syncBandSleepHistory` waits for `ble.historicalSyncStatus == "complete"` to detect a successful BLE historical sync. That status string does not exist. The actual terminal success value set by `completeHistoricalSync` is `"synced"` (assigned at `GooseBLEClient+HistoricalHandlers.swift:672`). The only valid terminal states are `"synced"` (success) and `"failed"` (error). As written, every BLE sync that completes successfully will be silently missed: the loop runs all 120 iterations (120 s), then calls `markBandSleepSyncFailed("BLE historical sync timed out")` and returns early — skipping the sleep-staging and session-insert steps entirely, even though gravity data was already written to SQLite.

All possible values of `historicalSyncStatus` by source:

| Value | Source |
|-------|--------|
| `"idle"` | initial / reset via `GooseBLEClient+Parsing.swift:478` |
| `"waiting"` | pre-sync / range poll setup |
| `"syncing"` | `GooseBLEClient+HistoricalCommands.swift:36` |
| `"synced"` | success — `GooseBLEClient+HistoricalHandlers.swift:672` |
| `"failed"` | error — `GooseBLEClient+HistoricalHandlers.swift:706` |

`"complete"` is absent from the entire codebase.

**Fix:**
```swift
// GooseAppModel+SleepSync.swift line 108
// Change:
if status == "complete" {
  break
}
// To:
if status == "synced" {
  break
}
```

---

## Warnings

### WR-01: `GooseAppModel.rust` shared instance accessed concurrently without synchronisation

**File:** `GooseSwift/GooseAppModel+SleepSync.swift:79,124,163` / `GooseSwift/GooseRustBridge.swift:23`

**Issue:** `GooseRustBridge` is declared `@unchecked Sendable` and mutates two unprotected fields — `counter` (Int) and `lastTiming` (Optional<GooseRustBridgeTiming>) — on every `requestValue` call:

```swift
lastTiming = nil
counter += 1   // ← unguarded mutation
```

`GooseAppModel.rust` is the single shared `GooseRustBridge` instance. `syncBandSleepHistory` calls `rust.requestAsync(...)`, which internally spawns `Task.detached { try self.requestValue(...) }`, running the bridge call on an arbitrary thread. Meanwhile, synchronous `rust.request(...)` calls from `@MainActor`-isolated methods in `GooseAppModel+HealthCapture.swift` (lines 125, 203, 377, 417) and `GooseAppModel+ActivityRecording.swift` can run concurrently on the main thread. This creates an unsynchronised concurrent mutation of `counter` and `lastTiming` — a Swift data race.

The practical impact is limited (`counter` is cosmetic for request IDs; `lastTiming` is diagnostic), but the race is provable and the `@unchecked Sendable` marking suppresses Swift Concurrency's safety checks.

**Fix:** Either add an `NSLock` guard around `counter` and `lastTiming` mutations in `GooseRustBridge`, or — consistent with the rest of the codebase where each subsystem owns its own bridge — give `syncBandSleepHistory` a local `GooseRustBridge()` instance instead of using `self.rust`:

```swift
// GooseAppModel+SleepSync.swift — syncBandSleepHistory()
// Replace all uses of `rust.requestAsync` with a locally-scoped bridge:
let localRust = GooseRustBridge()
let gravityResult = try await localRust.requestAsync(...)
// ...
```

This matches the pattern already used by `runStorageCompactionIfNeeded` (which creates `let localRust = GooseRustBridge()` in a nonisolated context).

---

### WR-02: `healthStore` captured inconsistently — weak ref used directly on lines 137 and 175 after local strong ref captured on line 60

**File:** `GooseSwift/GooseAppModel+SleepSync.swift:60,137,175`

**Issue:** `syncBandSleepHistory` correctly captures the weak `healthStore` property into a local strong reference at line 60 (`let store = healthStore`). All method calls that flow through the `store?` path keep `HealthDataStore` alive even if `AppShellView` disappears mid-sync. However, lines 137 and 175 bypass this pattern and access `healthStore?` directly — the raw weak optional on `GooseAppModel`. If `AppShellView.onDisappear` fires and nils `model.healthStore` between the `await` suspension points at lines 136 and 174, those two status-string writes silently drop. The two status messages are:

- Line 137: `"A aguardar sincronização"` (written on `stagingMethod == "no_imu_data"`)
- Line 175: `"Sincronizado da pulseira"` (written on success)

This means a user can successfully complete a morning sync but see a stale status string if they navigate away at exactly the right moment.

**Fix:**
```swift
// GooseSwift/GooseAppModel+SleepSync.swift

// Line 136-139: replace healthStore? with store?
await MainActor.run {
  store?.bandSleepImportStatus = "A aguardar sincronização"
}

// Line 174-176: replace healthStore? with store?
await MainActor.run {
  store?.bandSleepImportStatus = "Sincronizado da pulseira"
}
```

---

### WR-03: Redundant `await MainActor.run {}` inside an already-`@MainActor`-isolated async method

**File:** `GooseSwift/GooseAppModel+SleepSync.swift:136,174`

**Issue:** `syncBandSleepHistory` is declared in an extension of `GooseAppModel`, which is annotated `@MainActor @Observable`. All non-`nonisolated` methods in this class run on the main actor. After each `await rust.requestAsync(...)` suspension, execution resumes on the main actor (Swift Concurrency guarantees actor re-entry to the same isolation domain). Wrapping property assignments in `await MainActor.run {}` is therefore redundant — it adds an unnecessary scheduling hop and an `async` annotation that misleadingly implies the code could be running off the main actor.

**Fix:** Remove the `await MainActor.run {}` wrappers and assign directly:

```swift
// Line 134-139 simplified:
guard stagingMethod != "no_imu_data" else {
  store?.bandSleepImportStatus = "A aguardar sincronização"
  return
}

// Line 173-176 simplified:
await store?.refreshSleepAfterBandSync(packetCount: 0)
store?.bandSleepImportStatus = "Sincronizado da pulseira"
```

---

### WR-04: `healthStore` may be `nil` if BLE fires `"ready"` before `AppShellView.onAppear`

**File:** `GooseSwift/AppShellView.swift:21` / `GooseSwift/GooseAppModel+SleepSync.swift:60`

**Issue:** `model.healthStore` is assigned inside `.onAppear` on `AppShellView`. `GooseAppModel.init` leaves `healthStore` as `nil`. If the BLE peripheral is already in "ready" state when the app launches (reconnect scenario), `handleBLEConnectionStateChange("ready")` is dispatched via `Task { @MainActor in ... }` — which can resolve before SwiftUI's first `.onAppear` cycle completes. In that case:

1. `maybeScheduleMorningSleepSync()` fires.
2. `syncBandSleepHistory()` runs with `store = healthStore` capturing `nil`.
3. All `store?.markBandSleepSync*` calls silently no-op — no status updates.
4. `store?.refreshSleepAfterBandSync(...)` at line 173 is a no-op — sleep scores are not refreshed in the UI even though the sync succeeded.
5. The UserDefaults key is written (line 58), preventing any retry today.

The user sees no sync progress and no updated sleep data.

**Fix:** Assign `model.healthStore` earlier — either in `AppShellView.init` or in a `.task {}` modifier that fires before the BLE state change task resolves. Alternatively, check in `syncBandSleepHistory` whether `healthStore` is still `nil` and delay/retry if so:

```swift
// GooseAppModel+SleepSync.swift — syncBandSleepHistory()
// At the top, before the UserDefaults write:
guard healthStore != nil else {
  // HealthStore not yet wired up — skip; maybeScheduleMorningSleepSync will not
  // retry today, so reset the guard here if the intent is to retry on next connect.
  return
}
UserDefaults.standard.set(Date(), forKey: Self.lastBandSleepSyncDateKey)
```

Or preferably, assign `model.healthStore` in `AppShellView` at init time rather than in `.onAppear`.

---

## Info

### IN-01: `gravity2` length gate `>= 60` is always satisfied when reached — dead condition

**File:** `Rust/core/src/protocol.rs:730`

**Issue:** The V24 body parser has an early return at `data.len() < 77`, which means the gravity2 triplet guard `if data.len() >= 60` is trivially true every time it is evaluated. The check communicates the protocol's intention (gravity2 is present only in longer payloads) but cannot actually gate anything shorter than 77 bytes. Additionally, `gravity2_z` requires `data[57..61]` (4 bytes), so the correct minimum for a complete triplet is `data.len() >= 61`, not `>= 60`. This is functionally harmless (masked by the `< 77` guard) but misleading.

**Fix:**
```rust
// protocol.rs line 730
let gravity2_x = if data.len() >= 61 { read_f32_le(data, 49) } else { None };
let gravity2_y = if data.len() >= 61 { read_f32_le(data, 53) } else { None };
let gravity2_z = if data.len() >= 61 { read_f32_le(data, 57) } else { None };
```

---

### IN-02: Phase 50 test suite missing coverage for `gravity2`, duplicate gravity insert idempotency, and non-empty `stage_summary`

**File:** `Rust/core/tests/bridge_tests.rs:9410-9707`

**Issue:** The four new Phase 50 tests cover the primary happy path well. Three gaps worth noting:

1. **gravity2 extraction is untested.** The `historical_k24_frame_hex_with_gravity` helper does not set gravity2_x/y/z bytes (offsets 49–60 in body / payload[52..61]). There is no test that verifies secondary gravity extraction or that `store.insert_gravity2_batch` receives correct data.

2. **Idempotency of gravity inserts via `upload.get_recent_decoded_streams` is untested.** Calling this method twice for the same frames should produce `INSERT OR IGNORE` no-ops on the second call. The roundtrip test (`bridge_v24_gravity_insert_roundtrip`) only calls it once.

3. **`sleep.import_external_history` with a populated `stage_summary` is untested.** Both Phase 50 session tests use `"stage_summary": {}`. The production code in `syncBandSleepHistory` passes actual `[String: Double]` from the staging result. A test that round-trips a non-empty stage summary would confirm the serialisation path.

These are not blocking — the Rust layer has existing `sleep.import_external_history` tests with stage data at earlier lines — but the Phase 50 helpers could benefit from gravity2 coverage.

**Fix:** Add a `historical_k24_frame_hex_with_gravity2` helper and corresponding extraction test; add a double-call idempotency test for `upload.get_recent_decoded_streams`.

---

_Reviewed: 2026-06-10T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
