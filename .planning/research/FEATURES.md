# Features Research — v5.0 Metrics Accuracy

**Domain:** Biometric algorithm accuracy for wearable (WHOOP BLE)
**Researched:** 2026-06-06
**Confidence:** HIGH — algorithms are established academic methods with stable literature;
codebase reviewed directly for current state.

---

## HRV Pipeline

### Table Stakes

**Segment-aware RMSSD across BLE gaps > 3s**

RMSSD = sqrt(mean((RR_n+1 - RR_n)^2)). The standard is to compute successive differences only
within continuous segments. Any gap > 3 s (i.e. an inter-beat interval > 3000 ms, physiologically
impossible for a living heart) must be treated as a segment boundary, not as a valid RR pair. The
current v0 implementation collects all `rr_intervals_ms` into one flat vector and filters by the
[300, 2000] ms plausibility window — this correctly rejects individually impossible values but does
NOT prevent a cross-gap difference from being computed if two adjacent intervals are each
individually plausible. Fix: before flattening from `HrvFeature` structs, compute successive
differences within each BLE capture window separately, concatenate only the within-window deltas,
then run RMSSD on that delta list.

**Lipponen-Tarvainen ectopic beat filter (Kubios method)**

Published: Lipponen & Tarvainen (2019), *Physiological Measurement* 40:065014. The algorithm
operates on successive RR differences (dRR series). For each beat i, it computes:

```
dRR[i] = RR[i] - RR[i-1]
mRR = median(RR) over a +/-45-beat window    (short-term reference)
th1 = 0.2 * mRR                              (~200 ms at 60 bpm)
th2 = proportional to IQR(dRR)               (local HRV-adaptive threshold)
```

A beat is flagged ectopic if |dRR[i]| > th1 AND |dRR[i]| > th2. Two adjacent dRR spikes =
ectopic cluster. Flagged beats are either removed or interpolated (linear or cubic spline).
Kubios applies this before computing any time-domain HRV metrics. More principled than a static
[300, 2000] ms amplitude cutoff — adapts to subject's local heart rate context.

**pNN50 in output**

pNN50 = fraction of successive differences > 50 ms. Already computed as `pnn50_fraction` in
`goose_hrv_v0` and present in `HrvOutput`. No new work required.

**Tiered SWS window selection**

Kubios/WHOOP convention: prefer the last deep-sleep episode >= 5 min; fall back to weighted
average of all deep episodes; final fallback = full night window. This requires sleep stage
segmentation data to be joined with HRV computation. Currently the HRV window is passed in
directly by the caller — the tiering logic belongs in the feature report layer that constructs
`HrvInput`, not inside `goose_hrv_v0`.

### Differentiators

- Frequency-domain HRV (LF/HF power via Lomb-Scargle or interpolation + FFT): not required
  by WHOOP matching but adds clinical depth; HIGH complexity.
- DFA alpha1 nonlinear index: used by Kubios and Polar for overtraining detection; HIGH
  complexity (sliding window detrended fluctuation analysis).
- SDSD (SD of successive differences): trivially derived alongside RMSSD; LOW complexity.

### Complexity Notes

- The ectopic filter is the hardest single piece. The threshold computation from IQR requires a
  sliding window that must handle unequal capture-window lengths from BLE. Implement on the dRR
  delta list after gap segmentation, not on the raw RR list.
- Segment-aware gap detection must be done at the `HrvFeature` collection level (in
  `run_hrv_feature_report`), not inside `goose_hrv_v0`. The v0 function must remain stateless
  and receive only a clean, pre-filtered delta list.
- Cold-start: the current `min_rr_intervals_to_compute = 2` default is too low for meaningful
  RMSSD. WHOOP requires >= 30 valid intervals for a night reading; the tiered SWS window is the
  mechanism that ensures this.
- pNN50 is already implemented. No action needed.

---

## Recovery Score

### Table Stakes

**Z-score normalization + logistic squash (recovery_score_v1)**

Current `goose_recovery_v0` uses a fixed linear formula:
`hrv_score = 70 + (hrv / baseline - 1) * 100`. This does not saturate well and is sensitive to
outliers. The v1 target uses:

```
z = (value - personal_mean) / personal_sd
raw = 1 / (1 + exp(-z))            # sigmoid, [0, 1]
score_pct = anchor + raw * scale   # anchor and scale chosen so z=0 -> 58%
```

For z=0 to map to exactly 58%: `anchor + 0.5 * scale = 58`, so one valid parameterization is
anchor=16, scale=84 (giving z=0 -> 16 + 42 = 58%). Validate this against WHOOP 5.37.0 captures.

**EWMA personal baseline**

Standard smoothing constant alpha = 0.1 (effective ~10-day memory).
`baseline_new = alpha * today + (1 - alpha) * baseline_prev`
Straightforward; the SQLite daily metric row is the storage mechanism already in place.

**Cold-start gate (< 4 nights -> null)**

When fewer than 4 nights of data are available, return null rather than an unreliable score.
This is a policy gate, not an algorithm. Implement as a pre-check in the feature score report.

**Trust levels**

- calibrating: 0-3 nights (score null)
- provisional: 4-13 nights (score shown with warning)
- trusted: >= 14 nights (score shown with confidence)

Expose as an enum field in `RecoveryScoreOutput`.

### Differentiators

- Multi-variate Mahalanobis distance instead of per-metric Z-scores: accounts for correlation
  between HRV, RHR, respiratory rate; significantly better discrimination; HIGH complexity.
- Readiness forecast (predicted next-day recovery): requires multi-day modeling; out of scope.

### Complexity Notes

- Z-score approach requires stable personal_sd. With 1-2 data points, SD is near zero, causing
  division-by-zero or infinite Z. Guard: require >= 4 nights before computing SD; use a Bayesian
  prior (population SD ~8 ms for RMSSD) as the seed variance for the first window.
- The EWMA baseline and cold-start gate interact. The EWMA must not decay toward an uninitialized
  value. Seed the EWMA with the mean of the first N available nights (N >= 4).
- Logistic squash anchor/scale coefficients need validation against the WHOOP binary. Lock this
  constant before implementing trust level propagation — a wrong anchor shifts every score.

---

## Calories

### Table Stakes

**Mifflin-St Jeor RMR**

Published: Mifflin et al. (1990), *JADA* 90(1):106-110.
```
Men:   RMR = 10 * weight_kg + 6.25 * height_cm - 5 * age_years + 5
Women: RMR = 10 * weight_kg + 6.25 * height_cm - 5 * age_years - 161
```
More accurate than Harris-Benedict for non-athletic adults. Preferred for resting kcal if height
is available in the user profile.

**Validated Keytel formula coefficients**

Keytel et al. (2005), *Journal of Sports Sciences* 23(3):289-297:
```
Men:   kcal/min = (-55.0969 + 0.6309*HR + 0.1988*weight_kg + 0.2017*age) / 4.184
Women: kcal/min = (-20.4022 + 0.4472*HR - 0.1263*weight_kg + 0.0740*age) / 4.184
```
The /4.184 appears in the paper's VO2-to-kcal conversion chain; the output is kcal/min.
Validation against WHOOP 5.37.0: compare local total_kcal against app-displayed values.
Target tolerance: +/- 5% for sustained exercise sessions.

**Validated Harris-Benedict coefficients**

Current implementation exists. Published Roza & Shizgal (1984) revision:
```
Men:   BMR = 88.362 + 13.397*weight_kg + 4.799*height_cm - 5.677*age
Women: BMR = 447.593 + 9.247*weight_kg + 3.098*height_cm - 4.330*age
```
Milestone spec lists women's height coefficient as 309.8 — this is the original Benedict (1918)
paper's value using imperial units (pounds/inches). The SI revision is 3.098. Confirm which
version matches WHOOP's binary before locking; both are self-consistent when units match.

### Differentiators

- MET-table estimation for labeled activity types (running, cycling): bypasses HR dependency;
  useful when HR signal quality is low; MEDIUM complexity.
- FirstBeat-style VO2max-adjusted estimate: personalizes Keytel using individual aerobic fitness;
  HIGH complexity; requires VO2max estimation from submaximal HR data.

### Complexity Notes

- Keytel is optimized for continuous exercise (moderate-to-vigorous HR). At rest or very low HR
  it can produce negative values. Clamp to zero below the aerobic threshold.
- Harris-Benedict and Mifflin-St Jeor are RMR estimators (rest); Keytel is an active-exercise
  estimator. They must not be blended for the same minute. The existing hourly/daily window
  architecture with HR zone attribution already separates these conceptually.
- Height is not currently stored in the user profile. If missing, Mifflin-St Jeor cannot be
  computed. Fallback: use Keytel for active kcal; flag resting kcal as missing height with a
  quality flag and use a population-mean height estimate.
- Validation requires sessions with stable, known parameters (age, weight, HR). Plan at least
  3-5 diverse workout types before declaring validation complete.

---

## Strain

### Table Stakes

**Tanaka HRmax formula**

Tanaka et al. (2001), *JACC* 37(1):153-156:
```
HRmax = 208 - 0.7 * age_years
```
More accurate than Fox (1971) 220-age formula, particularly for adults over 40. Replaces the
current 220-age estimate that feeds the HRmax parameter in strain computation.

**Banister TRIMP**

Banister (1991), in: *Modeling Elite Athletic Performance*. Exponential-weighting TRIMP:
```
TRIMP = duration_min * HRR * 0.64 * e^(1.92 * HRR)    (men)
TRIMP = duration_min * HRR * 0.86 * e^(1.67 * HRR)    (women)
where HRR = (HR_avg - HR_rest) / (HR_max - HR_rest)
```
Current `goose_strain_v0` uses Edwards TRIMP (zone-weighted linear load, weights [1,2,3,4,5]).
Banister's exponential up-weights high-intensity time more aggressively, which is physiologically
more accurate. The 0-to-21 scale must be recalibrated after switching TRIMP formulas.

**Personal denominator calibration via least-squares**

Fit the personal HRmax (or the Tanaka correction factor) and strain scale denominator to observed
session data using least-squares regression. Requires >= 5-10 completed workout sessions before
calibration is usable; fall back to Tanaka population formula until then.

### Differentiators

- Power-based TSS (Coggan): requires power meter; not available from WHOOP BLE.
- Critical power / W' modeling: requires interval testing; out of scope.

### Complexity Notes

- Banister TRIMP requires moment-by-moment HRR, not zone summaries. The current `MetricWindowFeature`
  stores zone minutes and average HR, not a per-minute HR series. Two options:
  (a) Compute TRIMP continuously during workout capture and accumulate it; requires capture-time
      instrumentation.
  (b) Approximate from zone-minute distribution assuming uniform HR at each zone's midpoint.
  Option (b) is much simpler but introduces approximation error at zone boundaries. Start with
  (b) and flag as `banister_trimp_zone_midpoint_approximation` in quality flags.
- Personal calibration is a separate Rust bin tool (`goose-algo-benchmark.rs` exists as a
  precedent). Do not implement inline in `goose_strain_v0`; keep the algorithm function pure.
- The existing test golden files for strain will need updating after switching HRmax formula.

---

## Sleep Metrics (without staging)

### Table Stakes

**HR dip %**

Standard formula: `(baseline_awake_hr - min_sleep_hr) / baseline_awake_hr * 100`.
Baseline awake HR = mean HR in the 30-60 min before sleep onset. Healthy dip >= 8%.
`SleepWindowFeature` already has `heart_rate_dip_percent`, `baseline_awake_hr_bpm`, and
`lowest_sleep_hr_bpm` fields. The computation belongs in the sleep feature report builder and
feeds `goose_sleep_v0` via `SleepInput.heart_rate_dip_percent` (field already exists).

**WASO via HR threshold method**

Wake After Sleep Onset without staging: minutes where HR is above the sleep-phase threshold
are classified as probable-wake. Threshold = `mean_sleep_hr + 1 SD` computed from the quiet
trough of the sleep window. Store as `wake_after_sleep_onset_minutes` (field already exists on
`SleepWindowFeature`).

**SOL (Sleep Onset Latency)**

Time from lights-out/BLE-connect to first sustained low-HR / low-motion period. "Sustained"
= >= 3 consecutive minutes below motion and HR thresholds. `SleepWindowFeature.sleep_latency_minutes`
field already exists. Fill it from the feature extractor.

**REM latency (heuristic)**

Without staging: first sustained elevated HR after deep-trough HR as a proxy for REM onset.
Low accuracy without staging; flag as `heuristic_rem_latency_without_staging` in quality flags.
If staging data is available, use the first REM segment start time minus sleep onset directly.

**Disturbance count**

`SleepWindowFeature.disturbance_count` already exists. Fill from motion threshold crossings
during the sleep window — same logic as WASO but counting episodes, not total duration.

### Differentiators

- Circadian midpoint tracking: already supported via `midpoint_deviation_minutes`; no new work.
- Sympathovagal arc: linear regression of HR across sleep window (field `sleep_hr_trend_bpm_per_hour`
  already exists); captures parasympathetic restoration. Fill from the HR feature report.

### Complexity Notes

- The HR-based WASO and disturbance threshold must be derived from within-night data, not
  population constants. A bad threshold produces all-awake or all-asleep misclassification.
- All these metrics are proxy measures without staging. Quality flags must clearly distinguish
  them from staging-derived values. Do not display as equivalent precision in the UI.
- HR coverage gate: if HR coverage of the sleep window is < 50%, gate HR dip and WASO as
  unavailable. The existing `heart_rate_coverage_fraction` field on `SleepWindowFeature` enables
  this gate without new schema changes.

---

## Sleep Staging (Cole-Kripke + IMU)

### Table Stakes

**Cole-Kripke actigraphy baseline**

Cole et al. (1992), *Sleep* 15(5):461-469. Wrist-movement-based binary wake/sleep classifier.
Standard 1-minute epoch scoring uses a weighted sum of activity counts in a +/-2-minute window:

```
W = 0.00001 * (106*A_{-4} + 54*A_{-3} + 58*A_{-2} + 76*A_{-1} + 230*A_0 + 74*A_{+1} + 67*A_{+2})
if W >= 1.0: WAKE; else: SLEEP
```

This is binary (wake/sleep) only. For 4-class staging, Cole-Kripke is the first-pass gate;
cardiorespiratory features differentiate N1/N2/N3/REM within the SLEEP segments.

**Cardiorespiratory features per epoch**

For each 1-min epoch during SLEEP segments:
- Mean HR (low in deep, variable in REM, elevated in wake transitions)
- RMSSD or pNN50 per epoch (high in deep and REM, low in wake)
- Respiratory rate regularity (regular in deep, irregular in REM)
- HR variance proxy (LF/HF ratio heuristic from beat-to-beat data)

**4-class classifier output (awake / core / deep / REM)**

Without a labeled personal training set, use a published threshold-based heuristic:
- High motion OR high HR above awake threshold -> awake
- Low motion + low HR + high RMSSD (HRV-favorable) -> deep
- Low motion + elevated HR + variable RMSSD -> REM
- Low motion + transitional HR -> core

The `SleepStageKind` enum (awake/core/deep/rem) and `SleepStageSegmentFeature` struct already
exist in the codebase. The classifier output populates these fields.

**Physiological reimposition**

Sleep stage sequences must follow plausible architecture: NREM cycles ~90 min, REM periods
lengthening through the night. Post-classification:
1. Minimum duration filter: merge segments shorter than 5 min into adjacent dominant stage.
   The constant `MIN_SMOOTHED_SLEEP_STAGE_DURATION_MINUTES = 5.0` already exists.
2. Forbidden-transition suppression: e.g., direct deep->REM without core, REM in first 45 min.
   Implement as a simple state-machine post-processor, not a full HMM Viterbi decoder.

### Differentiators

- PPG-derived respiratory rate as a staging feature: being tracked as a vital event; if
  validated, adds a strong cardiorespiratory signal beyond HR alone.
- Per-epoch RMSSD (30-second windows): raises staging accuracy but requires HRV pipeline to
  operate at epoch granularity; significant implementation investment.

### Complexity Notes

- Cole-Kripke requires calibrated activity counts. The current `motion_intensity_0_to_1` scalar
  is a normalized version of raw I16 data. The ADC scale of the WHOOP accelerometer is
  undocumented. Use normalized intensity with an empirically fitted threshold rather than
  published Cole count thresholds directly.
- The 4-class classifier without labeled personal data typically achieves 70-75% agreement
  with PSG for actigraphy-only systems. WHOOP's PPG and HR improve this, but without PSG
  ground truth, per-stage accuracy cannot be precisely validated. Flag staging output with
  confidence scores and the `stage_model_version` field (already present on `SleepWindowFeature`).
- Physiological reimposition: a minimum-duration merge + forbidden-transition rule covers 80% of
  the correction benefit of a full Viterbi HMM at a fraction of the implementation cost.
- Sleep staging is the highest-complexity single feature in v5.0. It requires the full IMU
  pipeline to be operational first. Flag for a dedicated research sub-phase before implementation.

---

## IMU Pipeline

### Table Stakes

**Full I16SeriesSummary with all samples per axis**

The current `I16SeriesSummary` struct stores `min`, `max`, `sum`, and an 8-sample `preview`.
K10 carries up to 100 accelerometer samples per axis per frame; K21 carries two groups of up
to 100 samples each. The 8-sample preview is sufficient for motion intensity scalar computation
but not for signal analysis (epoch classification, step detection, gravity estimation).

Full pipeline requires: store all N samples per axis per frame, or accumulate them into a
gravity-separated dynamic-acceleration buffer in SQLite. Adding `samples: Vec<i16>` to
`I16SeriesSummary` is the minimal change; it is a protocol-level breaking change that requires
migrating all consumers of the current struct (metric_features.rs, export.rs, bridge.rs).

**Gravity SQLite table**

Separate the low-frequency DC gravity component from dynamic motion using a low-pass filter:
exponential moving average with alpha ~0.02 per sample at 10 Hz (50-sample time constant).
The gravity vector provides device orientation needed for step counting and sleep position
estimation. A dedicated `gravity` table in SQLite should store the per-epoch gravity estimate.
The placeholder `gravity: Vec<serde_json::Value> = Vec::new()` at bridge.rs:3098 must be
replaced with real computation.

**Auto TOGGLE_IMU_MODE**

The WHOOP device must be explicitly commanded to enable K10/K21 full IMU packets. Auto-trigger
this command during connected foreground sessions and at workout start. Without it, IMU data
is unavailable regardless of how well the pipeline is built.

### Complexity Notes

- Storage: 100 samples per axis per frame at 1 Hz = 300 i16 values/second (K10, 3 axes). Over
  an 8-hour sleep window: 300 * 28800 = 8.64 M values. K21 doubles this. Store as SQLite BLOBs
  per frame, not as individual rows.
- Adding `samples: Vec<i16>` to `I16SeriesSummary` is a breaking change. All golden-file tests
  that serialize or snapshot this struct will need updating.
- The gravity computation update-on-insert (per frame) must run in the Rust bridge on the
  background queue, not on the main actor. The existing `OvernightSQLiteMirrorQueue` pattern
  shows the right threading model.

---

## Upstream Fixes (Gen4 + body_hex)

### Scope

**Gen4 sync fixes (upstream PR #26, 5 code fixes)**

Bug fixes in the BLE frame parser / sync protocol for Gen4 devices from upstream `b-nnett/goose`
PR #26. Scope: import the 5 commits from that PR, resolve conflicts with local changes in
`protocol.rs` and `bridge.rs` (both heavily modified locally), and verify the existing 40+
integration tests pass after merge. These fixes are blocking for Gen4 device users. No algorithm
changes required.

**body_hex exclusion from K10/K21 cached JSON**

K21 motion packets carry up to ~1250 bytes of I16 samples. Including `body_hex` in the cached
JSON column of `decoded_frames` for these packets inflates SQLite storage significantly (~2500
chars per K21 frame). The fix: exclude `body_hex` from the cached JSON specifically for
`raw_motion_k10` and `raw_motion_k21` body kinds, since the data is already decoded into the
structured `I16SeriesSummary` axes in the parsed payload.

`export.rs` already excludes `body_hex` at line 2098 for export purposes. The parallel fix is
needed in the bridge's decode-and-cache path. This is a mechanical optimization, not a behavioral
change. Golden-file tests for cached JSON will need their snapshots regenerated after this change.

---

## Feature Dependencies

```
TOGGLE_IMU_MODE auto  ->  IMU full samples (data availability prerequisite)
IMU full samples      ->  Gravity table
IMU full samples      ->  Sleep staging (Cole-Kripke needs epoch-level activity)
Gravity table         ->  Sleep position estimation (differentiator, future)

Ectopic filter        ->  Clean RR interval list
BLE gap segmentation  ->  Segment-aware RMSSD (must happen before ectopic filter)
Clean RMSSD           ->  Tiered SWS window selection
Clean RMSSD           ->  Recovery score v1 Z-score baseline
Recovery v1 baseline  ->  Trust levels (needs N nights of clean data)

Tanaka HRmax          ->  Banister TRIMP (replaces 220-age input)
Banister TRIMP        ->  Updated strain golden files

HR dip / WASO / SOL   ->  HR coverage >= 50% of sleep window
Sleep staging         ->  IMU full samples + HR coverage + per-epoch RMSSD
Sleep staging         ->  Physiological reimposition post-processor

Mifflin-St Jeor       ->  Height field in user profile (fallback if missing)
Keytel validation     ->  Reference WHOOP 5.37.0 captures with known parameters

body_hex exclusion    ->  Independent (no dependencies, can ship first)
Gen4 sync fixes       ->  Independent (no dependencies, blocking for Gen4 users)
pNN50                 ->  Already shipped in HrvOutput (no work needed)
```

## MVP Recommendation

Priority order for phases:

1. **body_hex exclusion + Gen4 fixes** — pure fixes, no algorithm risk, unblocks Gen4 users,
   reduces storage bloat before IMU full-sample data arrives.
2. **BLE gap segmentation + ectopic filter** — foundation for all HRV accuracy; moderate complexity.
3. **Tanaka HRmax + Banister TRIMP approximation** — self-contained strain accuracy upgrade.
4. **Recovery score v1** — Z-score + EWMA baseline; depends on clean RMSSD; moderate complexity.
5. **Calories (Mifflin-St Jeor + Keytel validation)** — self-contained; validate against binary.
6. **Sleep metrics without staging** — HR dip / WASO / SOL from existing HR feature infrastructure.
7. **IMU full pipeline** — schema change, storage impact; prerequisite for staging.
8. **Sleep staging** — last; highest complexity and risk; requires dedicated research sub-phase.

Defer: frequency-domain HRV, DFA alpha1, VO2max-adjusted calories, Mahalanobis recovery,
       per-epoch RMSSD for staging, REM latency without staging.

---

## Sources

- Lipponen & Tarvainen (2019): *Physiological Measurement* 40:065014 — ectopic beat filter
- Cole et al. (1992): *Sleep* 15(5):461-469 — actigraphy wake/sleep classifier
- Banister (1991): in *Modeling Elite Athletic Performance*, Human Kinetics — TRIMP
- Tanaka et al. (2001): *Journal of the American College of Cardiology* 37(1):153-156 — HRmax
- Keytel et al. (2005): *Journal of Sports Sciences* 23(3):289-297 — HR-to-calorie formula
- Mifflin et al. (1990): *Journal of the American Dietetic Association* 90(1):106-110 — RMR
- Roza & Shizgal (1984): *American Journal of Clinical Nutrition* 40(1):168-182 — Harris-Benedict SI
- Codebase review: `Rust/core/src/metrics.rs`, `metric_features.rs`, `recovery_rollup.rs`,
  `energy_rollup.rs`, `protocol.rs`, `bridge.rs`, `export.rs`, `activity_candidates.rs`
  (direct inspection, 2026-06-06)
