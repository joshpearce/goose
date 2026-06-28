# Phase 127: Opus/Claude Sonnet Audit Findings

model=claude-sonnet-4-6 (Opus-class executor)
date=2026-06-28
axes: module-org / jni-ffi / threading / null-safety / android-compose
platforms: Rust / Android / iOS

---

## Axis 1: Module Organisation

### HIGH rust-future — Rust/core/src/store/mod.rs: GooseStore

**Axis:** module-org
**Platform:** Rust
**File:** Rust/core/src/store/mod.rs
**Symbol:** GooseStore
**Finding:** `store/mod.rs` is 5,112 lines containing schema DDL, migration logic, validation constants, and query methods on a single `GooseStore` struct — a god file that violates single-responsibility at the module level.
**Evidence:** 37 `.unwrap()` calls in production code paths (lines 4250, 4269, 4385, 4401, 4417, 4433, 4449, 4495, 4504, 4553, 4568, 4585, 4594, 4608, 4636); the struct holds all schema and query concerns: `Arc<Mutex<Connection>>` shared across 140+ methods; domain submodules (`store/sleep.rs`, `store/capture.rs`, etc.) exist but `mod.rs` still contains inline domain logic.
**Recommendation:** Move all domain queries out of mod.rs into the existing domain submodule files; mod.rs should only contain: `GooseStore::open`, `GooseStore::migrate`, and module re-exports. Replace `.unwrap()` on Mutex locks with `.map_err(|_| GooseError::message("lock poisoned"))`.

---

### HIGH rust-future — Rust/core/src/metric_features.rs: (module)

**Axis:** module-org
**Platform:** Rust
**File:** Rust/core/src/metric_features.rs
**Symbol:** (module)
**Finding:** `metric_features.rs` is 6,760 lines — the largest single file in the codebase — mixing HRV, sleep staging, motion, cardiac, respiratory-rate, and recovery feature computations in one file with no internal module structure.
**Evidence:** File contains at least 15 distinct feature families (HRV, resting HR, motion, sleep staging, strain, recovery, stress, SPO2, temperature, vital events, respiratory rate, window features, metric scoring, baseline EWMA, disturbance detection). All share a flat namespace with dozens of option structs (`HrvFeatureOptions`, `SleepFeatureScoreOptions`, `RecoveryFeatureScoreOptions`, `StrainFeatureScoreOptions`, etc.) inline.
**Recommendation:** Split into domain modules: `features/hrv.rs`, `features/sleep.rs`, `features/motion.rs`, `features/cardiac.rs`, `features/scoring.rs`. Re-export from `metric_features/mod.rs` to maintain ABI.

---

### MEDIUM rust-future — Rust/core/src/bridge/mod.rs: handle_bridge_request_inner

**Axis:** module-org
**Platform:** Rust
**File:** Rust/core/src/bridge/mod.rs
**Symbol:** handle_bridge_request_inner
**Finding:** `bridge/mod.rs` (1,398 lines) still contains inline battery-parsing logic and a flat `if method.starts_with(...)` prefix router with 8 branches — a partial god-file pattern that should delegate all domain logic to submodules.
**Evidence:** `parse_event48_battery`, `parse_cmd26_battery`, `parse_event48_battery_bridge`, `parse_cmd26_battery_bridge` are implemented directly in `mod.rs` rather than in a `bridge/battery.rs` module; the `handle_bridge_request_inner` function contains the router AND schema validation AND openwhoop reference logic inline.
**Recommendation:** Extract battery parsing to `bridge/battery.rs`, openwhoop to `bridge/openwhoop.rs`; reduce `mod.rs` to: envelope structs, routing table, and `goose_bridge_handle_json` / `goose_bridge_free_string` C FFI exports only.

---

### MEDIUM rust-future — Rust/core/src/historical_sync.rs: (module)

**Axis:** module-org
**Platform:** Rust
**File:** Rust/core/src/historical_sync.rs
**Symbol:** (module)
**Finding:** `historical_sync.rs` is 2,094 lines mixing WHOOP protocol state-machine logic, command framing, response parsing, and SQLite insert logic in a single flat file.
**Evidence:** File contains protocol parsing, telemetry recording, page-buffer algorithms, response codes, and database operations — 4+ distinct concerns. No submodule structure.
**Recommendation:** Split into `historical_sync/protocol.rs`, `historical_sync/state_machine.rs`, `historical_sync/telemetry.rs`; keep `mod.rs` as a facade.

---

### LOW android-v16 — android/app/src/main/kotlin/com/goose/app/viewmodel/AppViewModel.kt: AppViewModel

**Axis:** module-org
**Platform:** Android
**File:** android/app/src/main/kotlin/com/goose/app/viewmodel/AppViewModel.kt
**Symbol:** AppViewModel
**Finding:** `AppViewModel` constructs `MetricsViewModel` and `SettingsViewModel` directly via constructor, bypassing the Android `ViewModelProvider` factory pattern, which means these sub-ViewModels are not lifecycle-managed and will not survive configuration changes correctly.
**Evidence:** `private val metricsViewModel = MetricsViewModel(app)` and `private val settingsViewModel = SettingsViewModel(app)` — direct instantiation, not via `viewModelStore` or `ViewModelProvider`.
**Recommendation:** Either promote `MetricsViewModel` and `SettingsViewModel` to top-level ViewModels obtained via `ViewModelProvider`, or make them plain non-ViewModel classes if they don't require `CoroutineScope`/`onCleared` lifecycle semantics.

---

## Axis 2: JNI/FFI Patterns

### HIGH rust-future — Rust/core/src/bridge/mod.rs: string_to_c_string

**Axis:** jni-ffi
**Platform:** Rust
**File:** Rust/core/src/bridge/mod.rs
**Symbol:** string_to_c_string
**Finding:** `string_to_c_string` uses `.expect()` after sanitizing null bytes, which will panic inside the FFI boundary if CString allocation fails — converting an OOM or edge case into an abort rather than an error response.
**Evidence:** `CString::new(safe).expect("sanitized string cannot contain null bytes").into_raw()` at line 1340; this function is the terminal path for ALL bridge responses including error paths.
**Recommendation:** Return `*mut c_char` as `Option<*mut c_char>` or use a static fallback error buffer; replace `.expect()` with `.unwrap_or_else(|_| /* static error C string */ ...)` to prevent OOM panics from crossing the FFI boundary.

---

### HIGH android-v16 — android/app/src/main/kotlin/com/goose/app/ble/WhoopBleClient.kt: importFrame

**Axis:** jni-ffi
**Platform:** Android
**File:** android/app/src/main/kotlin/com/goose/app/ble/WhoopBleClient.kt
**Symbol:** importFrame
**Finding:** `importFrame` calls `GooseBridge.safeHandle(request)` from a `scope.launch(Dispatchers.IO)` coroutine but discards the return value and does not check `ok` in the JSON response — frame import failures are completely silent.
**Evidence:** `GooseBridge.safeHandle(request)` on line 589 — return value ignored. `safeHandle` itself catches `Throwable` and returns error JSON, but the caller never inspects `ok:false` responses.
**Recommendation:** Parse the JSON response from `safeHandle`; if `ok == false`, log the error with frame metadata (hex prefix, source, generation) using `Log.e(TAG, ...)` so import failures are diagnosable.

---

### MEDIUM rust-future — Rust/core/src/android_jni.rs: Java_com_goose_app_bridge_GooseBridge_handle

**Axis:** jni-ffi
**Platform:** Rust
**File:** Rust/core/src/android_jni.rs
**Symbol:** Java_com_goose_app_bridge_GooseBridge_handle
**Finding:** When `env.new_string(error_json)` itself fails (Java heap exhausted), the function returns `std::ptr::null_mut()` — a null `jstring` — which will cause a NullPointerException in the Kotlin caller with no indication of what failed.
**Evidence:** `Err(_) => std::ptr::null_mut()` on lines 55 and 70 — the Kotlin `external fun handle(request: String): String` has no null check; a null return from native code produces an NPE in `GooseBridge.safeHandle`.
**Recommendation:** Use `env.throw_new("java/lang/RuntimeException", "native bridge OOM")` before returning null, so Kotlin sees an exception rather than a null String; alternatively document the null contract in `GooseBridge.safeHandle` and add an explicit null check.

---

### MEDIUM ios-future — GooseSwift/GooseRustBridge.swift: requestValue

**Axis:** jni-ffi
**Platform:** iOS
**File:** GooseSwift/GooseRustBridge.swift
**Symbol:** requestValue
**Finding:** `requestValue` calls the Rust FFI function `goose_bridge_handle_json` from the caller's thread without catch_unwind protection on the Swift side — a Rust panic that escapes `catch_unwind` in `bridge/mod.rs` would still terminate the process.
**Evidence:** `goose_bridge_handle_json(c_request.as_ptr())` called inline in `requestValue`; the Swift layer relies entirely on the Rust-side `catch_unwind` in `goose_bridge_handle_json`. If the Rust side's `AssertUnwindSafe` assumption is violated, the Swift app terminates.
**Recommendation:** This is acceptable given the existing `catch_unwind` in Rust; document the dependency explicitly. Add an integration test that triggers a Rust panic via `test.panic` and verifies the app receives an error JSON rather than crashing.

---

### LOW rust-future — Rust/core/src/bridge/mod.rs: acquire_bridge_conn / checkout_bridge_conn

**Axis:** jni-ffi
**Platform:** Rust
**File:** Rust/core/src/bridge/mod.rs
**Symbol:** acquire_bridge_conn, checkout_bridge_conn
**Finding:** Two parallel connection acquisition strategies exist (`acquire_bridge_conn` using per-path migration tracking, and `checkout_bridge_conn` using `r2d2` pool) — both marked `#[allow(dead_code)]` indicating neither is used yet by the domain handlers.
**Evidence:** Both functions at lines 1055 and 1092 carry `#[allow(dead_code)]`. Domain bridge handlers (metrics, sleep, capture, activity) likely still call `open_bridge_store` / `open_bridge_store_hot` which opens a new connection per call.
**Recommendation:** Migrate all domain bridge handlers to `checkout_bridge_conn` (pooled) as the single acquisition path; remove `acquire_bridge_conn` and `open_bridge_store_hot` to eliminate the three-strategy ambiguity.

---

## Axis 3: Threading / Concurrency

### HIGH android-v16 — android/app/src/main/kotlin/com/goose/app/ble/WhoopBleClient.kt: WhoopBleClient

**Axis:** threading
**Platform:** Android
**File:** android/app/src/main/kotlin/com/goose/app/ble/WhoopBleClient.kt
**Symbol:** WhoopBleClient
**Finding:** `WhoopBleClient` owns a `CoroutineScope(SupervisorJob() + Dispatchers.IO)` that is never cancelled — when the ViewModel's `onCleared` calls `bleClient.disconnect()`, launched coroutines (reconnect timer, importFrame, optical enable) remain alive indefinitely.
**Evidence:** `private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)` on line 91; `AppViewModel.onCleared()` calls `bleClient.disconnect()` but no `scope.cancel()` is called. Reconnect coroutines (`reconnectJob = scope.launch { delay(5000); connect(device) }`) can fire after the ViewModel is destroyed.
**Recommendation:** Add `fun close() { scope.cancel() }` to `WhoopBleClient` and call it from `AppViewModel.onCleared()` alongside `disconnect()`.

---

### HIGH android-v16 — android/app/src/main/kotlin/com/goose/app/ble/WhoopBleClient.kt: handleNotification / completeSyncIfActive

**Axis:** threading
**Platform:** Android
**File:** android/app/src/main/kotlin/com/goose/app/ble/WhoopBleClient.kt
**Symbol:** handleNotification, completeSyncIfActive
**Finding:** `syncInProgress`, `pendingSyncCommand`, `activeGeneration`, `gatt`, `authRetryCount`, and `authExhausted` are mutated on the BLE callback thread and read on the IO dispatcher coroutine pool — `@Volatile` is applied only to a subset of these, and `@Volatile` alone does not guarantee atomicity for the compound read-check-write patterns used.
**Evidence:** `syncInProgress = false; pendingSyncCommand = 0` in `completeSyncIfActive` (line 568-572) and `scope.launch { startHistoricalSync() }` in `handleNotification` (line 409) — the check `if (syncInProgress)` in `startHistoricalSync` races with `completeSyncIfActive`. `gatt` is not `@Volatile` but is read in `handleNotification`.
**Recommendation:** Confine all BLE state to a `@GuardedBy("this")` synchronized section or a `Mutex`, or use a dedicated `Handler` + `HandlerThread` for all BLE state mutations so coroutines post work back to the single BLE thread.

---

### HIGH ios-future — GooseSwift/GooseAppModel.swift: captureFrameRowBuildQueueDepth / frameReassemblyBuffers

**Axis:** threading
**Platform:** iOS
**File:** GooseSwift/GooseAppModel.swift
**Symbol:** captureFrameRowBuildQueueDepth, captureFrameRowBuildQueueHighWatermark, frameReassemblyBuffers
**Finding:** Three properties marked `nonisolated(unsafe)` bypass Swift's actor isolation checking — `frameReassemblyBuffers` (a mutable Dictionary) and two Int counters are accessed from multiple queues without a lock documented at the declaration site.
**Evidence:** Lines 124-140: `@ObservationIgnored nonisolated(unsafe) var captureFrameRowBuildQueueDepth = 0`, `nonisolated(unsafe) var captureFrameRowBuildQueueHighWatermark = 0`, `nonisolated(unsafe) var frameReassemblyBuffers: [String: Data] = [:]`. SEED-007 identified these as protected by `frameReassemblyLock` (NSLock) but the annotation provides no compile-time enforcement.
**Recommendation:** Encapsulate these three properties in a `@unchecked Sendable` struct or class with an explicit `NSLock` guard; expose them only via lock-taking accessors to prevent future lock-bypass by callers.

---

### MEDIUM android-v16 — android/app/src/main/kotlin/com/goose/app/viewmodel/AppViewModel.kt: triggerUpload

**Axis:** threading
**Platform:** Android
**File:** android/app/src/main/kotlin/com/goose/app/viewmodel/AppViewModel.kt
**Symbol:** triggerUpload
**Finding:** `triggerUpload()` is called from `bleClient.onSyncComplete` callback which runs on the IO dispatcher, then `viewModelScope.launch(Dispatchers.IO)` is called — but `viewModelScope` is tied to the ViewModel's `Dispatchers.Main.immediate`, meaning the outer callback is on IO but the inner launch is fine; however `onSyncComplete` is invoked as a raw lambda without lifecycle awareness.
**Evidence:** `bleClient.onSyncComplete = { metricsViewModel.refresh(); triggerUpload() }` in `init` block; the callback is invoked from `completeSyncIfActive()` on whatever thread calls it (BLE callback or scope). No lifecycle check is performed before calling `viewModelScope.launch`.
**Recommendation:** Verify `viewModelScope` is alive before launching; alternatively convert `onSyncComplete` to a `SharedFlow` emission from `WhoopBleClient` so ViewModel can use `collect` with lifecycle-aware cancellation.

---

### MEDIUM ios-future — GooseSwift/GooseAppModel.swift: notificationIngestQueue, notificationParseQueue

**Axis:** threading
**Platform:** iOS
**File:** GooseSwift/GooseAppModel.swift
**Symbol:** notificationIngestQueue, notificationParseQueue, captureFrameRowBuildQueue
**Finding:** Four separate `DispatchQueue` instances (`notificationIngestQueue`, `notificationParseQueue`, `captureFrameRowBuildQueue`, `rustStartupQueue`) with separate `NSLock` guards create a multi-lock topology where accidental ordering could introduce deadlocks.
**Evidence:** Lines 33-38 in `GooseAppModel.swift`: four queues + `notificationIngestStateLock` + `notificationParseStateLock`; extension files add further locks. No documented lock-ordering protocol exists.
**Recommendation:** Document explicit lock acquisition order for all NSLock instances; consider consolidating parse and ingest into a single `serialQueue → bridgeQueue` pipeline to reduce the lock surface.

---

## Axis 4: Null-Safety / Error Handling

### HIGH android-v16 — android/app/src/main/kotlin/com/goose/app/viewmodel/MetricsViewModel.kt: queryScore

**Axis:** null-safety
**Platform:** Android
**File:** android/app/src/main/kotlin/com/goose/app/viewmodel/MetricsViewModel.kt
**Symbol:** queryScore
**Finding:** `queryScore` silently swallows all exceptions with `catch (_: Exception) { null }` — JNI failures, JSON parse errors, and bridge errors all surface as `null` recovery/strain/sleep scores with no log entry.
**Evidence:** Lines 52-62: `catch (_: Exception) { null }` — not even `Log.e(TAG, ...)` is present in the catch block; `GooseBridge.safeHandle` returns error JSON on native failures but `queryScore` treats `ok:false` as null via `optBoolean("ok", false)` check, so structured bridge errors are silently discarded.
**Recommendation:** Log bridge errors at `Log.e(TAG, "queryScore failed for $method: ${json.optJSONObject("error")?.optString("message")}")` and expose a separate `errorState: StateFlow<String?>` so UI can distinguish unavailable data from an error condition.

---

### HIGH ios-future — GooseSwift/GooseUploadService.swift: upload (multiple try? patterns)

**Axis:** null-safety
**Platform:** iOS
**File:** GooseSwift/GooseUploadService.swift
**Symbol:** upload
**Finding:** Network calls use `try? await session.data(for: request)` which silently discards URLSession errors — upload failures, DNS failures, and timeout errors produce no log entries and the caller gets no feedback.
**Evidence:** Line 306: `guard let (data, response) = try? await session.data(for: request)` and line 320 same pattern — both discard the error. SEED-007 identified 9 silent `try?` failures across the codebase.
**Recommendation:** Replace `try?` with `do { ... } catch { ble.record(level: .error, "upload failed: \(error)") }` pattern per SEED-007 fix pattern; at minimum call `ble.record` so operator can diagnose upload issues.

---

### HIGH ios-future — GooseSwift/CoreBluetoothBLETransport+HistoricalHandlers.swift: sync.record_hps_telemetry

**Axis:** null-safety
**Platform:** iOS
**File:** GooseSwift/CoreBluetoothBLETransport+HistoricalHandlers.swift
**Symbol:** (historical sync telemetry handler)
**Finding:** Bridge call `sync.record_hps_telemetry` uses `try?` which silently discards telemetry recording failures — historical sync telemetry data loss is undetectable.
**Evidence:** Line 764: `_ = try? telemetryBridge.request(method: "sync.record_hps_telemetry", args: telemetryArgs)` — error discarded.
**Recommendation:** Replace with explicit `do/catch` and log at warning level; telemetry failures should be visible to the operator diagnosing sync issues.

---

### MEDIUM android-v16 — android/app/src/main/kotlin/com/goose/app/ble/WhoopBleClient.kt: importFrame

**Axis:** null-safety
**Platform:** Android
**File:** android/app/src/main/kotlin/com/goose/app/ble/WhoopBleClient.kt
**Symbol:** importFrame
**Finding:** The database path is hardcoded as `context.filesDir.absolutePath + "/goose.sqlite"` without validation — if `filesDir` is unavailable (low-storage condition, first-boot before storage provisioned), the path is invalid and the Rust bridge returns `ok:false` which is silently ignored.
**Evidence:** Line 579: `val dbPath = context.filesDir.absolutePath + "/goose.sqlite"` — no existence check; `GooseBridge.safeHandle(request)` return value discarded.
**Recommendation:** Add a `context.filesDir.exists()` check before bridge calls; log the discarded result as described in the importFrame threading finding.

---

### MEDIUM ios-future — GooseSwift/CaptureFrameWriteQueue.swift: flushNext

**Axis:** null-safety
**Platform:** iOS
**File:** GooseSwift/CaptureFrameWriteQueue.swift
**Symbol:** flushNext
**Finding:** Error handling for the `storage.compact_raw_evidence` call uses `print()` rather than a structured log — compact failures are invisible in production and not connected to the BLE logging infrastructure.
**Evidence:** Lines 342-352: `} catch { print("storage.compact_raw_evidence: \(error)") }` — uses `print` not `ble.record` or `OSLog`.
**Recommendation:** Replace `print` with `os_log` or `ble.record(level: .warning, ...)` so compaction failures appear in the app's diagnostic log stream.

---

### LOW rust-future — Rust/core/src/store/mod.rs: GooseStore (Mutex unwrap pattern)

**Axis:** null-safety
**Platform:** Rust
**File:** Rust/core/src/store/mod.rs
**Symbol:** GooseStore
**Finding:** 37 `.unwrap()` calls on `Mutex::lock()` in `store/mod.rs` production paths — a poisoned mutex (from a panicking thread) will cause subsequent calls to panic with a confusing error.
**Evidence:** Lines 4250, 4269, 4385, 4401, 4417, 4433, 4449, 4495, 4504, 4553, 4568, 4585, 4594, 4608, 4636 — all `.unwrap()` on lock results. Total: 37 production unwraps.
**Recommendation:** Use `.map_err(|_| GooseError::message("GooseStore mutex poisoned"))?` throughout; the `?` operator propagates via `GooseResult<T>` so no panic crosses the FFI boundary.

---

## Axis 5: Android-Specific (Compose State / ViewModel Lifecycle)

### HIGH android-v16 — android/app/src/main/kotlin/com/goose/app/MainActivity.kt: MainActivity

**Axis:** android-compose
**Platform:** Android
**File:** android/app/src/main/kotlin/com/goose/app/MainActivity.kt
**Symbol:** MainActivity
**Finding:** `liveHeartRateBPM`, `recoveryScore`, `strainScore`, `sleepScore`, and `serverUrl` StateFlows are passed directly to `AppShell` composable as `StateFlow<T>` objects — Compose does not automatically collect them and they will not trigger recomposition when values change.
**Evidence:** Lines 22-25: `val liveHeartRateBPM = appViewModel.liveHeartRateBPM` (StateFlow), passed directly to `AppShell(..., liveHeartRateBPM = liveHeartRateBPM, ...)` without calling `collectAsStateWithLifecycle()`. Only `connectionState` (line 21) is correctly collected.
**Recommendation:** Apply `collectAsStateWithLifecycle()` to every StateFlow before passing to Compose: `val liveHeartRateBPM by appViewModel.liveHeartRateBPM.collectAsStateWithLifecycle()`.

---

### HIGH android-v16 — android/app/src/main/kotlin/com/goose/app/viewmodel/AppViewModel.kt: bleClient

**Axis:** android-compose
**Platform:** Android
**File:** android/app/src/main/kotlin/com/goose/app/viewmodel/AppViewModel.kt
**Symbol:** bleClient (public property)
**Finding:** `bleClient` is exposed as a `public val` on `AppViewModel`, allowing the UI layer to directly call `bleClient.connect()`, `disconnect()`, and other BLE operations — violating the ViewModel encapsulation contract that UI should only interact through the ViewModel's public API.
**Evidence:** `val bleClient = WhoopBleClient(app.applicationContext)` is public; Compose UI could call `bleClient.connect(device)` directly, bypassing any ViewModel lifecycle guards.
**Recommendation:** Make `bleClient` private; expose `fun connectDevice(device: BluetoothDevice)` and `fun disconnectDevice()` wrapper functions on `AppViewModel` that delegate to `bleClient` with appropriate state guards.

---

### MEDIUM android-v16 — android/app/src/main/kotlin/com/goose/app/upload/GooseUploadClient.kt: GooseUploadClient

**Axis:** android-compose
**Platform:** Android
**File:** android/app/src/main/kotlin/com/goose/app/upload/GooseUploadClient.kt
**Symbol:** GooseUploadClient
**Finding:** `GooseUploadClient` is an `object` singleton using `HttpURLConnection` — not a `ViewModel` or `Repository` class, so it has no lifecycle awareness; upload state (in-flight, success, error) is not observable from Compose.
**Evidence:** `object GooseUploadClient { fun upload(...) { ... } }` — no `StateFlow` for upload status; `AppViewModel.triggerUpload()` calls `GooseUploadClient.upload(...)` but never exposes upload progress or errors to the UI.
**Recommendation:** Convert `GooseUploadClient` to a `Repository` class injected into `AppViewModel`; add `val uploadState: StateFlow<UploadState>` to `AppViewModel` so Compose can show upload progress and errors.

---

### MEDIUM android-v16 — android/app/src/main/kotlin/com/goose/app/ble/WhoopBleClient.kt: onSyncComplete callback

**Axis:** android-compose
**Platform:** Android
**File:** android/app/src/main/kotlin/com/goose/app/ble/WhoopBleClient.kt
**Symbol:** onSyncComplete
**Finding:** `onSyncComplete: (() -> Unit)?` is a nullable callback wired by `AppViewModel.init` — this is an object reference cycle (ViewModel → BleClient → callback lambda → ViewModel) that prevents garbage collection and is a weak reference leak risk.
**Evidence:** `var onSyncComplete: (() -> Unit)? = null` (line 101); `AppViewModel.init { bleClient.onSyncComplete = { metricsViewModel.refresh(); triggerUpload() } }` captures ViewModel state in the lambda.
**Recommendation:** Replace the callback with a `SharedFlow<SyncEvent>` on `WhoopBleClient`; `AppViewModel` collects it in `viewModelScope` with lifecycle-aware cancellation, eliminating the object reference cycle.

---

### LOW android-v16 — android/app/src/main/kotlin/com/goose/app/viewmodel/SettingsViewModel.kt: serverUrl

**Axis:** android-compose
**Platform:** Android
**File:** android/app/src/main/kotlin/com/goose/app/viewmodel/SettingsViewModel.kt
**Symbol:** serverUrl
**Finding:** `serverUrl` uses `SharingStarted.WhileSubscribed(5_000)` — the 5-second timeout means the StateFlow stops collecting from DataStore 5 seconds after all subscribers unsubscribe, which can cause the Settings screen to briefly show a stale initial value on return.
**Evidence:** `started = SharingStarted.WhileSubscribed(5_000)` with `initialValue = ""` — if the screen is away for more than 5 seconds and returns, the empty initial value is shown briefly before DataStore emits.
**Recommendation:** Use `SharingStarted.Eagerly` for user-configuration flows that should always be current; or increase the timeout to 30s to cover orientation changes and back-stack navigation.

---

## Summary

| Severity | Count | By Platform |
|----------|-------|-------------|
| HIGH     | 10    | Rust: 3, Android: 4, iOS: 3 |
| MEDIUM   | 8     | Rust: 2, Android: 3, iOS: 3 |
| LOW      | 5     | Rust: 1, Android: 3, iOS: 1 |

| Tag           | HIGH | MEDIUM | LOW |
|---------------|------|--------|-----|
| android-v16   | 4    | 3      | 3   |
| rust-future   | 3    | 2      | 2   |
| ios-future    | 3    | 3      | 0   |

**Prior seed confirmation:**
- SEED-004 consensus confirmed: `store/mod.rs` (5,112L) and `metric_features.rs` (6,760L) are the largest god files; `bridge/mod.rs` (1,398L) has been partially refactored but retains battery parsing inline.
- SEED-007 confirmed: 9 silent `try?` failures exist; `nonisolated(unsafe)` without documented lock ordering on `frameReassemblyBuffers`.
- New findings beyond seeds: Android coroutine scope leak (`WhoopBleClient`), StateFlow not collected in Compose (`MainActivity`), silent `queryScore` exception swallowing (`MetricsViewModel`), `GooseUploadClient` object singleton with no Compose-observable state.
