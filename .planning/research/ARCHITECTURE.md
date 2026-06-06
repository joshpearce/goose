# Architecture Research — v5.0 Metrics Accuracy

**Domain:** Rust biometric algorithm layer for an iOS WHOOP app
**Researched:** 2026-06-06
**Confidence:** HIGH — based on direct codebase reading

---

## New vs Modified Components

| Component | New/Modified | Description |
|-----------|-------------|-------------|
| `protocol.rs` — `summarize_i16_series` | Modified | Expand `preview: Vec<i16>` from hardcoded cap of 8 to full 100 samples; changes the serialised `I16SeriesSummary` shape in `parsed_payload_json` stored in `decoded_frames` |
| `store.rs` — `gravity` table | New | Add `CREATE TABLE gravity (row_id INTEGER PK, device_id TEXT, ts_unix_ms INTEGER, x INTEGER, y INTEGER, z INTEGER)`; new schema migration bump to version 15 |
| `store.rs` — `GooseStore::insert_gravity_rows` | New | Batch INSERT function for gravity rows; called from the K21/K10 path in `upload.get_recent_decoded_streams` and from new bridge method |
| `metrics.rs` — Lipponen-Tarvainen ectopic filter | Modified | New pre-processing step inside `goose_hrv_v0`: classify RR intervals as normal/ectopic/missed using morphological rules from Lipponen & Tarvainen (2018); replaces the current simple range-gate drop |
| `metrics.rs` — Tanaka HRmax formula | Modified | New helper `tanaka_hrmax(age_years: u32) -> f64` = `208.0 - 0.7 * age`; used as denominator in `StrainInput` when user has not calibrated a personal max |
| `metrics.rs` — Banister TRIMP strain | Modified | New `goose_strain_v1` function implementing Banister's TRIMP formula using exponential HR-zone weighting; replaces the linear zone-weight model in `goose_strain_v0`; registered as a new `algorithm_definitions` row, not replacing v0 |
| `metrics.rs` — `fit_strain_denominator` | Modified | Helper that normalises raw TRIMP score to the 0–21 Goose scale using a fitted population denominator; feeds into `goose_strain_v1` |
| `metrics.rs` — `rmr_mifflin_st_jeor` | Modified | RMR calculator for energy rollup; replaces the current placeholder constant in `energy_rollup.rs` |
| `metrics.rs` — `heart_rate_dip_pct` | Modified | Computes nocturnal HR dip % = (pre-sleep average HR - nadir HR) / pre-sleep x 100; the field already exists as `heart_rate_dip_percent: Option<f64>` in `SleepInput` and `SleepV1Input` but is currently not computed from captured data |
| `metrics.rs` — `waso_estimation` | Modified | Computes WASO (Wake After Sleep Onset) from `SleepStageSegment` sequences; `wake_after_sleep_onset_minutes` already in `SleepInput`, currently populated externally |
| `sleep_staging.rs` | New | New module: Cole-Kripke activity-based staging pipeline, cardiorespiratory features per 30 s epoch, 4-class classifier (Awake/Core/Deep/REM) with physiological reimposition rules; consumes `gravity` rows + HR series from store |
| `baselines.rs` | New | New module: EWMA baseline state struct, `update(new_value: f64)` method, `fold_history(rows: &[DailyRecoveryMetricRow])` to rebuild from persisted data; used by recovery score to produce personal Z-scores instead of simple ratio |
| `metrics.rs` — `recovery_score_v1` | New | New function `goose_recovery_v1(input: &RecoveryV1Input)`: logistic squash of Z-scored HRV and RHR relative to personal EWMA baselines from `baselines.rs`; registered as new algorithm definition |
| `bridge.rs` — new methods | Modified | Four new RPC methods added to `BRIDGE_METHODS` and `handle_bridge_request` dispatcher; see Integration Points below |
| `GooseBLEClient.swift` — IMU sequence | Not changed | `startPhysiologyCapture` and `stopPhysiologyCapture` already include `TOGGLE_IMU_MODE_ON/OFF` (command 106); the IMU stream is already enabled; what changes is the extraction of that data downstream |
| `bridge.rs` — `upload.get_recent_decoded_streams` | Modified | Populate the currently-empty `gravity: Vec<serde_json::Value>` by extracting from `DataPacketBodySummary::RawMotionK21` axes; each sample becomes `{ts, device_id, x, y, z}` |
| `GooseUploadService.swift` | Not changed | Already sends `gravity` key in upload payload; no Swift changes needed |

---

## Data Flow Changes

### New path: gravity data BLE -> SQLite

```
WHOOP BLE (K21 packet, packet_type=51/52)
  -> GooseBLEClient -> CaptureFrameWriteQueue
  -> bridge: capture.import_frame_batch (existing)
  -> decoded_frames table (existing, stores parsed_payload_json with I16SeriesSummary)
  -> [NEW] upload.get_recent_decoded_streams extracts RawMotionK21 axes (preview now 100 samples)
  -> [NEW] bridge: store.insert_gravity_rows -> gravity table
```

The key change in `protocol.rs` is that `I16SeriesSummary.preview` grows from 8 to 100 samples. The `I16SeriesSummary` struct itself does not change shape — `preview` is already `Vec<i16>`. Existing rows stored in `decoded_frames` with 8-sample previews are not backfilled; the gravity extraction path operates on new frames only (filtered by `since_ts`).

### New path: sleep staging

```
gravity table (x, y, z timeseries at ~50 Hz per packet)
  + decoded_frames HR series
  -> [NEW] sleep_staging.rs: cole_kripke_activity_series (activity count per 30s epoch)
  -> [NEW] sleep_staging.rs: cardiorespiratory_features (HR features per epoch)
  -> [NEW] sleep_staging.rs: 4-class classifier with physiological reimposition
  -> Vec<SleepStageSegment>
  -> SleepV1Input.stage_segments (existing field, already handled by goose_sleep_v1)
```

`sleep_staging.rs` is a pure computation module. It reads from the store, computes, and returns `Vec<SleepStageSegment>`. It does not write to any table; the caller passes the result through the existing `SleepV1Input` path. No new output types are required.

### Modified path: HRV with ectopic filter

```
rr_intervals_ms (from decoded_frames, unchanged source)
  -> [NEW] lipponen_tarvainen_ectopic_filter()  (inside goose_hrv_v0 pre-step)
  -> cleaned rr_intervals
  -> existing RMSSD / SDNN / pNN50 computation (unchanged)
```

The existing `invalid_interval_count` counter and `invalid_rr_interval_dropped` quality flag are reused to cover ectopic-rejected intervals. No new output fields are required in `HrvOutput` for v1.

### Modified path: recovery with personal baselines

```
daily_recovery_metrics table (existing, stores hrv_rmssd_ms + resting_hr_bpm per day)
  -> [NEW] baselines.rs: fold_history() -> EwmaBaselineState {hrv_ewma, rhr_ewma}
  -> [NEW] goose_recovery_v1: Z-score each vital sign against personal EWMA
  -> logistic squash -> score_0_to_100
```

The `baselines.rs` state is reconstructed on each call — not persisted in SQLite in v1. This avoids a new table and migration for the first iteration. The EWMA fold is cheap: typically 30–90 rows from `daily_recovery_metrics`.

### Modified path: strain with Banister TRIMP

```
StrainInput {duration_minutes, resting_hr_bpm, average_hr_bpm, max_hr_bpm, hr_zone_minutes}
  -> [NEW] tanaka_hrmax(age_years) if max_hr_bpm not calibrated
  -> [NEW] goose_strain_v1 Banister TRIMP exponential weighting
  -> [NEW] fit_strain_denominator() -> normalised score_0_to_21
```

`goose_strain_v0` remains registered and active as fallback. `goose_strain_v1` is a new algorithm definition row; `settings.set_algorithm_preference` switches the active algorithm per scope.

---

## Build Order

Strict dependency order (each phase must be complete before the arrow target begins):

```
Phase 1 — protocol.rs + store.rs + gravity extraction in bridge.rs
  |
  +-> Phase 2 — sleep_staging.rs
  |     (needs gravity rows in store)
  |
  +-> Phase 3 — baselines.rs EWMA
  |     (reads existing daily_recovery_metrics; no Phase 1 data dependency,
  |      but wait for Phase 1 to stabilise the build before branching)
  |
  +-> Phase 4 — HRV ectopic filter (in metrics.rs)
  |     (pure computation, no data dependency on Phase 1,
  |      but logically grouped after data foundation)
  |
  +-> Phase 5 — Strain v1 Banister TRIMP (in metrics.rs)
        (pure computation, no data dependency)

After Phase 2 + Phase 3 + Phase 4 complete:
  -> Phase 6 — Recovery v1 (metrics.rs + bridge.rs + HealthDataStore Swift extension)
       (needs EWMA baselines from Phase 3, sleep staging from Phase 2,
        ectopic-filtered HRV from Phase 4 for accurate baseline history)

Phase 7 — Helper metrics (heart_rate_dip_pct, waso_estimation, rmr_mifflin_st_jeor)
  (independent, can be done at any time alongside Phase 2-5)
```

Phases 2, 3, 4, 5 can be developed in parallel after Phase 1 merges. Phase 6 is the only gate that requires all four to be complete.

---

## Integration Points

### bridge.rs — new methods

These four entries must be added to `BRIDGE_METHODS` (in lexicographic order to pass the constant-sync test) and to the `handle_bridge_request` match dispatcher:

| Method | Args | Returns | Depends on |
|--------|------|---------|------------|
| `metrics.goose_recovery_v1` | `database_path, start_time, end_time, baseline_window_days` | `AlgorithmRunResult<RecoveryScoreOutput>` | `baselines.rs`, `goose_recovery_v1` |
| `metrics.goose_strain_v1` | `StrainInput` JSON (same schema as v0) | `AlgorithmRunResult<StrainScoreOutput>` | `goose_strain_v1`, `tanaka_hrmax` |
| `metrics.sleep_staging` | `database_path, sleep_start, sleep_end, device_id` | `Vec<SleepStageSegment>` | `sleep_staging.rs` |
| `store.insert_gravity_rows` | `database_path, rows: [{ts_unix_ms, device_id, x, y, z}]` | `{inserted: usize}` | `GooseStore::insert_gravity_rows` |

`metrics.goose_recovery_v1` requires `database_path` because it reads `daily_recovery_metrics` history to build baselines. `metrics.goose_strain_v1` does not — it is a pure computation like v0.

### store.rs changes

1. Bump `CURRENT_SCHEMA_VERSION` from 14 to 15.
2. Add migration block for version 15 in `apply_migrations`: create `gravity` table with index.
3. Add `GooseStore::insert_gravity_rows(rows: &[GravityRowInput]) -> GooseResult<usize>`.
4. Add `GooseStore::gravity_rows_between(device_id: &str, start_unix_ms: i64, end_unix_ms: i64) -> GooseResult<Vec<GravityRow>>` — used by `sleep_staging.rs`.

Gravity table DDL:
```sql
CREATE TABLE IF NOT EXISTS gravity (
    row_id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    ts_unix_ms INTEGER NOT NULL,
    x INTEGER NOT NULL,
    y INTEGER NOT NULL,
    z INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
CREATE INDEX IF NOT EXISTS idx_gravity_device_ts ON gravity(device_id, ts_unix_ms);
```

### protocol.rs changes

In `summarize_i16_series`: change `if preview.len() < 8` to `if preview.len() < expected_count`. The `I16SeriesSummary` struct is unchanged — `preview` is already `Vec<i16>`. The only effect is that K21 and K10 packets now store all 100 samples in `parsed_payload_json` instead of the first 8.

### Swift call sites

| File | Change |
|------|--------|
| `GooseBLEClient.swift` | No change — IMU already toggled in `startPhysiologyCapture` |
| `GooseUploadService.swift` | No change — `gravity` key already sent in upload payload |
| `HealthDataStore+Recovery.swift` (new file) | Add `refreshRecoveryV1(start:end:)` calling `bridge.request(method: "metrics.goose_recovery_v1", args: [...])` |
| Existing `RecoveryV2DashboardView` | Update to consume `recoveryV1` property from `HealthDataStore` |

---

## Suggested Phase Groupings

| Phase | Work | Parallel with | Gate for |
|-------|------|--------------|----------|
| 1 — Data Foundation | `protocol.rs` preview expansion, gravity table + migration, K21 extraction in bridge | Nothing (first) | All algorithm phases |
| 2 — Sleep Staging | `sleep_staging.rs`, `metrics.sleep_staging` bridge method | Phase 3, 4, 5 after Phase 1 | Phase 6 |
| 3 — EWMA Baselines | `baselines.rs`, `fold_history` | Phase 2, 4, 5 after Phase 1 | Phase 6 |
| 4 — HRV Ectopic Filter | Lipponen-Tarvainen in `metrics.rs` | Phase 2, 3, 5 after Phase 1 | Phase 6 |
| 5 — Strain v1 | Banister TRIMP + Tanaka HRmax + `fit_strain_denominator`, `metrics.goose_strain_v1` bridge method | Phase 2, 3, 4 after Phase 1 | Independent |
| 6 — Recovery v1 | `goose_recovery_v1` in `metrics.rs`, bridge method, `HealthDataStore` extension | Nothing (last gate) | User-facing delivery |
| 7 — Helper metrics | `heart_rate_dip_pct`, `waso_estimation`, `rmr_mifflin_st_jeor` | Any phase | Not blocking |

Phase 7 is the lowest-risk work and can be used as a warm-up or fill work during the Phase 2-3-4 parallel sprint.
