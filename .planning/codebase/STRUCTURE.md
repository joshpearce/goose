# Codebase Structure

**Analysis Date:** 2026-06-04

## Directory Layout

```
goose/                              # Repo root
├── GooseSwift/                     # iOS app source (137 Swift files)
├── GooseSwift.xcodeproj/           # Xcode project (two targets: app + widget extension)
├── GooseSwiftTests/                # Swift unit tests (3 files)
├── GooseWorkoutLiveActivityExtension/  # WidgetKit/ActivityKit extension (1 Swift file)
├── Rust/
│   └── core/                       # Rust static library
│       ├── src/                    # 66 Rust source files + 35 CLI binaries in src/bin/
│       ├── tests/                  # 42 Rust integration test files
│       ├── fixtures/               # BLE capture fixtures (owned/ + synthetic/)
│       └── include/                # C header for FFI (goose_core_bridge.h)
├── Packages/
│   ├── WhoopProtocol/              # Placeholder SPM package (no source)
│   └── WhoopStore/                 # Placeholder SPM package (no source)
├── Scripts/
│   └── build_ios_rust.sh           # Rust cross-compile script (invoked by Xcode build phase)
├── server/                         # Self-hosted FastAPI + TimescaleDB server
│   ├── ingest/                     # FastAPI service
│   │   ├── app/                    # Python app package (main.py, store.py, ingest.py, read.py, …)
│   │   └── tests/                  # Python test suite (29 test files)
│   ├── client/                     # Python upload CLI (uploader.py)
│   ├── dashboard/                  # Legacy dashboard (server.py)
│   ├── db/                         # DB init scripts
│   ├── packages/                   # Shared Python packages
│   └── docker-compose.yml          # Docker Compose for ingest + TimescaleDB
├── docs/                           # Architecture decision records, guides, evidence
├── .planning/                      # GSD planning artifacts (committed)
│   ├── codebase/                   # Codebase map documents (this file)
│   ├── milestones/                 # Archived milestone phase docs
│   ├── phases/                     # Active phase plans
│   ├── quick/                      # Quick task logs
│   ├── research/                   # Research notes
│   └── todos/                      # Pending todo items
├── .github/
│   └── workflows/                  # CI: rust-core.yml, server-ci.yml, codeql.yml, security.yml
├── build/                          # Pre-built Rust static libraries (committed)
│   └── (libgoose_core.a for device/simulator)
├── CLAUDE.md                       # Project instructions for Claude
├── CONTRIBUTING.md
└── README.md
```

## Swift App (GooseSwift/)

**Total Swift files:** 137 (all in a single flat directory — no subdirectories)

### App Entry & Navigation (5 files)
- `GooseSwiftApp.swift` — `@main` entry point; injects `GooseAppModel` and `AppRouter` as `@StateObject`
- `RootView.swift` — Onboarding gate; renders `OnboardingView` or `AppShellView`
- `AppShellView.swift` — Tab bar; creates `HealthDataStore`
- `AppRouter.swift` — Tab selection and deep-link routing
- `GooseTheme.swift` — Global appearance configuration

### Central Coordinator (10 files)
- `GooseAppModel.swift` — `@MainActor final class`; 430+ lines of `@Published` state and named `DispatchQueue` declarations
- `GooseAppModel+ActivityRecording.swift`
- `GooseAppModel+ActivityTimeline.swift`
- `GooseAppModel+HealthCapture.swift`
- `GooseAppModel+Lifecycle.swift`
- `GooseAppModel+NotificationPipeline.swift` — BLE notification ingest pipeline (898 lines)
- `GooseAppModel+OvernightRecovery.swift`
- `GooseAppModel+OvernightRun.swift` — Overnight guard orchestration (815 lines)
- `GooseAppModel+OvernightState.swift`
- `GooseAppModel+PacketPublishing.swift` — Packet pipeline state publishing (816 lines)
- `GooseAppModel+Upload.swift` — Upload trigger logic and server health check

### BLE Client (10 files)
- `GooseBLEClient.swift` — `CBCentralManagerDelegate` + `CBPeripheralDelegate`; 974 lines of `@Published` state
- `GooseBLEClient+CentralDelegate.swift`
- `GooseBLEClient+Commands.swift` — WHOOP command framing (974 lines)
- `GooseBLEClient+DebugAndSync.swift`
- `GooseBLEClient+HistoricalCommands.swift`
- `GooseBLEClient+HistoricalHandlers.swift` — Historical sync response handling (733 lines)
- `GooseBLEClient+HRMonitor.swift`
- `GooseBLEClient+Parsing.swift` — Packet parsing dispatch (974 lines)
- `GooseBLEClient+PeripheralDelegate.swift`
- `GooseBLEClient+UserActions.swift`
- `GooseBLEClient+VitalsAndLogging.swift`

### Rust Bridge (2 files)
- `GooseRustBridge.swift` — JSON-over-FFI wrapper; calls `goose_bridge_handle_json` / `goose_bridge_free_string`
- `GooseSwift-Bridging-Header.h` — Imports `goose_core_bridge.h` into Swift

### Health Data Store (12 files)
- `HealthDataStore.swift` — `@MainActor final class`; 288-line base with bridge instance and queue declarations
- `HealthDataStore+ActivitySnapshots.swift`
- `HealthDataStore+Cardio.swift`
- `HealthDataStore+CoachSummaries.swift` — 864 lines; builds rich context for AI coach
- `HealthDataStore+PacketInputs.swift`
- `HealthDataStore+Sleep.swift`
- `HealthDataStore+Snapshots.swift` — 1058 lines; primary scored-metrics query layer
- `HealthDataStore+StaticSnapshots.swift`
- `HealthDataStore+StressEnergy.swift`
- `HealthDataStore+Trends.swift`
- `HealthDataStore+Utilities.swift` — 1038 lines; shared helpers and date arithmetic
- `HealthDataStore+Vitals.swift`

### Remote Server Upload (2 files)
- `GooseUploadService.swift` — Bearer-token POST to `/v1/ingest-decoded`; reads server URL and token from persisted config
- `RemoteServerPersistence.swift` — `UserDefaults` keys, URL validator, Keychain wrapper for API token

### Overnight & Capture Pipeline (5 files)
- `CaptureFrameWriteQueue.swift` — Batched SQLite frame insert via Rust bridge
- `OvernightRawNotificationSpool.swift` — File-backed spool for overnight raw notifications (1157 lines)
- `OvernightSQLiteMirrorQueue.swift` — Queued SQLite mirror writes during overnight guard
- `NotificationFrameParsing.swift` — BLE frame reassembly and compact summary extraction
- `WhoopDataSignalPipeline.swift` — Signal sample ingestion and aggregation

### Activity & Workouts (7 files)
- `ActivityModels.swift`, `ActivityPersistenceTypes.swift`, `ActivitySessionModel.swift`
- `ActivityLocationTracker.swift`
- `PassiveActivityDetector.swift`
- `WorkoutLiveActivityController.swift`
- `WorkoutLiveActivityAttributes.swift` — Shared with widget extension target

### Health Views (40+ files)
All `*Views.swift`, `*Screen.swift`, `*View.swift` files — SwiftUI `View` structs; no business logic.
Key view files by section:
- Home tab: `HomeDashboardView.swift`, `HomeScoreViews.swift`, `HomeTimelineViews.swift`, `HomeHealthMonitorViews.swift`
- Health tab: `HealthView.swift`, `HealthDashboardViews.swift`, `HealthCardioViews.swift`, `HealthRecoveryStressViews.swift`, `HealthSleepOverviewViews.swift`, `HealthSleepSheetsViews.swift`, `HealthMetricFamilyStrainViews.swift` (931 lines)
- Coach tab: `CoachView.swift`, `CoachChatScreen.swift`, `OpenAICoachChat.swift`
- More tab: `MoreView.swift`, `MoreRemoteServerViews.swift`, `MoreCaptureViews.swift`, `MoreDebugViews.swift`, `MoreRawExportViews.swift`
- Device: `DeviceView.swift` (703 lines), `ConnectionView.swift`
- Sleep: `SleepDetailViews.swift`, `SleepV2BevelTrendViews.swift` (731 lines), `SleepV2InsightViews.swift`, `SleepV2TimelineViews.swift`

### Types, Models & Support (15 files)
- `GooseBLETypes.swift`, `HealthDataTypes.swift`, `HealthModels.swift`
- `ActivityModels.swift`, `CoachChatTypes.swift`, `HealthPacketCaptureTypes.swift`
- `GooseLocalDataExporter.swift` + `GooseLocalDataExporter+*.swift` (4 files)
- `HealthKitFullImporter.swift`, `HealthKitSleepImporter.swift`
- `OnboardingModels.swift`, `OnboardingView.swift`, `OnboardingStepViews.swift`
- `GooseMessageStore.swift`, `GooseHello.swift`

### Assets
- `GooseSwift/Assets.xcassets/` — App icon, accent colour, onboarding images

## Rust Core (Rust/core/)

### Library Source (Rust/core/src/ — 66 .rs files)

**Bridge & Store (heaviest files):**
- `bridge.rs` — 8804 lines; dispatches 58+ JSON-RPC methods to all internal modules; defines `BRIDGE_METHODS` constant array
- `store.rs` — 7594 lines; `GooseStore` struct; SQLite schema v14 with `CURRENT_SCHEMA_VERSION = 14`

**Protocol & Algorithms:**
- `protocol.rs` — 834 lines; BLE frame hex parser; `ParsedFrame`, `ParsedPayload`, `DataPacketBodySummary`
- `metrics.rs` — 3390 lines; all algorithm implementations: HRV v0, Recovery v0, Sleep v0/v1, Strain v0, Stress v0
- `metric_features.rs` — Feature extraction for all sensor types
- `metric_readiness.rs` — Readiness scoring and next-action recommendations

**Domain Modules:**
- `activity_sessions.rs`, `activity_candidates.rs`, `activity_identity.rs` — Activity detection and session management
- `energy_rollup.rs`, `recovery_rollup.rs` — Daily/hourly rollup pipelines
- `sleep_validation.rs` — Sleep stage label validation and release gates
- `step_counter.rs`, `step_discovery.rs`, `step_motion_estimator.rs` — Pedometry pipeline
- `capture_import.rs`, `capture_sanitize.rs`, `capture_correlation.rs` — BLE capture batch processing
- `historical_sync.rs`, `health_sync.rs` — Historical data sync dry-run and validation
- `calibration.rs` — Calibration dataset and linear calibration evaluation
- `export.rs` — Raw data export bundling with SHA-256 checksums
- `debug_ws.rs`, `debug_ws_server.rs` — WebSocket debug server (`ws://127.0.0.1:8765`)
- `timeline.rs` — Packet timeline construction from decoded frames
- `commands.rs` — WHOOP command definitions and validation
- `algorithm_compare.rs` — Algorithm output comparison to reference implementations
- `openwhoop_reference.rs` — OpenWHOOP attribution constants

**Tooling Support:**
- `fixtures.rs`, `validation_labels.rs`, `property_tests.rs`, `perf_budget.rs`
- `privacy_lint.rs`, `ui_coverage.rs`, `local_health_validation.rs`, `report.rs`
- `reference.rs`, `tool_args.rs`, `error.rs`, `lib.rs`

### CLI Binaries (Rust/core/src/bin/ — 35 binaries)
All named `goose-*`. Used for development tooling, validation, benchmarking. Not included in the iOS static library. Examples:
- `goose-capture-import` — Import captured frames to SQLite
- `goose-algo-benchmark` — Algorithm performance benchmark
- `goose-sleep-v1-release-gate` — Sleep v1 release gate validator
- `goose-debug-ws-serve` — Start local WebSocket debug server
- `goose-metric-input-readiness` — Check metric input readiness

### Integration Tests (Rust/core/tests/ — 42 .rs files)
- `bridge_tests.rs` — Bridge method dispatch tests
- `protocol_tests.rs` — Frame parser tests
- `algorithm_compare_tests.rs` — Algorithm regression tests
- `export_tests.rs`, `sleep_validation_tests.rs`, `energy_rollup_tests.rs`
- Plus 36 additional domain-specific test files

### Fixtures (Rust/core/fixtures/)
- `owned/` — Real-device BLE capture fixtures
- `synthetic/` — Synthetically generated test fixtures

### C Header (Rust/core/include/)
- `goose_core_bridge.h` — Declares three C symbols: `goose_core_version_json`, `goose_bridge_handle_json`, `goose_bridge_free_string`

### Pre-built Libraries (build/)
- `Rust/iphoneos/libgoose_core.a` — ARM64 device static library
- `Rust/iphonesimulator/libgoose_core.a` — ARM64 + x86_64 simulator static library
Both are committed to git (skip rebuild if inputs unchanged).

## Extensions

### GooseWorkoutLiveActivityExtension/
- `GooseWorkoutLiveActivityWidget.swift` — Single file; declares `GooseWorkoutLiveActivityWidget` (`ActivityWidget` conformance); renders Dynamic Island compact/expanded + lock-screen UI
- `Info.plist` — Extension bundle config
- Bundle ID: `com.goose.swift.WorkoutLiveActivityExtension`

### GooseSwiftTests/ (3 files)
- `GooseBLETypesTests.swift` — BLE type unit tests
- `GooseUploadServiceTests.swift` — Upload service unit tests
- `WearableDescriptorTests.swift` — Wearable descriptor unit tests
- `Info.plist`

## Build & Scripts

### Scripts/
- `build_ios_rust.sh` — Cross-compiles Rust core for iOS targets; reads `PLATFORM_NAME`, `CONFIGURATION`, `CURRENT_ARCH`, `IPHONEOS_DEPLOYMENT_TARGET` from Xcode environment; produces device and simulator static libraries; skips rebuild if inputs unchanged

### GooseSwift.xcodeproj/
- `project.pbxproj` — Main Xcode project; two targets: `GooseSwift` (app), `GooseWorkoutLiveActivityExtension`; `IPHONEOS_DEPLOYMENT_TARGET = 26.0`; Rust build phase invokes `Scripts/build_ios_rust.sh`

### Rust/core/
- `Cargo.toml` — Crate config; edition 2024; MSRV 1.94
- `Cargo.lock` — Committed lockfile

## Server (server/)

### server/ingest/
FastAPI service; Python 3.x; `requirements.txt` lists `fastapi`, `psycopg`, `pydantic`, `uvicorn`

- `app/main.py` — FastAPI app; 14499 lines total; `POST /v1/ingest-decoded` (Bearer-auth), `GET /healthz`, `GET /`, dashboard static SPA mount; per-device recompute throttle (120s cooldown)
- `app/store.py` — TimescaleDB write layer (13047 lines)
- `app/read.py` — TimescaleDB read/query layer (14029 lines)
- `app/ingest.py` — Ingest validation logic (2753 lines)
- `app/config.py` — `load_config()` reads env vars
- `app/db.py` — Connection management and schema bootstrap
- `app/analysis/` — Daily computation pipeline (neurokit2 sleep staging)
- `app/whoop_api/` — WHOOP API client helpers
- `Dockerfile` — Python service container
- `tests/` — 29 pytest test files

### server/client/
- `uploader.py` — CLI for manual upload from desktop (4644 lines)
- `test_uploader.py` — Upload CLI tests

### server/dashboard/
- `server.py` — Legacy dashboard server (7729 lines)

### server/docker-compose.yml
- Defines `ingest` and `db` (TimescaleDB) services

## Planning & Docs

### .planning/
All planning artifacts are committed to git.

- `codebase/` — Codebase map documents (ARCHITECTURE.md, STACK.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, INTEGRATIONS.md, CONCERNS.md)
- `milestones/` — Archived milestone phase directories (`v2.0-phases/`, `v1.0-phases/`)
- `phases/` — Active phase plans (one subdirectory per phase, e.g., `06-whoop-gen4-ios-support/`)
- `quick/` — Quick task logs (timestamped subdirectories)
- `research/` — Architecture and protocol research notes
- `todos/pending/` — Pending todo items
- `PROJECT.md`, `ROADMAP.md`, `STATE.md`, `MILESTONES.md` — Project-level status

### docs/
- `architecture/` — Architecture decision records
- `api/` — API documentation
- `guides/` — Developer guides
- `goose-swift-mvp/` — MVP evidence and health data screenshots
- `ADR-android-jni.md` — Android/JNI architecture decision record

## Where to Add New Code

**New SwiftUI View:**
- Add `*View.swift` or `*Views.swift` to `GooseSwift/` (flat directory)
- No subdirectory structure exists; all 137 Swift files are in the same directory

**New GooseAppModel concern:**
- Add `GooseSwift/GooseAppModel+<Concern>.swift` as a new extension file
- Declare stored properties needed in `GooseSwift/GooseAppModel.swift` (extensions cannot declare stored properties)

**New HealthDataStore metric query:**
- Add to the appropriate existing extension (e.g., `GooseSwift/HealthDataStore+Cardio.swift`) or create `GooseSwift/HealthDataStore+<Domain>.swift`

**New Rust bridge method:**
- Add the implementation module to `Rust/core/src/<module>.rs`
- Register the module in `Rust/core/src/lib.rs`
- Add dispatch arm to `Rust/core/src/bridge.rs` `handle_bridge_request()` match block
- Add method name string to `BRIDGE_METHODS` constant in `bridge.rs`
- Add integration test to `Rust/core/tests/<module>_tests.rs`

**New server endpoint:**
- Add route handler to `server/ingest/app/main.py`
- Add DB write logic to `server/ingest/app/store.py`
- Add test to `server/ingest/tests/`

**New Swift type/model:**
- Add `*Types.swift` or `*Models.swift` to `GooseSwift/` following the existing naming conventions

---

*Structure analysis: 2026-06-04*
