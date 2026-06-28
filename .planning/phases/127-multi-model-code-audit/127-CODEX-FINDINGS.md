# Phase 127: Codex/GPT-4.1 Audit Findings
model=codex/gpt-4.1
date=2026-06-28

## Rust (module-org / jni-ffi / threading / null-safety)
## [HIGH] rust-future — Rust/core/src/bridge/mod.rs: go_to_c_string / string_to_c_string
**Axis:** jni-ffi
**Platform:** Rust
**Finding:** CString creation sanitizes interior nulls but still unwraps, so any allocation failure panics inside FFI boundary instead of surfacing an error response.
**Evidence:** `CString::new(safe).expect("sanitized string cannot contain null bytes")` in `string_to_c_string` is invoked from `response_to_c_string`/`json_to_c_string` for all bridge replies.
**Recommendation:** Return `null` or a static error JSON on CString::new failure; avoid `expect` inside FFI by mapping Err to a best-effort error response.

## [MEDIUM] rust-future — Rust/core/src/android_jni.rs: Java_com_goose_app_bridge_GooseBridge_handle
**Axis:** jni-ffi
**Platform:** Rust
**Finding:** Error JSON creation on JNI failure still uses `env.new_string`, and on failure returns null without releasing the allocated Rust string, risking leak if earlier steps succeeded.
**Evidence:** Early returns build error JSON via `env.new_string(error_json)`; on Err returns `std::ptr::null_mut()` without freeing any already-allocated response.
**Recommendation:** Centralize error path: build Rust-owned CString, free any response_ptr, and ensure a best-effort Java string or propagate a Java exception before returning.

## [LOW] rust-future — Rust/core/src/bridge/mod.rs: handle_bridge_request_inner
**Axis:** module-org
**Platform:** Rust
**Finding:** monolithic dispatcher with 8 domain routers and inline method guards in a single file (~1.7k lines) mixes schemas, routing, and battery parsing, reducing boundary clarity.
**Evidence:** handle_bridge_request_inner handles method parsing plus battery parsing inline rather than delegating to dedicated domain modules.
**Recommendation:** Extract battery.* handlers and core/openwhoop helpers into their own modules; keep mod.rs focused on envelope + routing table only.

## Android (jni-ffi / threading / null-safety / android-compose)
## [HIGH] android-v16 — android/app/src/main/kotlin/com/goose/app/ble/WhoopBleClient.kt: importFrame
**Axis:** threading
**Platform:** Android
**Finding:** BLE notifications dispatch to `scope.launch(Dispatchers.IO)` but use shared mutable `activeGeneration` and `syncInProgress` without synchronization; races could mis-tag frames or miss sync completion across threads.
**Evidence:** `activeGeneration` and `syncInProgress` mutated on BLE callback thread, read on IO coroutine in `importFrame`; marked `@Volatile` only for some flags (sensorSequence), not for these fields.
**Recommendation:** Guard shared state with a Mutex or confine to a single thread (BLE callback) by posting work back to that thread; pass generation as parameter into launched coroutines.

## [MEDIUM] android-v16 — android/app/src/main/kotlin/com/goose/app/viewmodel/MetricsViewModel.kt: queryScore
**Axis:** null-safety
**Platform:** Android
**Finding:** Swallows all Exceptions and returns null, making metric failures silent and impossible to surface to UI or logs.
**Evidence:** `catch (_: Exception) { return null }` in queryScore.
**Recommendation:** Log errors and propagate a distinct error state (sealed UI model) so Compose can render a retry/error indicator.

## [LOW] android-v16 — android/app/src/main/kotlin/com/goose/app/MainActivity.kt: AppShell usage
**Axis:** android-compose
**Platform:** Android
**Finding:** StateFlows passed directly to Composables without collecting cause recomposition to miss updates; only connectionState uses collectAsStateWithLifecycle.
**Evidence:** liveHeartRateBPM, recoveryScore, strainScore, sleepScore, serverUrl passed as StateFlow instead of State; no collect inside AppShell.
**Recommendation:** Collect each StateFlow with lifecycle-aware APIs inside Compose (e.g., collectAsStateWithLifecycle) before rendering.

## iOS (jni-ffi / threading / null-safety)
## [HIGH] ios-future — GooseSwift/GooseRustBridge.swift: requestValue / requestValueAsync
**Axis:** threading
**Platform:** iOS
**Finding:** Exposes `@unchecked Sendable` with manual NSLock but calls blocking FFI inside `Task.detached`, which hops threads and can outlive owning object; potential use-after-free if bridge deallocates mid-flight.
**Evidence:** `try await Task.detached { try self.requestValue(...) }.value` while class is `@unchecked Sendable` with lock-protected state; no lifetime pinning.
**Recommendation:** Wrap in `withTaskCancellationHandler` and capture a strong reference inside detached task; or provide `actor`-based bridge and mark API `nonisolated` to ensure lifetime.

## [MEDIUM] ios-future — GooseSwift/CaptureFrameWriteQueue.swift: flushNext
**Axis:** threading
**Platform:** iOS
**Finding:** Calls Rust bridge from serial `writeQueue` but coalesces completions onto main using pending closures without checking queue state; if `pendingCompletion` becomes nil, completion can be dropped silently.
**Evidence:** `pendingCompletion` set in `recordCompletion`, but `flushCompletion` early returns when either value is nil; race between writeQueue asyncAfter and enqueue could drop callbacks.
**Recommendation:** Hold completions in FIFO queue rather than single pending slot; always pair each enqueue with a completion invocation (success or error).

## [LOW] ios-future — GooseSwift/OvernightSQLiteMirrorQueue.swift: enqueue
**Axis:** null-safety
**Platform:** iOS
**Finding:** Drops overflow rows silently when queue is full, only setting `lastError` string; callers never get backpressure or failure indication.
**Evidence:** `if incomingCount > capacity { droppedRows += ...; lastError = "queue full" }` but enqueue returns Void and completion not invoked on drop.
**Recommendation:** Return an enqueue result with accepted/dropped counts; propagate to UI/logger so data loss is visible.
