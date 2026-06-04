<!-- refreshed: 2026-06-04 -->
# Architecture

**Analysis Date:** 2026-06-04

## System Overview

```text
┌──────────────────────────────────────────────────────────────────────┐
│                     iOS App (GooseSwift)                             │
│                                                                      │
│  ┌──────────────┐  ┌──────────────────┐  ┌──────────────────────┐   │
│  │  SwiftUI     │  │  GooseAppModel   │  │  HealthDataStore     │   │
│  │  Views       │  │  @MainActor      │  │  @MainActor          │   │
│  │  (137 files) │  │  coordinator     │  │  metric query layer  │   │
│  └──────┬───────┘  └───────┬──────────┘  └──────────┬───────────┘   │
│         │  @EnvironmentObject│                       │               │
│         └──────────────────┼───────────────────────┘               │
│                            │                                         │
│             ┌──────────────┴───────────────────┐                    │
│             │         GooseRustBridge           │                    │
│             │   JSON-over-C-FFI (synchronous)   │                    │
│             └──────────────────────────────────┘                    │
│                            │ goose_bridge_handle_json()              │
├────────────────────────────┼─────────────────────────────────────────┤
│                     Rust Static Library                              │
│              Rust/core/src/ (libgoose_core.a)                        │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐   │
│  │  bridge.rs   │  │  store.rs    │  │  metrics.rs              │   │
│  │  (8804 lines)│  │  (7594 lines)│  │  + metric_features.rs    │   │
│  │  dispatcher  │  │  SQLite ORM  │  │  algorithm impls         │   │
│  └──────────────┘  └──────────────┘  └──────────────────────────┘   │
│                            │                                         │
│                     goose.sqlite (embedded SQLite schema v14)        │
└──────────────────────────────────────────────────────────────────────┘
         │
         ▼ (optional — user-configured)
┌──────────────────────────────────────────────────────────────────────┐
│        Remote Server  (server/ingest/)                               │
│        FastAPI + TimescaleDB (Docker)                                │
│        GooseUploadService → POST /v1/ingest-decoded                  │
└──────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | Key Files |
|-----------|----------------|-----------|
| `GooseSwiftApp` | App entry point, scene lifecycle, deep link handling | `GooseSwift/GooseSwiftApp.swift` |
| `GooseAppModel` | Central `@MainActor` coordinator; owns BLE client, upload service, all dispatch queues, overnight guard state | `GooseSwift/GooseAppModel.swift` + `GooseAppModel+*.swift` (9 extension files) |
| `GooseBLEClient` | CoreBluetooth central; WHOOP GATT connection; packet framing; command writes and notifications | `GooseSwift/GooseBLEClient.swift` + `GooseBLEClient+*.swift` (9 extension files) |
| `GooseRustBridge` | Type-safe JSON envelope over `goose_bridge_handle_json` / `goose_bridge_free_string` C FFI; tracks per-call timing | `GooseSwift/GooseRustBridge.swift` |
| `HealthDataStore` | `@MainActor` metric query layer; calls Rust bridge for scores, snapshots, sleep, cardio, stress; split by domain | `GooseSwift/HealthDataStore.swift` + `HealthDataStore+*.swift` (10 extension files) |
| `NotificationFrameParser` | Delegates raw BLE bytes to Rust for frame reassembly and parsing | `GooseSwift/NotificationFrameParsing.swift` |
| `CaptureFrameWriteQueue` | Batches `CapturedFrameWriteRow` items; calls `capture.import_batch` via Rust bridge on background queue | `GooseSwift/CaptureFrameWriteQueue.swift` |
| `OvernightSQLiteMirrorQueue` | During overnight guard: queues raw notification rows for background insert via Rust bridge | `GooseSwift/OvernightSQLiteMirrorQueue.swift` |
| `GooseUploadService` | Fetches decoded streams via Rust bridge (`upload.get_recent_decoded_streams`) and POSTs to remote server | `GooseSwift/GooseUploadService.swift` |
| `AppRouter` | Tab selection and navigation path; handles deep links via `gooseswift://` URL scheme | `GooseSwift/AppRouter.swift` |
| `RootView` | Onboarding gate; renders `OnboardingView` or `AppShellView` | `GooseSwift/RootView.swift` |
| `AppShellView` | Tab bar (Home / Health / Coach / More); creates `HealthDataStore` | `GooseSwift/AppShellView.swift` |
| `WhoopDataSignalPipeline` | Ingests `WhoopDataSignalSample` on a dedicated queue; forwards to aggregators | `GooseSwift/WhoopDataSignalPipeline.swift` |
| `PassiveActivityDetectionPipeline` | Heuristic motion/HR analysis for auto-detecting workout sessions | `GooseSwift/PassiveActivityDetector.swift` |
| `WorkoutLiveActivityController` | Manages `ActivityKit` Live Activity lifecycle for workout sessions | `GooseSwift/WorkoutLiveActivityController.swift` |
| `HeartRateSeriesStore` | Module-level singleton; holds in-memory HR series data shared across views | `GooseSwift/HeartRateSeriesStores.swift` |
| `RemoteServerPersistence` | `UserDefaults` keys for server URL + upload toggle; Keychain wrapper for Bearer token | `GooseSwift/RemoteServerPersistence.swift` |
| Rust `bridge.rs` | 8804-line RPC dispatcher; 58+ methods dispatched by `method` string to internal modules | `Rust/core/src/bridge.rs` |
| Rust `store.rs` | `GooseStore` / SQLite schema v14; all health, capture, session, algorithm run persistence | `Rust/core/src/store.rs` |
| Rust `protocol.rs` | WHOOP BLE frame parser; `parse_frame_hex`; `ParsedFrame` / `ParsedPayload` types | `Rust/core/src/protocol.rs` |
| Rust `metrics.rs` | Algorithm implementations: `goose_hrv_v0`, `goose_recovery_v0`, `goose_sleep_v0/v1`, `goose_strain_v0`, `goose_stress_v0` | `Rust/core/src/metrics.rs` |
| Rust `metric_features.rs` | Feature extraction from raw capture data (HR, HRV, motion, SpO2, RR, temperature) | `Rust/core/src/metric_features.rs` |
| `GooseWorkoutLiveActivityWidget` | WidgetKit/ActivityKit extension; Dynamic Island + lock screen for active workouts | `GooseWorkoutLiveActivityExtension/GooseWorkoutLiveActivityWidget.swift` |
| FastAPI ingest server | Python FastAPI; `/v1/ingest-decoded` (Bearer-auth), `/healthz`, dashboard SPA; TimescaleDB backend | `server/ingest/app/main.py`, `server/ingest/app/store.py` |

## Data Flow

### Primary Real-Time BLE → SQLite Path

1. WHOOP device sends BLE notification → `GooseBLEClient` receives bytes on CoreBluetooth delegate (`GooseSwift/GooseBLEClient+PeripheralDelegate.swift`)
2. `GooseAppModel.handleNotification(_:)` called on `@MainActor`; dispatches to `notificationIngestQueue` (`GooseSwift/GooseAppModel+NotificationPipeline.swift`)
3. `notificationIngestQueue` calls `NotificationFrameParser` → Rust bridge `protocol.parse_notification_batch` → returns `ParsedFrame` list
4. Parsed frames passed to `CaptureFrameWriteQueue.enqueue(...)` on `captureFrameRowBuildQueue` (`GooseSwift/CaptureFrameWriteQueue.swift`)
5. Queue batches rows; calls Rust bridge `capture.import_batch` to write to `goose.sqlite`
6. After successful write, `triggerUpload(for:deviceEvent:)` fires `GooseUploadService.upload(...)` as a `Task.detached` (`GooseSwift/GooseAppModel+Upload.swift`)
7. `GooseUploadService` calls `upload.get_recent_decoded_streams`, then POSTs JSON to `POST /v1/ingest-decoded` on the remote server

### Metric Score Path (on-demand)

1. SwiftUI views call `HealthDataStore` extension methods (`HealthDataStore+Snapshots.swift`, `HealthDataStore+Sleep.swift`, etc.)
2. Each method dispatches to `packetInputQueue` (background queue)
3. Calls `bridge.request(method: "metrics.run_*", args: ["database_path": ...])` — synchronous FFI
4. Rust executes algorithm (e.g., `goose_recovery_v0`) against SQLite data; returns scored JSON
5. Result dispatched back to `@MainActor` → updates `@Published` state → SwiftUI re-renders

### Overnight Guard Path

1. User starts overnight guard via `GooseAppModel+OvernightRun.swift`
2. Raw BLE notifications written to `OvernightRawNotificationSpool` (file-backed, `GooseSwift/OvernightRawNotificationSpool.swift`)
3. `OvernightSQLiteMirrorQueue` writes rows to SQLite via Rust bridge on dedicated queue (`GooseSwift/OvernightSQLiteMirrorQueue.swift`)
4. Periodic range polls trigger historical sync commands via `GooseBLEClient+HistoricalCommands.swift`
5. On wakeup, final sync drain and export bundled via `GooseLocalDataExporter`

### Remote Upload Flow

1. `GooseAppModel` creates `GooseUploadService(databasePath:)` at init; `configureUploadService()` wires the status callback
2. Upload triggers: after each `CaptureFrameWriteQueue` batch, after manual user tap, on app foreground
3. `GooseUploadService` reads server URL from `UserDefaults` (`goose.remote.serverURL`), token from Keychain (`goose.remote` / `apiKey`)
4. Payload: `{ hr, rr, events, battery, spo2, skin_temp, resp, gravity }` arrays from Rust bridge
5. Server responds; status published back via `onStatusUpdate` closure on `@MainActor` → `serverReachable`, `lastUploadAt`, `pendingBatchCount`

### Live Activity Path

1. `WorkoutLiveActivityController` starts an `ActivityKit` Live Activity when workout begins (`GooseSwift/WorkoutLiveActivityController.swift`)
2. `WorkoutLiveActivityAttributes.ContentState` carries mutable metrics (HR, strain, elapsed time) (`GooseSwift/WorkoutLiveActivityAttributes.swift`)
3. Main app pushes `ContentState` updates; extension renders in Dynamic Island and lock screen

**State Management:**
- Observable state: `@Published` properties on `@MainActor` classes (`GooseAppModel`, `HealthDataStore`, `GooseBLEClient`)
- Navigation state: `AppRouter` (`GooseSwift/AppRouter.swift`)
- Persistence: `UserDefaults` for onboarding/device identity/server settings; Keychain for Bearer token; `goose.sqlite` at `ApplicationSupport/GooseSwift/goose.sqlite` for all health/packet data; `Documents/GooseSwift/` for user-accessible exports

## Key Abstractions

### JSON-RPC Bridge

The entire Rust library surface is exposed through two C symbols declared in `Rust/core/include/goose_core_bridge.h`:
- `goose_bridge_handle_json(const char *) -> char *`
- `goose_bridge_free_string(char *)`

Every call is a JSON envelope: `{ schema: "goose.bridge.request.v1", method: "...", args: {...} }`. Rust returns `{ ok, result, error, timing }`. Implementation in `GooseSwift/GooseRustBridge.swift` (lines 26–81).

**Rule:** Always pass `database_path` in `args` for any storage-backed method. The Rust library is stateless — it does not hold an open database handle between calls.

### Class Split into Extension Files

Large coordinator types split into focused extension files by concern. All extensions share state on the parent class.

- `GooseAppModel+*.swift` (9 extension files): `ActivityRecording`, `ActivityTimeline`, `HealthCapture`, `Lifecycle`, `NotificationPipeline`, `OvernightRecovery`, `OvernightRun`, `OvernightState`, `PacketPublishing`, `Upload`
- `GooseBLEClient+*.swift` (9 extension files): `CentralDelegate`, `Commands`, `DebugAndSync`, `HistoricalCommands`, `HistoricalHandlers`, `HRMonitor`, `Parsing`, `PeripheralDelegate`, `UserActions`, `VitalsAndLogging`
- `HealthDataStore+*.swift` (10 extension files): `ActivitySnapshots`, `Cardio`, `CoachSummaries`, `PacketInputs`, `Sleep`, `Snapshots`, `StaticSnapshots`, `StressEnergy`, `Trends`, `Utilities`, `Vitals`

### Multiple Bridge Instances (intentional)

`GooseRustBridge` is not a singleton. `GooseAppModel`, `HealthDataStore`, `GooseUploadService`, `OvernightSQLiteMirrorQueue`, and `CaptureFrameWriteQueue` each hold their own instance. This is intentional — the Rust side is stateless; each Swift owner has independent timing/counter state.

### `WorkoutLiveActivityAttributes` Shared Contract

`GooseSwift/WorkoutLiveActivityAttributes.swift` is compiled into both the main app target and `GooseWorkoutLiveActivityExtension`. It is the only shared type between the two targets.

## Architectural Constraints

- **Threading:** `@MainActor` for all UI mutations and all `@Published` state. Named `DispatchQueue` instances for: BLE events, notification ingest (`com.goose.swift.notification-ingest`), notification parse (`com.goose.swift.notification-parse`), capture frame row build (`com.goose.swift.capture-frame-row-build`), health packet inputs (`com.goose.swift.health.packet-inputs`), HR timeline (`com.goose.swift.health.heart-rate-timeline`), overnight SQLite mirror (`com.goose.swift.overnight-sqlite-mirror`). `NSLock` guards ingest/parse queue depth counters.
- **Rust bridge is synchronous:** `goose_bridge_handle_json` blocks the calling thread. Never call from `@MainActor` with expensive methods. Always dispatch to a background `DispatchQueue` first, then dispatch result back to `@MainActor`.
- **Database path convention:** SQLite file always at `ApplicationSupport/GooseSwift/goose.sqlite`, resolved via `HealthDataStore.defaultDatabasePath()`. Pass this path explicitly in every bridge call that needs storage.
- **Global state:** `HeartRateSeriesStore.shared` (`GooseSwift/HeartRateSeriesStores.swift`) is the only module-level singleton. All other state is instance-owned.
- **Extension target isolation:** `GooseWorkoutLiveActivityExtension` has no access to `GooseAppModel`, `GooseRustBridge`, or any coordinator. It only reads `WorkoutLiveActivityAttributes.ContentState` pushed from the main app.
- **Circular imports:** None detected.
- **No SPM packages:** Placeholder directories `Packages/WhoopProtocol` and `Packages/WhoopStore` exist but contain no source files. All dependencies are system frameworks.
- **Upload auth:** Bearer token stored in iOS Keychain under service `goose.remote` / account `apiKey` via `RemoteServerKeychain` in `GooseSwift/RemoteServerPersistence.swift`.

## Anti-Patterns

### Calling GooseRustBridge from @MainActor inline

**What happens:** Calling `bridge.request(...)` directly inside a `@MainActor` method or SwiftUI view body without dispatching to a background queue first.
**Why it's wrong:** The FFI call is synchronous and can take tens to hundreds of milliseconds for metric algorithms, blocking the main thread and causing UI hitches.
**Do this instead:** Wrap in `DispatchQueue(label: ..., qos: .utility).async { ... }` and dispatch results back via `Task { @MainActor in ... }`. See `GooseSwift/HealthDataStore+PacketInputs.swift` and `GooseSwift/GooseAppModel+NotificationPipeline.swift` for correct patterns.

### Constructing ad-hoc GooseRustBridge() per call site

**What happens:** Creating a `GooseRustBridge()` instance inline inside a one-off function or closure.
**Why it's wrong:** Timing state (`lastTiming`) and request counters are lost immediately; no way to track performance for that call site.
**Do this instead:** Assign a `GooseRustBridge` instance as a `let` property on the owning type so timing can be observed. Each coordinator type gets exactly one bridge instance.

### Bypassing RemoteServerURLValidator

**What happens:** Reading `UserDefaults.standard.string(forKey: RemoteServerStorage.serverURL)` and using the URL directly without calling `RemoteServerURLValidator.validate(_:)`.
**Why it's wrong:** Allows non-private-IP HTTP URLs through App Transport Security, creating a silent security gap.
**Do this instead:** Always validate before use. `GooseSwift/GooseUploadService.swift` and `GooseSwift/GooseAppModel+Upload.swift` demonstrate the correct guard pattern.

---

*Architecture analysis: 2026-06-04*
