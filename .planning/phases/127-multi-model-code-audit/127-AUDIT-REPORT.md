# Phase 127: Multi-Model Code Audit Report

**Date:** 2026-06-28
**Models:** Opus (Claude Sonnet 4.6 — executor), Codex (gpt-5.1-codex-max via Siemens gateway)
**Gemini:** Excluded — timed out on agentic file reads (3 attempts, 90s each; output: 190 bytes banner only). Per D-01, consolidation proceeds with Opus + Codex only.
**Scope:** Rust/core/src/ (60 files), android/app/src/main/kotlin/ (17 files), GooseSwift/ (36 files)
**Analysis axes:** module-org, jni-ffi, threading, null-safety, android-compose
**Note: This is an ANALYSIS-ONLY report. No source files were modified in Phase 127.**

---

## Phase 128 Android Fix List (android-v16 HIGH + MEDIUM)

These findings are directly actionable in Phase 128 without touching Rust or iOS source.

| # | Severity | File | Symbol | Axis | Finding |
|---|----------|------|--------|------|---------|
| A-01 | HIGH | WhoopBleClient.kt | `importFrame` | threading | BLE coroutine scope never cancelled — outlives ViewModel lifecycle |
| A-02 | HIGH | WhoopBleClient.kt | `handleNotification`, `completeSyncIfActive` | threading | `syncInProgress`/`activeGeneration`/`gatt` race between BLE callback thread and IO dispatcher |
| A-03 | HIGH | WhoopBleClient.kt | `importFrame` | jni-ffi / null-safety | `GooseBridge.safeHandle()` return value discarded — frame import failures are silent |
| A-04 | HIGH | MainActivity.kt | `MainActivity` | android-compose | 4 StateFlows passed to Compose as raw `StateFlow<T>` — no `collectAsStateWithLifecycle()` → zero recomposition |
| A-05 | HIGH | AppViewModel.kt | `bleClient` | android-compose | `bleClient` is a public val — UI layer can bypass ViewModel lifecycle guards |
| A-06 | MEDIUM | MetricsViewModel.kt | `queryScore` | null-safety | All exceptions swallowed silently; `ok:false` bridge responses treated as null with no log |
| A-07 | MEDIUM | AppViewModel.kt | `triggerUpload` | threading | `onSyncComplete` callback captured lambda creates object reference cycle (ViewModel → BleClient → ViewModel) |
| A-08 | MEDIUM | GooseUploadClient.kt | `GooseUploadClient` | android-compose | Singleton `object` with no Compose-observable upload state — upload progress/errors invisible to UI |
| A-09 | MEDIUM | AppViewModel.kt | `metricsViewModel`, `settingsViewModel` | module-org | Sub-ViewModels constructed directly via constructor, bypassing ViewModelProvider lifecycle |

---

## All Findings by Severity

### HIGH

#### Axis: Module Organisation

| Finding | File | Symbol | Platform | Tag | Models |
|---------|------|--------|----------|-----|--------|
| `store/mod.rs` is 5,112 lines — god file mixing DDL, migration, validation constants, 140+ query methods | `Rust/core/src/store/mod.rs` | `GooseStore` | Rust | rust-future | Opus |
| `metric_features.rs` is 6,760 lines — 15+ feature families with no internal module structure | `Rust/core/src/metric_features.rs` | (module) | Rust | rust-future | Opus |

#### Axis: JNI/FFI

| Finding | File | Symbol | Platform | Tag | Models |
|---------|------|--------|----------|-----|--------|
| `string_to_c_string` uses `.expect()` — OOM during bridge reply can abort process at FFI boundary | `Rust/core/src/bridge/mod.rs` | `string_to_c_string` | Rust | rust-future | Opus + Codex |
| `importFrame` discards `safeHandle()` result — bridge failures produce zero diagnostic output | `android/…/ble/WhoopBleClient.kt` | `importFrame` | Android | android-v16 | Opus + Codex |

#### Axis: Threading

| Finding | File | Symbol | Platform | Tag | Models |
|---------|------|--------|----------|-----|--------|
| `WhoopBleClient.scope` never cancelled — coroutines survive ViewModel destruction | `android/…/ble/WhoopBleClient.kt` | `WhoopBleClient` | Android | android-v16 | Opus |
| `syncInProgress`, `activeGeneration`, `gatt` race between BLE callback thread and IO dispatcher | `android/…/ble/WhoopBleClient.kt` | `handleNotification`, `completeSyncIfActive` | Android | android-v16 | Opus + Codex |
| `nonisolated(unsafe)` on `frameReassemblyBuffers`, `captureFrameRowBuildQueueDepth` — no compile-time lock enforcement | `GooseSwift/GooseAppModel.swift` | `captureFrameRowBuildQueueDepth`, `frameReassemblyBuffers` | iOS | ios-future | Opus |
| `requestValueAsync` wraps blocking FFI in `Task.detached` — potential use-after-free if bridge deallocated mid-flight | `GooseSwift/GooseRustBridge.swift` | `requestValueAsync` | iOS | ios-future | Codex |

#### Axis: Null-Safety / Error Handling

| Finding | File | Symbol | Platform | Tag | Models |
|---------|------|--------|----------|-----|--------|
| `queryScore` swallows all exceptions silently — metric failures invisible to operator | `android/…/viewmodel/MetricsViewModel.kt` | `queryScore` | Android | android-v16 | Opus + Codex |
| `try? await session.data(for:)` pattern discards network errors silently | `GooseSwift/GooseUploadService.swift` | `upload` | iOS | ios-future | Opus |
| `try? telemetryBridge.request(method: "sync.record_hps_telemetry")` discards historical sync telemetry errors | `GooseSwift/CoreBluetoothBLETransport+HistoricalHandlers.swift` | (telemetry handler) | iOS | ios-future | Opus |

#### Axis: Android-Specific (Compose / ViewModel)

| Finding | File | Symbol | Platform | Tag | Models |
|---------|------|--------|----------|-----|--------|
| 4 StateFlows passed to AppShell as raw `StateFlow<T>` — no `collectAsStateWithLifecycle()` → Compose never recomposes | `android/…/MainActivity.kt` | `MainActivity` | Android | android-v16 | Opus + Codex |
| `bleClient` is public val on AppViewModel — UI layer can bypass ViewModel lifecycle guards | `android/…/viewmodel/AppViewModel.kt` | `bleClient` | Android | android-v16 | Opus |

---

### MEDIUM

#### Axis: Module Organisation

| Finding | File | Symbol | Platform | Tag | Models |
|---------|------|--------|----------|-----|--------|
| `bridge/mod.rs` (1,398L) retains inline battery parsing and openwhoop logic instead of delegating to modules | `Rust/core/src/bridge/mod.rs` | `handle_bridge_request_inner` | Rust | rust-future | Opus + Codex |
| `historical_sync.rs` (2,094L) mixes protocol, state-machine, telemetry, and DB logic | `Rust/core/src/historical_sync.rs` | (module) | Rust | rust-future | Opus |
| Sub-ViewModels constructed via direct constructor bypassing ViewModelProvider | `android/…/viewmodel/AppViewModel.kt` | `metricsViewModel`, `settingsViewModel` | Android | android-v16 | Opus |

#### Axis: JNI/FFI

| Finding | File | Symbol | Platform | Tag | Models |
|---------|------|--------|----------|-----|--------|
| Null `jstring` return on `env.new_string` failure causes NPE in Kotlin with no error context | `Rust/core/src/android_jni.rs` | `Java_com_goose_app_bridge_GooseBridge_handle` | Rust | rust-future | Opus + Codex |
| Two parallel connection strategies (`acquire_bridge_conn`, `checkout_bridge_conn`) both `#[allow(dead_code)]` — domain handlers still call `open_bridge_store` per-request | `Rust/core/src/bridge/mod.rs` | `acquire_bridge_conn`, `checkout_bridge_conn` | Rust | rust-future | Opus |
| `CaptureFrameWriteQueue.flushNext` can drop completion callbacks silently when `pendingCompletion` races with `nil` | `GooseSwift/CaptureFrameWriteQueue.swift` | `flushNext` | iOS | ios-future | Codex |

#### Axis: Threading

| Finding | File | Symbol | Platform | Tag | Models |
|---------|------|--------|----------|-----|--------|
| `onSyncComplete` callback captures ViewModel lambda — object reference cycle; callback fires without lifecycle check | `android/…/viewmodel/AppViewModel.kt` | `triggerUpload`, `onSyncComplete` | Android | android-v16 | Opus |
| Four `DispatchQueue` + two `NSLock` instances with no documented acquisition order — potential deadlock surface | `GooseSwift/GooseAppModel.swift` | `notificationIngestQueue`, `notificationParseQueue` | iOS | ios-future | Opus |

#### Axis: Null-Safety / Error Handling

| Finding | File | Symbol | Platform | Tag | Models |
|---------|------|--------|----------|-----|--------|
| 37 `.unwrap()` on `Mutex::lock()` in production store paths — poisoned mutex panics propagate to FFI | `Rust/core/src/store/mod.rs` | `GooseStore` | Rust | rust-future | Opus |
| `importFrame` hardcodes database path without `filesDir.exists()` check — invalid path silently discarded | `android/…/ble/WhoopBleClient.kt` | `importFrame` | Android | android-v16 | Opus |
| `storage.compact_raw_evidence` errors use `print()` not structured log | `GooseSwift/CaptureFrameWriteQueue.swift` | `flushNext` | iOS | ios-future | Opus + Codex |

#### Axis: Android-Specific

| Finding | File | Symbol | Platform | Tag | Models |
|---------|------|--------|----------|-----|--------|
| `GooseUploadClient` singleton `object` — upload status not observable from Compose; no lifecycle awareness | `android/…/upload/GooseUploadClient.kt` | `GooseUploadClient` | Android | android-v16 | Opus |
| `serverUrl` uses `SharingStarted.WhileSubscribed(5_000)` — stale `""` initial value shown briefly on screen return | `android/…/viewmodel/SettingsViewModel.kt` | `serverUrl` | Android | android-v16 | Opus |

---

### LOW

#### Axis: Module Organisation

| Finding | File | Symbol | Platform | Tag | Models |
|---------|------|--------|----------|-----|--------|
| `bridge/mod.rs` battery parsing and inline method guards mix schema, routing, and parsing concerns | `Rust/core/src/bridge/mod.rs` | `handle_bridge_request_inner` | Rust | rust-future | Codex |

#### Axis: JNI/FFI

| Finding | File | Symbol | Platform | Tag | Models |
|---------|------|--------|----------|-----|--------|
| Android JNI error path missing `env.throw_new()` before null return — Kotlin sees NPE not runtime exception | `Rust/core/src/android_jni.rs` | `Java_com_goose_app_bridge_GooseBridge_handle` | Rust | rust-future | Codex |

#### Axis: Threading

| Finding | File | Symbol | Platform | Tag | Models |
|---------|------|--------|----------|-----|--------|
| `GooseRustBridge.requestValueAsync` wraps blocking FFI in `Task.detached` — should document lifetime pinning | `GooseSwift/GooseRustBridge.swift` | `requestValueAsync` | iOS | ios-future | Codex |

#### Axis: Null-Safety

| Finding | File | Symbol | Platform | Tag | Models |
|---------|------|--------|----------|-----|--------|
| `OvernightSQLiteMirrorQueue.enqueue` drops overflow rows silently — no backpressure or failure indication to callers | `GooseSwift/OvernightSQLiteMirrorQueue.swift` | `enqueue` | iOS | ios-future | Codex |

#### Axis: Android-Specific

| Finding | File | Symbol | Platform | Tag | Models |
|---------|------|--------|----------|-----|--------|
| `AppShell` receives StateFlows without collecting — per finding A-04, but also affects internal AppShell rendering | `android/…/MainActivity.kt` | `AppShell` | Android | android-v16 | Codex |
| `serverUrl` StateFlow 5s timeout causes stale empty initial value on screen return | `android/…/viewmodel/SettingsViewModel.kt` | `serverUrl` | Android | android-v16 | Opus |

---

## Model Agreement Matrix

| Finding | Opus | Codex | Confidence |
|---------|------|-------|------------|
| `string_to_c_string` expect() panics at FFI boundary | HIGH | HIGH | **Strong — 2 models** |
| `importFrame` ignores `safeHandle()` return | HIGH | HIGH | **Strong — 2 models** |
| `syncInProgress`/`activeGeneration` BLE thread races | HIGH | HIGH | **Strong — 2 models** |
| `queryScore` swallows all exceptions silently | HIGH | MEDIUM | **Strong — 2 models** (Opus: HIGH) |
| `MainActivity` StateFlows not collected | HIGH | LOW | **Strong — 2 models** (Opus: HIGH) |
| `bridge/mod.rs` battery parsing inline | MEDIUM | LOW | **Moderate — 2 models** |
| `android_jni.rs` null return on OOM | MEDIUM | MEDIUM | **Strong — 2 models** |
| `CaptureFrameWriteQueue.flushNext` completion race | MEDIUM | MEDIUM | **Strong — 2 models** |
| `store/mod.rs` god file (37 unwraps) | HIGH | (not reviewed) | Single model (confirmed by SEED-004) |
| `metric_features.rs` god file 6,760L | HIGH | (not reviewed) | Single model (confirmed by SEED-004) |
| `nonisolated(unsafe)` without lock enforcement | HIGH | (not reviewed) | Single model (confirmed by SEED-007) |
| `WhoopBleClient.scope` never cancelled | HIGH | (not reviewed) | Single model |
| `GooseUploadService` silent try? | HIGH | (not reviewed) | Single model (confirmed by SEED-007) |

---

## Severity / Tag Summary

| Tag | HIGH | MEDIUM | LOW | Total |
|-----|------|--------|-----|-------|
| android-v16 | 5 | 4 | 3 | **12** |
| rust-future | 3 | 4 | 2 | **9** |
| ios-future | 4 | 4 | 2 | **10** |
| **Total** | **12** | **12** | **7** | **31** |

---

## Gemini Exclusion Note

Gemini CLI was invoked 3 times with self-contained inline prompts (no file paths, explicit "Do NOT read any files" instruction, code slices totalling 231 lines). Each attempt resulted in Gemini entering agentic file-read mode, outputting only the banner ("YOLO mode enabled / Ripgrep not available") and timing out. Exit conditions: exit-0 with 190 bytes (attempt 1), Perl SIGALRM / exit-142 (attempt 2 — 90s timeout fired), process kill after 90s (attempt 3). Status recorded in `127-GEMINI-STATUS.md` per D-01.

---

*Analysis-only report — no source files were modified in Phase 127.*
*Findings feed Phase 128 (android-v16 items) and future milestones (ios-future, rust-future).*
