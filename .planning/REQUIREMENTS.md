# Requirements: Goose v5.0 — Metrics Accuracy, IMU & Upstream Fixes

**Milestone:** v5.0
**Goal:** Port validated algorithms from `my-whoop` into the Rust core — confirmed against WHOOP 5.37.0 IPA via Ghidra and peer-reviewed literature — so each metric (HRV, Recovery, Strain, Calories, Sleep) produces values aligned with WHOOP from the same raw data.

---

## Upstream Fixes & Storage

- [ ] **SYNC-01**: Gen4 historical sync retain inversion corrected (`AppShellView.swift`: `onHistoricalSyncCompleted` closure uses `[weak healthStore]` + `.onDisappear` cleanup)
- [ ] **SYNC-02**: Gen4 historical sync wrapping overflow consistent (`GooseBLEClient+HistoricalHandlers.swift`: all `gen4HistoricalPageSeq` increments use `&+=`)
- [ ] **SYNC-03**: Gen4 padding clarified (`GooseBLETypes.swift`: `buildGen4CommandFrame` 4-byte padding confirmed or documented against PacketLogger captures)
- [ ] **SYNC-04**: Gen4 confinement documented (`GooseBLEClient.swift`: `activeDeviceGeneration` has queue-confinement doc comment)
- [ ] **SYNC-05**: Gen4 UUID normalised (`WhoopGeneration.detect`: `hasPrefix` comparison lowercased before match)
- [x] **PERF-05**: `body_hex` excluded from K10/K21 cached parsed-payload JSON (K10/K21 `body_hex` assertions added to `protocol_tests.rs` first; then exclusion applied in `parse_frame_batch`)

## IMU Data Pipeline

- [ ] **IMU-01**: `I16SeriesSummary` in `protocol.rs` gains `full_samples: Option<Vec<i16>>` — additive, non-breaking; `preview` field unchanged; existing tests unaffected
- [ ] **IMU-02**: `gravity` table created in SQLite (schema migration v14 → v15): `(device_id TEXT, ts REAL, x REAL, y REAL, z REAL)` with index on `(device_id, ts)`; `insert_gravity_rows` and `gravity_rows_between` bridge methods implemented
- [ ] **IMU-03**: K21/K10 gravity extraction in `bridge.rs` populates `gravity` Vec from `RawMotionK10` frames with LSB→g conversion (factor ~3900, configurable); replaces `Vec::new()` placeholder
- [ ] **IMU-04**: TOGGLE_IMU_MODE (command 106) feature-flagged off by default; type-51 packet parsing implemented in `protocol.rs` before flag is enabled

## HRV Pipeline Accuracy

- [ ] **ALG-HRV-01**: `rmssd_segment_aware` extended — BLE gaps > 3 s are segment boundaries; successive differences that cross gaps are rejected, not included in RMSSD computation
- [ ] **ALG-HRV-02**: Lipponen-Tarvainen ectopic beat filter implemented with adaptive thresholds (local median reference ± computed threshold); `ectopic_filter_removal_fraction` exposed in `HrvOutput`; replaces static 300–2000 ms range gate as primary filter
- [ ] **ALG-HRV-03**: Tiered SWS window selection: (1) last deep-sleep episode ≥ 5 min; (2) weighted mean of all deep episodes; (3) full night fallback — `HrvInput` accepts optional `stage_segments`
- [ ] **ALG-HRV-04**: Cross-validation gate — Rust RMSSD output validated against `my-whoop` Python reference on ≥ 5 real overnight sessions; delta ≤ 1 ms required before phase is closed

## Strain & Calories

- [ ] **ALG-STR-01**: `profile_sex` field added to `StrainInput`; Tanaka HRmax formula (`208 − 0.7 × age`) replaces `220 − age` throughout strain pipeline; `estimate_hrmax_from_history` implemented (percentile 99.5 of history when ≥ 600 samples)
- [ ] **ALG-STR-02**: `banister_trimp_zone_midpoint` implemented as alternative to Edwards — sex-dependent constants (b=1.92 men / b=1.67 women); `banister_trimp_zone_midpoint_approximation` quality flag in output; golden files updated
- [ ] **ALG-STR-03**: `fit_strain_denominator` implemented — given ≥ 2 (TRIMP, strain_WHOOP) pairs, fits `D` in `21 × ln(TRIMP+1)/ln(D)` via least-squares; bridge exposes as calibration method
- [ ] **ALG-CAL-01**: `rmr_mifflin_st_jeor(weight_kg, height_cm, age, sex)` implemented in `energy_rollup.rs`; `profile_height_cm: Option<f64>` added to `EnergyDailyRollupOptions`; quality flag emitted when height absent; replaces `weight_kg * 22.0` proxy
- [ ] **ALG-CAL-02**: Keytel and Harris-Benedict coefficients in `energy_rollup.rs` validated against Ghidra-confirmed values (Keytel men: −55.0969, 0.6309, 0.1988, 0.2017; women: −20.4022, 0.4472, −0.1263, 0.0740; H-B men: 88.362, 13.397, 479.9, −5.677; women: 447.593, 9.247, 309.8, −4.330); SI unit variant confirmed

## Sleep Metrics (Without Staging)

- [ ] **ALG-SLP-01**: HR dip %, WASO (HR threshold method), SOL (first sustained low-HR/low-motion ≥ 3 consecutive min), REM latency (from stage_segments when available), disturbance count — all computed and exposed in `SleepScoreOutput`; dashboard Sleep V2 updated
- [ ] **ALG-SLP-02**: `baselines.rs` module implemented — EWMA state struct; `fold_history()` rebuilds from `daily_recovery_metrics` rows; cold-start guard (baseline inactive until 7 nights of valid data); `BEGIN EXCLUSIVE` transaction guards write; double-update prevented via date guard (`WHERE last_updated_date < ?`)

## Recovery Score v1

- [ ] **ALG-REC-01**: `goose_recovery_v1` implemented in `metrics.rs` — Z-score normalisation via `baselines.rs` EWMA + logistic squash `100 / (1 + exp(-1.6 × (Z + 0.20)))`; Z=0 produces ≈ 58%; cold-start gate returns `null` for < 4 nights of valid baseline
- [ ] **ALG-REC-02**: Trust levels exposed in `RecoveryScoreOutput`: `calibrating` (< 4 nights) → `provisional` (4–13) → `trusted` (≥ 14); colour bands: Vermelho < 34 / Amarelo 34–66 / Verde ≥ 67
- [ ] **ALG-REC-03**: `HealthDataStore+Recovery.swift` extension calls `metrics.goose_recovery_v1` bridge method; `RecoveryV2DashboardView` updated with "A calibrar" state and trust level indicator

## Sleep Staging (4-class, IMU-dependent)

- [ ] **ALG-SLP-03**: Cole-Kripke actigraphy classifier in `sleep_staging.rs` — 1-minute aggregated epochs from `full_samples`; empirical WHOOP IMU scaling factor derived before implementation (requires research sub-phase); `staging_method_actigraphy_uncalibrated` quality flag mandatory
- [ ] **ALG-SLP-04**: 4-class classifier (wake/light/deep/REM) using cardiorespiratory features per 30s epoch + physiological reimposition (minimum 5-min segment merge, forbidden-transition suppression); AASM metrics (TST, efficiency, SOL, WASO, stage_minutes) computed from hypnogram; validated on ≥ 5 overnight sessions against WHOOP stages

---

## Future Requirements

Requirements known but deferred beyond v5.0:

- Frequency-domain HRV (LF/HF via Lomb-Scargle) — HIGH complexity; v6.0
- DFA alpha1 nonlinear HRV index — HIGH complexity; v6.0
- Multi-variate Mahalanobis distance for recovery — HIGH complexity; v6.0
- Full Android app (beyond architecture foundations) — out of scope
- Background URLSession for upload when app is suspended — out of scope
- Upload queue persisted in SQLite to survive app restarts — out of scope

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| `ndarray`, `nalgebra`, `statrs` crates | All algorithms are closed-form `f64` arithmetic — no crate needed |
| Real-time HRV feedback during workout | Requires continuous type-51 stream processing; deferred to v6.0 |
| Sleep staging from WHOOP proprietary stages alone | Cole-Kripke requires IMU; no IMU = no staging |
| PRs back to upstream b-nnett/goose with fork fixes | Out of scope |
| Server-side data analysis (dashboard, alerts) | Out of scope |

---

## Traceability

| Phase | Requirements |
|-------|-------------|
| Phase 20 — Upstream Fixes & Storage | SYNC-01, SYNC-02, SYNC-03, SYNC-04, SYNC-05, PERF-05 |
| Phase 21 — IMU Data Foundation | IMU-01, IMU-02, IMU-03, IMU-04 |
| Phase 22 — HRV Accuracy | ALG-HRV-01, ALG-HRV-02, ALG-HRV-03, ALG-HRV-04 |
| Phase 23 — Strain & Calories | ALG-STR-01, ALG-STR-02, ALG-STR-03, ALG-CAL-01, ALG-CAL-02 |
| Phase 24 — Sleep Metrics Without Staging + Baselines | ALG-SLP-01, ALG-SLP-02 |
| Phase 25 — Recovery Score v1 | ALG-REC-01, ALG-REC-02, ALG-REC-03 |
| Phase 26 — Sleep Staging | ALG-SLP-03, ALG-SLP-04 |
