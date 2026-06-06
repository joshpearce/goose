# Stack Research — v5.0 Metrics Accuracy

**Project:** Goose biometric algorithm accuracy
**Researched:** 2026-06-06
**Based on:** Direct inspection of `Rust/core/Cargo.toml`, `src/metrics.rs`, `src/energy_rollup.rs`, `src/protocol.rs`, `src/metric_features.rs`

---

## New Crates Needed

**None.**

Every mathematical primitive required for the algorithms listed in scope can be implemented
directly in Rust using `f64` standard library methods (`f64::exp`, `f64::ln`, `f64::sqrt`,
`f64::powi`, `f64::abs`, `f64::signum`). The algorithms are closed-form formulas with no
dependency on external numerical libraries.

The existing Cargo.toml already provides everything the new algorithms need to persist
results, serialise outputs, and report errors:

- `rusqlite 0.37` — gravity table in SQLite, algorithm run records
- `serde 1.0` + `serde_json 1.0` — all input/output structs and bridge protocol
- `thiserror 2.0` — error types

Do not add `ndarray`, `nalgebra`, `statrs`, `rand`, or any ML runtime crate. The algorithms
in scope (Lipponen-Tarvainen, Mifflin-St Jeor, Keytel, Banister TRIMP, Cole-Kripke) are
well-defined arithmetic formulas expressible in a dozen lines of Rust each.

---

## Existing Crates Sufficient For

| Algorithm or Feature | Covered By |
|---|---|
| Lipponen-Tarvainen ectopic beat filter | `f64` stdlib (`abs`, comparison) — pure iteration over RR array |
| EWMA baseline (HRV, RHR) | `f64` stdlib — single-pass iterator with alpha x + (1-alpha) x prev |
| Z-score normalisation | `f64::sqrt`, `f64::powi` — existing `mean` + `sample_sd` already in `metrics.rs` |
| Logistic recovery model (sigmoid) | `f64::exp` — `1.0 / (1.0 + (-z).exp())` |
| Mifflin-St Jeor RMR | `f64` arithmetic — replaces the `weight_kg * 22.0` proxy in `energy_rollup.rs` |
| Keytel active-kcal formula | `f64` arithmetic — already uses HR-reserve zone approach; Keytel adds sex-specific coefficients |
| Harris-Benedict coefficients | `f64` arithmetic — sex + age + weight + height lookup table as `match` |
| Tanaka HRmax (208 - 0.7 x age) | `f64` arithmetic — single expression |
| Banister TRIMP (zone-weighted impulse) | `f64::exp`, zone-time iteration — compatible with existing `hr_zone_minutes` input |
| Cole-Kripke 4-class sleep staging | `f64` arithmetic on epoch features — thresholded scoring table |
| HR dip computation | `f64` arithmetic — ratio of means already partially handled in `metrics.rs` |
| WASO / SOL from stage segments | `f64` arithmetic on `SleepStageSegment` — already parsed |
| I16SeriesSummary gravity projection | `f64` arithmetic — dot product with calibration table row |
| SQLite gravity table persistence | `rusqlite` — existing store pattern |
| JSON bridge input/output | `serde_json` — existing `AlgorithmRunResult<T>` pattern |
| Quality flags and provenance | `serde_json::json!` macro — existing pattern |

---

## Mathematical Primitives Needed

All of these are pure Rust, no external crates. They follow the same module-local private
function pattern already used in `metrics.rs` and `metric_features.rs`.

### 1. EWMA (exponential weighted moving average)

Used for: HRV RMSSD baseline, RHR baseline — both replace the simple windowed mean
currently passed in as `hrv_baseline_rmssd_ms` and `resting_hr_baseline_bpm`.

```rust
fn ewma_update(prev: f64, new_value: f64, alpha: f64) -> f64 {
    alpha * new_value + (1.0 - alpha) * prev
}

fn ewma_series(values: &[f64], alpha: f64) -> Option<f64> {
    let mut acc = *values.first()?;
    for &v in &values[1..] {
        acc = ewma_update(acc, v, alpha);
    }
    Some(acc)
}
```

### 2. Z-score

Used for: recovery logistic model normalisation.

```rust
fn z_score(value: f64, mean: f64, sd: f64) -> Option<f64> {
    if sd <= 0.0 || !sd.is_finite() { return None; }
    Some((value - mean) / sd)
}
```

`mean` and `sample_sd` are already defined as private functions in `metrics.rs`. They
may need to be made `pub(crate)` or moved to a shared `math.rs` if reused across modules.

### 3. Logistic function (sigmoid)

Used for: recovery score — map z-score to 0..1 probability, scale to 0..100.

```rust
fn logistic(z: f64) -> f64 {
    1.0 / (1.0 + (-z).exp())
}
```

### 4. Lipponen-Tarvainen ectopic beat filter

Three-pass algorithm on a `&[f64]` RR interval series:

1. Reject intervals outside `[300, 2000]` ms (already done in `goose_hrv_v0` — reuse).
2. Compute a local reference using the median of k nearest valid neighbours (k=5). Flag
   as ectopic if `|RR_i - RR_ref| / RR_ref > 0.2`.
3. Replace ectopic beats with linear interpolation between nearest valid neighbours.

Primitive needed: `median5` on a fixed-size window — no heap allocation.

```rust
fn median5(window: &[f64]) -> f64 {
    let mut buf = [0.0f64; 5];
    let len = window.len().min(5);
    buf[..len].copy_from_slice(&window[..len]);
    buf[..len].sort_by(|a, b| a.partial_cmp(b).unwrap());
    buf[len / 2]
}
```

### 5. Tiered SWS window selection

Pure control-flow logic on `Vec<SleepStageSegment>` (already parsed in `metrics.rs`).
Pick the longest contiguous `stage_kind == "deep"` run in the first half of the sleep
window. Returns `Option<(usize, usize)>` index range for the RMSSD computation window.
No new math — iterator + `max_by`.

### 6. Mifflin-St Jeor RMR

Replaces `weight_kg * 22.0` proxy in `energy_rollup.rs::resting_kcal`.

```rust
fn mifflin_st_jeor_rmr_kcal_per_day(
    weight_kg: f64,
    height_cm: f64,
    age_years: u32,
    sex: &str, // "male" | "female" | other
) -> f64 {
    let base = 10.0 * weight_kg + 6.25 * height_cm - 5.0 * age_years as f64;
    match sex {
        "male"   => base + 5.0,
        "female" => base - 161.0,
        _        => base - 78.0, // sex-neutral midpoint
    }
}
```

Requires adding `profile_height_cm: Option<f64>` to `EnergyDailyRollupOptions`.

### 7. Keytel active-kcal per minute

Sex-specific polynomial from Keytel et al. 2005:

```rust
fn keytel_active_kcal_per_minute(
    hr_bpm: f64,
    age_years: u32,
    weight_kg: f64,
    sex: &str,
) -> f64 {
    let age = age_years as f64;
    let raw = match sex {
        "male"   => -55.0969 + 0.6309*hr_bpm + 0.1988*weight_kg + 0.2017*age,
        "female" => -20.4022 + 0.4472*hr_bpm - 0.1263*weight_kg + 0.0740*age,
        _        => -37.5496 + 0.5390*hr_bpm + 0.0363*weight_kg + 0.1379*age,
    };
    (raw / 4.184).max(0.0)
}
```

### 8. Tanaka HRmax estimate

Used when `max_hr_bpm` is not provided as a profile field.

```rust
fn tanaka_hrmax(age_years: u32) -> f64 {
    208.0 - 0.7 * age_years as f64
}
```

### 9. Banister TRIMP

Supplements the existing zone-weighted `zone_load` in `goose_strain_v0`.

```rust
fn banister_trimp(
    duration_minutes: f64,
    hr_average_bpm: f64,
    hr_rest_bpm: f64,
    hr_max_bpm: f64,
    sex: &str,
) -> f64 {
    let delta = ((hr_average_bpm - hr_rest_bpm) / (hr_max_bpm - hr_rest_bpm))
        .clamp(0.0, 1.0);
    let y = match sex { "male" => 1.92, "female" => 1.67, _ => 1.80 };
    duration_minutes * delta * y.exp().powf(delta)
}
```

### 10. Cole-Kripke activity-based sleep/wake classifier

Fixed coefficient table from Cole-Kripke 1992, 1-minute wrist actigraphy epochs:

```rust
const CK_WEIGHTS: [f64; 5] = [0.0033, 0.0055, 0.0080, 0.0055, 0.0033];
const CK_P: f64 = 0.00001;

fn cole_kripke_epoch_is_sleep(activity_window: &[f64; 5]) -> bool {
    let score = CK_P * CK_WEIGHTS.iter().zip(activity_window.iter())
        .map(|(w, a)| w * a).sum::<f64>();
    score < 1.0
}
```

The 4-class extension (Wake/NREM-light/NREM-deep/REM) adds HR and RMSSD thresholds in a
decision tree — no runtime fitting required.

### 11. Gravity projection for IMU samples

```rust
fn project_gravity_axis(samples: &[i16], scale_factor: f64, unit_vector: f64) -> f64 {
    let raw_mean = samples.iter().map(|&s| s as f64).sum::<f64>() / samples.len() as f64;
    raw_mean * scale_factor * unit_vector
}
```

The calibration unit vector `[gx, gy, gz]` is loaded from the SQLite gravity table
(new schema migration). `scale_factor` is device-specific (stored alongside unit vector).

---

## Integration Points

### bridge.rs

Add new `method` strings in the existing `match method_str` dispatch. The C FFI surface
(`goose_bridge_handle_json` / `goose_bridge_free_string`) stays unchanged.

Proposed additions:
- `"metrics.hrv_v1"` — Lipponen-Tarvainen filter + SWS-tiered window + RMSSD
- `"metrics.recovery_v1"` — EWMA baselines + z-score + logistic model
- `"metrics.strain_v1"` — Tanaka HRmax + Banister TRIMP alongside existing zone_load
- `"metrics.calories_v1"` — Mifflin-St Jeor RMR + Keytel active-kcal
- `"metrics.sleep_stage_classify"` — Cole-Kripke epoch classifier on IMU series
- `"store.upsert_gravity_calibration"` — write gravity calibration row via rusqlite
- `"store.read_gravity_calibration"` — read latest gravity row for a device

### metrics.rs

Add `goose_hrv_v1`, `goose_recovery_v1`, `goose_strain_v1` following the
`AlgorithmRunResult<T>` pattern. Math helpers (`ewma_series`, `z_score`, `logistic`,
`lipponen_tarvainen_filter`, `median5`) placed as module-private `fn` at the bottom of
the file, matching the existing `mean`, `rmssd`, `sample_sd`, `pnn50` layout.

Existing helpers (`mean`, `sample_sd`, `clamp_0_100`, `clamp_fraction`, `score_component`,
`component_sum`, `require_finite_positive`) can be reused as-is or made `pub(crate)` if
needed across modules.

### energy_rollup.rs

- Replace `resting_kcal()` with `mifflin_st_jeor_rmr_kcal_per_day()` when
  `profile_height_cm` is available; fall back to `weight_kg * 22.0` with a quality flag.
- Supplement the `reserve_active_met_minutes` path with `keytel_active_kcal_per_minute()`
  when age + sex are available, selecting the higher of the two estimates.
- Add `profile_height_cm: Option<f64>` to both `EnergyDailyRollupOptions` and
  `EnergyHourlyRollupOptions`.

### protocol.rs / I16SeriesSummary

`I16SeriesSummary` currently stores `preview: Vec<i16>` (a capped sample count, not all
100 IMU samples per axis). The milestone requires full samples for Cole-Kripke and gravity
projection. Add `samples: Option<Vec<i16>>` alongside `preview`; populate it only when
the bridge call requests it via an explicit flag argument. Keep `preview` for existing
callers (additive, backward-compatible).

### store.rs — new gravity_calibration table

New SQLite migration in `GooseStore::initialize`, following the existing pattern:

```sql
CREATE TABLE IF NOT EXISTS gravity_calibration (
    id            TEXT PRIMARY KEY,
    device_id     TEXT NOT NULL,
    calibrated_at TEXT NOT NULL,
    gx            REAL NOT NULL,
    gy            REAL NOT NULL,
    gz            REAL NOT NULL,
    scale_factor  REAL NOT NULL,
    source        TEXT NOT NULL,
    provenance_json TEXT NOT NULL
);
```

---

## What NOT to Add

| Candidate | Reason |
|---|---|
| `ndarray` | All vector ops are simple O(n) iteration; ndarray's compile cost and API surface is not justified for these scalar formulas |
| `nalgebra` | Same as ndarray — gravity projection is a single dot product, not linear algebra |
| `statrs` | Normal CDF and other distributions not needed; logistic sigmoid is a one-liner and sufficient |
| `rand` | No stochastic algorithms in scope; all algorithms are deterministic |
| `linregress` / `polyfit` | No curve fitting at runtime; all coefficients are from published papers, hard-coded as `const` |
| `tensorflow` / `tract` / `candle` | No neural network inference; Cole-Kripke and the 4-class extension are threshold classifiers with fixed coefficients |
| `chrono` | Time arithmetic already handled with the custom RFC3339 parser in `energy_rollup.rs`; chrono would pull a large dependency for no new capability |
| Any Python FFI crate | The reference scripts in `Rust/core/tools/reference/` are validation tools only, not runtime dependencies |
| `approx` (even as dev-dep) | Use manual delta assertions matching the existing test style — `(result - expected).abs() < 0.01` |

The correct constraint is: every formula needed for these algorithms is in a published paper
and can be transcribed as a pure arithmetic Rust function under 30 lines. If implementing
a formula requires a crate, that is a sign the algorithm scope has drifted, not that the
crate should be added.
