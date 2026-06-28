---
phase: 128
reviewers: [claude, codex]
reviewed_at: 2026-06-28T16:00:00Z
plans_reviewed:
  - 128-01-PLAN.md
  - 128-02-PLAN.md
  - 128-03-PLAN.md
notes: >
  Gemini CLI (0.49.0) invoked but timed out in agentic repo-exploration mode
  after 4+ minutes — no output produced. Two reviewers (claude, codex) completed
  successfully. Both had full repo access and cited file:line evidence.
---

# Cross-AI Plan Review — Phase 128

## Claude Review

Now I have the full picture. Writing the review grounded in `file:line` evidence.

---

## Phase 128 Plan Review

### Evidence Base

All findings below are traced to actual file+line numbers in the repo. No finding is based solely on the plan's own assertions.

---

## 128-01-PLAN.md — WhoopBleClient BLE/Coroutine Fixes

### Summary

The plan correctly identifies every real bug in `WhoopBleClient.kt`. `importFrame` at line 589 discards `safeHandle()`'s return value entirely; `onSyncComplete` at line 101 is a callback reference; `gatt` at line 103 lacks `@Volatile`; and `scope` at line 91 is never cancelled. The execution plan is mostly sound but has two concrete implementation blockers that will cause either a compile error or a logic gap if not addressed.

### Strengths

- **`importFrame` silent discard correctly identified**: `WhoopBleClient.kt:589` calls `GooseBridge.safeHandle(request)` and discards the `String` return value — a real bug. Fix is straightforward.
- **`onSyncComplete` callback reference cycle**: `AppViewModel.kt:46` does `bleClient.onSyncComplete = { ... }`, holding a reference into AppViewModel from WhoopBleClient. SharedFlow approach eliminates this cleanly.
- **`gatt @Volatile` gap real**: `WhoopBleClient.kt:103` — `private var gatt: BluetoothGatt?` has no `@Volatile`. BLE callback thread writes it; `importFrame` (dispatched to Dispatchers.IO, line 577) reads it at line 398 via `gatt?.device?.address`. Race is real.
- **Scope cancel scope correctly conditional**: `disconnect()` sets `userDisconnected = true` first (line 173). `onGattDisconnected()` checks `willReconnect = !userDisconnected` (line 631) before launching reconnect on scope (line 638). So cancelling scope after `gatt?.disconnect()` in explicit disconnect is safe — the reconnect branch is never reached.
- **D-01 "only cancel on explicit disconnect" traceable**: Reconnect path guarded by `userDisconnected` flag; idle-timeout coroutine dying on scope cancel during explicit disconnect is correct behaviour.

### Concerns

- **HIGH — `val scope` cannot be reassigned**: `WhoopBleClient.kt:91` declares `private val scope`. The plan says "Guard connect() to rebuild scope when prior scope is cancelled." Rebuilding requires `private var scope`. This is a compile-time blocker if the plan is executed as written. The change from `val` to `var` must be explicit in the plan.

- **HIGH — Mutex.withLock requires suspend context**: `startHistoricalSync()` at line 188 is a plain (non-suspend) function called from `scope.launch { }` (line 409) AND the BLE `onCharacteristicWrite` callback (which is not a coroutine). `syncMutex.withLock` is a suspend function — it cannot be called from a non-suspend function without `runBlocking` (which would deadlock the BLE callback thread). The plan must either: (a) make `startHistoricalSync` suspend (and always call via `scope.launch`), or (b) use `Mutex.tryLock()`/`unlock()` with explicit try/finally, or (c) accept that `syncInProgress` as `@Volatile` is the correct level of protection here. As written, the plan will produce a compile error or a blocking call on the BLE thread.

- **MEDIUM — `@Volatile syncInProgress` + Mutex is redundant**: Plan says "Keep @Volatile on syncInProgress … for visibility" AND "Guard transitions with syncMutex.withLock." Once you use a Mutex for write serialisation, @Volatile on the same field is cargo-cult. It won't cause a bug but signals unclear ownership of the invariant.

- **MEDIUM — filesDir validation is unnecessary**: `WhoopBleClient.kt:579` — `context.filesDir` is guaranteed non-null and the directory always exists in a running Android app. D-03's "validate filesDir existence before bridge call" will compile fine but can never actually prevent a failure path. The plan faithfully implements D-03 but reviewers should note this is dead code.

- **LOW — scope rebuild race with reconnect job**: `onGattDisconnected()` at line 638 sets `reconnectJob = scope.launch { ... }`. If `connect()` is called before the reconnect fires and rebuilds scope, `reconnectJob` still references a coroutine on the old scope. The `reconnectJob?.cancel()` at line 160 correctly cancels it, but the comment in the plan should acknowledge this.

### Suggestions

- Explicitly state: change `private val scope` → `private var scope` and declare it `lateinit` or initialise via a factory method called from constructor and from `connect()`.
- For the Mutex problem: either make `startHistoricalSync()` internal and always call via `scope.launch { syncMutex.withLock { ... } }`, or accept `@Volatile` alone as sufficient given the `syncInProgress` check at line 189 is a best-effort guard (missing an update window is not catastrophic — the worst outcome is skipping a sync, not data corruption).
- Verification grep should check both `GlobalScope` AND `runBlocking` — the latter would be a red flag for the Mutex fix.

### Risk Assessment: **MEDIUM**

Correct analysis of all bugs. Two implementation gaps — `val → var` and Mutex/suspend mismatch — need explicit resolution before execution, otherwise the implementor will encounter compile errors and may choose an unsafe workaround.

---

## 128-02-PLAN.md — Compose/ViewModel Fixes

### Summary

The plan correctly diagnoses all four Compose/ViewModel findings. The `StateFlow<T>` passthrough to `AppShell` (current `AppShell.kt:26-31`) and `MoreScreen` collecting its own StateFlow (current `MoreScreen.kt:23`) are real anti-patterns. `queryScore` at `MetricsViewModel.kt:60` silently swallows exceptions. However, the plan has a concrete scope gap (child screen files not listed), a wave-ordering dependency on 128-01, and an architectural gap in how `GooseUploadClient` can emit observable state given it is a singleton `object`.

### Strengths

- **StateFlow passthrough gap is real**: `MainActivity.kt:22-26` — five flows (`liveHeartRateBPM`, `recoveryScore`, `strainScore`, `sleepScore`, `serverUrl`) passed as `StateFlow<T>` to `AppShell`, then to child composables. Only `connectionState` is lifecycle-collected (line 21). Pattern is inconsistent and leaks lifecycle management into child screens.
- **queryScore silent catch identified correctly**: `MetricsViewModel.kt:60` — `catch (_: Exception) { null }` — no logging on any failure path. Fix (Log.e) is correct and minimal.
- **bleClient public visibility real bug**: `AppViewModel.kt:26` — `val bleClient = WhoopBleClient(...)` — public, accessible from UI layer. `private val` is correct fix.
- **MoreScreen double-collection identified**: `MoreScreen.kt:23` calls `collectAsStateWithLifecycle()` on a `StateFlow<String>` that was already available as a resolved value in MainActivity. Fix is correct.
- **syncCompleteEvent collection in viewModelScope**: Collecting SharedFlow in `viewModelScope` is correct lifecycle scope for AppViewModel.

### Concerns

- **HIGH — HomeScreen.kt and HealthScreen.kt missing from "Files Modified"**: `AppShell.kt:69` passes `liveHeartRateBPM: StateFlow<Int?>` to `HomeScreen` and lines 71-76 pass `StateFlow<Float?>` flows to `HealthScreen`. If AppShell's signature changes to receive resolved values and passes them down, HomeScreen and HealthScreen signatures must change too. Neither file is in the plan's files-modified list. The plan will either leave AppShell passing `StateFlow<T>` to children (half-fix) or break compilation.

- **HIGH — Wave 1 parallel execution creates dependency**: 128-01 and 128-02 are both Wave 1. 128-02's AppViewModel change (`bleClient.syncCompleteEvent.collect { ... }` in viewModelScope) depends on `syncCompleteEvent: SharedFlow<Unit>` being added to `WhoopBleClient` by 128-01. If executors run these in parallel, 128-02's AppViewModel code will not compile until 128-01 lands. One plan must be Wave 1, the other Wave 2 (or 128-01 must be a strict dependency gate for 128-02).

- **MEDIUM — GooseUploadClient is a singleton `object`**: `GooseUploadClient.kt:21` — `object GooseUploadClient`. Adding `uploadStatus: StateFlow<UploadState>` to a singleton `object` means it's a process-global StateFlow with no lifecycle. Plan says "GooseUploadClient emits state via callback or Flow<UploadState>" but doesn't decide the mechanism. Options: (a) add `val uploadStatus = MutableStateFlow<UploadState>(Idle)` directly on the object — works but is a global; (b) refactor to a class owned by AppViewModel — breaking change to callers. D-08 specifies AppViewModel exposes `uploadStatus: StateFlow<UploadState>` but doesn't say how GooseUploadClient emits. The plan needs to choose.

- **MEDIUM — queryScore ok:false already returns null**: `MetricsViewModel.kt:56-57` — `if (!json.optBoolean("ok", false)) return null` does return null on ok:false, but silently. The plan correctly adds Log.e here. Note that after fix, callers still see null — the fix improves diagnostics only, no behaviour change.

- **LOW — MoreScreen receives StateFlow<String> removal needs signature update on AppShell**: `AppShell.kt:81` passes `serverUrl = serverUrl` (StateFlow) to MoreScreen. After fix, MoreScreen should receive `String`. This cascades to AppShell's own signature; AppShell is in files-modified, so this is likely handled, but the review should confirm both the parameter and the AppShell → MoreScreen call site are changed together.

### Suggestions

- Add `HomeScreen.kt` and `HealthScreen.kt` to files-modified and detail their signature changes.
- Move 128-02 to Wave 2 (after 128-01 completes) or mark WhoopBleClient's `syncCompleteEvent` addition as a prerequisite that must land first.
- For GooseUploadClient: explicitly decide in CONTEXT.md — either add a `MutableStateFlow<UploadState>` companion to the object (accept global state) or convert to a class instantiated by AppViewModel.
- Verification criterion "collectAsStateWithLifecycle count >= 6 in MainActivity" should add "AND zero StateFlow<T> parameters in AppShell/HomeScreen/HealthScreen/MoreScreen signatures" to be complete.

### Risk Assessment: **MEDIUM**

Two compilation risks (missing child screen files, wave ordering dependency). The GooseUploadClient architecture gap is medium priority. All individual bug identifications are correct against the code.

---

## 128-03-PLAN.md — Hilt DI + CI Gate

### Summary

This plan has the highest risk surface. Hilt + KSP on a Kotlin 2.4.0 / AGP 9.2.0 stack is cutting-edge; the KSP version number is left as a placeholder `2.4.0-<kspPatch>`; the `kotlin-android` plugin is absent from the current build and missing from the plan; and the proposed `@HiltViewModel + @Inject constructor(app: Application)` pattern for `MetricsViewModel` and `SettingsViewModel` is incorrect for Hilt. The D-09a fallback is the correct safety net.

### Strengths

- **D-09a fallback is correctly scoped**: "If Hilt fails CI, revert annotations, keep sub-ViewModels private, document A-09 as DEFERRED" — the fallback does not break prior fixes (128-01, 128-02 are already applied). The fallback outcome (private sub-ViewModels) is already the current state for `metricsViewModel` and `settingsViewModel` (`AppViewModel.kt:28-29`).
- **assembleDebug as integration gate is correct**: This is the right verification signal — if Hilt/KSP wiring is broken it will surface at compile time, not at runtime.
- **`@HiltAndroidApp` application class approach**: Correct entry point for Hilt. `GooseApplication.kt` + `AndroidManifest` update is the standard wiring.
- **T-128-07 threat acknowledged**: The plan surfaces Hilt/KSP version mismatch as a named threat. This is accurate — it is the most likely failure mode.

### Concerns

- **HIGH — `kotlin-android` plugin missing from app/build.gradle.kts and the plan**: `android/app/build.gradle.kts:1-4` applies only `android-application` and `kotlin-compose`. Hilt requires annotation processing via KSP, which requires the `kotlin-android` (or `kotlin-jvm`) plugin to be applied before KSP. Without `kotlin-android`, `ksp` configuration target may not be recognised. The root `build.gradle.kts` would also need `alias(libs.plugins.kotlin.android) apply false`. Neither file nor the plan mentions this. This is likely to fail CI.

- **HIGH — KSP version placeholder not resolved**: The plan writes "KSP version (Kotlin 2.4.0 compatible format `2.4.0-<kspPatch>`)". Kotlin 2.4.0 is extremely new; a KSP stable release for it may or may not exist at execution time. The implementor must resolve this before executing, and the plan does not direct them to a specific source of truth. If no KSP release targets Kotlin 2.4.0, the entire plan stalls.

- **HIGH — `@HiltViewModel + @Inject constructor(app: Application)` is incorrect**: Hilt does not support `@HiltViewModel` on classes that extend `AndroidViewModel` with `@Inject constructor(app: Application)` via default binding. The correct pattern is `@HiltViewModel class MetricsViewModel @Inject constructor(@ApplicationContext private val context: Context) : ViewModel()` — dropping `AndroidViewModel` and using `@ApplicationContext`. The plan's instruction will likely produce a Dagger/Hilt compile error.

- **MEDIUM — Sub-ViewModel composition conflict with Hilt**: `AppViewModel.kt:28-29` — `private val metricsViewModel = MetricsViewModel(app)` and `private val settingsViewModel = SettingsViewModel(app)`. With Hilt, `@HiltViewModel` ViewModels cannot be directly instantiated — they must be obtained via `hiltViewModel()` in Compose or `by viewModels()` in an Activity/Fragment. The plan says "inject via Hilt or Activity-level viewModels()" but an AppViewModel cannot call `viewModels()` on the Activity — it has no Activity reference. The actual solution is to either: (a) inject MetricsViewModel and SettingsViewModel as Hilt entry-points from MainActivity and pass their state into AppViewModel, or (b) merge their logic into AppViewModel.

- **LOW — Hilt 2.59.x + AGP 9.2.0 compatibility**: Hilt 2.56+ added KSP2 support. AGP 9.2.0 is ahead of the stable release track. The combination has not been widely validated.

### Suggestions

- Before executing: resolve the exact KSP version by checking `https://github.com/google/ksp/releases` for a release targeting Kotlin 2.4.0. If none exists, invoke D-09a immediately.
- Add `kotlin-android` plugin to libs.versions.toml, root build.gradle.kts, and app build.gradle.kts.
- Change `@Inject constructor(app: Application)` to `@Inject constructor(@ApplicationContext context: Context)` and change base class from `AndroidViewModel` to `ViewModel()` for Hilt-annotated ViewModels.
- Decide upfront whether D-09a is the default path given the Kotlin 2.4.0 toolchain is very new.

### Risk Assessment: **HIGH**

Three concrete blockers before execution: `kotlin-android` plugin missing, KSP version unresolved, and incorrect `@HiltViewModel` + `AndroidViewModel` + `Application` injection pattern. D-09a fallback is sound, but the fallback must be explicitly planned as the probable outcome rather than a contingency.

---

## Cross-Plan Issues (Claude)

| Issue | Plans | Severity |
|---|---|---|
| 128-01 and 128-02 both Wave 1 but 128-02 depends on `syncCompleteEvent` from 128-01 | 01, 02 | HIGH |
| HomeScreen.kt + HealthScreen.kt not in any plan's files-modified | 02 | HIGH |
| `kotlin-android` plugin absent from plan and build files | 03 | HIGH |
| KSP version unresolved placeholder | 03 | HIGH |
| `@HiltViewModel + AndroidViewModel + Application` incorrect pattern | 03 | HIGH |
| `val scope` must become `var` — not stated explicitly | 01 | HIGH |
| Mutex.withLock in non-suspend function | 01 | HIGH |
| GooseUploadClient `object` + StateFlow architecture undecided | 02 | MEDIUM |

## Overall Phase Risk (Claude): **HIGH**

128-01 and 128-02 are well-grounded in the actual bugs but have implementation gaps that will surface as compile errors. 128-03 has three blockers that make CI failure the most likely first outcome; the D-09a fallback is the correct response but should be treated as the primary path given the toolchain risk. Recommend resolving the wave-ordering dependency, adding the missing screen files, and deciding on the KSP question before any code touches the repository.

---

## Codex Review

**Summary**
The three Phase 128 plans mostly describe changes that are not yet present in the repo. Current Android code still uses a single long-lived BLE scope with callback-based sync completion, public `bleClient`, naive Compose flow collection, fire-and-forget uploads, and no Hilt/KSP wiring. Each success criterion in the plans has open gaps, so risk is high unless these deltas are implemented and verified.

**Strengths**
- No `GlobalScope` usage in the current BLE client, so removing it is low-effort compliance with BP-AND-02. (`android/app/src/main/kotlin/com/goose/app/ble/WhoopBleClient.kt:91`)
- StateFlows are already exposed for BLE connection and metrics, providing a solid basis for lifecycle-aware collection. (`android/app/src/main/kotlin/com/goose/app/viewmodel/AppViewModel.kt:23-35`, `android/app/src/main/kotlin/com/goose/app/viewmodel/MetricsViewModel.kt:29-36`)

**Concerns**
- **HIGH** – Scope lifecycle not fixed: BLE `scope` is a single `CoroutineScope(SupervisorJob()+Dispatchers.IO)` created once and never cancelled or recreated; `disconnect()` only calls `gatt?.disconnect()`, so coroutines may outlive the connection. (`ble/WhoopBleClient.kt:91,167-176,606-620`)
- **HIGH** – Sync completion still callback-based; no `SharedFlow` event and no mutex around sync state. `onSyncComplete` remains a nullable function; `syncInProgress`/`pendingSyncCommand` mutate without locking. (`ble/WhoopBleClient.kt:100-140,563-573`)
- **HIGH** – Import path still swallows bridge errors: `importFrame` fires `GooseBridge.safeHandle` without JSON parsing or logging on `ok:false`; invalid `filesDir` isn't validated. (`ble/WhoopBleClient.kt:575-590`)
- **HIGH** – AppViewModel exposes `val bleClient` publicly, contradicting D-05 privacy intent and allowing UI-layer access. (`viewmodel/AppViewModel.kt:18-35`)
- **HIGH** – Compose lifecycle collection not applied: MainActivity collects only `connectionState`; other flows are passed downstream, and child screens do their own collection, violating the "collect in MainActivity" plan. (`MainActivity.kt:21-35`, `ui/AppShell.kt:24-83`, `ui/MoreScreen.kt:17-48`, `ui/HealthScreen.kt:18-39`, `ui/HomeScreen.kt:18-39`)
- **HIGH** – `MetricsViewModel.queryScore` swallows exceptions and `ok:false` without logging, contrary to A-06/D-06. (`viewmodel/MetricsViewModel.kt:51-63`)
- **HIGH** – Upload path is still fire-and-forget with no observable `UploadState` or status rendering; no SharedFlow collection of sync completion; MoreScreen has no status UI. (`upload/GooseUploadClient.kt:33-102`, `viewmodel/AppViewModel.kt:37-49`, `ui/MoreScreen.kt:17-48`)
- **HIGH** – Hilt/KSP not integrated: no hilt dependencies or plugins, no `@HiltAndroidApp` Application, no `@AndroidEntryPoint` Activity/ViewModels; build.gradle and version catalog lack hilt/ksp entries, so the assembleDebug gate is currently absent. (`android/app/build.gradle.kts:1-60`, `android/build.gradle.kts:1-4`, `android/gradle/libs.versions.toml:1-26`)
- **MEDIUM** – GATT/thread safety gaps: `gatt` is not `@Volatile` and there's no mutex protecting `syncInProgress`/`activeGeneration`, leaving races unaddressed. (`ble/WhoopBleClient.kt:103-140`)
- **MEDIUM** – Phase goals not yet verifiable: No grep/lint guard for silent JNI error discards; `GooseBridge` calls still ignore return values in several paths. (`ble/WhoopBleClient.kt:575-590`, `upload/GooseUploadClient.kt:43-65`)

**Suggestions**
- Add lifecycle-bound scope management: recreate `scope` if inactive on `connect`, and `scope.cancel()` after `gatt?.disconnect()` completes when not reconnecting.
- Replace `onSyncComplete` with `MutableSharedFlow<Unit>(replay=0, extraBufferCapacity=1, onBufferOverflow=DROP_OLDEST)` and emit from `completeSyncIfActive`; collect in `AppViewModel` within `viewModelScope`.
- Introduce `syncMutex.withLock { ... }` around sync start/complete mutations; mark `gatt` `@Volatile`.
- In `importFrame`, validate `filesDir`, parse `safeHandle` JSON, and `Log.e` on `ok:false` or parse failures; return early on errors.
- Make `bleClient` `private` in `AppViewModel`; expose only needed flows and actions.
- In `MainActivity`, use `collectAsStateWithLifecycle` for all flows (HR, recovery, strain, sleep, serverUrl) and pass resolved values to `AppShell`; drop downstream flow collection.
- Add logging in `queryScore` for exceptions and `ok:false`, preserving null fallback.
- Implement `UploadState` sealed class and `StateFlow` pipeline from `GooseUploadClient` → `AppViewModel` → `MoreScreen` status display.
- Integrate Hilt/KSP per plan (catalog entries, plugins, `GooseApplication @HiltAndroidApp`, `@AndroidEntryPoint` MainActivity, `@HiltViewModel` constructors) and keep a documented fallback path if assembleDebug fails.
- Add a CI or local `./gradlew :app:assembleDebug` gate once Hilt wiring lands to satisfy success criterion 4.

**Risk Assessment**: HIGH — Major plan items are absent in code: lifecycle scope handling, mutexed sync state, error propagation, lifecycle-aware Compose collection, upload observability, and Hilt integration. Without these, success criteria 1–4 of Phase 128 are unmet and regressions (leaked coroutines, swallowed errors) remain.

---

## Consensus Summary

Both reviewers (claude CLI and codex) had full repo access and cited file:line evidence. Gemini CLI timed out without producing output and is excluded from consensus.

### Agreed Strengths

- The plan's bug analysis is accurate: `WhoopBleClient.kt:589` silent discard, `AppViewModel.kt:46` reference cycle via `onSyncComplete`, `WhoopBleClient.kt:103` missing `@Volatile`, and `AppViewModel.kt:26` public `bleClient` are all confirmed real issues by both reviewers.
- The StateFlow passthrough pattern in `MainActivity.kt:22-26` is confirmed as a real anti-patterns with existing `collectAsState()` inconsistency.
- The SharedFlow approach (D-07) and D-09a fallback are both confirmed as sound.
- `queryScore` silent catch at `MetricsViewModel.kt:60` confirmed as a real bug.

### Agreed Concerns (Highest Priority)

**These were raised by both reviewers and should block execution until resolved:**

1. **Plan 128-01: `val scope` vs `var scope`** — `WhoopBleClient.kt:91` declares `val scope`; rebuilding it on reconnect requires `var`. Compile-time blocker not stated in the plan.

2. **Plan 128-01: Mutex.withLock in non-suspend context** — `startHistoricalSync()` is called from the BLE callback thread (non-coroutine). `withLock` is a suspend function; calling it here will deadlock or not compile. Plan must choose an alternative (make function suspend + scope.launch, or use tryLock/unlock, or stay with @Volatile only).

3. **Plan 128-02: HomeScreen.kt + HealthScreen.kt missing from files-modified** — Both reviewers confirm `AppShell.kt:69-76` passes `StateFlow<T>` to HomeScreen and HealthScreen. These files must be modified when AppShell's signature changes, or compilation breaks.

4. **Plan 128-02: Wave ordering dependency** — 128-01 and 128-02 are both Wave 1, but 128-02's `AppViewModel` change (collecting `syncCompleteEvent`) depends on the `SharedFlow` added by 128-01. Parallel execution will fail to compile 128-02.

5. **Plan 128-03: `kotlin-android` plugin missing** — Claude reviewer identified `android/app/build.gradle.kts:1-4` only applies `android-application` and `kotlin-compose`. KSP requires `kotlin-android`. The plan does not mention this, making the Hilt setup likely to fail without this plugin.

6. **Plan 128-03: KSP version placeholder unresolved** — "2.4.0-<kspPatch>" is not a real version. Kotlin 2.4.0 is new enough that a compatible KSP release may not exist; execution must resolve this first.

7. **Plan 128-03: Incorrect `@HiltViewModel + AndroidViewModel + Application` injection** — Claude reviewer flags that injecting `Application` directly via `@Inject constructor(app: Application)` into a `@HiltViewModel` class does not work out of the box. Correct pattern uses `@ApplicationContext context: Context` with base class `ViewModel()`.

### Divergent Views

- **Codex** classified all current gaps as HIGH (plans describe changes not yet in code), while **Claude** split them into MEDIUM (01, 02) vs HIGH (03), noting that 01/02 bugs are correctly identified but the implementation blockers are surgical. Both are correct — Codex is auditing current state, Claude is auditing plan quality.
- **filesDir validation** (D-03): Claude notes it is dead code (filesDir always exists on Android); Codex does not comment on this. Agree to disagree — it is harmless but pointless.
- **GooseUploadClient `object` architecture**: Claude flags this as an unresolved MEDIUM decision; Codex notes it as a gap but does not rate it separately. Both agree the mechanism needs to be chosen before execution.
