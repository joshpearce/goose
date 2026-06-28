---
phase: 128-android-architecture-best-practices-fixes
plan: "02"
subsystem: android-compose-viewmodel
status: complete
tags:
  - android
  - compose
  - viewmodel
  - stateflow
  - lifecycle
dependency_graph:
  requires:
    - 128-01
  provides:
    - lifecycle-aware StateFlow collection in MainActivity
    - UploadState observable pipeline
    - private bleClient in AppViewModel
  affects:
    - android/app/src/main/kotlin/com/goose/app/MainActivity.kt
    - android/app/src/main/kotlin/com/goose/app/viewmodel/AppViewModel.kt
    - android/app/src/main/kotlin/com/goose/app/viewmodel/MetricsViewModel.kt
    - android/app/src/main/kotlin/com/goose/app/viewmodel/UploadState.kt
    - android/app/src/main/kotlin/com/goose/app/upload/GooseUploadClient.kt
    - android/app/src/main/kotlin/com/goose/app/ui/AppShell.kt
    - android/app/src/main/kotlin/com/goose/app/ui/HomeScreen.kt
    - android/app/src/main/kotlin/com/goose/app/ui/HealthScreen.kt
    - android/app/src/main/kotlin/com/goose/app/ui/MoreScreen.kt
    - android/app/src/main/kotlin/com/goose/app/ble/WhoopBleClient.kt
tech_stack:
  added:
    - UploadState sealed class (Idle / Uploading / Success(count) / Error(msg))
  patterns:
    - Lifecycle-aware StateFlow collection via collectAsStateWithLifecycle() owned exclusively in MainActivity
    - Child Composables receive resolved value types, never StateFlow<T>
    - Object-level MutableStateFlow on GooseUploadClient singleton for upload progress
    - SharedFlow consumption (syncCompleteEvent) in viewModelScope replacing callback reference cycle
key_files:
  created:
    - android/app/src/main/kotlin/com/goose/app/viewmodel/UploadState.kt
  modified:
    - android/app/src/main/kotlin/com/goose/app/MainActivity.kt
    - android/app/src/main/kotlin/com/goose/app/viewmodel/AppViewModel.kt
    - android/app/src/main/kotlin/com/goose/app/viewmodel/MetricsViewModel.kt
    - android/app/src/main/kotlin/com/goose/app/upload/GooseUploadClient.kt
    - android/app/src/main/kotlin/com/goose/app/ui/AppShell.kt
    - android/app/src/main/kotlin/com/goose/app/ui/HomeScreen.kt
    - android/app/src/main/kotlin/com/goose/app/ui/HealthScreen.kt
    - android/app/src/main/kotlin/com/goose/app/ui/MoreScreen.kt
    - android/app/src/main/kotlin/com/goose/app/ble/WhoopBleClient.kt
decisions:
  - "Lifecycle-aware collection centralized in MainActivity; child screens receive primitive/sealed types"
  - "UploadState defined in viewmodel package (UploadState.kt); GooseUploadClient imports from there"
  - "GooseUploadClient.postToServer() changed to return Int HTTP code so upload() can set Success/Error from actual result"
  - "syncCompleteEvent SharedFlow collected in viewModelScope.launch on Main dispatcher; triggerUpload dispatches to Dispatchers.IO internally"
  - "onSyncComplete @Deprecated stub deleted from WhoopBleClient in this plan as planned — no onSyncComplete reference remains anywhere"
metrics:
  duration_seconds: 363
  completed_date: "2026-06-28"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 9
---

# Phase 128 Plan 02: Compose/ViewModel Fixes Summary

**One-liner:** Lifecycle-aware StateFlow collection moved to MainActivity, resolved values passed to child screens, bleClient privatised, MetricsViewModel failures logged, and GooseUploadClient.uploadState pipeline wired end-to-end to MoreScreen.

## Tasks Completed

| Task | Description | Commit | Findings |
|------|-------------|--------|----------|
| 1 | Lifecycle-collect all StateFlows in MainActivity; push resolved values to child screens; private bleClient (A-04, A-05) | 9cb00a3 | All 7 StateFlows collected in MainActivity; 4 files shed StateFlow<T> params; bleClient private |
| 2 | Log queryScore failures; observable uploadStatus pipeline; syncCompleteEvent wiring (A-06, A-07, A-08) | 6347d09 | MetricsViewModel logs on ok:false and Exception; UploadState pipeline complete; deprecated stub deleted |

## Changes by File

### MainActivity.kt
- Replaced 5 raw `val x = appViewModel.x` StateFlow pass-throughs with `val x by appViewModel.x.collectAsStateWithLifecycle()`
- Added `val uploadStatus by appViewModel.uploadStatus.collectAsStateWithLifecycle()`
- Total: 7 flows collected with lifecycle awareness (connectionState + 6 previously raw)
- Passes resolved values (Int?, Float?, Float?, Float?, String, UploadState) to AppShell

### AppShell.kt
- Signature changed: all `StateFlow<T>` params replaced with resolved value types (Int?, Float?, String, UploadState)
- Removed `import kotlinx.coroutines.flow.StateFlow`
- No intermediate collection inside AppShell — passes values straight to child screens

### HomeScreen.kt
- `liveHeartRateBPM: StateFlow<Int?>` → `liveHeartRateBPM: Int?`
- Deleted `val hr by liveHeartRateBPM.collectAsStateWithLifecycle()` — uses parameter directly
- Removed collectAsStateWithLifecycle and StateFlow imports

### HealthScreen.kt
- Three `StateFlow<Float?>` params → `Float?`
- Deleted three `.collectAsStateWithLifecycle()` calls — uses parameters directly as `recoveryScore`, `strainScore`, `sleepScore`
- Removed collectAsStateWithLifecycle and StateFlow imports

### MoreScreen.kt
- `serverUrl: StateFlow<String>` → `serverUrl: String`
- Deleted `val url by serverUrl.collectAsStateWithLifecycle()` — binds OutlinedTextField directly to `serverUrl` param
- Added `uploadStatus: UploadState` param; renders status line ("Uploading...", "Uploaded N", "Upload error: ...", hidden when Idle)
- Removed collectAsStateWithLifecycle and StateFlow imports

### AppViewModel.kt
- `val bleClient` → `private val bleClient` (A-05)
- Replaced `bleClient.onSyncComplete = { ... }` init block with `viewModelScope.launch { bleClient.syncCompleteEvent.collect { metricsViewModel.refresh(); triggerUpload() } }`
- Added `val uploadStatus: StateFlow<UploadState> = GooseUploadClient.uploadState`

### MetricsViewModel.kt (A-06)
- Added `companion object { private const val TAG = "MetricsViewModel" }`
- `queryScore`: ok:false path now reads error message and calls `Log.e(TAG, "queryScore failed method=$method: $errMsg")`
- `queryScore`: catch block changed from `catch (_: Exception) { null }` to `catch (e: Exception) { Log.e(TAG, "queryScore failed method=$method", e); null }`
- Both paths still return null — no behavioural regression

### UploadState.kt (new)
- `sealed class UploadState` with `object Idle`, `object Uploading`, `data class Success(val count: Int)`, `data class Error(val msg: String)`
- Package: `com.goose.app.viewmodel`

### GooseUploadClient.kt (A-08)
- Added `private val _uploadState = MutableStateFlow<UploadState>(UploadState.Idle)` and `val uploadState: StateFlow<UploadState> = _uploadState.asStateFlow()`
- `postToServer()` return type changed from `Unit` to `Int` (HTTP response code, -1 on IOException)
- `upload()` exit paths:
  - empty serverUrl skip: no state change (stays Idle)
  - before bridge call: `_uploadState.value = UploadState.Uploading`
  - ok:false branch: `_uploadState.value = UploadState.Error(errMsg)` then return
  - null/empty result branch: `_uploadState.value = UploadState.Success(0)` then return
  - HTTP result: `Success(count)` if 200..299 else `Error("HTTP $code")`
  - outer catch: `_uploadState.value = UploadState.Error(e.message ?: "upload failed")`

### WhoopBleClient.kt (A-07 cleanup)
- Deleted `@Deprecated("Use syncCompleteEvent; removed in plan 128-02") var onSyncComplete: (() -> Unit)? = null` and its comment block
- No `onSyncComplete` reference remains anywhere under `android/app/src/main/kotlin`

## Deviations from Plan

None — plan executed exactly as written.

## Verification Results

```
Task 1:
  private val bleClient:                           PASS
  collectAsStateWithLifecycle count >= 6 (actual 8): PASS (7 calls + 1 import line)
  No appViewModel.bleClient refs:                  PASS
  No StateFlow in AppShell:                        PASS
  No StateFlow in HomeScreen:                      PASS
  No StateFlow in HealthScreen:                    PASS
  No StateFlow in MoreScreen:                      PASS

Task 2:
  queryScope failed log in MetricsViewModel:       PASS
  sealed class UploadState exists:                 PASS
  uploadState in GooseUploadClient:                PASS
  UploadState.Uploading in GooseUploadClient:      PASS
  uploadStatus in AppViewModel:                    PASS
  syncCompleteEvent in AppViewModel:               PASS
  No onSyncComplete anywhere in app/src/main/kotlin: PASS
```

## Known Stubs

None. All data flows are wired end-to-end.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. Changes are purely structural (Compose collection pattern, ViewModel encapsulation, observable state). Existing upload HTTP boundary unchanged.

## Self-Check: PASSED

- `/Users/francisco/Documents/goose/android/app/src/main/kotlin/com/goose/app/viewmodel/UploadState.kt` — FOUND
- `/Users/francisco/Documents/goose/android/app/src/main/kotlin/com/goose/app/MainActivity.kt` — FOUND
- `/Users/francisco/Documents/goose/android/app/src/main/kotlin/com/goose/app/upload/GooseUploadClient.kt` — FOUND
- Commit 9cb00a3 — FOUND
- Commit 6347d09 — FOUND
