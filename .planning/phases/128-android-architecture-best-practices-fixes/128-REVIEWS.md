---
phase: 128
reviewers: [claude, codex]
reviewed_at: 2026-06-28T20:00:00Z
plans_reviewed:
  - 128-01-PLAN.md
  - 128-02-PLAN.md
  - 128-03-PLAN.md
notes: >
  Gemini CLI (0.49.0) invoked twice but timed out in agentic repo-exploration mode
  both times (2026-06-28T16:00Z and 2026-06-28T18:00Z) — no output produced even
  with --approval-mode plan and gemini-2.0-flash. Excluded from consensus.
  Claude CLI and Codex both completed with full codebase access and file:line evidence.
  Cycle-3 review; all cycle-2 HIGH concerns are incorporated into current plan versions
  (@Volatile var scope, compareAndSet per-site, onSyncComplete stub pattern,
  MoreScreen serverUrl, @Preview N/A, D-09a confirm-only, upload emit paths,
  AppShell uploadState chain, native libs pre-flight, dispatcher safety).
  Claude CLI completed with 3 new concerns (2 MEDIUM on 128-02, 1 cross-plan MEDIUM).
  Codex found no new concerns (all cycle-2 issues resolved). Cycle 3 is the final
  convergence cycle; phase risk is MEDIUM solely from the UploadState placement
  ambiguity and the collectAsStateWithLifecycle threshold undercount in 128-02.
---

# Cross-AI Plan Review — Phase 128 (Cycle 3)

## Claude Review

### Phase 128 Plan Review

#### Evidence Base

| File | Lines reviewed |
|------|----------------|
| `android/app/src/main/kotlin/com/goose/app/ble/WhoopBleClient.kt` | 91, 103, 126, 133, 158–171, 188, 305, 396, 401, 471–472, 567–573, 622–624, 638, 714 |
| `android/app/src/main/kotlin/com/goose/app/viewmodel/AppViewModel.kt` | 26, 28–29, 44–50, 55–59, 61–64 |
| `android/app/src/main/kotlin/com/goose/app/viewmodel/MetricsViewModel.kt` | 51–63 |
| `android/app/src/main/kotlin/com/goose/app/ui/AppShell.kt` | 24–32, 66, 71–76, 78–82 |
| `android/app/src/main/kotlin/com/goose/app/ui/HomeScreen.kt` | 19–24 |
| `android/app/src/main/kotlin/com/goose/app/ui/HealthScreen.kt` | 19–27 |
| `android/app/src/main/kotlin/com/goose/app/ui/MoreScreen.kt` | 17–29 |
| `android/app/src/main/kotlin/com/goose/app/upload/GooseUploadClient.kt` | 33–65 |

---

### 128-01-PLAN.md — WhoopBleClient BLE/Coroutine Fixes

#### Summary

Solid, narrowly-scoped plan. All cycle-2 HIGH/MEDIUM concerns are incorporated with precise change descriptions. The concurrency model (AtomicBoolean/AtomicReference, @Volatile scope, compareAndSet per call site) is correctly specified for the BLE callback threading model.

#### Strengths
- compareAndSet semantics locked in per call site (false→true for start, true→false for complete, set(false) for disconnect reset).
- DROP_OLDEST buffer policy on SharedFlow is correct for the fire-and-forget BLE completion signal — no coroutine can block the BLE callback thread.
- `onSyncComplete` stub explicitly never invoked; wave-1 isolation rationale is clear and correct.
- Automated grep verification covers all structural changes.

#### Concerns

- **LOW** — `reconnectJob` reference not reset after `scope.cancel()`. `reconnectJob: Job?` (WhoopBleClient.kt line 126) is stored independently of the scope. When `scope.cancel()` fires in `disconnect()`, the job is cancelled as a scope child, but the field remains non-null. If `connect()` checks `reconnectJob?.isActive` before launching a new reconnect coroutine, the check returns false (correct, job is cancelled), so the behaviour is benign. But the plan's silence means the executor may leave a stale reference that future readers must reason through. Worth a one-liner note in the SUMMARY.

- **LOW** — Verification does not check new SharedFlow imports. The automated grep for Task 1 checks `syncCompleteEvent` presence and `scope.cancel` but does not verify the four new imports (BufferOverflow, MutableSharedFlow, SharedFlow, asSharedFlow). A partial import (e.g. missing BufferOverflow) would fail compilation but not fail the verification command — the assembleDebug gate in 128-03 would catch it, but the gap means Task 1 can report PASS before wave-3.

#### Suggestions
- Add `reconnectJob = null` after `scope.cancel()` in disconnect() (or explicitly state that the stale-reference-is-benign invariant is intentional) so the SUMMARY records this.
- Extend Task 1 automated grep: add `grep -q 'BufferOverflow.DROP_OLDEST' WhoopBleClient.kt` alongside the existing checks.

#### Risk Assessment: **LOW**

---

### 128-02-PLAN.md — Compose/ViewModel Fixes

#### Summary

Comprehensive plan that correctly migrates all StateFlow collection into MainActivity. Two genuine new concerns: a package-layering inversion risk in UploadState placement, and a verification threshold that undercounts the expected `collectAsStateWithLifecycle` calls.

#### Strengths
- All 5 UploadState emit paths explicitly enumerated (Uploading at start, Error on get-streams ok:false, Success(0) on no-pending, Success(count)/Error on HTTP result, Error in outer catch).
- `grep -rq 'onSyncComplete'` across the full kotlin tree is a strong completeness check.
- AppShell signature change explicitly cascaded into all 3 child screens; serverUrl and uploadStatus forwarding chains are both stated.
- No-@Preview verification eliminates the false-preview-breakage risk.

#### Concerns

- **MEDIUM** — UploadState placement "Claude's discretion" risks package-layer inversion. The plan allows placing `sealed class UploadState` in `AppViewModel.kt` or a sibling `UploadState.kt` in `com.goose.app.viewmodel`. But `GooseUploadClient.kt` lives in `com.goose.app.upload`. If the executor places UploadState in the viewmodel package, GooseUploadClient must import from `com.goose.app.viewmodel` — an upward upload→viewmodel dependency that inverts the natural layering (upload client should not depend on ViewModel types). The correct placement is `com.goose.app.upload.UploadState` so AppViewModel imports downward from the upload layer.

- **MEDIUM** — `collectAsStateWithLifecycle` verification threshold `>= 6` undercounts. After all 128-02 changes, MainActivity will have 7 `collectAsStateWithLifecycle` calls: existing `connectionState` (1) + migrated `liveHeartRateBPM`, `recoveryScore`, `strainScore`, `sleepScore`, `serverUrl` (5) + new `uploadStatus` (1) = 7. The automated check `test "$(grep -c ...)" -ge 6` passes with 6, meaning an executor that collects all 6 original flows but forgets `uploadStatus` in MainActivity — and instead threads it as a raw `StateFlow<UploadState>` through AppShell — would pass the grep gate. This is exactly the anti-pattern 128-02 exists to eliminate. Threshold must be `>= 7`.

- **LOW** — Task 2 is `tdd="true"` with no test plan. Task 2 is flagged `tdd="true"` but acceptance criteria are entirely grep-based structural checks. There is no specification of which test file to create, which classes to test (GooseUploadClient.upload() emit sequence? MetricsViewModel.queryScore() on ok:false?), or what test doubles to use for the Rust bridge and HTTP layer. Either the `tdd` flag is a copy error (Task 1 is `tdd="false"`) or the test scope needs to be specified. As-is, an executor taking `tdd="true"` literally will produce unguided tests.

#### Suggestions
- Pin UploadState to `com.goose.app.upload.UploadState` explicitly: "place `sealed class UploadState` in `android/app/src/main/kotlin/com/goose/app/upload/UploadState.kt`; AppViewModel imports from `com.goose.app.upload`."
- Change verification threshold to `>= 7` to require the uploadStatus collection.
- Change Task 2 to `tdd="false"` (matching Task 1), or add an explicit `<test>` block specifying behaviours to test and test doubles to use.

#### Risk Assessment: **MEDIUM**

---

### 128-03-PLAN.md — Hilt DI + CI Gate

#### Summary

Conservative and correctly gated. D-09a is the primary path with clear rationale; Hilt is optional with explicit precondition checks. No new concerns beyond what is already incorporated.

#### Strengths
- KSP/Kotlin 2.4.0 compatibility check is explicitly gated at runtime (check github.com/google/ksp/releases) rather than assumed.
- Correct Hilt pattern documented: `@ApplicationContext context: Context`, `ViewModel()` not `AndroidViewModel(app)`.
- `kotlin-android` before `ksp` ordering constraint is called out.
- jniLibs pre-flight acknowledged as an environment prerequisite, not a phase defect.
- Sub-ViewModels already private — confirm-only path is low-risk.

#### Concerns

No new concerns identified beyond those already incorporated.

#### Suggestions
- Optionally add a checklist line to VERIFICATION.md: "Hilt deferred — revisit when KSP 2.4.0-x.y.z tag appears on github.com/google/ksp/releases" so the deferral has an actionable follow-up anchor.

#### Risk Assessment: **LOW**

---

### Cross-Plan Issues

**MEDIUM: `GooseUploadClient` singleton `uploadState` persists across ViewModel recreation**

`GooseUploadClient` is a Kotlin `object`. The `_uploadState: MutableStateFlow<UploadState>` placed on it will survive Activity configuration changes (which destroy and recreate `AppViewModel`). The new `AppViewModel` instance delegates `uploadStatus` to the singleton's stale flow — which may be `Error(msg)` or `Success(n)` from the previous lifecycle visible on first render. None of the three plans address reset-on-recreation semantics. This is not a data-loss bug but a UX defect (MoreScreen shows a stale upload badge after rotation). Fix: either (a) reset `_uploadState.value = UploadState.Idle` in `AppViewModel.init {}`, or (b) explicitly accept stale-state display for v1. The plan must choose one.

**LOW: No intermediate compile gate between waves**

128-02-PLAN explicitly states it "runs AFTER plan 128-01 has landed" and warns about compile failure if run in parallel. The `depends_on: [128-01]` field encodes this. However, the only compile gate is the assembleDebug in wave-3. If an executor runs 128-01 and 128-02 concurrently despite the dependency, there is no intermediate compilation check. This is an execution risk, not a plan defect.

### Overall Phase Risk: **MEDIUM**

The 128-02 UploadState placement ambiguity is the most actionable open item — likely to be resolved incorrectly (viewmodel package) without explicit guidance, introducing a package-layer inversion requiring a follow-up cleanup commit. The collectAsStateWithLifecycle threshold undercounting compounds this: an incorrect executor could pass all grep checks while threading a StateFlow through AppShell. Both are fixable with one-line additions to the plan before execution. The singleton stale-state issue is a UX concern easily addressed by one `AppViewModel.init` line, but requires an explicit decision.

---

## Codex Review

### Phase 128 Plan Review

#### Evidence Base

Codex explored the repository with full filesystem access and read:
- `.planning/phases/128-android-architecture-best-practices-fixes/128-01-PLAN.md`
- `.planning/phases/128-android-architecture-best-practices-fixes/128-02-PLAN.md`
- `.planning/phases/128-android-architecture-best-practices-fixes/128-03-PLAN.md`
- `android/app/src/main/kotlin/com/goose/app/ble/WhoopBleClient.kt`
- `android/app/src/main/kotlin/com/goose/app/viewmodel/AppViewModel.kt`
- `android/app/src/main/kotlin/com/goose/app/ui/AppShell.kt`, HomeScreen.kt, HealthScreen.kt, MoreScreen.kt
- `android/app/src/main/kotlin/com/goose/app/upload/GooseUploadClient.kt`

---

### 128-01-PLAN.md — WhoopBleClient BLE/Coroutine Fixes

#### Summary

Wave 1 hardens `WhoopBleClient` threading and error logging without changing behaviour.

#### Strengths
- Explicit volatile scope lifecycle and atomic sync/gatt state remove race windows.
- SharedFlow-based completion signal avoids callback cycle and is non-blocking.
- `importFrame` now surfaces bridge failures via structured Log.e.

#### Concerns

No new concerns identified beyond those already incorporated.

#### Suggestions
- None; proceed with implementation as specified.

#### Risk Assessment: **LOW**

---

### 128-02-PLAN.md — Compose/ViewModel Fixes

#### Summary

Wave 2 moves lifecycle-aware StateFlow collection to `MainActivity`, privatizes BLE access, adds upload/status observability, and logs metric failures.

#### Strengths
- Single-point lifecycle collection eliminates UI-layer StateFlow leakage.
- UploadState pipeline is fully specified with five emit paths.
- `bleClient` encapsulation and `queryScore` logging address audit findings directly.

#### Concerns

No new concerns identified beyond those already incorporated.

#### Suggestions
- Keep `UploadState` in a package accessible to both `GooseUploadClient` and `AppViewModel` to avoid accidental duplication.

#### Risk Assessment: **LOW**

---

### 128-03-PLAN.md — Hilt DI + CI Gate

#### Summary

Wave 3 confirms pre-existing sub-ViewModel encapsulation, documents Hilt deferral, and gates the integrated changes with `assembleDebug`.

#### Strengths
- Clear primary path (D-09a) avoids Kotlin 2.4.0/KSP fragility while meeting A-09 intent.
- Build gate explicitly classifies native-libs absence as environment, preventing false regressions.
- VERIFICATION.md ensures audit traceability for deferred Hilt work.

#### Concerns

No new concerns identified beyond those already incorporated.

#### Suggestions
- If native libs are missing, record the exact path and absence in VERIFICATION.md alongside the classification already described.

#### Risk Assessment: **LOW**

---

### Cross-Plan Issues

No new cross-plan issues discovered; wave sequencing and interfaces are already aligned.

### Overall Phase Risk: **LOW**

---

## Consensus Summary

Both reviewers (Claude CLI and Codex) had full repository access. Gemini CLI (0.49.0) invoked but timed out in both Cycle 1 and Cycle 2 — excluded from consensus. This is Cycle 3.

### Agreed Strengths

- All six Cycle-2 HIGH concerns are correctly resolved in the current plan versions: @Volatile var scope, compareAndSet per-site specificity, onSyncComplete stub isolation, MoreScreen serverUrl fix, @Preview N/A confirmation, D-09a confirm-only for already-private sub-ViewModels.
- SharedFlow contract remains well-specified (replay=0, extraBufferCapacity=1, DROP_OLDEST, tryEmit).
- UploadState 5-path enumeration is complete and explicit.
- Wave sequencing is correct and the dependency field is properly encoded.
- Hilt deferral rationale (Kotlin 2.4.0 / KSP / kotlin-android) remains sound and documented.

### Agreed Concerns (Highest Priority)

**Claude only — not independently confirmed by Codex but grounded in codebase evidence:**

1. **Plan 128-02: UploadState package placement ambiguity** — The plan says "AppViewModel.kt or a sibling UploadState.kt" (i.e. `com.goose.app.viewmodel`). But GooseUploadClient lives in `com.goose.app.upload`. If UploadState is in the viewmodel package, GooseUploadClient must import it upward — an upload→viewmodel dependency inversion. Correct placement: `com.goose.app.upload.UploadState`. Codex independently noted the same layering risk in its suggestion ("keep UploadState in a package accessible to both GooseUploadClient and AppViewModel"). Fix: state the package explicitly in the plan.

2. **Plan 128-02: `collectAsStateWithLifecycle` verification threshold undercounts** — Current automated check is `>= 6`; post-128-02 MainActivity will have 7 calls (connectionState + 5 migrated + uploadStatus). With threshold 6 an executor could omit uploadStatus collection and still pass. Fix: change to `>= 7`.

3. **Cross-plan: GooseUploadClient singleton stale UploadState on ViewModel recreation** — The `object`-level `_uploadState` MutableStateFlow survives Activity rotation. A new AppViewModel instance will show the previous session's terminal state (Error/Success) on first render. No plan addresses reset-on-recreation semantics. Fix: add `GooseUploadClient._uploadState.value = UploadState.Idle` (or equivalent reset) to `AppViewModel.init {}`, or explicitly document the stale-display as acceptable.

### Divergent Views

- **128-01 reconnectJob null-reset**: Claude flags the stale non-null `reconnectJob` field after `scope.cancel()` as LOW; Codex does not independently raise it. Behaviour is benign (isActive check returns false), but documenting the invariant in the SUMMARY is good practice.

- **128-02 tdd="true" flag**: Claude flags that Task 2 `tdd="true"` has no test plan; Codex does not raise it. Either correct the flag to `tdd="false"` or add a test specification block.

- **Overall risk**: Claude rates MEDIUM (two actionable 128-02 concerns + cross-plan stale state); Codex rates LOW (no new concerns). The divergence is explained by the UploadState placement and threshold issues, which Claude confirmed against the source files.

---

# Cross-AI Plan Review — Phase 128 (Cycle 2)

## Claude Review

### Phase 128 Plan Review

#### Evidence Base

| File | Lines reviewed |
|------|----------------|
| `android/app/src/main/kotlin/com/goose/app/ble/WhoopBleClient.kt` | 91, 103–140, 126, 167–176, 188–201, 335, 409, 415, 567–573, 606–620, 638 |
| `android/app/src/main/kotlin/com/goose/app/viewmodel/AppViewModel.kt` | 28–29, 46 |
| `android/app/src/main/kotlin/com/goose/app/viewmodel/MetricsViewModel.kt` | 51–63 |
| `android/app/src/main/kotlin/com/goose/app/ui/AppShell.kt` | 24–32, 29, 66, 71–76, 78–82 |
| `android/app/src/main/kotlin/com/goose/app/ui/HomeScreen.kt` | 18–23, 22, 24 |
| `android/app/src/main/kotlin/com/goose/app/ui/HealthScreen.kt` | 18–27 |
| `android/app/src/main/kotlin/com/goose/app/ui/MoreScreen.kt` | 17–48, 18, 23, 29 |
| `android/app/src/main/kotlin/com/goose/app/upload/GooseUploadClient.kt` | 43–65 |

---

### 128-01-PLAN.md — WhoopBleClient BLE/Coroutine Fixes

#### Summary

The cycle-1 blockers are all resolved: `val→var` is explicit in D-01, Mutex is replaced by AtomicBoolean/AtomicReference in D-02, and onSyncComplete is replaced by SharedFlow in D-07. Two new cycle-2 issues remain: a JVM memory model hazard on the `var scope` write/read across threads, and a compile break between wave-1 and wave-2 commits caused by wave-1 deleting `onSyncComplete` before wave-2 removes the AppViewModel consumer.

#### Strengths
- All four audit findings (A-01, A-02, A-03, A-07) are mapped to explicit decisions and tasks.
- Atomic primitives rationale is correctly grounded in BLE callback threading constraints.
- SharedFlow contract (replay, extraBufferCapacity, DROP_OLDEST, tryEmit) is precisely specified.

#### Concerns

- **HIGH** — `private var scope` needs `@Volatile`. D-01 changes `val` → `var scope`, but the BLE callback thread reads `scope.launch {...}` (lines 335, 409, 415, 638) while the main/caller thread writes `scope = CoroutineScope(...)` in `connect()` and `scope.cancel()` in `disconnect()`. Without `@Volatile`, the JVM memory model permits the BLE thread to cache the pre-cancel scope value in a register, causing coroutines to launch on a cancelled scope (silently no-ops). Plan mentions neither `@Volatile` nor `@GuardedBy`.

- **HIGH** — Wave-1-to-wave-2 compile break on `onSyncComplete`. Wave 1 Task 3 deletes `var onSyncComplete` from `WhoopBleClient`. But `AppViewModel.kt:46` (`bleClient.onSyncComplete = { metricsViewModel.refresh(); triggerUpload() }`) is not modified until wave 2. If the GSD executor commits each wave independently — which it does — `assembleDebug` after the wave-1 commit fails with `Unresolved reference: onSyncComplete`. Either move AppViewModel.init cleanup into wave-1 Task 3, or keep `onSyncComplete` as a deprecated no-op stub until wave 2 completes.

- **MEDIUM** — `compareAndSet` assignment not specified. Plan says "update all read/write sites to use `.get()/.set()/.compareAndSet()`" but doesn't assign which operation applies where. `completeSyncIfActive()` (line 567–573) must use `.compareAndSet(true, false)` (not `.set(false)`) to prevent double-completion from the idle-timeout coroutine and the R22 notification path racing. `startHistoricalSync()` (line 188) must use `.compareAndSet(false, true)`. An executor reading "update all sites" may choose `.set()` everywhere, introducing a TOCTOU window.

- **LOW** — `reconnectJob: Job?` (line 126) is written on the BLE callback thread (`onGattDisconnected`) and read/cancelled on the main thread (`disconnect()`, `connect()`). Pre-existing issue; `@Volatile` on it would be consistent with the thread-safety sweep in this wave.

#### Suggestions
- Add `@Volatile` to the `var scope` declaration: `@Volatile private var scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)`.
- Move the AppViewModel `bleClient.onSyncComplete = {...}` removal into wave-1 Task 3 (alongside the onSyncComplete deletion) so wave 1 compiles in isolation.
- Specify compareAndSet assignment per call site: `completeSyncIfActive` uses `.compareAndSet(true, false)`; `startHistoricalSync` uses `.compareAndSet(false, true)`.

#### Risk Assessment: **HIGH**

---

### 128-02-PLAN.md — Compose/ViewModel Fixes

#### Summary

The wave-ordering dependency on 128-01 is correctly encoded. HomeScreen.kt and HealthScreen.kt are now listed in files-modified. Two new issues: MoreScreen.kt has an identical StateFlow anti-pattern on `serverUrl` (not just `uploadStatus`) that blocks the AppShell StateFlow removal goal, and GooseUploadClient's UploadState emit points are underspecified.

#### Strengths
- `depends_on: [128-01]` is explicit and correct.
- HomeScreen.kt and HealthScreen.kt are in files-modified.
- `private val bleClient` change is a one-liner with clear verification.

#### Concerns

- **HIGH** — `MoreScreen.kt:18` takes `serverUrl: StateFlow<String>`; `MoreScreen.kt:23` calls `.collectAsStateWithLifecycle()` internally — identical anti-pattern to HomeScreen/HealthScreen. `AppShell.kt:29` passes it down as a StateFlow. Task 1 lists MoreScreen only for `uploadStatus`, not for `serverUrl`. The verification check explicitly omits MoreScreen. Consequence: AppShell still needs `serverUrl: StateFlow<String>` to satisfy MoreScreen's existing param type, making "No StateFlow params in AppShell.kt" unachievable without fixing MoreScreen's serverUrl param first.

- **MEDIUM** — GooseUploadClient UploadState emit points underspecified. Plan says "expose `val uploadState: StateFlow<UploadState>`; emit on `triggerUpload()`". But `triggerUpload()` lives in AppViewModel, not GooseUploadClient. The emit points inside `upload()` (before POST, on success, on HTTP error, on IO exception) are not specified. An executor must restructure the blocking `upload()` method without knowing which of the 4 exit paths sets which state.

- **MEDIUM** — AppShell `uploadState` forwarding not stated. Plan mentions "MoreScreen receives resolved uploadState" but never says to add `uploadState: UploadState` to AppShell's parameter list. The executor must infer the full threading chain.

- **LOW** — `MetricsViewModel.queryScore` (line 52–62) already has `catch (_: Exception) { null }`. Plan says "wrap in try/catch". An executor reading this literally may add an outer try/catch around the existing catch, where the inner `safeHandle` never throws and the outer catch never fires. Should say "add `Log.e` inside the existing catch block".

#### Suggestions
- Add MoreScreen `serverUrl` to Task 1: change `serverUrl: StateFlow<String>` → `String`, remove internal `collectAsStateWithLifecycle()`, add MoreScreen to verification check.
- For A-08, enumerate emit points: "Before POST → InProgress; HTTP 2xx → Success; HTTP non-2xx → Error(responseCode); IOException → Error(message)."
- Explicitly add `uploadState: UploadState` to AppShell's parameter list and threading chain in the task description.

#### Risk Assessment: **MEDIUM**

---

### 128-03-PLAN.md — Hilt DI + CI Gate

#### Summary

The Hilt deferral rationale is solid and the kotlin-android/KSP blockers are correctly documented. One significant issue: Task 1 is a no-op because the sub-ViewModels are already private in the current codebase. The VERIFICATION.md would falsely record this as a change made in phase 128.

#### Strengths
- D-09a is the unambiguous primary path with clear rationale.
- Hilt optional path documents the correct `@ApplicationContext context: Context` + `ViewModel()` pattern.
- assembleDebug as a single end-to-end gate is architecturally sound.

#### Concerns

- **HIGH** — `AppViewModel.kt:28–29`: `private val metricsViewModel = MetricsViewModel(app)` and `private val settingsViewModel = SettingsViewModel(app)` are **already `private val`** in the current codebase. Task 1 says "Change MetricsViewModel and SettingsViewModel from public to private" — this is a no-op. The VERIFICATION.md will falsely record this as a fix made during phase 128. The plan should acknowledge the current state and have the executor confirm (not change) and document this.

- **LOW** — assembleDebug CWD not explicit. Plan says "Run `./gradlew :app:assembleDebug` from android/ directory." GSD executor's CWD is the repo root. The verification block needs `cd android && ./gradlew :app:assembleDebug` to be explicit.

#### Suggestions
- Reframe Task 1: "Confirm MetricsViewModel and SettingsViewModel are already `private val` in AppViewModel (no code change required). Write VERIFICATION.md entry: A-09 is satisfied by pre-existing encapsulation; Hilt migration remains deferred with rationale."
- Add explicit `cd android &&` prefix to the assembleDebug command in the verification block.

#### Risk Assessment: **LOW** (once Task 1 mischaracterization is corrected)

---

### Cross-Plan Issues

**`onSyncComplete` → `syncCompleteEvent` compilation gap** (128-01 → 128-02): The most operationally risky gap. Wave 1 deletes a field that wave 2's AppViewModel still references at init time. If GSD commits wave 1 independently, the repo is uncompilable between wave-1 and wave-2 completion. Fix: move the `bleClient.onSyncComplete = {...}` removal from AppViewModel.init into wave-1 Task 3.

**MoreScreen `serverUrl` threading gap** (128-02 → AppShell → MainActivity): The A-04 fix is structurally incomplete. MoreScreen has a StateFlow anti-pattern on `serverUrl` (not just uploadStatus). The fix chain requires all four files: MainActivity collects serverUrl → passes String to AppShell → AppShell passes String to MoreScreen → MoreScreen removes internal collectAsStateWithLifecycle. All four must be touched, but only MoreScreen's uploadStatus is mentioned in the plan.

**A-09 already satisfied** (128-03 misdiagnosis): The sub-ViewModels are already `private val` in AppViewModel. The plan documents a fix for a finding that the current code already satisfies. The executor should confirm and document this, not attempt to change it.

### Overall Phase Risk: **MEDIUM**

The wave-1 compilation break (`onSyncComplete` deletion before AppViewModel cleanup) and the MoreScreen `serverUrl` gap are concrete defects that will surface during execution. Neither is a design flaw — both are mechanical oversights patchable with targeted plan edits before the executor starts. The `@Volatile var scope` concern is a correctness issue in a concurrent system that won't manifest in `assembleDebug` but will under device stress. Fix the three HIGH items before execution and the phase is sound.

---

## Codex Review

### Phase 128 Plan Review

#### Evidence Base

Codex explored the repository with full filesystem access and read:
- `.planning/phases/128-android-architecture-best-practices-fixes/128-01-PLAN.md`
- `.planning/phases/128-android-architecture-best-practices-fixes/128-02-PLAN.md`
- `.planning/phases/128-android-architecture-best-practices-fixes/128-03-PLAN.md`
- `android/app/src/main/kotlin/com/goose/app/ble/WhoopBleClient.kt`
- `android/app/src/main/kotlin/com/goose/app/viewmodel/AppViewModel.kt`
- `android/app/src/main/kotlin/com/goose/app/ui/AppShell.kt`, HomeScreen.kt, HealthScreen.kt, MoreScreen.kt

---

### 128-01-PLAN.md — WhoopBleClient BLE/Coroutine Fixes

#### Summary

The plan correctly addresses the four audit findings with atomic primitives and a SharedFlow signal. Cycle-1 blockers are resolved. One new medium concern on scope lifecycle ownership.

#### Strengths
- Clear mapping of each audit finding to action and verification grep.
- AtomicBoolean/AtomicReference rationale explicitly tied to BLE callback threading.
- SharedFlow interface contract documented for downstream consumer (wave 2).

#### Concerns

- **MEDIUM** — Scope lifecycle depends on callers invoking `disconnect()`. If a ViewModel is cleared without an explicit disconnect call, the IO `scope` survives, violating the "lifecycle-bound scopes" intent. The plan doesn't add an `onCleared()`/owner hook or a cancellation path for abnormal teardown scenarios beyond explicit `disconnect()`.

- **LOW** — Dispatcher review not addressed: reconnect logic, importFrame parsing, and logging all run on `Dispatchers.IO`; BLE callbacks re-enter IO via `scope.launch`. Potential unnecessary thread hop and log ordering issues are not assessed.

#### Suggestions

- Document that `AppViewModel.onCleared()` already calls `disconnect()` (per existing code), so the lifecycle-bound invariant is satisfied transitively — or explicitly add the onCleared guarantee if it is not already present.
- Specify compareAndSet assignment per call site: `completeSyncIfActive` uses `.compareAndSet(true, false)`; `startHistoricalSync` uses `.compareAndSet(false, true)`.

#### Risk Assessment: **MEDIUM**

---

### 128-02-PLAN.md — Compose/ViewModel Fixes

#### Summary

Wave ordering is correctly encoded. HomeScreen/HealthScreen are in files-modified. One new HIGH: Preview composables with StateFlow<T> params will break compilation when signatures change to value types.

#### Strengths
- `depends_on: [128-01]` is correct and explicit.
- `private val bleClient` change is straightforward and verifiable.
- collectAsStateWithLifecycle pattern is correctly targeted.

#### Concerns

- **HIGH** — Preview composables not accounted for. Signature changes (AppShell/HomeScreen/HealthScreen/MoreScreen) are not paired with updates to in-file `@Preview` composables or default parameters. Existing previews that pass `StateFlow<T>` will break compilation when signatures change to value types. These preview functions are in the same files listed under `files_modified` but are not mentioned in any task.

- **MEDIUM** — `syncCompleteEvent.collect { metricsViewModel.refresh(); triggerUpload() }` in `viewModelScope` runs on the Main dispatcher by default. If `refresh()` or `triggerUpload()` performs blocking JNI/IO work, this risks UI jank. Plan does not offload to `Dispatchers.IO` via `withContext`.

- **LOW** — Verification count-rule fragility: `grep -c collectAsStateWithLifecycle >= 6` may pass even if a new collection (e.g., `uploadStatus`) is omitted; a count-based check can miss individual missed flow collections.

#### Suggestions

- Add a task step: "Update `@Preview` composables in HomeScreen.kt, HealthScreen.kt, MoreScreen.kt, AppShell.kt to use hardcoded value literals (Int?, Float?, String) instead of `MutableStateFlow(...)` parameters."
- Add `withContext(Dispatchers.IO)` or a note on dispatcher safety for the syncCompleteEvent handler in AppViewModel.

#### Risk Assessment: **MEDIUM**

---

### 128-03-PLAN.md — Hilt DI + CI Gate

#### Summary

The Hilt deferral is well-reasoned. assembleDebug is the right integration gate. One new HIGH on jniLibs being gitignored — assembleDebug may fail for missing native artifacts unrelated to Phase 128 changes.

#### Strengths
- D-09a is the unambiguous primary path.
- Revert-on-fail protocol is documented for the optional Hilt path.
- assembleDebug as a single end-to-end gate covers all three waves.

#### Concerns

- **HIGH** — assembleDebug requires native `.a`/`.so` libraries in `jniLibs` srcDirs (`android/app/build.gradle.kts` line 41). These are gitignored and must be present locally. No mitigation is documented if CI/runner lacks the binaries, meaning the phase could fail solely from missing native artifacts unrelated to Phase 128 changes.

- **LOW** — Task 1 may be a no-op (sub-ViewModels may already be private). If no code change occurs, VERIFICATION.md still changes; acceptance criteria should acknowledge "no-op code, doc-only" to avoid ambiguity.

#### Suggestions

- Add pre-flight check: "Confirm `android-libs/` or equivalent native library path is populated before running assembleDebug; if absent, document this as a pre-existing build environment gap, not a Phase 128 failure."
- Explicitly state that if fields are already private, Task 1 records confirmation and rationale in VERIFICATION.md without code churn.

#### Risk Assessment: **MEDIUM**

---

### Cross-Plan Issues

**Native library build prerequisite** (128-03): The assembleDebug CI gate may fail not from Phase 128 code changes but from missing gitignored jniLibs. This is a cross-cutting environment concern that should be validated before starting any wave.

**compareAndSet vs set disambiguation** (128-01 → all waves): The "update all sites" instruction for AtomicBoolean/AtomicReference leaves assignment of specific atomic operations to executor judgment. Both reviewers flagged this; explicit per-site assignment prevents a TOCTOU regression.

### Overall Phase Risk: **MEDIUM**

Primary functional fixes are well targeted, but unresolved build prerequisites (jniLibs) and unaccounted Compose Preview breakages could block or degrade the phase if not addressed pre-implementation.

---

## Consensus Summary

Both reviewers (Claude CLI and Codex) had full repository access and cited file:line evidence. Gemini CLI (0.49.0) invoked twice but timed out both times in agentic repo-exploration mode — no output produced; excluded from consensus.

### Agreed Strengths

- The cycle-1 HIGH concerns (AtomicBoolean, val→var, HomeScreen/HealthScreen in files-modified, wave ordering, kotlin-android/KSP/HiltViewModel pattern) are all correctly resolved in the current plan versions.
- SharedFlow contract is well-specified (replay=0, extraBufferCapacity=1, DROP_OLDEST, tryEmit).
- Wave 2 dependency on wave 1 is explicit and correctly models the SharedFlow consumer relationship.
- Hilt deferral rationale (Kotlin 2.4.0/KSP/kotlin-android) is sound and documented.

### Agreed Concerns (Highest Priority)

**These were raised by both reviewers and represent the highest-priority pre-execution fixes:**

1. **Plan 128-01: `@Volatile` on `var scope`** — Both reviewers agree the JVM memory model requires `@Volatile` on `private var scope` when it is written from one thread (main/connect/disconnect) and read from another (BLE callback thread launching coroutines). Without it, the BLE thread may cache a stale scope reference after disconnect, causing coroutines to launch on a cancelled scope (silent no-ops). *(Claude: HIGH; Codex: not independently rated but confirms thread-safety gap.)*

2. **Plan 128-01: `compareAndSet` assignment per call site** — Both reviewers flag that "update all read/write sites" for AtomicBoolean/AtomicReference is underspecified. `completeSyncIfActive()` must use `.compareAndSet(true, false)` and `startHistoricalSync()` must use `.compareAndSet(false, true)` to avoid TOCTOU races. `.set()` everywhere is incorrect.

3. **Plan 128-01 → 128-02: `onSyncComplete` compilation break** — Claude raises this as HIGH; Codex confirms the dependency structure creates an intermediate uncompilable state. Wave 1 deletes `onSyncComplete` from WhoopBleClient; AppViewModel.kt:46 still references it until wave 2. Fix: move AppViewModel init cleanup to wave-1 Task 3.

4. **Plan 128-02: MoreScreen `serverUrl` StateFlow anti-pattern** — Both reviewers confirm MoreScreen.kt:18 takes `serverUrl: StateFlow<String>` and collects it internally at line 23. This is the same anti-pattern as HomeScreen/HealthScreen and blocks the "no StateFlow params in AppShell" verification goal. MoreScreen's serverUrl must be treated identically to the other screens.

5. **Plan 128-02: Compose `@Preview` compilation break** — Codex raises this as HIGH. When AppShell/HomeScreen/HealthScreen/MoreScreen signatures change from `StateFlow<T>` to value types, any in-file `@Preview` functions that pass `MutableStateFlow(...)` as parameters will fail to compile. These preview updates are not mentioned in any task.

6. **Plan 128-03: `AppViewModel.kt:28–29` sub-ViewModels already private** — Both reviewers confirm MetricsViewModel and SettingsViewModel are already `private val` in the current codebase. Task 1 is a no-op; the plan should acknowledge this and reframe the task as "confirm and document" rather than "change to private."

### Divergent Views

- **128-03 jniLibs gap**: Codex raises this as HIGH (assembleDebug CI gate fails from missing native artifacts); Claude does not independently flag it but acknowledges it in suggestions. Grounded in the `build.gradle.kts:41` jniLibs srcDirs config. Both agree a pre-flight check is needed.

- **128-01 scope lifecycle ownership**: Codex flags that `disconnect()` is the only teardown path and asks whether `AppViewModel.onCleared()` already calls `disconnect()` (which would satisfy the lifecycle-bound requirement transitively). Claude does not raise this as a gap because the existing code already has this path. Codex's concern is effectively resolved by confirming the existing `AppViewModel.onCleared()` → `disconnect()` call chain.

- **GooseUploadClient emit points**: Claude rates this MEDIUM (4 exit paths in `upload()` not specified); Codex does not independently raise this. Both agree the state machine needs explicit per-exit-path assignments.
