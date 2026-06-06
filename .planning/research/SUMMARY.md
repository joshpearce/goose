# Research Summary — v5.0 Metrics Accuracy, IMU & Upstream Fixes

**Project:** Goose v5.0 — Metrics Accuracy, IMU Pipeline & Upstream Fixes
**Domain:** Rust biometric algorithm accuracy for iOS WHOOP BLE app
**Researched:** 2026-06-06
**Confidence:** HIGH

---

## Stack Additions

**Zero new crates required.** Every algorithm in scope (Lipponen-Tarvainen ectopic filter, EWMA baselines, Z-score/logistic recovery model, Mifflin-St Jeor RMR, Keytel active-kcal, Banister TRIMP, Cole-Kripke sleep staging, gravity projection) is a closed-form arithmetic formula implementable using `f64` standard library methods. Do not add `ndarray`, `nalgebra`, `statrs`, `rand`, or any ML runtime crate — if a formula requires a crate, scope has drifted.

Existing crates already cover all persistence, serialisation, and error needs:
- `rusqlite 0.37` — gravity table (new migration to schema v15), algorithm run records
- `serde 1.0` + `serde_json 1.0` — all bridge input/output structs (no change to FFI surface)
- `thiserror 2.0` — error types for new modules

New Rust modules required: `sleep_staging.rs` (Cole-Kripke + 4-class classifier), `baselines.rs` (EWMA state management).

---

## Feature Table Stakes

**HRV Pipeline**
- BLE gap-aware RMSSD: compute successive differences within continuous capture windows only; gaps > 3 s are segment boundaries, not valid RR pairs
- Lipponen-Tarvainen ectopic beat filter: local median reference ± adaptive threshold; replaces the current static 300–2000 ms range gate
- Tiered SWS window selection: longest deep-sleep episode ≥ 5 min, fallback to weighted mean of all deep, fallback to full night

**Recovery Score**
- EWMA personal HRV/RHR baseline with α = 0.1 (~10-day memory); seeded from mean of first 7 nights, never from night 1
- Z-score normalisation + logistic squash to 0–100; inflection at z = 0 must produce ~58% (validate against WHOOP 5.37.0)
- Cold-start gate: null score for < 4 nights; trust levels: calibrating / provisional / trusted

**Calories**
- Mifflin-St Jeor RMR replacing `weight_kg * 22.0` proxy; requires `profile_height_cm` in `EnergyDailyRollupOptions`; fallback with quality flag when height absent
- Keytel active-kcal sex-specific coefficients (Keytel et al. 2005); validate to ±5% against WHOOP labels for 3–5 workout types
- Harris-Benedict revision: confirm SI vs imperial unit variant against WHOOP binary before locking

**Strain**
- Tanaka HRmax formula (208 − 0.7 × age) replacing Fox 220-age; add `profile_sex` to `StrainInput`
- Banister TRIMP with zone-midpoint approximation (`banister_trimp_zone_midpoint_approximation` quality flag); normalise to 0–21 via population denominator; update strain golden files after switch

**Sleep Metrics (without staging)**
- HR dip %: `(baseline_awake_hr − min_sleep_hr) / baseline_awake_hr × 100`; gate on HR coverage ≥ 50%
- WASO via HR threshold method; SOL from first sustained low-HR/low-motion period (≥ 3 consecutive minutes)
- Disturbance count from motion threshold crossings

**Sleep Staging (Cole-Kripke + IMU)**
- Cole-Kripke actigraphy binary wake/sleep classifier on 1-minute aggregated epochs; do NOT use published coefficients directly on raw WHOOP IMU — derive empirical scaling factor
- 4-class classifier (awake/core/deep/REM) using cardiorespiratory features per epoch
- Physiological reimposition: minimum 5-min segment merge, forbidden-transition suppression

**IMU Pipeline**
- Expand `I16SeriesSummary` via new optional `full_samples: Option<Vec<i16>>` field (non-breaking; do NOT extend `preview` in-place)
- Gravity SQLite table (schema v15); batch insert from K21/K10 decoded frames
- TOGGLE_IMU_MODE: feature-flagged off by default until type-51 packet parsing is fully implemented

**Upstream Fixes**
- Gen4 sync fixes (upstream PR #26, 5 commits): import and resolve conflicts; verify 40+ integration tests pass
- `body_hex` exclusion from K10/K21 cached JSON: add explicit `body_hex` assertions to K10/K21 tests first, then apply fix

---

## Feature Differentiators

Defer to v6+:
- Frequency-domain HRV (LF/HF via Lomb-Scargle): HIGH complexity
- DFA alpha1 nonlinear index: HIGH complexity
- Multi-variate Mahalanobis distance for recovery: HIGH complexity
- MET-table active-calorie estimation: MEDIUM complexity
- Per-epoch RMSSD for sleep staging: HIGH implementation investment

Include in v5.0 (low effort, fields already exist):
- pNN50: already computed in `HrvOutput.pnn50_fraction` — zero work needed
- Circadian midpoint tracking: `midpoint_deviation_minutes` field exists; no new work
- Sympathovagal arc: `sleep_hr_trend_bpm_per_hour` field exists; fill from HR feature report

---

## Critical Discoveries

1. **TOGGLE_IMU_MODE is a debug command never sent in production.** `GooseBLEClient.swift` defines commands 106 ON/OFF but `startCapture` does not send them. Sending command 106 without type-51 packet parsing causes all packets during IMU mode to be stored as `Raw` frames — HRV gaps, no staging data, no visible error. IMU pipeline cannot ship until type-51 parsing is complete and feature-flagged.

2. **I16SeriesSummary preview cap is hardcoded at 8 samples in `protocol.rs`.** Extending it in-place breaks all 40+ K10/K21 protocol_tests.rs assertions. The safe path is a new `full_samples: Option<Vec<i16>>` field. Existing `decoded_frames` rows cannot be backfilled — gravity extraction operates on new frames only.

3. **EWMA baseline has three independent failure modes that stack.** Cold-start bias (seeding from night 1), double-update from UI retries (non-idempotent write), and concurrent write race across multiple `GooseRustBridge` instances. All three require different mitigations and must be addressed before recovery v1 ships.

4. **`StrainInput` has no `profile_sex` field today.** Banister TRIMP sex-specific constants differ by ~15–25% for the same session. Silently defaulting to the male constant is a clinical-quality error for 50% of users. `profile_sex` must be added to `StrainInput` before TRIMP is implemented.

5. **Cole-Kripke published coefficients cannot be used directly on WHOOP IMU.** The algorithm was calibrated on wrist actigraph counts, not raw I16 acceleration samples. Without device-specific scaling validation against 5+ nights of ground-truth data, the classifier will over-detect sleep (pleasant but wrong).

6. **body_hex and I16SeriesSummary changes have no K10/K21 assertions in existing tests.** `protocol_tests.rs` uses `..` pattern matching that ignores `body_hex` for K10/K21 variants. Any change to these fields is a silent Swift API contract break unless test coverage is added first.

---

## Architecture Summary

All algorithm work is purely in the Rust core (`Rust/core/src/`). The C FFI surface (`goose_bridge_handle_json` / `goose_bridge_free_string`) is unchanged. New bridge methods are added to the existing `match method_str` dispatcher in `bridge.rs`.

The build order is strictly gated by one data foundation dependency: `protocol.rs` preview expansion + `store.rs` gravity table migration (schema v14 → v15) + K21/K10 gravity extraction in `bridge.rs` must complete first. After that, four algorithm streams can proceed in parallel — sleep staging (`sleep_staging.rs`), EWMA baselines (`baselines.rs`), HRV ectopic filter (in `metrics.rs`), and strain v1 (in `metrics.rs`). Recovery v1 is the final integration gate requiring all four to be complete.

Swift-side changes are minimal: one new `HealthDataStore+Recovery.swift` extension; no changes to `GooseBLEClient.swift` or `GooseUploadService.swift`.

New components:
- `sleep_staging.rs` — pure computation; reads gravity table + HR series; returns `Vec<SleepStageSegment>`
- `baselines.rs` — EWMA state struct; `fold_history()` rebuilds from `daily_recovery_metrics` rows on each call (no new table in v1)
- `gravity` table — schema v15; `device_id + ts_unix_ms` index

---

## Watch Out For

1. **Lipponen-Tarvainen over-filters athletes (silent RMSSD suppression).** Adaptive thresholds required; add `ectopic_filter_removal_fraction` to `HrvOutput`; cross-validate against Python reference on 5 real overnight sessions. Any delta > 1 ms vs reference = investigate before shipping.

2. **EWMA cold-start + double-update + concurrent race (three silent baseline corruption paths).** Require 7 nights before baseline is active; guard `UPDATE SET baseline = ? WHERE last_updated_date < ?`; wrap read-modify-write in `BEGIN EXCLUSIVE` transaction or use single atomic SQL expression.

3. **Banister TRIMP sex constant silently defaults to male.** `profile_sex` must be in `StrainInput` before implementing TRIMP; emit `sex_unknown_using_population_average` quality flag when sex absent; add a test asserting male vs female outputs differ by the expected TRIMP constant ratio.

4. **Cole-Kripke calibration mismatch — over-detects sleep on WHOOP IMU.** Never ship staging without a `staging_method_actigraphy_uncalibrated` quality flag; validate on 5+ overnight sessions against WHOOP official stages.

5. **I16SeriesSummary structural changes silently break the Swift API contract.** Add explicit `body_hex` assertions to K10/K21 tests before any change; use `full_samples: Option<Vec<i16>>` (new field) not `preview` extension; measure JSON payload size before shipping 100-sample mode (K21 grows from ~150 bytes to ~1.8 KB per frame).

---

## Phase Ordering Recommendation

**Phase 1 — Upstream Fixes & Storage Cleanup** (no dependencies; unblocks everything)
- Gen4 sync fixes (upstream PR #26, 5 commits)
- `body_hex` exclusion from K10/K21 cached JSON (add K10/K21 `body_hex` test assertions first)
- Rationale: zero algorithm risk; cleans the foundation before adding IMU data volume

**Phase 2 — IMU Data Foundation** (must complete before Phases 3–5 start)
- Add `full_samples: Option<Vec<i16>>` to `I16SeriesSummary` (non-breaking)
- `store.rs`: gravity table DDL, schema migration v14 → v15, `insert_gravity_rows`, `gravity_rows_between`
- `bridge.rs`: K21/K10 gravity extraction replacing `Vec::new()` placeholder; bridge methods for gravity store
- Feature flag for TOGGLE_IMU_MODE (defaults off); implement type-51 packet parsing
- Rationale: all algorithm phases touching IMU data block on this; early completion maximises parallel work

**Phase 3 — HRV Accuracy** (parallel with Phases 4 and 5 after Phase 2 merges)
- BLE gap segmentation (segment-aware RMSSD at `HrvFeature` collection level)
- Lipponen-Tarvainen ectopic filter with adaptive thresholds; `high_ectopic_removal_fraction` quality flag
- Tiered SWS window selection in feature report builder
- Cross-validate against Python reference on 5 real sessions before completing
- Rationale: foundation for recovery score v1; Phase 6 depends on clean RMSSD history

**Phase 4 — Strain & Calories** (parallel with Phases 3 and 5 after Phase 2 merges)
- Add `profile_sex` to `StrainInput`; Tanaka HRmax; Banister TRIMP zone-midpoint approximation; `fit_strain_denominator`; register `goose_strain_v1`; update golden files
- Mifflin-St Jeor RMR; add `profile_height_cm` to rollup options; fallback quality flag
- Keytel active-kcal validation (3–5 workout types, ±5% tolerance)
- Harris-Benedict SI coefficient confirmation
- Rationale: self-contained; no data dependencies beyond Phase 1; independent delivery

**Phase 5 — Sleep Metrics Without Staging** (parallel with Phases 3 and 4 after Phase 2 merges)
- HR dip %, WASO, SOL, disturbance count from existing HR feature infrastructure
- `baselines.rs`: EWMA state, `fold_history()`, cold-start guard (7 nights), idempotent write, `BEGIN EXCLUSIVE` transaction
- Sympathovagal arc fill (existing field; low effort)
- Rationale: populates fields that already exist in schema; medium complexity; value without IMU staging risk

**Phase 6 — Recovery Score v1** (gates on Phases 3 + 5 both complete)
- `goose_recovery_v1`: Z-score normalisation + logistic squash; trust level enum in `RecoveryScoreOutput`
- `metrics.goose_recovery_v1` bridge method (reads `daily_recovery_metrics` history)
- `HealthDataStore+Recovery.swift`: new extension; update `RecoveryV2DashboardView`
- Idempotency test + concurrent write test required before ship
- Rationale: final integration of clean RMSSD (Phase 3) + EWMA baselines (Phase 5)

**Phase 7 — Sleep Staging** (gates on Phase 2; ship last; highest complexity)
- `sleep_staging.rs`: Cole-Kripke on 1-min aggregated epochs from `full_samples`; cardiorespiratory features; 4-class classifier with physiological reimposition
- `metrics.sleep_staging` bridge method
- Validation: 5+ overnight sessions against WHOOP official stages; `staging_method_actigraphy_uncalibrated` quality flag required
- **Requires dedicated research sub-phase before implementation begins**
- Rationale: highest complexity and empirical risk; Cole-Kripke calibration is an empirical unknown; shipping last minimises risk to stable metrics

**Research flags:**
- Phase 7 (Sleep Staging): requires dedicated research sub-phase before implementation
- Phase 3 (HRV): conditional research sub-phase if cross-validation fails > 1 ms tolerance

**Standard patterns (skip research):** Phases 1, 4, 5 — all coefficients explicit from peer-reviewed papers.

---

*Research completed: 2026-06-06*
*Ready for roadmap: yes*
