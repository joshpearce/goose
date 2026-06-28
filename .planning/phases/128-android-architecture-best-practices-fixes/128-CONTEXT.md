# Phase 128: Android Architecture & Best-Practices Fixes - Context

**Gathered:** 2026-06-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix all 9 android-v16 findings from Phase 127 audit (A-01–A-09) in the Android Kotlin layer only. No Rust or iOS changes. All fixes must preserve existing BLE/sync/upload behaviour while eliminating the identified code health gaps.

</domain>

<decisions>
## Implementation Decisions

### A-01: WhoopBleClient coroutine scope lifecycle
- **D-01:** Add `fun disconnect()` (or extend existing) that cancels `scope` on BLE disconnect. Bind scope creation to object init; cancel on explicit disconnect or Activity/ViewModel destruction. Use `CoroutineScope(SupervisorJob() + Dispatchers.IO)` owned by WhoopBleClient, cancelled via `scope.cancel()` in disconnect path.

### A-02: syncInProgress/activeGeneration/gatt thread safety
- **D-02:** Wrap sync state mutations (`syncInProgress`, `activeGeneration`) with `Mutex` from kotlinx.coroutines. `gatt` reference protected with `@Volatile` or replaced by `AtomicReference<BluetoothGatt?>`.

### A-03: importFrame silent discard
- **D-03:** `importFrame` must check `GooseBridge.safeHandle()` return value and propagate failure: return `Result<Unit>` or throw, log error with `Log.e` at minimum.

### A-04: MainActivity StateFlow Compose collection
- **D-04:** Replace raw `StateFlow<T>` collection in Compose with `collectAsStateWithLifecycle()` from `androidx.lifecycle.compose`. Already available (libs.androidx.lifecycle.runtime.compose is in build.gradle.kts).

### A-05: bleClient visibility
- **D-05:** Change `bleClient` from `val` to `private val` on AppViewModel. Any existing UI access must go through ViewModel methods.

### A-06: queryScore exception logging
- **D-06:** Add `try/catch` around bridge call in `queryScore`; log with `Log.e("MetricsViewModel", "queryScore failed", e)` and return null/empty state. Also handle `ok:false` responses explicitly.

### A-07: onSyncComplete reference cycle → SharedFlow
- **D-07:** Replace `onSyncComplete: () -> Unit` callback in WhoopBleClient with `val syncCompleteEvent: SharedFlow<Unit> = MutableSharedFlow()`. AppViewModel collects this in its `viewModelScope`. Eliminates ViewModel→BleClient→ViewModel cycle.

### A-08: GooseUploadClient observable state
- **D-08:** Add `uploadStatus: StateFlow<UploadState>` to AppViewModel (enum/sealed class: Idle, Uploading, Success, Error(msg)). AppViewModel collects from GooseUploadClient (refactored to emit via Flow), publishes to Compose via `uploadStatus`. MoreScreen observes `uploadStatus` with `collectAsStateWithLifecycle()`.

### A-09: Sub-ViewModels → Hilt DI
- **D-09:** Add Hilt to Android project (not currently present). Add to `build.gradle.kts`:
  - Plugin: `id("com.google.dagger.hilt.android")` + kapt or ksp
  - Deps: `hilt-android`, `hilt-android-compiler`
  - `@HiltAndroidApp` on Application class (create if absent)
  - `@HiltViewModel` + `@Inject constructor` on MetricsViewModel and SettingsViewModel
  - `@AndroidEntryPoint` on MainActivity
  - AppViewModel receives MetricsViewModel + SettingsViewModel via constructor injection or `hiltViewModel()` Compose API
- **D-09a:** If Hilt proves too complex to wire without tests (build issues), fallback: make sub-ViewModels `private` in AppViewModel and document as deferred in VERIFICATION.md.

### Claude's Discretion
- Order of fixes within plans (can group by file)
- Exact UploadState sealed class shape
- Whether to add Application class or find existing one

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 127 Audit Output (primary input)
- `.planning/phases/127-multi-model-code-audit/127-AUDIT-REPORT.md` — Full findings report; Phase 128 Fix List section is the bounded input
- `.planning/phases/127-multi-model-code-audit/127-OPUS-FINDINGS.md` — Detailed Opus findings with evidence

### Android Source Files to Modify
- `android/app/src/main/kotlin/com/goose/app/ble/WhoopBleClient.kt` — A-01, A-02, A-03, A-07
- `android/app/src/main/kotlin/com/goose/app/MainActivity.kt` — A-04, Hilt @AndroidEntryPoint
- `android/app/src/main/kotlin/com/goose/app/viewmodel/AppViewModel.kt` — A-05, A-07, A-08, A-09
- `android/app/src/main/kotlin/com/goose/app/viewmodel/MetricsViewModel.kt` — A-06, A-09
- `android/app/src/main/kotlin/com/goose/app/viewmodel/SettingsViewModel.kt` — A-09
- `android/app/src/main/kotlin/com/goose/app/upload/GooseUploadClient.kt` — A-08

### Build Config
- `android/app/build.gradle.kts` — needs Hilt plugin + deps (D-09)
- `android/build.gradle.kts` (root) — needs Hilt classpath
- `android/gradle/libs.versions.toml` (if exists) — version catalog

### Requirements
- `.planning/REQUIREMENTS.md` — RUST-AUD-02, BP-AND-01, BP-AND-02

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `androidx.lifecycle.runtime.compose` already in build.gradle.kts → `collectAsStateWithLifecycle()` available without new dep
- `kotlinx.coroutines` already available (BLE client uses coroutines)
- `GooseBridge.safeHandle()` already has error return value — just need to check it

### Established Patterns
- Existing BLE callback pattern in WhoopBleClient uses coroutines
- AppViewModel already has `viewModelScope` (AndroidX lifecycle)
- Compose screens already observe StateFlows via `collectAsState()` — upgrade to `collectAsStateWithLifecycle()`

### Integration Points
- A-07 fix (SharedFlow) changes WhoopBleClient's public interface — AppViewModel must update collection site
- A-09 (Hilt) requires Application class — check if GooseApplication exists, else create
- A-08 (uploadStatus StateFlow) feeds MoreScreen which must be updated to observe it

</code_context>

<specifics>
## Specific Ideas

- For A-07 (SharedFlow): `MutableSharedFlow<Unit>(replay=0, extraBufferCapacity=1, onBufferOverflow=DROP_OLDEST)` — fire-and-forget sync complete signal
- For A-08 (UploadState): `sealed class UploadState { object Idle; object Uploading; data class Success(val count: Int); data class Error(val msg: String) }`
- For A-09 (Hilt): if Application class doesn't exist, create `GooseApplication : Application()` with `@HiltAndroidApp`
- D-09a fallback: if Hilt wiring fails CI, defer A-09 with comment in VERIFICATION.md and mark as deferred

</specifics>

<deferred>
## Deferred Ideas

- iOS threading fixes (ios-future from audit) — v17.0
- Rust god-file decomposition (rust-future from audit) — future milestone
- Android HealthConnect export parity — future seed
- Full Hilt migration of all Android components — only A-09 sub-ViewModels in scope here

</deferred>

---

*Phase: 128-Android Architecture & Best-Practices Fixes*
*Context gathered: 2026-06-28*
