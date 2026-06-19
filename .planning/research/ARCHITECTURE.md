# Architecture Research

**Domain:** iOS biometric app — WHOOP BLE + Rust core + SwiftUI
**Researched:** 2026-06-12
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           SwiftUI View Layer                             │
│  ┌───────────┐ ┌──────────┐ ┌──────────────┐ ┌────────────────────────┐ │
│  │ HomeView  │ │HealthView│ │  CoachView   │ │MoreView / SleepCoach  │ │
│  │ Dashboard │ │Stress/   │ │  VOW Card    │ │AlarmUI / BreatheView  │ │
│  │           │ │Trends    │ │  ChatRoutes  │ │IntervalTimer          │ │
│  └─────┬─────┘ └────┬─────┘ └──────┬───────┘ └──────────┬────────────┘ │
└────────┼────────────┼──────────────┼────────────────────┼──────────────┘
         │            │              │                    │
┌────────▼────────────▼──────────────▼────────────────────▼──────────────┐
│                     @MainActor Coordinator Layer                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  GooseAppModel (@MainActor @Observable)                          │   │
│  │  + NotificationPipeline  + ActivityRecording  + BandFirstSync    │   │
│  │  + Upload  + SleepSync   + HealthCapture     + Lifecycle         │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  HealthDataStore (@MainActor @Observable, async/await)            │  │
│  │  + Snapshots + Sleep + Cardio + Trends + Stress + PacketInputs   │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
         │                          │
┌────────▼──────────┐   ┌───────────▼──────────────────────────────────┐
│  BLE Layer        │   │   Service Layer (v10.0 new)                  │
│  GooseBLEClient   │   │  GooseHapticService     (HAP-01/02/03)       │
│  + CentralDelegate│   │  GooseBLEHistoricalManager  (BLE5-03)        │
│  + Commands       │   │  GooseStrainAccumulator     (DATA-02)        │
│  + HistoricalCmds │   │  GooseWakeWindowManager     (HAP-04)         │
│  + Parsing        │   │  GooseNotificationService   (FEAT-03)        │
│  + UserActions    │   │  GooseHRDecimator           (DATA-04)        │
│  GooseBLEDataVal. │   │  GooseCoachVOWService       (FEAT-01)        │
│  (BLE5-04 new)    │   └──────────────────────────────────────────────┘
│  GooseBLEBonding  │
│  GooseHRSanitizer │
└────────┬──────────┘
         │  coreBluetoothQueue (dedicated DispatchQueue)
┌────────▼─────────────────────────────────────────────────────────────┐
│  Background Queue Layer                                               │
│  notificationIngestQueue  notificationParseQueue  captureFrameRowBuild│
│  rustStartupQueue         heart-rate-series       com.goose.swift.*  │
└────────┬──────────────────────────────────────────────────────────────┘
         │
┌────────▼──────────────────────────────────────────────────────────────┐
│  Rust Core (libgoose_core — stateless, synchronous FFI)                │
│  bridge.rs (58+ methods) → protocol.rs / store.rs / historical_sync.rs│
│  + R22 parser (BLE5-01 new)   + v18 decoder (BLE5-02 new)             │
│  + journal/workout/appleDaily/metricSeries tables (DATA-01 new)        │
│  + coach.vow_message() (FEAT-01 new)                                   │
└────────┬──────────────────────────────────────────────────────────────┘
         │
┌────────▼──────────────────────────────────────────────────────────────┐
│  Persistence Layer                                                     │
│  goose.sqlite (rusqlite bundled)  HeartRateSeriesStore (JSON on disk) │
│  UserDefaults (config/watermarks) Keychain (Bearer token)             │
└───────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities — Existing (v9.0 baseline)

| Component | Responsibility | File(s) |
|-----------|----------------|---------|
| `GooseAppModel` | @MainActor coordinator; owns BLE client, queues, pipelines, upload | `GooseAppModel.swift` + 9 extension files |
| `HealthDataStore` | @MainActor metric query layer; async/await bridge calls per metric family | `HealthDataStore.swift` + extension files |
| `GooseBLEClient` | CoreBluetooth central; WHOOP GATT; BLE command writes; historical sync orchestration | `GooseBLEClient.swift` + 10 extension files |
| `GooseRustBridge` | Synchronous JSON-over-FFI; never call from @MainActor | `GooseRustBridge.swift` |
| `CaptureFrameWriteQueue` | Batched SQLite inserts of BLE frames via Rust bridge | `CaptureFrameWriteQueue.swift` |
| `HeartRateSeriesStore` | In-memory + persisted HR series; singleton; NSLock-protected | `HeartRateSeriesStores.swift` |
| `WhoopDataSignalPipeline` | Routes WhoopDataSignalSample to HR pipeline + passive detector | `WhoopDataSignalPipeline.swift` |
| `PassiveActivityDetectionPipeline` | Heuristic motion/HR workout detection | `PassiveActivityDetector.swift` |
| `GooseBLEBondingManager` | 5-state bonding state machine (v9.0) | `GooseBLEBondingManager.swift` |
| `GooseNetworkMonitor` | NWPathMonitor; publishes `isReachable` to GooseAppModel (v9.0) | `GooseNetworkMonitor.swift` |
| `GooseHRSanitizer` | HR spike filter 25-220 BPM; spike counter (v9.0) | `GooseHRSanitizer.swift` |
| `StateMachine<State, Event>` | Generic state machine type (v9.0) | `GooseStateMachine.swift` |

---

## New Components for v10.0 — Classification

### Strictly New Files

| Component | ID | Purpose | Integration Point |
|-----------|----|---------|-------------------|
| `GooseBLEHistoricalManager` | BLE5-03 | Dedicated historical sync lifecycle; decouples from `GooseBLEClient` | `GooseAppModel+BandFirstSync.swift` replaces direct `ble.syncHistoricalPackets()` calls |
| `GooseBLEDataValidator` | BLE5-04 | Swift-side frame validation before Rust/SQLite ingestion | Inserted into `CaptureFrameWriteQueue` and/or `NotificationFrameParsing.swift` |
| `GooseHapticService` | HAP-01/02 | Orchestrates `buzz(loops:)` calls and Breathe session pacing | Owned by `GooseAppModel`; calls `ble.buzz()` on the BLE client |
| `GooseWakeWindowManager` | HAP-04 | Wake-window alarm orchestration; sleep-stage polling fallback | Owned by `GooseAppModel`; calls `ble.setWindowedAlarm()` |
| `GooseNotificationService` | FEAT-03 | UNUserNotificationCenter wrapper; sleep summary + workout + battery | Actor; called from `GooseAppModel` lifecycle triggers |
| `GooseStrainAccumulator` | DATA-02 | Real-time Swift-side strain accumulator during live workouts | Subscribes to `WhoopDataSignalPipeline`; owned by `GooseAppModel` |
| `GooseHRDecimator` | DATA-04 | LTTB decimation of HR samples before chart rendering | Applied in `HeartRateSeriesStore` before publishing to views |
| `GooseCoachVOWView` | FEAT-01 | SwiftUI banner/card showing bridge-computed VOW coaching nudge | Inserted into `CoachViews.swift` top section |
| `GooseBLEManaging` (protocol) | ARCH-01 | Protocol extracted from `GooseBLEClient` | New file; conformance added to `GooseBLEClient` |
| `GooseRustBridging` (protocol) | ARCH-01 | Protocol extracted from `GooseRustBridge` | New file; conformance added to `GooseRustBridge` |
| `GooseAppServicing` (protocol) | ARCH-01 | Top-level service protocol wrapping BLE + bridge + health store | New file |
| `GooseBLEClientMock` | ARCH-01 | Test double for `GooseBLEManaging` | Test target only (`#if DEBUG`) |
| `GooseRustBridgeMock` | ARCH-01 | Test double for `GooseRustBridging` (fixture JSON) | Test target only (`#if DEBUG`) |

### Modifications to Existing Files

| File | Change | ID |
|------|--------|----|
| `Rust/core/src/protocol.rs` | Add R22 (0x10) packet type variant + `parse_r22_body()`; split v18 arm from `7|9|12|18` to `parse_v18_body()` | BLE5-01, BLE5-02 |
| `Rust/core/src/historical_sync.rs` | Add stale-clock dedup (86400s threshold + 300s grid snap); EVENT type-48 timestamp bypass | BLE5-02 |
| `Rust/core/src/store.rs` | Add `run_migrations()` for 4 new tables: `journal`, `workout`, `appleDaily`, `metricSeries` + helpers | DATA-01 |
| `Rust/core/src/bridge.rs` | New dispatch arms: `journal.*`, `workout.*`, `apple_daily.*`, `metric_series.*`, `coach.vow_message` | DATA-01, FEAT-01 |
| `GooseSwift/GooseBLEClient+Commands.swift` | Add `buzz(loops: UInt8)` — cmd 0x13 puffin frame (~15 lines) | HAP-01 |
| `GooseSwift/GooseBLEClient+HistoricalCommands.swift` | Reduce to pure BLE command writes; move orchestration to `GooseBLEHistoricalManager` | BLE5-03 |
| `GooseSwift/GooseBLEClient+HistoricalHandlers.swift` | Move sync lifecycle callbacks to `GooseBLEHistoricalManager` | BLE5-03 |
| `GooseSwift/GooseAppModel+BandFirstSync.swift` | Replace `ble.syncHistoricalPackets()` calls with `historicalManager.beginSync()` | BLE5-03 |
| `GooseSwift/CaptureFrameWriteQueue.swift` | Insert `GooseBLEDataValidator` validation step before Rust bridge call | BLE5-04 |
| `GooseSwift/NotificationFrameParsing.swift` | Optional early validation hook for frame type + length before reassembly | BLE5-04 |
| `GooseSwift/WhoopDataSignalPipeline.swift` | Feed samples to `GooseStrainAccumulator` on sample arrival | DATA-02 |
| `GooseSwift/GooseAppModel+ActivityRecording.swift` | Wire `GooseStrainAccumulator` reset on session start/stop | DATA-02 |
| `GooseSwift/HeartRateSeriesStores.swift` | Apply `GooseHRDecimator` before publishing to chart views | DATA-04 |
| `GooseSwift/GooseBLEClient.swift` | Add conformance to `GooseBLEManaging` protocol | ARCH-01 |
| `GooseSwift/GooseRustBridge.swift` | Add conformance to `GooseRustBridging` protocol | ARCH-01 |
| `GooseSwift/HealthKitFullImporter.swift` | Write to `appleDaily` bridge method instead of mixed daily tables | DATA-01 |
| `GooseSwift/CoachViews.swift` | Insert `GooseCoachVOWView` at top of Coach tab | FEAT-01 |

### New SwiftUI Screens (DATA-03, FEAT-02)

| File | Screen | Prerequisite |
|------|--------|--------------|
| `GooseSwift/FitnessManualWorkoutSheet.swift` | Manual workout entry/edit sheet | `workout` table (DATA-01) |
| `GooseSwift/HealthTrendsDashboardView.swift` | Long-range trends dashboard | `metricSeries` table (DATA-01) |
| `GooseSwift/HealthStressViews.swift` | Stress/ANS additions (calm time, baseline-delta, range selector) | None |
| `GooseSwift/BreatheView.swift` | Breathe HRV-biofeedback screen | HAP-01 (`buzz(loops:)`) |
| `GooseSwift/IntervalTimerView.swift` | Interval timer with strap haptic cues | HAP-01 (`buzz(loops:)`) |
| `GooseSwift/MetricExplorerView.swift` | Arbitrary metric key browsing | `metricSeries` table (DATA-01) |

---

## Recommended Build Order — Dependency Graph

```
BLE5-01 (R22 Rust parser)
    |-- feeds metric pipeline for WHOOP 5.0 users
BLE5-02 (v18 historical decode + stale-clock)
    |-- completes WHOOP 5.0 historical offload
BLE5-03 (GooseBLEHistoricalManager)
    |-- depends on BLE5-01/02 for full test coverage; also depends on ARCH-01 for mocks
BLE5-04 (GooseBLEDataValidator)
    |-- independent of BLE5-01/02/03 -- can build in parallel with Wave 2
ARCH-01 (protocol layer + mocks)
    |-- unblocks unit tests for BLE5-03, DATA-02, HAP-01+
HAP-01 (buzz primitive -- GooseBLEClient+Commands.swift)
    |-- HAP-02 (Breathe screen + GooseHapticService)
    |-- HAP-03 (smart alarm UI, event-57 RE required first)
    |-- HAP-04 (GooseWakeWindowManager -- after HAP-03 event-57 and RE SetAlarmInfoCommandPacketRev4)
DATA-01 (4 SQLite tables: metricSeries -> journal -> workout -> appleDaily)
    |-- DATA-03 Screen 1: Stress additions (independent of DATA-01, build first)
    |-- DATA-03 Screen 2: Manual Workout Entry (needs workout table)
    |-- DATA-03 Screen 3: Trends Dashboard (needs metricSeries table)
DATA-02 (GooseStrainAccumulator)
    |-- independent; depends on WhoopDataSignalPipeline (already exists)
DATA-04 (GooseHRDecimator)
    |-- fully independent; add only after Instruments profile confirms render issue
FEAT-01 (Coach VOW -- Rust bridge.rs + GooseCoachVOWView)
    |-- depends on existing bridge metrics; no new tables needed for v1
FEAT-02 (NoopApp: Breathe, Interval Timer, Metric Explorer)
    |-- Breathe/Intervals depend on HAP-01; MetricExplorer depends on DATA-01 metricSeries
FEAT-03 (GooseNotificationService)
    |-- independent; uses PassiveActivityDetector callbacks + sleep sync + BLE battery
```

### Recommended Phase Wave Order

**Wave 1 — Foundation (no dependencies, highest user impact)**
1. BLE5-01: R22 parser (Rust only, ~1 day) — fixes WHOOP 5.0 users seeing zero metrics
2. DATA-01: 4 SQLite tables, implementation order: metricSeries, journal, workout, appleDaily
3. ARCH-01: Protocol layer + mocks (Phase 1 protocols, Phase 2 mocks, Phase 3 tests together — only if test target can be added)

**Wave 2 — Protocol completeness + buzz prerequisite**
4. BLE5-02: v18 decode + stale-clock (Rust only, ~1 day) — completes WHOOP 5.0 historical offload
5. HAP-01: `buzz(loops:)` primitive — 2 hours; gates all HAP-02/03/04 and FEAT-02 Breathe/Intervals
6. BLE5-03: GooseBLEHistoricalManager — depends on ARCH-01 mocks for tests
7. BLE5-04: GooseBLEDataValidator — insertable independently after BLE5-03 refactor settles

**Wave 3 — Features (parallel, all Wave 1+2 gates met)**
8. HAP-02: GooseHapticService + Breathe screen
9. HAP-03: Smart alarm UI (BTSnoop session to capture event-57 required before implementation)
10. HAP-04: GooseWakeWindowManager (after HAP-03 event-57 resolved; RE SetAlarmInfoCommandPacketRev4)
11. DATA-02: GooseStrainAccumulator
12. FEAT-01: Coach VOW (Rust method + SwiftUI card)
13. FEAT-03: GooseNotificationService

**Wave 4 — Polish**
14. DATA-03: Stress additions, Manual Workout Entry (workout table), Trends Dashboard (metricSeries)
15. FEAT-02: NoopApp Breathe + Interval Timer + Metric Explorer (metricSeries table)
16. DATA-04: GooseHRDecimator (only after Instruments profile confirms render problem)

---

## Data Flow

### New Real-Time Path — Strain Accumulator

```
BLE notification (HR sample via 0x0022)
    |
GooseBLEClient.onLiveHeartRate callback
    |
WhoopDataSignalPipeline (realtimeVitalsQueue)
    |-- HeartRateSamplePipeline -> HeartRateSeriesStore (existing)
    |-- GooseStrainAccumulator.onSample() (new DATA-02)
            |
        Task { @MainActor in appModel.liveSessionStrain = updated }
            |
        SwiftUI workout view (live strain card updates)
```

### New Historical Path — WHOOP 5.0 V18

```
BLE notification (WHOOP 5.0 historical frame on 0x0022)
    |
GooseBLEClient (subscription unchanged)
    |
GooseBLEHistoricalManager (new BLE5-03, receives frame via callback)
    |
GooseBLEDataValidator.validate() (new BLE5-04)
    |-- if invalid: log warn + increment discardedFrameCount; drop
    |-- if valid:
CaptureFrameWriteQueue -> GooseRustBridge
    |
Rust bridge.rs -> protocol.rs.parse_v18_body() (new BLE5-02)
    |
store.rs inserts: skin_temp_samples / rr_interval_samples /
                  step_counter_samples / gravity2_samples
```

### New BLE Command Path — Haptics

```
User action (Breathe screen inhale cue)
    | @MainActor
GooseHapticService.sendBreatheInhale() (new HAP-02)
    | must dispatch off @MainActor
GooseBLEClient.buzz(loops: 1) (new HAP-01, added to Commands extension)
    | coreBluetoothQueue via writeValue
activePeripheral.writeValue(puffinFrame, for: commandCharacteristic, type: .withoutResponse)
```

### New Journal/Workout Entry Path

```
User action (journal tag tap / manual workout save)
    | @MainActor SwiftUI view
Task.detached { bridge.request(method: "journal.upsert", args: [...]) }
    | background thread -- never @MainActor inline
GooseRustBridge.request() -> bridge.rs dispatch arm (new DATA-01)
    |
store.rs -> journal / workout / appleDaily / metricSeries table
    |
goose.sqlite
```

---

## Integration Points — Threading Analysis

### HAP-01: buzz(loops:) Command — Threading Risk: MEDIUM

The existing `writeAlarmCommand()` and `writeClockCommand()` in `GooseBLEClient+Commands.swift` already include a main-thread dispatch guard:

```swift
guard Thread.isMainThread else {
  DispatchQueue.main.async { [weak self] in self?.writeAlarmCommand(kind) }
  return
}
```

`buzz(loops:)` must include the same guard. `GooseHapticService` may schedule a `Timer` for Breathe session pacing — that timer must fire on the main run loop (schedule via `@MainActor` context), not a background `RunLoop.current`. If the timer fires on a background thread and calls `buzz()` without the guard, the guard catches it but silently adds latency. Preferred: schedule the Breathe timer from `@MainActor` so the guard never triggers.

### BLE5-03: GooseBLEHistoricalManager — Threading Risk: HIGH

`GooseBLEHistoricalManager` must coordinate with `GooseBLEClient` state (`isHistoricalSyncing`, `connectionState`, `activePeripheral`). These are `@Observable` properties mutated from both `coreBluetoothQueue` and `@MainActor`.

The manager must not read `GooseBLEClient` internal state directly from a non-main thread. All reads must come from callbacks already dispatched to main (`onHistoricalSyncProgress`, `onConnectionStateChange`), or the manager must be `@MainActor` itself.

If `GooseBLEHistoricalManager` owns a sync-timeout `DispatchWorkItem`, that work item must check state via a @MainActor-dispatched closure, not directly. Otherwise it races with `coreBluetoothQueue` mutations.

After ARCH-01: the manager depends on `GooseBLEManaging` protocol only. State is communicated back via existing callbacks that `GooseBLEClient` already dispatches to main — do not add new direct property reads.

### DATA-02: GooseStrainAccumulator — Threading Risk: MEDIUM

`WhoopDataSignalPipeline` delivers samples on `realtimeVitalsQueue`. The accumulator computes incrementally on that queue (O(1) per sample). Publishing `liveSessionStrain` to `GooseAppModel` requires a main-actor hop:

```swift
// Inside GooseStrainAccumulator (realtimeVitalsQueue)
func accumulate(sample: WhoopDataSignalSample) {
  // O(1) Banister TRIMP increment
  accumulatedStrain += deltaStrain(sample)
  let snapshot = accumulatedStrain
  Task { @MainActor in appModel.liveSessionStrain = snapshot }
}
```

One `Task { @MainActor in }` per BLE sample (1/s) is acceptable. Do not coalesce unless profiling shows actor-hop overhead.

### ARCH-01: Protocol Layer — Threading Risk: LOW

Adding protocol conformances is purely additive. The protocols must document the threading contract inherited from the concrete types: callers must not call `GooseRustBridging.request()` from `@MainActor` inline; `GooseBLEManaging.buzz()` dispatches to main internally.

Mock implementations in the test target must explicitly state they run on the caller's thread — `GooseBLEClientMock` does not simulate `coreBluetoothQueue`. Test assertions must not rely on background-queue timing.

### FEAT-03: GooseNotificationService — Threading Risk: LOW

`UNUserNotificationCenter` is safe from any thread. Implement as a Swift `actor` to serialize the battery notification reschedule sequence (read drain rate -> compute crossing time -> cancel old -> schedule new). Sleep summary and workout notifications are fire-and-forget and don't need serialization.

The battery drain-rate computation reads SQLite via Rust bridge — must not happen on `@MainActor`. Call via `Task.detached` or via an existing `HealthDataStore` async method.

### BLE5-04: GooseBLEDataValidator — Threading Risk: LOW

`CaptureFrameWriteQueue` runs on `captureFrameRowBuildQueue`. `GooseBLEDataValidator` is a pure `struct` called inline in that queue — inherently safe. If a discarded-frame counter needs to be observable from the UI, expose it via `Task { @MainActor in }`, not a shared mutable property.

---

## Architectural Patterns

### Pattern 1: @MainActor Coordinator + Background Queue Dispatch

All UI-observable state lives on `@MainActor`. Background work dispatches results back via `Task { @MainActor in }` or `DispatchQueue.main.async`. Every new v10.0 component that publishes to `GooseAppModel` or `HealthDataStore` must follow this. Applies to: `GooseStrainAccumulator`, `GooseHapticService`, `GooseWakeWindowManager`, `GooseNotificationService`.

```swift
// New GooseHapticService call site in GooseAppModel (already @MainActor):
func startBreatheSession() {
  hapticService.begin()  // schedules Timer on main run loop internally
}

// Inside GooseHapticService (@MainActor):
func begin() {
  Timer.scheduledTimer(withTimeInterval: inhaleSeconds, repeats: true) { [weak self] _ in
    self?.ble.buzz(loops: 1)  // ble is GooseBLEManaging; buzz dispatches internally
  }
}
```

### Pattern 2: Protocol-over-Concrete for Testable Services

New service components depend on `GooseBLEManaging` and `GooseRustBridging` protocols, never on concrete types. `GooseBLEHistoricalManager` takes `any GooseBLEManaging` at init. `CaptureFrameWriteQueue` (post-refactor) takes `any GooseRustBridging`. No file outside `GooseBLEClient*.swift` casts to the concrete `GooseBLEClient` type.

### Pattern 3: Rust Bridge as Stateless Service

All new bridge calls for DATA-01 tables and FEAT-01 VOW follow the existing pattern: always pass `database_path`; never call from `@MainActor` inline; each caller either creates its own `GooseRustBridge()` instance or reuses one held by the owning class. The `GooseCoachVOWView` data should be fetched via a new `HealthDataStore+Coach.swift` extension that follows the async/await pattern from v7.0.

### Pattern 4: Sequential Migration Order for SQLite Tables

`store.rs:run_migrations()` applies all migrations in a single function, guarded by the current schema version. Each new table is a new migration version increment. DATA-01 must not use `ALTER TABLE` on existing tables. Add new table migrations in order: `metricSeries` (version N), `journal` (N+1), `workout` (N+2), `appleDaily` (N+3). In-memory test fixtures must run all migrations before any test assertion.

---

## Anti-Patterns

### Anti-Pattern 1: Calling buzz() from a Background Timer Without Main-Thread Guard

**What people do:** Schedule a `Timer` on `RunLoop.current` in a background thread inside `GooseHapticService.startBreatheSession()`, then call `ble.buzz(loops:)` directly when the timer fires.
**Why it's wrong:** CoreBluetooth peripheral writes must originate from main or `coreBluetoothQueue`. The main-thread guard in `buzz()` catches this but silently adds per-buzz latency on every Breathe cycle (background -> main dispatch).
**Do this instead:** Schedule the Breathe session `Timer` from `@MainActor` context. `GooseHapticService` is `@MainActor` or uses `DispatchQueue.main.async` for the timer callback.

### Anti-Pattern 2: GooseBLEHistoricalManager Holding a Strong Reference to GooseBLEClient

**What people do:** Store `let ble: GooseBLEClient` in the manager and read `ble.isHistoricalSyncing` or `ble.connectionState` directly.
**Why it's wrong:** Defeats BLE5-03 decoupling; requires a real `CBCentralManager` to instantiate in tests; breaks ARCH-01 DI.
**Do this instead:** Store `let ble: any GooseBLEManaging`. Historical state changes are communicated via `onHistoricalSyncProgress` and `onConnectionStateChange` callbacks — set these during init, clear on `deinit`.

### Anti-Pattern 3: Writing to Journal/Workout Tables from @MainActor Inline

**What people do:** Call `bridge.request(method: "journal.upsert", ...)` directly in a `@MainActor` button action.
**Why it's wrong:** `GooseRustBridge.request()` is synchronous and blocks the caller. A cold SQLite write can take 5-30ms — on `@MainActor` this drops frames.
**Do this instead:** Always wrap in `Task.detached` or call via an `async` method on `HealthDataStore` that dispatches internally. This is the pattern established in v7.0 async migration.

### Anti-Pattern 4: Adding Protocol Conformance Without Tests

**What people do:** Extract `GooseBLEManaging` and `GooseRustBridging` as protocols without creating a test target to use the mocks.
**Why it's wrong:** The seed is explicit: protocols without tests are dead code. ARCH-01 is only justified when test targets exist.
**Do this instead:** Build ARCH-01 Phase 1 (protocols) + Phase 2 (mocks) + Phase 3 (tests for `PassiveActivityDetector` and `CaptureFrameWriteQueue`) in a single phase. If the test target cannot be added, defer ARCH-01 entirely.

### Anti-Pattern 5: Decimating HR Samples at Ingest

**What people do:** Filter HR samples before storing them in `HeartRateSeriesStore` to reduce memory.
**Why it's wrong:** `HeartRateSeriesStore` already has `maxSamples = 100_000` + `prune()`. Memory is not the primary problem. Decimating at ingest permanently discards data needed for HRV computation and accurate chart zoom-in.
**Do this instead:** `GooseHRDecimator` operates only on the slice passed to chart views (view-side projection), not on the stored series. LTTB is fast enough to run at chart render time.

---

## Scaling Considerations

This is a single-user personal device app. Scale concerns are per-session data volume, not concurrent users.

| Concern | Current | v10.0 Risk | Mitigation |
|---------|---------|------------|------------|
| HR samples in memory | 100k cap + prune | `GooseStrainAccumulator` adds per-sample computation on `realtimeVitalsQueue` | Accumulate incrementally (O(1) per sample, not O(n)) |
| SQLite migration time | Schema v19, ~100ms cold start | 4 new tables in DATA-01 | All 4 tables in one `run_migrations()` transaction; no schema version regression risk |
| Breathe session timer precision | N/A | Paced haptic requires ~100ms accuracy | Use `Timer` on main run loop; avoid `DispatchQueue.asyncAfter` chaining for pacing |
| Notification scheduling | OnboardingModels.swift requests permission | 3 notification types, 1 actor | `GooseNotificationService` actor serializes battery reschedule; UNUserNotificationCenter handles OS queuing |

---

## Sources

- Seed files in `.planning/seeds/` (2026-06-11): R22 wire format from hardware capture (#92), v18 field layout from NoopApp/WhoopProtocol cross-reference, alarm payloads confirmed on real MG hardware, journal schema from hardware observation, service-layer DI rationale from WHOOP class inventory
- Project history: `.planning/PROJECT.md` — v9.0 architecture baseline (StateMachine, BondingManager, NetworkMonitor, HRSanitizer confirmed shipped)
- Codebase inspection: `GooseBLEClient.swift`, `GooseAppModel.swift`, `GooseBLEClient+Commands.swift`, `GooseAppModel+BandFirstSync.swift`, `Rust/core/src/protocol.rs` (PACKET_TYPE constants, `packet_type_name` dispatch table), `GooseSwift/HeartRateSeriesStores.swift` (maxSamples, prune, NSLock pattern)
- Protocol analysis: `smart-alarm-strap-haptic.md` — puffin frame format + buzz payload confirmed on real MG hardware; `whoop5-r22-packet-support.md` — BLE HCI capture from issue #92 (darylbleach)
- Protocol analysis: `advanced-haptic-breathe-primitive.md` — ObjC class inventory (WhoopBiotelemetry framework); `wake-window-alarm.md` — WhoopSleepCoach class names (WakeWindow, SmartAlarmTriggerManager, SetAlarmInfoCommandPacketRev4)

---
*Architecture research for: Goose iOS biometric platform — v10.0 component integration*
*Researched: 2026-06-12*
