---
phase: 72-screens-on-new-foundation-service-layer
reviewed: 2026-06-13T12:00:00Z
depth: standard
files_reviewed: 28
files_reviewed_list:
  - GooseSwift/CoachView.swift
  - GooseSwift/GooseAppModel+NotificationPipeline.swift
  - GooseSwift/GooseBLEClient+HistoricalCommands.swift
  - GooseSwift/GooseBLEClient+HistoricalHandlers.swift
  - GooseSwift/GooseBLEClient+Parsing.swift
  - GooseSwift/GooseBLEManaging.swift
  - GooseSwift/GooseRustBridging.swift
  - GooseSwift/HealthDashboardViews.swift
  - GooseSwift/HealthDataStore+Snapshots.swift
  - GooseSwift/HealthDataStore+StaticSnapshots.swift
  - GooseSwift/HealthDataStore.swift
  - GooseSwift/HealthDataStoring.swift
  - GooseSwift/HealthModels.swift
  - GooseSwift/HealthRecoveryStressViews.swift
  - GooseSwift/HealthView.swift
  - GooseSwift/ManualWorkoutEntryViews.swift
  - GooseSwift/MoreDebugViews.swift
  - GooseSwift/TrendsDashboardViews.swift
  - GooseSwiftTests/MockBLEClient.swift
  - GooseSwiftTests/MockHealthStore.swift
  - GooseSwiftTests/MockRustBridge.swift
  - GooseSwiftTests/TrendsFetchTests.swift
  - GooseSwiftTests/WorkoutEntryTests.swift
  - Rust/core/src/bridge.rs
  - Rust/core/src/historical_sync.rs
  - Rust/core/src/storage_check.rs
  - Rust/core/src/store.rs
  - Rust/core/tests/protocol_tests.rs
findings:
  critical: 4
  warning: 7
  info: 4
  total: 15
status: issues_found
---

# Phase 72: Code Review Report

**Reviewed:** 2026-06-13T12:00:00Z
**Depth:** standard
**Files Reviewed:** 28
**Status:** issues_found

## Summary

Phase 72 introduced protocol abstractions (`GooseBLEManaging`, `GooseRustBridging`, `HealthDataStoring`), mock test doubles, two new test suites, a `ManualWorkoutEntryViews` workout entry sheet with a `WorkoutEntryViewModel`, a `TrendsDashboardView`, and refactored `HealthDataStore` extensions. The Rust files reviewed are pre-existing modules with no phase-specific changes; they are clean at this depth.

The critical findings centre on three issues: (1) a data-race on the `frameReassemblyBuffers` dictionary accessed from `notificationIngestQueue` as `nonisolated`, (2) the mock `fetchTrendsSeries` silently discards the bridge response and always returns `[]`, making the test vacuous for the actual date-range mapping logic, (3) `WorkoutEntryViewModel.submitWorkout()` does not call the bridge's synchronous `request` path and silently eats the error message—the error is overwritten regardless of the exception type—and (4) `HealthRouteDetailView` constructs a new `HealthDataStore()` from inside a SwiftUI `View.init`, which means every navigation re-renders produce independent, isolated stores that never receive the ambient `packetScoreStatus` that the parent injected.

---

## Critical Issues

### CR-01: Data race on `frameReassemblyBuffers` — `nonisolated` function reads/writes a stored dictionary

**File:** `GooseSwift/GooseAppModel+NotificationPipeline.swift:802-859`

**Issue:** `gooseFrames(in:event:)` is `nonisolated` and is called from `notificationIngestQueue` (a background `DispatchQueue`). It reads and writes `frameReassemblyBuffers[key]` directly. `GooseAppModel` is `@MainActor`, so `frameReassemblyBuffers` is owned by the main actor. Reading and mutating it from a background queue without synchronisation is an unprotected data race. Swift's actor isolation rules are bypassed by `nonisolated` here — the compiler does not enforce actor-isolation for stored properties accessed through `nonisolated` methods.

The code comment says "This function is intentionally NOT @MainActor", and the queue is a private `DispatchQueue`, but `nonisolated` on a method of a `@MainActor` class does **not** move property access off the main actor — it just removes the warning. Any concurrent read/write of `frameReassemblyBuffers` is therefore a race.

**Fix:** Either protect the buffer with a dedicated `NSLock` (consistent with the pattern used for `notificationIngestStateLock` elsewhere in the file), or move the reassembly state into a separate lock-protected value type:

```swift
private let frameReassemblyLock = NSLock()
private var _frameReassemblyBuffers: [String: Data] = [:]

nonisolated func gooseFrames(in data: Data, event: GooseNotificationEvent) -> FrameReassemblyResult {
  let key = frameReassemblyKey(for: event)
  frameReassemblyLock.lock()
  defer { frameReassemblyLock.unlock() }
  // ... operate on _frameReassemblyBuffers ...
}
```

---

### CR-02: `MockHealthStore.fetchTrendsSeries` always returns `[]` — test only verifies the method string, not the data path

**File:** `GooseSwiftTests/MockHealthStore.swift:15-25`

**Issue:** `MockHealthStore.fetchTrendsSeries` calls the bridge (correctly recording the method name), but then ignores the bridge's `stubbedResult["rows"]` entirely and hard-codes `return []`. This means `TrendsFetchTests.test_fetchTrendsSeries_calls_metric_series_query_range` only verifies that the correct bridge method string is invoked; it does not test that the real `HealthDataStore.fetchTrendsSeries` correctly maps `rows` from the response into `(date: String, value: Double)` tuples. The mock deviates from the real implementation's logic.

When `stubbedResult["rows"]` contains actual row data (e.g. `[["date": "2026-06-10", "value": 72.0]]`), the test silently returns `[]` instead of `[(date: "2026-06-10", value: 72.0)]`, so a regression in row-mapping code would go undetected.

**Fix:** Make the mock decode rows from `stubbedResult` the same way the real store does, or add a separate test that exercises the real `HealthDataStore.fetchTrendsSeries` with a mock bridge via `GooseRustBridging`:

```swift
func fetchTrendsSeries(metricName: String, days: Int) async throws -> [(date: String, value: Double)] {
  let result = try await bridge.requestAsync(
    method: "metric_series.query_range",
    args: ["database_path": databasePath, "metric_name": metricName,
           "start_date": startDate, "end_date": endDate]
  )
  let rows = result["rows"] as? [[String: Any]] ?? []
  return rows.compactMap { row in
    guard let date = row["date"] as? String,
          let value = row["value"] as? Double else { return nil }
    return (date: date, value: value)
  }
}
```

---

### CR-03: `WorkoutEntryViewModel` error message is overwritten — real error detail is lost

**File:** `GooseSwift/ManualWorkoutEntryViews.swift:50-53`

**Issue:** In `submitWorkout()`, the `catch` block sets `errorMessage = "Could not save workout. Please try again."` and discards the actual error. This is not inherently a bug, but the immediately preceding success path does `isSubmitting = false` and then has the comment `// success — caller dismisses`. The structural problem is that after `try await bridge.requestAsync(...)`, the success path does **not** call `dismiss()` — it is the responsibility of the call site in the `Button` closure:

```swift
await vm.submitWorkout()
if vm.errorMessage == nil { dismiss() }
```

This means the `isSubmitting = true` flag is set at line 25, but if `bridge.requestAsync` throws AND the thrown error sets `errorMessage`, the `isSubmitting` flag is reset via `isSubmitting = false` in the catch block. The UI button is re-enabled. This is correct. However, the flag is also set back to `false` in the success path — but the `isSubmitting = false` in the success path at line 49 runs **before** the caller's `dismiss()`. The UI will briefly flash the Log button as re-enabled before the sheet closes. More critically, there is no guard against double-submission: if the `Log` button is tapped, sets `isSubmitting = true`, disables the button, but a `Task` re-entry is possible because `Task { ... }` is not cancellation-tracked. A second tap while `isSubmitting == true` is prevented by `.disabled(!vm.isFormValid || vm.isSubmitting)`, but only while the button evaluates — a very fast double-tap before SwiftUI re-renders could bypass this.

The actual blocker is different: the error message is a static string that hides the real failure cause from debug logs. The `error.localizedDescription` is silently dropped, making it impossible to diagnose bridge failures in production.

**Fix:** Log the real error before replacing it with user-facing text:

```swift
} catch {
  // Keep user-facing message brief; log details for debugging
  print("[WorkoutEntryViewModel] submitWorkout failed: \(error)")
  errorMessage = "Could not save workout. Please try again."
  isSubmitting = false
}
```

Or surface via a separate `debugError` property used in debug builds.

---

### CR-04: `HealthRouteDetailView` creates an isolated `HealthDataStore()` per-navigation — data is orphaned

**File:** `GooseSwift/HealthDashboardViews.swift:305-322`

**Issue:** `HealthRouteDetailView.init` constructs `HealthDataStore()` fresh and stores it in `@State`. This isolated store never receives `packetScoreStatus`, `packetInputReports`, or any other state from the ancestor `HealthDataStore` passed to `HealthView` and `AppShellView`. Every navigation to a sub-route via `HealthRouteDetailView` shows a blank, unloaded store state, requiring the user to wait while `loadBridgeCatalogsIfNeeded` re-runs.

This is especially impactful for `HealthRouteContentView(route:store:)` called from `HealthView.navigationDestination` — that path passes the *correct* shared store (line 49 in `HealthView.swift`). But `HealthRouteDetailView` is also used directly in previews and can be placed anywhere as a standalone view, creating silent divergence between the two paths for the same route.

**Fix:** Remove the isolated store creation from `HealthRouteDetailView` or require an external store to be injected (use `@Environment` or a parameter):

```swift
struct HealthRouteDetailView: View {
  let route: HealthRoute
  // Inject from the calling context instead of creating a new store
  var store: HealthDataStore

  init(route: HealthRoute, store: HealthDataStore) {
    self.route = route
    self.store = store
  }
  // ...
}
```

---

## Warnings

### WR-01: `GooseBLEManaging` protocol surface is too narrow to be useful for tests

**File:** `GooseSwift/GooseBLEManaging.swift:1-10`

**Issue:** The protocol declares only `connectionState`, `isScanning`, `startScanning()`, and `stopScanning()`. However, `GooseAppModel+NotificationPipeline.swift` accesses `ble.liveHeartRateBPM`, `ble.liveHeartRateSource`, `ble.liveHeartRateUpdatedAt`, `ble.record(...)`, `ble.activeDeviceName`, etc. — none of which are on the protocol. This means the abstraction cannot be used to inject a mock BLE client into `GooseAppModel`; `MockBLEClient` is a test double with no caller. The protocol comment says "extend as test coverage grows" but no existing test uses it to drive `GooseAppModel` behaviour. The abstraction is currently dead weight.

**Fix:** Either extend the protocol to cover the properties actually used by `GooseAppModel` and `GooseAppModel+NotificationPipeline`, or remove the protocol until it is genuinely needed. An unused abstraction adds complexity with no benefit.

---

### WR-02: `HealthDataStoring` protocol is too narrow — `fetchTrendsSeries` default `days:` parameter not declared

**File:** `GooseSwift/HealthDataStoring.swift:6-8`

**Issue:** The protocol declares `fetchTrendsSeries(metricName:days:)` without a default value. The concrete implementation has `days: Int = 7`. Callers of the protocol must always supply `days:` explicitly, even though the real store has a sensible default. Callers that use `HealthDataStoring` (e.g. future code that only has the protocol) will either fail to compile or must repeat `7` everywhere.

**Fix:**

```swift
protocol HealthDataStoring: AnyObject {
  var databasePath: String { get }
  func fetchTrendsSeries(metricName: String, days: Int) async throws -> [(date: String, value: Double)]
}
// And document that 7 is the standard default for callers
```

This is not a compile error today (the protocol works), but it breaks the abstraction contract intent. At minimum, add a protocol extension with the default:

```swift
extension HealthDataStoring {
  func fetchTrendsSeries(metricName: String) async throws -> [(date: String, value: Double)] {
    try await fetchTrendsSeries(metricName: metricName, days: 7)
  }
}
```

---

### WR-03: `TrendsDashboardView.loadTrends()` — all three bridge errors are silently swallowed

**File:** `GooseSwift/TrendsDashboardViews.swift:38-46`

**Issue:** All three `async let` expressions use `try? await` — bridge errors are discarded and produce `[]`. If the Rust bridge is unavailable (e.g. database path missing, schema mismatch), the view silently shows "No data for the last 7 days" with no indication that an error occurred. There is no `isError` state or error message propagation.

**Fix:** Track error state and show an appropriate message:

```swift
@State private var loadError: String? = nil

private func loadTrends() async {
  isLoading = true
  loadError = nil
  do {
    async let recovery = try await store.fetchTrendsSeries(metricName: "recovery")
    async let hrv = try await store.fetchTrendsSeries(metricName: "hrv")
    async let sty await store.fetchTrendsSeries(metricName: "strain")
    recoveryPoints = try await recovery
    hrvPoints = try await hrv
    strainPoints = try await strain
  } catch {
    loadError = error.localizedDescription
  }
  isLoading = false
}
```

---

### WR-04: `DailyJournalStore` — all calls on main thread with synchronous `UserDefaults` encode/decode in `View.onAppear`

**File:** `GooseSwift/CoachView.swift:782-800`

**Issue:** `DailyJournalStore.load()` decodes a potentially large JSON dictionary from `UserDefaults` on the main thread. `save(_:)` does the reverse. Both are called from `View.onAppear` and `sheet.onDismiss` — synchronous main-thread JSON decode/encode. As the journal grows (one entry per day, indefinitely retained), this will block the main thread proportionally. There is no bound on the number of entries stored.

**Fix:** Run decode/encode on a background queue and update the `@State` on the main actor. Also add a maximum retention limit (e.g. keep last 365 entries only).

---

### WR-05: `ManualWorkoutEntrySheet` constructs `WorkoutEntryViewModel` using the concrete `store.bridge` — bypasses the protocol abstraction

**File:** `GooseSwift/ManualWorkoutEntryViews.swift:63-67`

**Issue:** `ManualWorkoutEntrySheet.init(store: HealthDataStore)` reaches into `store.bridge` (the concrete `GooseRustBridge` property on `HealthDataStore`) rather than accepting any `GooseRustBridging`. This defeats the injection protocol. If the phase's goal was to make `ManualWorkoutEntrySheet` testable through the protocol layer, this init creates a hard dependency on the concrete store type.

**Fix:** Accept the store as `HealthDataStoring` (if the protocol is extended to expose `bridge`), or accept the bridge directly:

```swift
init(bridge: any GooseRustBridging, databasePath: String) {
  _vm = StateObject(wrappedValue: WorkoutEntryViewModel(bridge: bridge, databasePath: databasePath))
}
```

Call site in `HealthView`:
```swift
ManualWorkoutEntrySheet(bridge: store.bridge, databasePath: store.databasePath)
```

---

### WR-06: `TrendsFetchTests` contains a duplicated test — `test_workout_entry_calls_workout_upsert` is also in `WorkoutEntryTests`

**File:** `GooseSwiftTests/TrendsFetchTests.swift:17-27`

**Issue:** `TrendsFetchTests` has a second test function `test_workout_entry_calls_workout_upsert` that is completely unrelated to trends fetching. The identical assertion exists in `WorkoutEntryTests.test_submit_calls_workout_upsert`. The duplicate is a noise test in the wrong file; it also partially duplicates coverage that `WorkoutEntryTests` covers more thoroughly (the latter asserts all args fields).

**Fix:** Remove `test_workout_entry_calls_workout_upsert` from `TrendsFetchTests`.

---

### WR-07: `GooseAppModel+NotificationPipeline.swift` — `nonisolated func notificationIngestResult` accesses `frameReassemblyBuffers` from a non-actor context

**File:** `GooseSwift/GooseAppModel+NotificationPipeline.swift:698-733`

**Issue:** This is the caller of `gooseFrames(in:event:)` (CR-01). Additionally, `notificationIngestResult` itself is `nonisolated`, yet it calls the also-`nonisolated` `gooseFrames`, and both share `frameReassemblyBuffers`. The comment correctly notes that HR monitor notifications must stay off the main thread, but the solution of using `nonisolated` without a lock is incomplete. The `notificationIngestQueue` serialises calls through one queue, but `gooseFrames` could theoretically be called from two different events on the same queue concurrently (the queue has `qos: .userInitiated` and async blocks can interleave if submitted in bursts). In practice a serial queue prevents this, but the serial nature of the queue is an undocumented invariant that CR-01's lock would make explicit and safe.

**Fix:** Same as CR-01 — add an explicit `NSLock` protecting `frameReassemblyBuffers`.

---

## Info

### IN-01: `CoachView` — `CoachOverviewSnapshot.make` is a `@MainActor static func` marked both `@MainActor` and calling `HealthDataStore.relativeText(for:)` on line 257

**File:** `GooseSwift/CoachView.swift:189-275`

**Issue:** `CoachOverviewSnapshot.make` accesses `appModel.ble.liveHeartRateUpdatedAt` and calls `HealthDataStore.relativeText(for:appModel.ble.liveHeartRateUpdatedAt)` on line 257. This is correct (method is nonisolated). Minor: the static property `CoachOverviewSnapshot` is a private value type; creating two instances of `CoachOverviewSnapshot` per `onChange(of: healthStore.packetScoreStatus)` notification is potentially wasteful given the snapshot contains six snapshots + two highlights + up to five data-gap objects.

**Fix:** No action required for correctness; consider memoising the snapshot per packetScoreStatus + packetInputStatus pair if profiling shows layout cost.

---

### IN-02: `DailyJournalEntry.id` is always equal to `dateKey` — only one entry per day is possible by design, but this is not documented

**File:** `GooseSwift/CoachView.swift:755-770`

**Issue:** `id = dateKey` means two entries on the same day would collide in `Identifiable` contexts (e.g. `ForEach`). The store only keeps one entry per day (the `save` function overwrites by `dateKey`), so in practice this works. However, there is no enforcement at the type level and the intent is not documented. If a future change tries to store multiple entries per day, `ForEach` would silently show only the first.

**Fix:** Add a comment at the `id` declaration: `// id == dateKey: one entry per calendar day; the store enforces uniqueness`.

---

### IN-03: `HealthView` — `bpmRefreshTask` cancellation relies on implicit `Task.isCancelled` check after `Task.sleep`

**File:** `GooseSwift/HealthView.swift:82-86`

**Issue:** The `bpmRefreshTask` pattern is correct — it cancels the prior task before creating a new one. The `try? await Task.sleep(...)` call will throw `CancellationError` when cancelled (silently discarded by `try?`), and the guard correctly checks `Task.isCancelled`. This is fine. Minor: if `refreshSnapshots()` itself were to become async, the pattern would need updating. This is an observation, not a defect.

**Fix:** No action required.

---

### IN-04: `MockRustBridge.request` (synchronous) and `requestAsync` both mutate `lastMethod`/`lastArgs` — concurrent test isolation not guaranteed

**File:** `GooseSwiftTests/MockRustBridge.swift:11-23`

**Issue:** `MockRustBridge` is not thread-safe. Both `request` and `requestAsync` write `lastMethod` and `lastArgs` without synchronisation. In the current tests this is not a problem because tests are `@MainActor` or use a single `await`. If future tests add concurrency or run from multiple threads, the recorded values will be racy.

**Fix:** Annotate `MockRustBridge` with `@MainActor` or add a lock for `lastMethod` and `lastArgs`.

---

_Reviewed: 2026-06-13T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
