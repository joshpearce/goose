# Technical Concerns

**Analysis Date:** 2026-06-04

---

## Critical Issues

### C1: `panic = "abort"` applies uniformly to Android release builds — no per-target override

- **File:** `Rust/core/Cargo.toml` line 161 (`[profile.release]`)
- **Severity:** HIGH — any Rust panic on Android kills the JVM process with SIGABRT; no exception is surfaced, no crash report, no recovery possible
- **Detail:** The `[profile.release]` section has `panic = "abort"` with no `[profile.release-android]` override. The Android JNI entry point (`bridge.rs:8784`) does not use `std::panic::catch_unwind`. Any unhandled `.unwrap()` or `.expect()` in a Rust method reached via JNI will abort the Android process.
- **Fix approach:** Add a custom profile `[profile.release-android]` with `panic = "unwind"` and build Android with `--profile release-android`. Alternatively, add `std::panic::catch_unwind` inside `Java_com_goose_core_GooseBridge_handle` at `bridge.rs:8789`.

### C2: JNI response string not validated for MUTF-8 null bytes — potential JVM crash

- **File:** `Rust/core/src/bridge.rs` lines 8800–8802
- **Severity:** HIGH — specific BLE payloads containing `\0` bytes in hex strings could crash the JVM on Android
- **Detail:** `env.new_string(response)` at line 8800 passes the raw JSON bridge response directly. The JSON may contain hex-encoded BLE frame data (`payload_hex`) with null bytes encoded as `\0` in the string. JNI's MUTF-8 encoding cannot represent a literal `\0`, causing a JNI abort.
- **Fix approach:** Before `env.new_string(response)`, replace any null characters with a safe placeholder, or pass the response as `jbyteArray` instead of `jstring` and decode as UTF-8 on the Kotlin side.

### C3: No Android `.cargo/config.toml` — Android build infrastructure missing

- **Files:** `Rust/core/` (no `.cargo/config.toml` present)
- **Severity:** HIGH — `cargo build --target aarch64-linux-android` will fail with a cryptic linker error on any clean checkout; there is no `Scripts/build_android_rust.sh` equivalent
- **Detail:** The iOS build is driven by `Scripts/build_ios_rust.sh` which sets `CARGO_TARGET_AARCH64_APPLE_IOS_LINKER`. No equivalent exists for Android. `rusqlite = { features = ["bundled"] }` compiles SQLite via the `cc` crate and requires the NDK clang toolchain to be explicitly configured.
- **Fix approach:** Create `Rust/core/.cargo/config.toml` with `[target.aarch64-linux-android]` linker/ar settings derived from `ANDROID_NDK_HOME`. Add a `Scripts/build_android_rust.sh` analogous to the iOS script.

### C4: Pending unimplemented quick task — `upload.ingest_fetched_streams` bridge method and UI actions

- **Files:** `Rust/core/src/bridge.rs`, `GooseSwift/GooseAppModel+Upload.swift`, `GooseSwift/MoreRemoteServerViews.swift`
- **Severity:** HIGH — planned feature (Test Connection, Import from Server) is fully specified in `.planning/quick/260603-tqd-add-test-and-import-actions-to-remote-se/260603-tqd-PLAN.md` but not implemented; `upload.ingest_fetched_streams` bridge method does not exist; `testServerConnection()` and `importFromServer()` methods do not exist
- **Fix approach:** Execute quick task `260603-tqd` per its PLAN.md.

---

## Security Concerns

### S1: `GooseUploadService` is `@unchecked Sendable` with mutable state accessed from concurrent tasks

- **File:** `GooseSwift/GooseUploadService.swift` line 12
- **Severity:** MEDIUM — `pendingBatchCount`, `lastUploadTimestamp`, and `lastSyncedCount` are mutated from `Task.detached` closures without a lock or actor
- **Detail:** The comment at line 17 claims "Protected by Swift's cooperative thread pool — only mutated from upload tasks" but multiple concurrent `Task.detached` tasks (one per `upload()` call) can race on `pendingBatchCount`. The increment at line 32 and decrements at lines 40/45/49/66/82/93/124 are not atomic.
- **Fix approach:** Make `GooseUploadService` an `actor` or protect mutable state with an `NSLock`.

### S2: Bearer token transmitted over HTTP to non-private IPs is blocked by validator, but `localhost`/`.local` always allowed without HTTPS

- **File:** `GooseSwift/RemoteServerPersistence.swift` lines 23–27
- **Severity:** LOW — by design for local network use; documented in CLAUDE.md; `NSAllowsLocalNetworking = true` in `Info.plist` is consistent
- **Detail:** URLs ending in `.local` or `localhost` bypass the HTTPS requirement. The API token is sent as `Bearer` in plain HTTP. Acceptable for a personal server on a trusted LAN, but a risk if a `.local` hostname resolves outside the LAN (mDNS spoofing).
- **Mitigation in place:** `RemoteServerURLValidator` blocks public numeric IPs not in RFC 1918 ranges; blocks public hostnames without HTTPS.

### S3: Remote server API token Keychain item uses `.afterFirstUnlockThisDeviceOnly` — accessible before user authentication after reboot

- **File:** `GooseSwift/RemoteServerPersistence.swift` line 68
- **Severity:** LOW — consistent with use case (background BLE capture needs token after reboot before first unlock); token is for a personal self-hosted server

### S4: `tungstenite` WebSocket server binds only to `127.0.0.1` — host validation enforced in Rust

- **File:** `Rust/core/src/debug_ws.rs` lines 720, 787
- **Severity:** LOW — confirmed safe; `is_local_bind_host` at line 787 rejects any non-loopback bind address

---

## Performance Concerns

### P1: Rust bridge is synchronous — no runtime guard prevents `@MainActor` callers

- **Files:** `GooseSwift/GooseRustBridge.swift`, `Rust/core/src/bridge.rs`
- **Severity:** MEDIUM — if called from `@MainActor` inline (the documented anti-pattern), blocks the UI thread; metric computations (e.g., `sleep_validation.rs` at 6334 lines) can be multi-second
- **Current mitigation:** Architectural rule documented in CLAUDE.md: "Never call from `@MainActor` with expensive methods; always dispatch to a background queue first"
- **Residual risk:** No runtime assertion enforces this rule; a future developer can violate it silently

### P2: `GooseUploadService` uses `URLSessionConfiguration.ephemeral` — no background URL session

- **File:** `GooseSwift/GooseUploadService.swift` line 26
- **Severity:** MEDIUM — if iOS suspends the app mid-upload, the in-flight task is cancelled and the batch is silently discarded (line 122: "discarding batch silently")
- **Detail:** Uploads are retried 3x with 1/2/4s backoff within the same foreground session but are never persisted. A backgrounded upload is lost. Deferred to v3 as `UPLD-V2-02`.
- **Fix approach:** Use `URLSessionConfiguration.background(withIdentifier:)` for uploads.

### P3: No upload sync cursor/watermark — in-memory `lastUploadAt` resets to nil on restart

- **File:** `GooseSwift/GooseAppModel+Upload.swift` lines 21, 50–51
- **Severity:** LOW — after restart `lastUploadAt` is nil; manual upload defaults to re-uploading last 24h; the server uses `INSERT OR IGNORE` so data is not duplicated, but repeated large fetches are wasteful. Deferred to v3 as `UPLD-V2-03`.

### P4: Large Rust files — `bridge.rs` at 8804 lines, `export.rs` at 8226 lines, `store.rs` at 7594 lines

- **Files:** `Rust/core/src/bridge.rs` (8804 lines), `Rust/core/src/export.rs` (8226 lines), `Rust/core/src/store.rs` (7594 lines), `Rust/core/src/metric_features.rs` (6436 lines), `Rust/core/src/sleep_validation.rs` (6334 lines)
- **Severity:** LOW — incremental compilation is slow for files this large; 80+ bridge methods in a single `match` arm make navigation difficult
- **Fix approach:** Split `bridge.rs` into per-domain submodules (e.g., `bridge/upload.rs`, `bridge/metrics.rs`)

---

## Maintainability

### M1: 12 suppressed `clippy` lints declared globally in `lib.rs`

- **File:** `Rust/core/src/lib.rs` lines 3–14
- **Severity:** MEDIUM — suppressed lints include `clippy::too_many_arguments`, `clippy::unnecessary_unwrap`, `clippy::result_large_err`; these mask real code-quality issues
- **Key suppressions of concern:** `clippy::unnecessary_unwrap` (could hide eliminable `.unwrap()` calls), `clippy::too_many_arguments` (functions with 8+ parameters are harder to test)
- **Fix approach:** Address each lint class incrementally; remove from `#![allow(...)]` as fixed

### M2: Device type classification uses characteristic UUID prefix heuristic at notification time — not resolved at connect time

- **Files:** `GooseSwift/GooseBLETypes.swift` (computed `rustDeviceType`), `GooseSwift/GooseBLEClient+Commands.swift` lines 147–165
- **Severity:** MEDIUM — adding a third wearable requires updating the heuristic in `GooseBLETypes.swift` AND the guards in `GooseBLEClient+Commands.swift`; the "V5" naming on `supportsV5HistoricalSync` etc. is a misnomer after Gen4 support was added
- **Fix approach (v3):** Introduce a `WearableKind` enum resolved at `processDiscoveredCharacteristics` time; propagate through `GooseNotificationEvent`. Rename `supportsV5*` to `supportsHistorical*`.

### M3: `decoded_frames.device_type TEXT NOT NULL` has no `CHECK` constraint — arbitrary strings accepted by SQL schema

- **File:** `Rust/core/src/store.rs` line 954 (DDL)
- **Severity:** MEDIUM — `parse_device_type` enforces valid values for BLE-sourced frames but a future bridge method (e.g., `upload.ingest_fetched_streams` using `device_type: "IMPORT"`) can insert new strings that bypass Rust-level validation
- **Fix approach:** Add `CHECK (device_type IN ('GEN4','MAVERICK','PUFFIN','GOOSE','HrMonitor','IMPORT'))` in the next schema migration

### M4: `GooseBLEClient` is architecturally single-peripheral — no multi-wearable simultaneous connection support

- **Files:** `GooseSwift/GooseBLEClient.swift` (`activePeripheral`, `commandCharacteristic`, `connectionState` are single-valued)
- **Severity:** LOW for v2.0 (constraint documented), MEDIUM for v3.0 — a third wearable with simultaneous connection will require significant refactoring

### M5: Unstaged formatting change in `protocol.rs` not committed

- **File:** `Rust/core/src/protocol.rs` (git status: `M`)
- **Severity:** LOW — the diff is a `cargo fmt` reformatting of a `match` arm with no logic change; should be committed to keep the working tree clean

### M6: Placeholder Swift packages with no source or documented purpose

- **Files:** `Packages/WhoopProtocol/Package.swift`, `Packages/WhoopStore/Package.swift`
- **Severity:** LOW — contain only `.swiftpm` metadata; no source files; may confuse future contributors

---

## Dependencies at Risk

### D1: `tungstenite = "0.28"` — gated correctly for Android but verify no transitive leak

- **File:** `Rust/core/Cargo.toml` lines 148–150
- **Status:** RESOLVED — under `[target.'cfg(not(target_os = "android"))'.dependencies]`; `debug_ws_server` module is `#[cfg(not(target_os = "android"))]` in `lib.rs` line 29
- **Residual concern:** `debug_ws` module (not `debug_ws_server`) is still compiled for Android; verify it does not transitively pull in `tungstenite` types on Android

### D2: `jni = "0.21"` — pre-1.0 crate; API may change on minor version bump

- **File:** `Rust/core/Cargo.toml` line 152
- **Severity:** LOW — crate is stable in practice; `default-features = false` is correct; Android bridge is new code so migration is cheap now vs. later

### D3: `rusqlite = "0.37"` with `bundled` — SQLite version determined by `libsqlite3-sys`; security patches may lag

- **File:** `Rust/core/Cargo.toml` line 141
- **Severity:** LOW — `bundled` is the right choice for portability; SQLite is very stable; update policy should be tracked

---

## Scalability

### SC1: No per-device-type TTL or row-count limit on `decoded_frames` — unbounded SQLite growth

- **Files:** `Rust/core/src/store.rs`, `Rust/core/src/export.rs`
- **Severity:** LOW currently (single device), MEDIUM at dual-wearable scale
- **Detail:** `decoded_frames`, `ble_raw_notifications`, and `raw_evidence` tables grow indefinitely. With two wearables, `decoded_frames` may accumulate millions of rows over months. No archive or purge policy exists.
- **Fix approach (v3):** Add a bridge method `storage.prune_decoded_frames(older_than_days, device_type)` and call it periodically

### SC2: Upload fires on every captured BLE batch — high-frequency small HTTP requests to personal server

- **Files:** `GooseSwift/GooseAppModel+Upload.swift` lines 48–56, `GooseSwift/GooseUploadService.swift`
- **Severity:** LOW — server uses `INSERT OR IGNORE` so duplicates are harmless, but request frequency at high sampling rates may stress a low-powered personal server
- **Fix approach:** Debounce uploads with a minimum interval (e.g., 60s) or batch by time window

---

## Observability Gaps

### O1: Upload failures are silent — 3-retry exhaustion produces only a `logger.debug` message

- **File:** `GooseSwift/GooseUploadService.swift` line 122
- **Severity:** MEDIUM — no user-visible indicator when uploads fail persistently; no retry queue; data loss is silent

### O2: No production error tracking — crashes go unmonitored

- **Severity:** MEDIUM — no Sentry, Crashlytics, or equivalent; errors surface only through OSLog (device-local) or the UI status strings in `GooseAppModel`/`HealthDataStore`

### O3: Rust bridge errors surface only as free-form UI status strings

- **Files:** `GooseSwift/HealthDataStore.swift`, `GooseSwift/GooseAppModel.swift`
- **Detail:** Bridge errors set `catalogStatus`, `overnightGuardWarning`, etc. as human-readable strings. No machine-readable error log exists. Debugging requires reading UI labels.

### O4: Swift test coverage severely limited — BLE pipeline, overnight guard, and metric scoring have zero test coverage

- **Files:** `GooseSwiftTests/` (3 test files, 336 lines total)
- **Severity:** HIGH gap — `GooseBLEClient`, `GooseAppModel`, `OvernightSQLiteMirrorQueue`, `CaptureFrameWriteQueue`, and `HealthDataStore` have no unit tests; only `GooseUploadService.buildUploadPayload` (pure function) and BLE type helpers are covered
- **Impact:** Regressions in the BLE → SQLite pipeline are caught only by physical-device UAT; CI cannot validate data capture correctness

---

## Unresolved TODOs / Deferred Items

### T1: Quick task `260603-tqd` not yet executed — "Test Connection" and "Import from Server" UI unimplemented

- **Plan:** `.planning/quick/260603-tqd-add-test-and-import-actions-to-remote-se/260603-tqd-PLAN.md`
- **Missing artifacts:** `upload.ingest_fetched_streams` in `Rust/core/src/bridge.rs`; `testServerConnection()` and `importFromServer()` in `GooseSwift/GooseAppModel+Upload.swift`; UI rows in `GooseSwift/MoreRemoteServerViews.swift`

### T2: Upload reliability deferred to v3 (from `STATE.md` Deferred Items)

- `UPLD-V2-01`: Upload queue not persisted in SQLite — batches lost on crash/kill
- `UPLD-V2-02`: No background `URLSession` — uploads cancelled when app is backgrounded
- `UPLD-V2-03`: No sync cursor/watermark — re-uploads last 24h after restart

### T3: iOS dashboard deferred to v3

- `DASH-V2-01`: No HR/RR/SpO2 time-series charts — only scored metric cards exist; raw biometric data not visualised on-device

### T4: `supportsV5*` naming misnomer in `GooseBLEClient+Commands.swift`

- **File:** `GooseSwift/GooseBLEClient+Commands.swift` lines 147–165
- **Detail:** After Gen4 support (v2.0 Phase 6), `supportsV5HistoricalSync`, `supportsV5AlarmCommands`, `supportsV5ClockCommands` misleadingly imply Gen5-only; documented in `STATE.md` Pending Todos

### T5: Force unwraps in HealthKit importers — crash risk if assumption violated

- **Files:** `GooseSwift/HealthKitFullImporter.swift` line 146, `GooseSwift/HealthKitSleepImporter.swift` line 178
- **Detail:** `current.last!` is used inside a loop guarded by `current = [asleep[0]]` initialization; if `current` is somehow empty (e.g., concurrent modification), this crashes. Risk is low due to the loop structure but should use safe unwrap.

---

*Concerns audit: 2026-06-04*
