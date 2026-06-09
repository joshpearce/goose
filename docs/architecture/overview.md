<!-- generated-by: gsd-doc-writer -->
# Architecture Overview

Goose is a two-tier biometric platform. An iOS app captures raw biometric data from a WHOOP wearable over Bluetooth Low Energy and persists it locally in SQLite (schema v19) via a Rust core library. A self-hosted server (FastAPI + TimescaleDB, deployed via Docker Compose) receives decoded biometric streams from the app and provides a read API and a static dashboard. The two tiers are loosely coupled: the iOS app operates fully offline and uploads opportunistically when a server URL and API key are configured.

---

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│ iOS App (GooseSwift)                                                │
│                                                                     │
│  WHOOP Device                                                       │
│      │ BLE GATT notifications                                       │
│      ▼                                                              │
│  GooseBLEClient  ──onNotification──►  GooseAppModel                │
│                                           │                         │
│                              notificationIngestQueue                │
│                                           │                         │
│                                           ▼                         │
│                                 NotificationFrameParser             │
│                                    (Rust: protocol.parse_frame_hex) │
│                                           │ frames                  │
│                                           ▼                         │
│                               CaptureFrameWriteQueue                │
│                                    (Rust: capture.import_frame_batch)│
│                                           │ SQLite write            │
│                                           ▼                         │
│                                  goose.sqlite (local, schema v19)   │
│                                           │                         │
│                              ┌────────────┴───────────┐            │
│                              │                        │             │
│                              ▼                        ▼             │
│                       HealthDataStore          GooseUploadService   │
│                       (Rust: metrics.*)         (detached tasks)    │
│                       @MainActor scores         │                   │
│                                                 │ POST /v1/ingest-  │
│                                                 │ decoded + Bearer  │
└─────────────────────────────────────────────────┼───────────────────┘
                                                  │ HTTPS
┌─────────────────────────────────────────────────▼───────────────────┐
│ Self-Hosted Server (Docker Compose)                                 │
│                                                                     │
│  goose-ingest (FastAPI, port 8770)                                  │
│      │ store.upsert_streams → daily.compute_day                     │
│      ▼                                                              │
│  goose-db (TimescaleDB / PostgreSQL 16)                             │
│      hypertables: hr_samples, rr_intervals, events, battery,       │
│      spo2_samples, skin_temp_samples, resp_samples, gravity_samples │
│      plain tables: sleep_sessions, exercise_sessions, daily_metrics │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow

### Primary real-time BLE → SQLite path

1. **GooseBLEClient** receives raw BLE characteristic notification bytes on its `notificationIngestQueue`. The `onNotification` callback is set by `GooseAppModel`.
2. **GooseAppModel.handleNotification** dispatches work to `notificationIngestQueue`. `NotificationFrameParser` calls the Rust bridge (`GooseRustBridge`) to reassemble multi-packet frames via `protocol.parse_frame_hex`.
3. Parsed frames are handed to **CaptureFrameWriteQueue**, which batches rows and calls the Rust bridge method `capture.import_frame_batch` on its own dedicated queue. Rust writes decoded samples to `goose.sqlite` at `ApplicationSupport/GooseSwift/goose.sqlite`.
4. When a write batch succeeds, `GooseAppModel.triggerUpload` is called, which dispatches `GooseUploadService.upload` on Swift concurrency detached tasks.

### Upload path (iOS → server)

1. **GooseUploadService** runs entirely on Swift concurrency detached tasks (`Task.detached(priority: .utility)`) — never on `@MainActor`.
2. It calls the Rust bridge method `upload.get_recent_decoded_streams` to fetch decoded biometric streams from SQLite. After a successful POST, it calls `sync.rows_pending_upload` to locate the `hr_samples` row IDs that were included, then `sync.mark_synced` to set `synced = 1` on those rows.
3. It POSTs a `DecodedBatch` JSON payload to `POST /v1/ingest-decoded` with a `Bearer` token loaded from the iOS Keychain (`RemoteServerKeychain`, service: `goose.remote`, account: `apiKey`). The server URL is stored in `UserDefaults` under the key `goose.remote.serverURL`.
4. After decoded stream upload succeeds, `GooseUploadService` also calls `upload.get_raw_frames_for_upload` and attempts to POST raw BLE frames to `POST /v1/ingest-frames`.
5. Retry logic: up to 3 attempts with 1 s / 2 s / 4 s backoff. Silent failure after 3 attempts — raw data is already in local SQLite and will be retried next trigger.
6. Upload status (`lastUploadAt`, `pendingBatchCount`) is published back to `@MainActor` via `DispatchQueue.main.async`.

### Metric score path (on-demand)

`HealthDataStore` (a `@MainActor ObservableObject`) holds its own `GooseRustBridge` instance. It queries Rust `metrics.*` methods on its `packetInputQueue` and `heartRateTimelineQueue` dispatch queues, then publishes results as `@Published` properties consumed by SwiftUI views.

### Exercise detection path

`exercise.detect_sessions` is dispatched through the Rust bridge. It accepts a time-windowed array of HR samples and gravity rows from `gravity2_samples`, applies a dual-gate filter (HR above resting HR margin AND smoothed accelerometer magnitude above motion threshold), groups contiguous active pairs into sessions, and computes per-session metrics: strain, calories (Keytel active EE + resting EE), heart rate zones (Edwards 5-zone based on HRR%), and zone time percentages.

### Server daily analysis path

When `POST /v1/ingest-decoded` is received, the server calls `daily.compute_day` for each calendar day touched by the batch (throttled: at most once per device/day per 120 s; single-flight). `compute_day` reads the raw stream hypertables, runs the sleep → recovery → strain → exercise pipeline (modules in `server/ingest/app/analysis/`), and persists results idempotently to `sleep_sessions`, `exercise_sessions`, and `daily_metrics`.

---

## Key Abstractions

| Abstraction | File | Description |
|---|---|---|
| `GooseAppModel` | `GooseSwift/GooseAppModel.swift` + `GooseAppModel+*.swift` | Central `@MainActor` coordinator; owns BLE client, Rust bridge, all notification queues, upload service. Split across 10 extension files by concern. |
| `GooseBLEClient` | `GooseSwift/GooseBLEClient.swift` + `GooseBLEClient+*.swift` | CoreBluetooth central manager; WHOOP GATT connection and proprietary frame framing; command writes. Split across 10 extension files. |
| `GooseRustBridge` | `GooseSwift/GooseRustBridge.swift` | JSON-RPC envelope over `goose_bridge_handle_json` / `goose_bridge_free_string` (C FFI). Schema: `goose.bridge.request.v1`. Stateless — multiple instances are normal. |
| `HealthDataStore` | `GooseSwift/HealthDataStore.swift` + `HealthDataStore+*.swift` | `@MainActor` metric query layer. Holds its own `GooseRustBridge`; publishes scored health metrics to SwiftUI views. |
| `GooseUploadService` | `GooseSwift/GooseUploadService.swift` | Fetches pending-upload rows from Rust (`upload.get_recent_decoded_streams`), POSTs to `POST /v1/ingest-decoded`, then marks `hr_samples` rows synced via `sync.rows_pending_upload` + `sync.mark_synced`. Runs on Swift concurrency detached tasks; never touches `@MainActor` inline. |
| `CaptureFrameWriteQueue` | `GooseSwift/CaptureFrameWriteQueue.swift` | Batches parsed BLE frames and writes them to SQLite via Rust bridge `capture.import_frame_batch`. |
| `NotificationFrameParser` | `GooseSwift/NotificationFrameParsing.swift` | Delegates raw BLE bytes to Rust for frame reassembly and compact summary extraction. |
| `OvernightSQLiteMirrorQueue` | `GooseSwift/OvernightSQLiteMirrorQueue.swift` | During overnight guard mode, queues raw notification rows for Rust bridge SQLite insert. |
| Rust core (`libgoose_core.a`) | `Rust/core/src/bridge.rs` | 142 dispatched methods: protocol parsing, SQLite persistence, metric algorithms, BLE frame import, exercise detection, upload sync, export. Entry point: `bridge.rs`. |
| FastAPI ingest service | `server/ingest/app/main.py` | Bearer-gated REST API: `POST /v1/ingest-decoded`, read endpoints, daily compute. No OpenAPI schema exposed publicly (`docs_url=None`). |

---

## Rust Core Modules

The Rust library (`Rust/core/src/`) is compiled to `libgoose_core.a` and linked into the iOS app via a C FFI pair. Key modules:

| Module | File | Responsibility |
|---|---|---|
| `bridge` | `bridge.rs` | FFI dispatch table; routes JSON `method` strings to internal functions; 142 methods |
| `protocol` | `protocol.rs` | WHOOP BLE frame parsing; packet reassembly; V24 biometric decode tables |
| `store` | `store.rs` | SQLite schema (v19); all persistence helpers; `synced` flag management; `V24BiometricBatch` decode |
| `metrics` | `metrics.rs` | Health algorithm implementations (HRV, recovery, strain scores) |
| `metric_features` | `metric_features.rs` | Feature extraction layer used by `metrics` |
| `metric_readiness` | `metric_readiness.rs` | Per-metric readiness and availability checks |
| `sleep_staging` | `sleep_staging.rs` | Cole-Kripke actigraphy + HR-aided sleep staging; AASM-compatible epoch classification |
| `sleep_validation` | `sleep_validation.rs` | Sleep window and stage label validation |
| `exercise_detection` | `exercise_detection.rs` | Dual-gate (HR + motion) exercise session detection; Edwards 5-zone intensity; Keytel calorie estimation |
| `energy_rollup` | `energy_rollup.rs` | Daily/hourly active and resting energy rollup; Mifflin-St Jeor RMR; Harris-Benedict RMR |
| `recovery_rollup` | `recovery_rollup.rs` | Daily recovery metric rollup |
| `baselines` | `baselines.rs` | EWMA personal baselines (HRV RMSSD, resting HR); cold-start guard; trust levels |
| `step_counter` | `step_counter.rs` | Step count ingestion and daily/hourly rollup |
| `step_discovery` | `step_discovery.rs` | Step packet discovery from raw BLE capture |
| `step_motion_estimator` | `step_motion_estimator.rs` | Motion-based step estimation |
| `activity_sessions` | `activity_sessions.rs` | Activity session persistence and querying |
| `capture_import` | `capture_import.rs` | Batch BLE frame import pipeline |
| `capture_correlation` | `capture_correlation.rs` | Correlation analysis for captured frame sequences |
| `capture_sanitize` | `capture_sanitize.rs` | Sanitisation of raw capture data for export |
| `commands` | `commands.rs` | WHOOP command definitions and validation evidence |
| `health_sync` | `health_sync.rs` | HealthKit sync dry-run and activity sync |
| `historical_sync` | `historical_sync.rs` | WHOOP Gen4 historical data sync state machine |
| `timeline` | `timeline.rs` | Decoded frame timeline reconstruction |
| `export` | `export.rs` | ZIP/CSV export of raw frames and decoded streams |
| `debug_ws_server` | `debug_ws_server.rs` | Local WebSocket debug server (`ws://127.0.0.1:8765`) |
| `debug_ws` | `debug_ws.rs` | WebSocket protocol types and session bookkeeping |

---

## SQLite Schema (v19)

The embedded SQLite database at `ApplicationSupport/GooseSwift/goose.sqlite` is managed by the Rust core. Schema version is declared as `CURRENT_SCHEMA_VERSION = 19` in `store.rs`.

Stream tables with `synced` flag (used by the upload pipeline):

| Table | Content | Synced flag |
|---|---|---|
| `hr_samples` | Heart rate BPM samples | Yes |
| `rr_intervals` | R-R interval data | Yes |
| `events` | WHOOP event packets | Yes |
| `battery` | Battery level samples | Yes |
| `spo2_samples` | SpO2 (V24 decode) | Yes |
| `skin_temp_samples` | Skin temperature delta (V24 decode) | Yes |
| `resp_samples` | Respiration rate (V24 decode) | Yes |
| `gravity` | Raw gravity (legacy) | Yes (added via migration) |
| `gravity2_samples` | Accelerometer XYZ from V24 frames | Yes |
| `exercise_sessions` | Detected exercise sessions | Yes |

The `synced` column (default `0`) is used by the upload pipeline: `upload.get_recent_decoded_streams` reads rows for the `since_ts` window; `sync.rows_pending_upload` returns pending row IDs per stream; `sync.mark_synced` sets `synced = 1` on those row IDs after a confirmed server POST. Pruning (`prune_synced_stream_rows`) only removes rows where `synced = 1`. The tables `gravity`, `spo2_samples`, `skin_temp_samples`, `resp_samples`, `gravity2_samples`, and `exercise_sessions` receive their `synced` column via the `ensure_synced_columns` migration if it was not present at table creation time.

`V24BiometricBatch` (`store.rs`) is the Rust struct that groups raw V24 decode fields (SpO2 photodiode counts, skin temp raw ADC, respiration raw ADC) before they are written to their respective tables.

---

## Directory Structure

```
goose/
├── GooseSwift/                 iOS app source (Swift/SwiftUI, iOS 26.0)
│   ├── GooseAppModel*.swift    Central coordinator + 10 extension files
│   ├── GooseBLEClient*.swift   CoreBluetooth + WHOOP protocol (10 extension files)
│   ├── GooseRustBridge.swift   C FFI bridge (JSON-RPC)
│   ├── HealthDataStore*.swift  Metric query layer
│   ├── GooseUploadService.swift Server upload (detached tasks, synced-flag aware)
│   └── *Views.swift / *Screen.swift  SwiftUI UI
├── GooseWorkoutLiveActivityExtension/
│   └── GooseWorkoutLiveActivityWidget.swift  ActivityKit / Dynamic Island
├── Rust/core/src/              Rust library (libgoose_core)
│   ├── bridge.rs               FFI dispatch table (142 methods)
│   ├── protocol.rs             WHOOP BLE frame parsing + V24 decode tables
│   ├── store.rs                SQLite schema v19 + synced-flag helpers
│   ├── metrics.rs              Health algorithm implementations
│   ├── metric_features.rs      Feature extraction
│   ├── sleep_staging.rs        Cole-Kripke actigraphy + sleep staging
│   ├── exercise_detection.rs   Dual-gate exercise detection + calorie estimation
│   ├── energy_rollup.rs        Daily/hourly energy rollup (Keytel, Mifflin-St Jeor)
│   ├── baselines.rs            EWMA personal baselines (HRV, RHR)
│   └── ...                     40+ additional modules
├── server/
│   ├── ingest/app/             FastAPI ingest service
│   │   ├── main.py             Route definitions
│   │   ├── ingest.py           Raw-frame batch pipeline
│   │   ├── store.py            Idempotent DB upserts
│   │   ├── read.py             Read queries
│   │   └── analysis/           Daily pipeline (sleep/recovery/strain/exercise)
│   ├── db/init.sql             TimescaleDB schema (hypertables)
│   └── docker-compose.yml      goose-db + goose-ingest services
├── Scripts/build_ios_rust.sh   Cross-compile Rust → iOS static libs
└── GooseSwift.xcodeproj        Xcode project (iOS 26.0 deployment target)
```

---

## Threading Model

| Thread / Queue | Owner | Used For |
|---|---|---|
| `@MainActor` (main thread) | Swift runtime | All `@Published` state mutations, SwiftUI rendering, `GooseAppModel` and `HealthDataStore` methods |
| `com.goose.swift.notification-ingest` | `GooseAppModel` | Initial BLE notification receipt and frame boundary detection |
| `com.goose.swift.notification-parse` | `GooseAppModel` | Rust frame parsing calls (blocking FFI) |
| `com.goose.swift.capture-frame-row-build` | `GooseAppModel` | Building SQLite row structs from parsed frames |
| Swift concurrency detached task (`.utility`) | `GooseUploadService` | Rust bridge `upload.get_recent_decoded_streams` + HTTP upload + `sync.mark_synced` |
| `com.goose.swift.health.packet-inputs` | `HealthDataStore` | Metric score queries via Rust bridge |
| `com.goose.swift.health.heart-rate-timeline` | `HealthDataStore` | Heart rate timeline refresh |
| `CBCentralManager` queue | CoreBluetooth | BLE delegate callbacks from `GooseBLEClient` |

**Critical constraint:** `GooseRustBridge.request(...)` is a blocking synchronous call (it calls `goose_bridge_handle_json` via C FFI and waits for a response). It must never be called from `@MainActor` inline for any expensive method. Always dispatch to a background queue first.

---

## Persistence Boundaries

| Store | Location | Owner | Contains |
|---|---|---|---|
| `goose.sqlite` (schema v19) | `ApplicationSupport/GooseSwift/goose.sqlite` | Rust core (via `rusqlite`) | All captured BLE frames, decoded biometric samples (including V24 streams and gravity2_samples), metric scores, activity sessions, synced flags |
| `UserDefaults` | iOS system | Swift | Onboarding state, device identity, HR estimates, server URL (`goose.remote.serverURL`), upload enabled flag (`goose.remote.uploadEnabled`) |
| iOS Keychain | iOS system | `RemoteServerKeychain` | Server API token (service: `goose.remote`, account: `apiKey`) |
| TimescaleDB | Docker volume `goose-db-data` | Server | Hypertables for HR, RR, events, battery, SpO2, skin temp, respiration, gravity; derived tables for sleep/exercise/daily metrics |
| Raw frame archive | Docker volume `goose-raw-data` (`/data/raw`) | Server | Archived raw BLE frame batches (hex, by device/date) |

---

## Server API Summary

All `/v1` routes require `Authorization: Bearer <GOOSE_API_KEY>`. The OpenAPI schema is intentionally disabled (`docs_url=None`, `redoc_url=None`, `openapi_url=None`) to avoid advertising the API surface publicly.

| Method | Path | Description |
|---|---|---|
| `GET` | `/healthz` | DB connectivity check (no auth required) |
| `POST` | `/v1/ingest-decoded` | Ingest a decoded biometric stream batch from the iOS app |
| `POST` | `/v1/ingest` | Ingest a raw BLE frame batch (legacy / reference) |
| `GET` | `/v1/devices` | List known devices |
| `GET` | `/v1/streams/{kind}` | Query a decoded stream (hr, rr, events, battery, spo2, skin_temp, resp, gravity) |
| `GET` | `/v1/batches` | List raw batch records for a device |
| `GET` | `/v1/batches/{batch_id}/frames` | Retrieve raw BLE frames for a specific batch |
| `GET` | `/v1/summary` | Stream row counts for a device/time range |
| `GET` | `/v1/daily` | Daily metric rows for a date range |
| `GET` | `/v1/today` | Most recent daily metric row for a device |
| `GET` | `/v1/sleep` | Sleep sessions for a date |
| `GET` | `/v1/workouts` | Exercise sessions for a date range |
| `POST` | `/v1/compute-daily` | Force recompute daily metrics for a device/date |
| `POST` | `/v1/backfill-workouts` | Recompute exercise sessions over a date range |
| `GET` | `/v1/profile` | Retrieve user profile (height/weight/age/sex) |
| `POST` | `/v1/profile` | Create or update user profile |
| `GET` | `/` | Static dashboard SPA |
| `GET` | `/architecture` | Static architecture page (no auth required) |

---

## Architectural Constraints

- **Rust bridge is synchronous.** `goose_bridge_handle_json` blocks the calling thread. All bridge calls for expensive operations (capture import, metric computation, upload fetch) must happen on a background `DispatchQueue`.
- **Multiple bridge instances are intentional.** `GooseAppModel`, `HealthDataStore`, `OvernightSQLiteMirrorQueue`, `CaptureFrameWriteQueue`, and `GooseUploadService` each hold their own `GooseRustBridge` instance. The Rust library is stateless across calls; state lives in SQLite.
- **Database path convention.** The SQLite file is always resolved via `HealthDataStore.defaultDatabasePath()`. Every bridge call that accesses storage must pass `database_path` in its args.
- **Upload is opt-in.** `GooseUploadService` checks `UserDefaults` key `goose.remote.uploadEnabled` before every upload attempt. An unconfigured or disabled server URL results in a silent no-op — local SQLite is unaffected.
- **Synced flag is the upload cursor.** The `synced` INTEGER column (default `0`) on stream tables is the source of truth for upload state. Rows are never deleted while `synced = 0` regardless of age; only `synced = 1` rows are eligible for pruning.
- **Server ingest is idempotent.** All `store.upsert_*` calls use `ON CONFLICT DO UPDATE` or `DO NOTHING`. The iOS app may upload the same window multiple times; the server deduplicates by `(device_id, ts)` primary keys on each hypertable.
- **No circular imports.** The `GooseWorkoutLiveActivityExtension` target shares only `WorkoutLiveActivityAttributes.swift` with the main app. It has no access to `GooseAppModel`, `GooseRustBridge`, or any SQLite layer.
- **iOS deployment target: 26.0.** All Swift source targets `IPHONEOS_DEPLOYMENT_TARGET = 26.0` as set in `GooseSwift.xcodeproj/project.pbxproj`. App marketing version is `0.1.0`.
