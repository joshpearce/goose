# Technology Stack

**Analysis Date:** 2026-06-04

## Languages

**Primary:**
- Swift 5.0 — iOS app, all UI and business logic; 137 source files under `GooseSwift/` and `GooseWorkoutLiveActivityExtension/`
- Rust (Edition 2024, MSRV 1.96 per `Rust/core/Cargo.toml`) — core library at `Rust/core/src/`; protocol parsing, metric computation, SQLite persistence, C FFI bridge

**Secondary:**
- Python 3.11 — self-hosted ingest server under `server/ingest/`; FastAPI app + analytics pipeline
- Bash — Rust cross-compilation script at `Scripts/build_ios_rust.sh`

**Reference / tooling only:**
- Python scripts under `Rust/core/tools/reference/` (neurokit2, pyhrv, pyactigraphy, ggir) — algorithm validation only, not in the production Docker image

## Runtime & Platform

**iOS app:**
- Deployment target: iOS 26.0 (`IPHONEOS_DEPLOYMENT_TARGET = 26.0` in `GooseSwift.xcodeproj/project.pbxproj`)
- Supported architectures: `aarch64-apple-ios` (device), `aarch64-apple-ios-sim` (ARM64 simulator), `x86_64-apple-ios` (x86_64 simulator)
- Bundle ID: `com.goose.swift` (main), `com.goose.swift.WorkoutLiveActivityExtension` (extension)
- URL scheme: `gooseswift://`

**Server:**
- Python 3.11-slim Docker image (multi-stage build defined in `server/ingest/Dockerfile`)
- TimescaleDB 2.17.2 on PostgreSQL 16 (`timescale/timescaledb:2.17.2-pg16`)
- Deployed via Docker Compose (`server/docker-compose.yml`) or Dockge (`server/dockge-stack.yml`)
- Default ingest port: 8770 (configurable via `GOOSE_INGEST_PORT`)

## Frameworks & Libraries

**iOS — Apple frameworks:**
- SwiftUI — all UI; 80+ files import SwiftUI
- UIKit — appearance configuration and low-level hooks; 81 files
- Foundation — universal; 97 files
- CoreBluetooth — BLE communication with WHOOP devices; 14 files
- HealthKit — body mass autofill and health data import from Apple Health; 11 files
- CoreLocation + MapKit — GPS tracking for outdoor workouts; 12 + 9 files
- ActivityKit — Live Activity / Dynamic Island for active workouts; `GooseSwift/WorkoutLiveActivityController.swift`
- WidgetKit — Live Activity widget extension; `GooseWorkoutLiveActivityExtension/GooseWorkoutLiveActivityWidget.swift`
- OSLog — structured logging; 11 files
- CryptoKit — SHA-256 file integrity checksums on export; 5 files (`GooseSwift/GooseLocalDataExporter+FileSystem.swift` etc.)
- Security — iOS Keychain for OAuth tokens and API keys; `GooseSwift/CodexEmbeddedAuth.swift`, `GooseSwift/RemoteServerPersistence.swift`
- UserNotifications — notification permission onboarding; `GooseSwift/OnboardingPermissions.swift`

**Rust — crate dependencies (`Rust/core/Cargo.toml`):**
- `rusqlite 0.37` (feature: `bundled`) — SQLite embedded in the static library; all persistence
- `serde 1.0` + `serde_json 1.0` — JSON serialisation for the FFI bridge protocol
- `tungstenite 0.28` — WebSocket server for local debug sessions; conditionally compiled for non-Android targets
- `zip 0.6` — raw data export bundling
- `sha2 0.10` — SHA-256 digests in Rust (separate from Swift CryptoKit)
- `crc32fast 1.4` — CRC32 frame checksums
- `hex 0.4` — hex encoding for BLE frame capture
- `thiserror 2.0` — error type derivation
- `tempfile 3.13` (dev-only) — test temporary files

**Server — Python packages (`server/ingest/requirements.txt`):**
- `fastapi 0.115.5` — REST API framework
- `uvicorn[standard] 0.32.1` — ASGI server
- `psycopg[binary] 3.2.3` — PostgreSQL client
- `zstandard 0.23.0` — zstd compression for raw frame archives (`server/ingest/app/archive.py`)
- `neurokit2 0.2.13` — signal processing and sleep staging
- `numpy 2.4.6` — numerical arrays
- `scipy 1.17.1` — signal processing (Welch PSD for respiratory rate)
- `scikit-learn 1.8.0` — ML utilities for biometric feature pipelines
- `pandas 2.3.3` — dataframe handling in analysis pipeline
- `httpx >=0.27` — async HTTP client for WHOOP Developer API calls

**Local Python package:**
- `whoop-protocol 0.1.0` — shared WHOOP 4.0/5.0 BLE frame decoder (schema-as-data); source at `server/packages/whoop-protocol/`; installed from local path into the Docker image

## Build & Tooling

**iOS:**
- Xcode project: `GooseSwift.xcodeproj` (no SPM root `Package.swift`)
- Placeholder local packages: `Packages/WhoopProtocol/`, `Packages/WhoopStore/` (`.swiftpm` metadata only; no source files)
- Rust cross-compilation: `Scripts/build_ios_rust.sh` — invoked as an Xcode build phase; incremental (skips rebuild if inputs unchanged); output at `Rust/iphoneos/libgoose_core.a` and `Rust/iphonesimulator/libgoose_core.a`
- Build artefact staging: `build/rust-target/goose-core/` (configured via `CARGO_TARGET_DIR`)
- `GOOSE_SKIP_RUST_CORE_BUILD=1` — env var to skip Rust build during Xcode runs

**Rust:**
- Package manager: Cargo; lockfile at `Rust/core/Cargo.lock` (committed)
- Crate type: `rlib`, `staticlib`, `cdylib` (produces static library for iOS)
- Release profile: `opt-level=3`, `lto=thin`, `codegen-units=1`, `panic=abort`, `strip=debuginfo`
- 15 diagnostic/validation CLI binaries defined in `Rust/core/Cargo.toml`

**Server:**
- Docker multi-stage build: `server/ingest/Dockerfile` (builder stage installs deps; runtime stage is lean Python 3.11-slim)
- Orchestration: `server/docker-compose.yml` (local dev/self-hosted); `server/dockge-stack.yml` (Dockge panel deployment using pre-built GHCR image)
- Test runner: pytest >=8 (`server/ingest/requirements-dev.txt`)

## Key Dependencies

- `rusqlite 0.37` (bundled) — all iOS health and packet data lives in `goose.sqlite`; every bridge call that needs persistence requires a `database_path` argument
- `serde_json 1.0` — the FFI boundary between Swift and Rust is entirely JSON; every bridge call encodes a request and decodes a response via this crate
- `tungstenite 0.28` — powers the local debug WebSocket server (`ws://127.0.0.1:8765`); excluded from Android builds via Cargo target cfg
- `fastapi 0.115.5` + `psycopg 3.2.3` — the entire server ingest surface; all iOS to server uploads and dashboard reads go through these
- `neurokit2 0.2.13` — drives the sleep-staging pipeline that runs server-side on every `compute_day` call; most CPU-intensive dependency
- `timescale/timescaledb:2.17.2-pg16` — all decoded biometric time-series are stored as TimescaleDB hypertables; not replaceable with plain PostgreSQL without schema changes to `server/db/init.sql`

## Configuration

**iOS app:**
- No config files; runtime configuration is driven by `UserDefaults` and the iOS Keychain
- Remote server URL: `UserDefaults` key `goose.remote.serverURL` (`GooseSwift/RemoteServerPersistence.swift`)
- Remote upload enabled: `UserDefaults` key `goose.remote.uploadEnabled`
- Server API key: iOS Keychain, service `goose.remote`, account `apiKey` (`GooseSwift/RemoteServerPersistence.swift`)
- OpenAI/Codex auth tokens: iOS Keychain, service `com.goose.swift.codex`, account `chatgpt-auth` (`GooseSwift/CodexEmbeddedAuth.swift`)
- Database path: `ApplicationSupport/GooseSwift/goose.sqlite` resolved by `HealthDataStore.defaultDatabasePath()` in `GooseSwift/HealthDataStore.swift`
- Build-time: Xcode environment variables read by `Scripts/build_ios_rust.sh` (`PLATFORM_NAME`, `CONFIGURATION`, `CURRENT_ARCH`, `IPHONEOS_DEPLOYMENT_TARGET`)

**Server:**
- All configuration via environment variables, loaded in `server/ingest/app/config.py`:
  - `GOOSE_API_KEY` — required; Bearer token for all `/v1/` endpoints
  - `GOOSE_DB_DSN` — required; PostgreSQL connection string (`postgresql://user:pass@host:5432/db`)
  - `GOOSE_RAW_ROOT` — optional; filesystem path for raw frame archives (default `/data/raw`)
  - `TZ` — timezone (default `UTC`)
  - `GOOSE_INGEST_PORT` — host port mapping (default `8770`)
- WHOOP Developer API (optional calibration feature):
  - `WHOOP_CLIENT_ID`, `WHOOP_CLIENT_SECRET`, `WHOOP_REFRESH_TOKEN` (or `WHOOP_REFRESH_TOKEN_FILE`)

---

*Stack analysis: 2026-06-04*
