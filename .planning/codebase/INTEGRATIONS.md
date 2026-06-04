# External Integrations

**Analysis Date:** 2026-06-04

## APIs & External Services

**OpenAI Codex / ChatGPT (iOS Coach feature):**
- Used for: AI coach chat inside the app
- Auth flow: OAuth2 device-code flow against `https://auth.openai.com`; endpoints:
  - `POST https://auth.openai.com/api/accounts/deviceauth/usercode` — request device code
  - `POST https://auth.openai.com/api/accounts/deviceauth/token` — poll for auth code
  - `POST https://auth.openai.com/oauth/token` — exchange code for tokens / refresh
- Chat endpoint: `POST https://chatgpt.com/backend-api/codex/responses` (SSE streaming)
- Client: `URLSession` (no SDK); implemented in `GooseSwift/CodexEmbeddedAuth.swift` and `GooseSwift/OpenAICoachResponsesClient.swift`
- Credentials: stored in iOS Keychain, service `com.goose.swift.codex`, account `chatgpt-auth` (access token + refresh token + id token)

**WHOOP Developer API v2 (server-side calibration, optional):**
- Used for: fetching ground-truth recovery/sleep/workout data to calibrate the server-side metric algorithms
- Base URL: `https://api.prod.whoop.com/developer`
- Auth: OAuth2 authorization-code flow; auth URL `https://api.prod.whoop.com/oauth/oauth2/auth`, token URL `https://api.prod.whoop.com/oauth/oauth2/token`
- Scopes: `read:recovery read:sleep read:cycles read:workout read:body_measurement read:profile offline`
- Client: `httpx` (async); implemented in `server/ingest/app/whoop_api/client.py`
- Credentials: env vars `WHOOP_CLIENT_ID`, `WHOOP_CLIENT_SECRET`, `WHOOP_REFRESH_TOKEN`

**Goose Self-hosted Ingest Server (iOS → server upload):**
- Used for: persisting decoded WHOOP biometric streams from the iPhone to the self-hosted server
- Endpoint: `POST {serverURL}/v1/ingest-decoded` (user-configured base URL)
- Auth: `Authorization: Bearer {token}` (token stored in iOS Keychain via `RemoteServerKeychain`)
- Health check: `GET {serverURL}/healthz`
- Client: `URLSession.ephemeral` with 15 s timeout; retry with 1/2/4 s exponential backoff; implemented in `GooseSwift/GooseUploadService.swift`
- Upload trigger: called from `GooseSwift/GooseAppModel+Upload.swift` on BLE data arrival

## Hardware / Protocols

**WHOOP Gen 5 (primary device):**
- Protocol: Bluetooth Low Energy (BLE) GATT
- Service UUID prefix: `fd4b0001-`
- Command characteristic prefix: `fd4b0002-`
- Notification characteristic: proprietary; raw frames captured and CRC-checked before parsing
- Apple framework: CoreBluetooth (`GooseSwift/GooseBLEClient.swift` and `GooseBLEClient+*.swift`)

**WHOOP Gen 4:**
- Protocol: BLE GATT
- Service UUID prefix: `61080001-`
- Command characteristic prefix: `61080002-`
- Parsing: same Rust parser as Gen 5 (`Rust/core/src/`); upload tagged `device_generation: "4.0"` in `GooseUploadService.buildUploadPayload`

**Generic Bluetooth Heart Rate Monitors:**
- Protocol: BLE GATT; standard Bluetooth Heart Rate Service `0x180D` / HR Measurement `0x2A37`
- Read-only notify devices; no command characteristic
- Upload tagged with `device_class: "HR_MONITOR"` in `GooseUploadService.buildUploadPayload`

**Local Debug WebSocket:**
- Used for: streaming debug data from the iOS app to desktop tooling during development
- Endpoint: `ws://127.0.0.1:8765` (server runs inside the Rust library)
- Implementation: `Rust/core/src/debug_ws_server.rs` using `tungstenite 0.28`

## Data Storage

**iOS — SQLite (on-device):**
- Engine: `rusqlite 0.37` (bundled SQLite) inside `libgoose_core.a`
- Path: `ApplicationSupport/GooseSwift/goose.sqlite` (resolved via `HealthDataStore.defaultDatabasePath()`)
- Managed entirely by the Rust core; Swift side passes the path in every bridge call
- Exports: ZIP bundles written to `Documents/GooseSwift/` for user-accessible exports; SHA-256 checksums computed via CryptoKit (`GooseSwift/GooseLocalDataExporter+FileSystem.swift`)

**iOS — UserDefaults:**
- Keys namespaced under `goose.*` prefix (e.g. `goose.remote.serverURL`, `goose.remote.uploadEnabled`, `goose.swift.liveHRVRMSSD`)
- Used for onboarding state, device identity, and HR estimates; not biometric time-series

**Server — TimescaleDB (PostgreSQL 16):**
- Container: `timescale/timescaledb:2.17.2-pg16` named `goose-db`
- Schema bootstrapped by `server/db/init.sql` on first init; re-applied idempotently on every container start
- Hypertables (partitioned by `ts`): `hr_samples`, `rr_intervals`, `events`, `battery`, `spo2_samples`, `skin_temp_samples`, `resp_samples`, `gravity_samples`
- Plain tables (low-volume derived data): `sleep_sessions`, `exercise_sessions`, `daily_metrics`, `profile`, `raw_batches`, `devices`
- Named Docker volume: `goose-db-data`

**Server — Raw frame archive (filesystem):**
- Format: newline-delimited hex frames, zstd-compressed (level 10), content-addressed
- Location: Docker volume `goose-raw-data` mounted at `GOOSE_RAW_ROOT` (default `/data/raw`)
- Implementation: `server/ingest/app/archive.py` using `zstandard 0.23.0`
- Index: `raw_batches` table in TimescaleDB stores `file_path`, `sha256`, and `byte_size` per batch

## Auth & Security

**iOS Keychain items:**

| Service | Account | Contents | File |
|---------|---------|----------|------|
| `goose.remote` | `apiKey` | Bearer token for self-hosted server | `GooseSwift/RemoteServerPersistence.swift` |
| `com.goose.swift.codex` | `chatgpt-auth` | OpenAI/Codex OAuth tokens (JSON-encoded `CodexStoredChatGPTAuth`) | `GooseSwift/CodexEmbeddedAuth.swift` |

- Keychain accessibility: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` for both items
- Token freshness: Codex tokens auto-refreshed if `expiresAt` is within 60 seconds (`CodexEmbeddedAuth.swift:storedAuth`)

**Server Bearer auth:**
- All `/v1/` endpoints require `Authorization: Bearer {GOOSE_API_KEY}`
- Checked via `secrets.compare_digest` to prevent timing attacks (`server/ingest/app/main.py:require_auth`)
- OpenAPI docs disabled (`docs_url=None`, `redoc_url=None`, `openapi_url=None`) to avoid advertising the API surface

**App Transport Security:**
- `NSAllowsLocalNetworking: true` allows HTTP to `.local` hostnames and `localhost`
- RFC 1918 private IP ranges allowed over HTTP; public hostnames require HTTPS (enforced in `RemoteServerURLValidator.validate` in `GooseSwift/RemoteServerPersistence.swift`)

## Platform Integrations

**HealthKit:**
- Entitlement: `com.apple.developer.healthkit` in `GooseSwift/GooseSwift.entitlements`
- Used for: body mass autofill; full health data import (HR, HRV, SpO2, respiratory rate, skin temperature, steps, active calories, sleep, workouts)
- Read types requested at runtime; no write access
- Implementation: `GooseSwift/HealthKitFullImporter.swift` (7-day + 90-day lookback); `GooseSwift/HealthDataStore.swift`

**CoreLocation / MapKit:**
- Used for: GPS route recording during outdoor workouts
- Background mode: `location` declared in `Info.plist`
- Implementation: `GooseSwift/ActivityLocationTracker.swift`

**ActivityKit / WidgetKit (Live Activity):**
- Used for: Dynamic Island and lock-screen widget displaying real-time workout metrics
- Contract type: `WorkoutLiveActivityAttributes` (shared between main target and extension) in `GooseSwift/WorkoutLiveActivityAttributes.swift`
- Extension entry point: `GooseWorkoutLiveActivityExtension/GooseWorkoutLiveActivityWidget.swift`
- Controller: `GooseSwift/WorkoutLiveActivityController.swift`

**CoreBluetooth (BLE):**
- Background mode: `bluetooth-central` declared in `Info.plist`
- State restoration: used to reconnect to WHOOP device after backgrounding
- Queue: dedicated `DispatchQueue("com.goose.swift.corebluetooth")` for all CB delegate callbacks

**UserNotifications:**
- Used for: onboarding permission request only
- Implementation: `GooseSwift/OnboardingPermissions.swift`

---

*Integration audit: 2026-06-04*
