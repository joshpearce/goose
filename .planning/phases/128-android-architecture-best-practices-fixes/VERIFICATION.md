# Phase 128 Verification Record

**Phase:** 128-android-architecture-best-practices-fixes
**Generated:** 2026-06-28

This file records the verification status of each Phase 128 finding (A-01 through A-09),
the decisions applied, and any deferred items with rationale.

---

## A-09: Sub-ViewModel Encapsulation — D-09a Path Applied

**Status:** SATISFIED BY PRE-EXISTING ENCAPSULATION (no Phase 128 code change for encapsulation intent)
**Hilt DI migration:** DEFERRED — see rationale below

### Encapsulation Status

`MetricsViewModel` and `SettingsViewModel` are constructed as `private val` fields inside
`AppViewModel` (lines 29–30 of `AppViewModel.kt`). This pre-existing structure satisfies the
encapsulation intent of A-09: sub-ViewModel construction is not exposed to the UI layer; all
metric and settings state reaches Compose screens only through `AppViewModel`'s delegated
`StateFlow` properties and methods.

This is **NOT** recorded as a code change introduced by Phase 128. The `private val` fields
were already in place before this phase. Phase 128 plan 03 confirms their presence and
documents the decision audit trail.

### Hilt DI Migration — Deferred

The Hilt DI migration portion of D-09 (full sub-ViewModel construction via Hilt/KSP) is
deferred. The following blocking concerns from cross-AI review apply:

- **HIGH-5 (kotlin-android plugin missing):** The app module currently applies only the
  `android.application` and `kotlin.compose` plugins. KSP annotation processing requires the
  `org.jetbrains.kotlin.android` plugin to be applied first — it is not present in
  `android/app/build.gradle.kts` or the version catalog.

- **HIGH-6 (KSP version unresolved):** KSP releases are pinned to exact Kotlin versions. The
  project is on Kotlin 2.4.0 and AGP 9.2.0. A KSP release targeting Kotlin 2.4.0 was not
  confirmed available at execution time. Proceeding without a confirmed KSP coordinate would
  leave the `libs.versions.toml` entry as an unresolvable placeholder, breaking CI.

- **HIGH-7 (incorrect Hilt injection pattern):** The original D-09 plan specified
  `@Inject constructor(app: Application) : AndroidViewModel(app)`, which is not the correct
  Hilt pattern. The correct pattern is
  `@Inject constructor(@ApplicationContext private val context: Context) : ViewModel()`,
  dropping `AndroidViewModel`. Applying the wrong pattern silently would introduce a latent
  runtime error.

Given two toolchain blockers (HIGH-5, HIGH-6) and one incorrect-pattern risk (HIGH-7),
attempting Hilt on the primary D-09a path would most likely fail CI. Full Hilt migration
of all Android components remains a deferred idea per `128-CONTEXT.md`.

### Future Hilt Migration Gate Conditions

Hilt migration may be attempted in a future phase ONLY when ALL of the following are confirmed:

1. A KSP release targeting Kotlin 2.4.0 (or the project's current Kotlin version) is
   published at `github.com/google/ksp/releases` with a `2.4.0-x.y.z` tag.
2. A Hilt version compatible with that KSP release and the project's AGP version is available.
3. The implementation uses the correct Hilt pattern:
   `@HiltViewModel class XViewModel @Inject constructor(@ApplicationContext private val context: Context) : ViewModel()`.
4. The `org.jetbrains.kotlin.android` plugin is applied to the app module **before** KSP in
   the plugins block.
5. `assembleDebug` succeeds end-to-end with all Hilt changes integrated.

---

## Notes

- All nine Phase 128 findings (A-01–A-09) are addressed across plans 128-01, 128-02, and 128-03.
- A-09 encapsulation is satisfied by the pre-existing `private val` structure in `AppViewModel`.
- The `assembleDebug` CI gate (128-03 Task 2) is the single end-to-end compile verification
  for wave-1 + wave-2 + wave-3 changes integrated together.
