# Pitfalls Research — v5.0 Metrics Accuracy

**Domain:** Biometric algorithm accuracy additions to existing Rust core + Swift iOS system
**Researched:** 2026-06-06
**Confidence:** HIGH — all pitfalls derived from direct inspection of the live codebase (`metrics.rs`, `protocol.rs`, `energy_rollup.rs`, `recovery_rollup.rs`, `metric_features.rs`, `bridge.rs`, `GooseBLEClient.swift`) plus established algorithm literature on HRV ectopic filtering, EWMA personalisation, TRIMP, Cole-Kripke actigraphy, and IMU BLE framing.

---

## Critical Pitfalls (silent failures)

Mistakes that pass tests but produce wrong results — the most dangerous category because they ship undetected.

---

### Pitfall 1: Lipponen-Tarvainen ectopic filter removes valid RR intervals from athletes with normal sinus arrhythmia

**What goes wrong:**
The Kubios ectopic filter (Lipponen-Tarvainen 2019) classifies beats as ectopic using a local reference interval computed from the surrounding N beats. For athletes with high respiratory sinus arrhythmia (RSA), RR intervals during deep breathing can vary ±300 ms legitimately. The filter's default thresholds (typically ±20% of local reference, or a fixed 200 ms deviation) correctly handle average-population physiology but aggressively remove physiologically valid intervals from trained athletes. The result is an artificially elevated RMSSD (fewer intervals → smaller squared differences → lower sum → but also fewer valid pairs, which can inflate or deflate depending on which end of the distribution is trimmed). This never triggers a test failure — the algorithm runs, produces a number, and the number is plausible.

**Root cause:**
The filter is defined with population-average thresholds. The current `goose_hrv_v0` uses a simple range filter (300–2000 ms), which is correct as a first pass but does not implement ectopic detection at all. Adding Lipponen-Tarvainen without a per-user threshold adaptation will silently over-filter athletic users.

**Consequences:**
HRV appears artificially low on nights when a trained user has strong RSA. Recovery score is suppressed. The user sees "low recovery" on nights when they are physiologically well-rested. This is a trust-destroying error — the number looks plausible but is wrong in a systematic direction.

**Prevention:**
(a) Implement the filter with adaptive thresholds (local reference ± user-specific percentile from 30-night history, not a fixed population constant). (b) Add a `ectopic_filter_removal_fraction` field to `HrvOutput` — any session where >5% of intervals are removed should emit a `high_ectopic_removal_rate` quality flag. (c) Cross-validate output RMSSD against the reference Python tool (`Rust/core/tools/reference/`) on at least 5 real overnight sessions before shipping.

**Detection:**
Quality flag `high_ectopic_removal_rate` present in output but score still shown to user without warning. Comparison against `pyhrv` reference on the same interval sequence showing >3 ms RMSSD difference.

---

### Pitfall 2: EWMA personal baseline converges to wrong steady state when the first N nights are non-representative

**What goes wrong:**
The EWMA baseline for HRV uses the formula `baseline_t = α * hrv_t + (1-α) * baseline_{t-1}`. The choice of α and the initialisation value are critical. If the initial baseline is set from night 1 (which may be a night with illness, travel, or alcohol), all subsequent values are anchored to a depressed baseline. A user who starts healthy will have their baseline slowly drift up; a user who starts sick will have their baseline suppressed for weeks. The logistic squash applied to `hrv / baseline` will then produce systematically high recovery scores (if baseline is too low) or systematically low scores (if baseline is too high) for the first 2–4 weeks.

**Root cause:**
EWMA is state that must be persisted in SQLite (Rust core is stateless per bridge call — this is explicitly documented in `CLAUDE.md`). The risk is that the initialisation value is set once and never audited. If the Rust bridge writes the first baseline value without checking whether night 1 is a representative sample (minimum confidence threshold), the error propagates indefinitely.

**Consequences:**
Recovery scores are systematically biased for new users. A user who wears the device for the first time after a poor night will see inflated recovery scores for weeks because their baseline is depressed. This is a silent failure — every individual score looks reasonable, only the long-term trend is wrong.

**Prevention:**
(a) Do not initialise the EWMA until at least `baseline_min_days` nights (currently 7 in `HrvFeatureOptions.baseline_min_days`) are collected. Use a simple mean of the first 7 nights as the cold-start value, not the first night. (b) Store `baseline_cold_start_night_count` and `baseline_initialised_at` in SQLite alongside the baseline value. (c) Flag nights used for baseline initialisation as `excluded_from_baseline` if their confidence is below threshold — mirror the existing `excluded_from_baseline` field in `SleepNightHistoryInput`.

**Detection:**
Baseline value in SQLite is identical to night-1 HRV. `baseline_initialised_at` is set to a night with quality flag `low_interval_count`. Run a 90-night simulation with synthetic data: inject a low-HRV night 1, verify baseline does not reach true steady state within 14 nights.

---

### Pitfall 3: Strain Banister TRIMP sex constant applied to wrong variable produces a plausible but wrong number

**What goes wrong:**
Banister TRIMP uses the formula `TRIMP = duration × ΔHR × 0.64 × e^(1.92 × ΔHR)` for males and `0.86 × e^(1.67 × ΔHR)` for females, where `ΔHR = (average_HR - resting_HR) / (max_HR - resting_HR)` (heart rate reserve fraction). The current `goose_strain_v0` uses simplified zone-load weights `[1.0, 2.0, 3.0, 4.0, 5.0]` and does not implement TRIMP at all. Adding TRIMP means introducing the sex constant. The pitfall: applying the male constant to a female user (or vice versa) produces a strain score that is off by ~15-25% for moderate-intensity sessions. This is not caught by any range check because 0–21 is still a valid output range.

**Root cause:**
`StrainInput` has no `profile_sex` field. `EnergyDailyRollupOptions` has `profile_sex: Option<&'a str>` — the energy rollup already handles sex. If sex is not threaded into the strain computation, the algorithm silently defaults to a single constant, which is biologically incorrect for 50% of users.

**Consequences:**
Female users systematically see lower strain scores for the same effort level. They may under-recover because their training load appears lighter than it is. This is a clinical-quality error for a health metric.

**Prevention:**
(a) Add `profile_sex: Option<String>` to `StrainInput` before implementing TRIMP. (b) Emit a `sex_unknown_using_population_average_trimp_constant` quality flag when sex is not provided. (c) Never silently default to the male constant — use the midpoint of male/female constants (approximately `0.75 × e^(1.79 × ΔHR)`) as the population-average fallback and document this. (d) Add a test that passes identical HR data with `sex: "male"` vs `sex: "female"` and asserts the outputs differ by the expected ratio.

**Detection:**
Test `goose_strain_v0` with `profile_sex = None` — if the output is identical to `profile_sex = Some("male")`, the sex constant is not being used. Run a manual calculation on a 60-minute session at 70% HRR: male TRIMP ≈ 63, female ≈ 47 — verify the Rust output matches within 2%.

---

### Pitfall 4: Calorie coefficients from Ghidra reverse-engineering are floating-point approximations — small errors compound over multi-hour sessions

**What goes wrong:**
Binary reverse-engineering via Ghidra produces floating-point constants that may differ from the source-code values by 1–3 ULPs (units in the last place) due to compiler optimisations, FMA fusion, and constant folding. The current `resting_kcal` uses `weight_kg * 22.0` (a clearly intentional round number — simplified RMR). The `active_kcal` formula uses `3.5 * weight_kg / 200.0` (the MET-to-kcal conversion). These are standard values. However, if the Ghidra-extracted coefficients for a new formula are `0.01748` instead of `0.0175`, the error is 0.11% per interval. For a 3-hour workout with 10,800 one-second samples, this compounds to a final calorie error of ~12 kcal — which is within typical tolerance, but if multiple coefficients are off, errors add.

**Root cause:**
Floating-point constants extracted from compiled binaries are not exact. Ghidra may display `0.01748046875` (the nearest float32 representation of 0.0175) rather than the exact source value `0.0175`. The implementer may copy the Ghidra hex representation directly into Rust as `f64`, causing a systematic bias.

**Consequences:**
Calorie output is off by 1–5% from WHOOP's official value. Validation tests against official labels pass within tolerance (±30 kcal by default in the energy capture validation) but the bias is real and grows with session duration.

**Prevention:**
(a) For each Ghidra-extracted constant, verify against the nearest "clean" rational number (e.g., is `0.01748046875` meant to be `7/400 = 0.0175`?). Use the clean form in Rust source if it differs by less than 0.1%. (b) Document each constant with its source: `// MET-to-kcal: 3.5 mL·kg⁻¹·min⁻¹ O2 × weight_kg / 200 (Ainsworth et al. 1993)`. (c) Run validation against at least 10 official label pairs spanning 30 min – 3 hr sessions before accepting the formula.

**Detection:**
Compare `active_kcal` output from Rust against a Python reference implementation of the same formula using Python's `float` (IEEE 754 double) — if they differ by more than 0.01 kcal for identical inputs, a coefficient is wrong.

---

### Pitfall 5: Cole-Kripke actigraphy applied to WHOOP IMU gravity data instead of wrist-worn actigraph data — calibration mismatch

**What goes wrong:**
The Cole-Kripke algorithm was derived from and validated on data from wrist-worn actigraph devices (e.g., Actiwatch) that measure acceleration in counts per epoch. The WHOOP IMU produces raw I16 samples in `g × 1000` units (approximately) at a much higher sampling rate. The Cole-Kripke threshold for classifying an epoch as "wake" vs "sleep" was calibrated on the actigraph's native count scale. Applying the same threshold to WHOOP IMU data without unit conversion and normalisation will produce systematically incorrect sleep/wake classifications. Motion during light sleep will look like deep wakefulness.

**Root cause:**
The `I16SeriesSummary` currently captures only 8 samples (preview). The plan to extend to 100 samples gives enough data to compute epoch-level activity counts, but the conversion from raw I16 acceleration to Cole-Kripke compatible counts requires a device-specific scaling factor that must be validated empirically against polysomnography or at minimum against a reference actigraph worn simultaneously.

**Consequences:**
Sleep staging is wrong in the most important direction: wake is classified as sleep (the algorithm was tuned to be sensitive, so it tends to miss wake epochs in low-motion contexts). This artificially inflates sleep duration and improves the sleep score. Users see a better sleep score than reality — a pleasant error that is hard to discover without ground truth.

**Prevention:**
(a) Do not use Cole-Kripke with its published coefficients on raw WHOOP IMU data. Either: derive your own calibration coefficients using paired WHOOP + Actiwatch data, or use a device-agnostic model. (b) Before shipping, validate on at least 5 overnight sessions with a reference (even self-reported sleep diary is better than nothing). (c) Emit a `staging_method_actigraphy_uncalibrated` quality flag when the classifier is used without validated device-specific scaling. (d) Implement the physiological reimposition rules (minimum REM/deep durations, sleep cycle constraints) as hard constraints that override the actigraphy output — this reduces but does not eliminate the calibration error.

**Detection:**
Compare computed sleep stages against WHOOP app official stages for the same night. For a night where WHOOP reports 45 min deep, 90 min REM — if Cole-Kripke reports 20 min deep, 60 min REM, the classifier is over-detecting wake. Compare at least 3 nights before accepting the implementation.

---

### Pitfall 6: EWMA baseline update is written to SQLite on every bridge call — double-update when rollup is called twice for the same date

**What goes wrong:**
The recovery rollup pipeline calls `write_metric = true` to persist the daily metric. If the bridge method for recovery daily rollup is called twice for the same `date_key` (which can happen if the UI retries after a timeout, or if two async bridge calls overlap), the EWMA state is updated twice: `baseline_new = α * hrv_today + (1-α) * baseline_old` is applied twice, pulling the baseline further toward today's value than intended. After N retry calls, the baseline is permanently biased toward the most recent day.

**Root cause:**
`upsert_daily_recovery_metric` in `store.rs` is idempotent for the metric row (UPSERT by primary key), but the EWMA state update (a separate write to a baseline table) may not be idempotent. If the baseline update is a simple `UPDATE SET baseline = ?` without a "only update if this day is newer than last_updated_date" guard, double-calls corrupt the baseline.

**Consequences:**
EWMA baseline is biased toward the most recent day. Recovery score is overly responsive to single-day changes. A bad night causes a sharp baseline drop that takes weeks to recover instead of being smoothed out.

**Prevention:**
(a) Make EWMA baseline updates idempotent: include a `last_updated_date_key` column in the baseline table and guard `UPDATE SET baseline = ? WHERE last_updated_date_key < ?`. (b) Log a `baseline_update_skipped_already_current` event when the guard triggers — this makes double-calls visible. (c) Add an integration test that calls the rollup bridge method twice for the same date and asserts the baseline value is identical after both calls.

**Detection:**
Call `metrics.recovery_daily_rollup` twice with `write_metric: true` for the same date. Query the baseline table before and after the second call — if the value changed, the update is not idempotent.

---

## Integration Pitfalls

Mistakes specific to adding these algorithms to the existing Rust/Swift system.

---

### Pitfall 7: Extending I16SeriesSummary from 8-sample preview to 100 full samples — JSON payload size causes FFI buffer overflow at the Swift boundary

**What goes wrong:**
`I16SeriesSummary.preview` currently holds at most 8 samples (enforced at line 678 of `protocol.rs`). The `DataPacketBodySummary::RawMotionK10` and `RawMotionK21` variants each embed `Vec<I16SeriesSummary>` (up to 3 axes). Extending to 100 samples means each `I16SeriesSummary` grows from ~50 bytes JSON to ~600 bytes JSON. A K21 packet with 3 axes becomes ~1.8 KB of JSON just for the IMU sample data, versus ~150 bytes today. The `goose_bridge_handle_json` FFI returns a `*mut c_char` allocated by Rust and freed by Swift via `goose_bridge_free_string`. If the Swift side has any hardcoded buffer assumption (e.g., a `Data(bytes:count:)` allocation with a fixed upper bound), large IMU payloads will silently truncate.

**Root cause:**
The bridge protocol was designed for small payloads (metric scores, status reports). The preview was intentionally kept small (8 samples) to control JSON size. Extending to 100 samples is a 12× increase in the IMU portion of the JSON, which compounds if the caller requests multiple frames in a batch.

**Consequences:**
Silent JSON truncation. The Swift side parses a truncated JSON string and either throws a decode error (best case) or produces a partially-decoded struct with trailing fields as `nil` or `0` (worst case, if using permissive decoding). The `parsed_count` field in `I16SeriesSummary` will appear to confirm 100 samples were parsed when only 50 were present in the truncated payload.

**Prevention:**
(a) Measure the JSON size of a K10/K21 packet with 100 samples before shipping. Add a test that calls the bridge with a K21 frame and asserts `result.len() > 1500` (a lower bound confirming the samples are present). (b) Add a `max_preview_count` parameter to the bridge call that allows the caller to request 8 (existing behavior) or 100 (new behavior) — the existing 8-sample path remains the default and does not break existing tests. (c) Verify on device that `goose_bridge_handle_json` response is fully received by checking that the last byte of the JSON is `}` before parsing.

**Detection:**
Parse the JSON response from a K21 batch bridge call. Check `result.parsed_payload.body_summary.axes[0].preview.count` — if it is less than 100 when 100 were requested, truncation occurred.

---

### Pitfall 8: body_hex field in DataPacket payload is included in round-trip JSON tests — removing or modifying it for K10/K21 breaks existing protocol_tests.rs assertions

**What goes wrong:**
`protocol_tests.rs` line 192 asserts `body_hex: "aa4dbbccddeeff".to_string()` for a `NormalHistory` packet. K10 and K21 tests (lines 334–451) assert on `body_summary` but do NOT currently assert `body_hex` for those variants (the tests use `..` pattern matching that ignores `body_hex`). However, any refactoring that changes `body_hex` to be empty (or conditionally absent) for K10/K21 frames — for example, to reduce payload size — will pass the current tests but change the JSON schema that Swift decodes. Existing Swift code that reads `parsedPayload.body_hex` for debug display will silently get an empty string.

**Root cause:**
The `DataPacket` variant serialises `body_hex` as a `String` field unconditionally. If the intent is to exclude `body_hex` from K10/K21 frames to reduce JSON size when serving 100-sample IMU data, the field must be removed from the struct and the `#[serde(skip_serializing_if)]` attribute used, or the Swift decoder updated simultaneously. No test currently enforces the K10/K21 `body_hex` value.

**Consequences:**
Swift's `ParsedPayload` decode (if it uses a Codable struct matching the JSON) will either fail to decode (if the field is now absent but expected) or silently use the wrong value. This is a cross-language API contract break that is undetectable from the Rust test suite alone.

**Prevention:**
(a) Do NOT remove or conditionally skip `body_hex` for K10/K21 without simultaneously updating the Swift decoder and adding an explicit round-trip test. (b) Add protocol_tests.rs assertions for `body_hex` in K10 and K21 test cases — even if the value is just `assert!(body_hex.starts_with("..."))` — to make the field part of the tested contract. (c) Any change to `DataPacket`'s serialised fields requires a Swift decoder audit.

**Detection:**
Add a test that serialises a K10 frame to JSON and deserialises it back using `serde_json::from_str::<ParsedFrame>` — if `body_hex` is present in the original struct but missing in the round-trip, the serde annotation is wrong.

---

### Pitfall 9: TOGGLE_IMU_MODE (command 106) sent automatically in startCapture breaks existing WHOOP protocol state machine

**What goes wrong:**
`TOGGLE_IMU_MODE_ON` (command 106, payload `true`) and `TOGGLE_IMU_MODE_OFF` (command 106, payload `false`) exist as `SensorStreamCommandKind` instances in `GooseBLEClient.swift` (lines 533, 550) but are never sent automatically in the production `startCapture` path — only in explicit debug/historical contexts. The WHOOP firmware responds to command 106 by switching the realtime stream from standard data packets to IMU data packets (type 51: `PACKET_TYPE_REALTIME_IMU_DATA_STREAM`). Sending `TOGGLE_IMU_MODE_ON` without accounting for the stream type change means the existing `NotificationFrameParser` receives IMU packet type 51 but dispatches it through the standard packet parsing path, which expects types 40 (realtime data) or 43 (raw). The frame is parsed incorrectly, producing garbled `ParsedPayload` values, without any error — `packet_type_name` will be `None` (type 51 has no name in the current `command_name` match) and the packet will fall through to `Raw { ... }`.

**Root cause:**
Command 106 was added to the command catalog as a debug command (`risk_gate: CriticalStateChange` in `commands.rs` line 865–866). The BLE timing for toggling IMU mode (whether to wait for a command response before the stream changes, or whether the change is immediate) is not documented in the existing codebase. Sending it during a live capture without a corresponding stream-type handler will produce silent data corruption.

**Consequences:**
All packets during IMU mode are stored as `Raw` frames. The HRV pipeline receives no new RR intervals during the IMU window. The sleep staging pipeline has no IMU data. The user sees a capture session with a gap in heart rate data coinciding exactly with the IMU mode window. This is detectable only by inspecting `decoded_frames` for the session.

**Prevention:**
(a) Do not send TOGGLE_IMU_MODE automatically in `startCapture` until `PACKET_TYPE_REALTIME_IMU_DATA_STREAM` (type 51) parsing is fully implemented and tested. (b) Add type 51 to the `data_packet_domain` match in `protocol.rs` and implement `parse_k_imup_body_summary` before sending the command in production. (c) Use a feature flag (`imu_mode_enabled: Bool` in `MoreDataStore` or `GooseAppModel`) that defaults to `false` and is only set to `true` by an explicit test session, not by normal `startCapture`.

**Detection:**
Send `TOGGLE_IMU_MODE_ON` in a test session. Query `SELECT packet_type, COUNT(*) FROM decoded_frames WHERE session_id = ?` — if all records after the toggle have `packet_type = NULL` (Raw frames), the parser is not handling type 51.

---

### Pitfall 10: EWMA baseline state stored in SQLite as a single row — concurrent bridge calls from multiple GooseRustBridge instances produce a read-modify-write race

**What goes wrong:**
The Rust core is stateless per bridge call, but multiple `GooseRustBridge` instances exist simultaneously (`GooseAppModel`, `HealthDataStore`, `OvernightSQLiteMirrorQueue`, `CaptureFrameWriteQueue`). SQLite serialises writes, but a read-modify-write sequence (1. read current baseline, 2. compute new baseline, 3. write new baseline) is not atomic unless wrapped in a `BEGIN EXCLUSIVE` transaction. If two bridge instances call the EWMA update simultaneously (e.g., `GooseAppModel` triggers a recovery rollup while `OvernightSQLiteMirrorQueue` triggers a nightly sync), the sequence interleaves: both read the same old baseline, both compute a new value, and the last writer wins — dropping one night's update.

**Root cause:**
`rusqlite` with `bundled` feature opens the database in WAL mode by default (or serialised mode). SQLite WAL mode allows concurrent reads but serialises writes. However, a read-modify-write at the Rust function level is not atomic at the SQLite level unless the entire operation is inside a transaction. The existing `upsert_daily_recovery_metric` uses UPSERT which is atomic, but any new EWMA state table update must also be atomic.

**Consequences:**
EWMA baseline loses update steps unpredictably under concurrent bridge usage. The baseline drifts more slowly than expected (half the nightly updates are lost). This shows up as a "sluggish personalisation" symptom — the algorithm takes twice as many nights to converge.

**Prevention:**
(a) Wrap the EWMA read-modify-write in a `BEGIN EXCLUSIVE` transaction in Rust. (b) Alternatively, use SQLite's `UPDATE SET baseline = α * ? + (1-α) * baseline WHERE ...` in a single atomic statement — this avoids the Rust-level race entirely. (c) Add a test that spawns two threads calling the EWMA update simultaneously and asserts the final baseline is exactly the correct two-step application.

**Detection:**
Log `baseline_before` and `baseline_after` for each update. If two calls on the same night produce the same `baseline_before`, the race occurred.

---

### Pitfall 11: Changing I16SeriesSummary.preview from Vec<i16> to a larger Vec breaks existing JSON snapshot tests in protocol_tests.rs

**What goes wrong:**
`protocol_tests.rs` line 271 asserts `preview: vec![1000, -1000, 200]` for an r17 packet with exactly 3 samples. K10 tests at line 334+ assert specific preview values for the first 8 samples. Any change that extends `preview` to 100 elements will break all existing assertions that check `preview` contents. Even a change that makes preview length configurable (but defaults to 8) is safe only if the test-facing API is unchanged. A change to the serialised field name (e.g., renaming `preview` to `samples`) will silently break Swift decoding without a Rust compile error.

**Root cause:**
`I16SeriesSummary` is `#[derive(Serialize, Deserialize)]` with default field naming. Any rename or structural change to `preview` is a breaking JSON schema change. The existing test assertions are tight: they check exact `Vec<i16>` contents, not just lengths.

**Consequences:**
All 40+ integration tests that parse K10, K21, or r17 frames fail at CI. This is a test failure (visible) but the fix may inadvertently change the JSON schema in a way that breaks Swift without a corresponding test.

**Prevention:**
(a) Add a `#[serde(rename = "preview")]` or `#[serde(alias = "preview")]` annotation before changing the field. (b) Use a separate `full_samples: Option<Vec<i16>>` field (always `None` in the 8-sample mode, populated in the 100-sample mode) rather than extending `preview`. This is a non-breaking addition. (c) Run `cargo test` before and after any `I16SeriesSummary` change — but also check the Swift `Codable` struct for the field name.

**Detection:**
`cargo test -- protocol_tests` after the change. Any failure on preview contents = breaking change. Zero failures = likely safe, but still audit the Swift decoder.

---

## Algorithm Implementation Traps

Common mistakes in each algorithm family.

---

### HRV — Lipponen-Tarvainen

| Trap | What Goes Wrong | How to Catch |
|------|----------------|--------------|
| Using population-average thresholds | Over-filters athletic users; artificially lowers RMSSD | Per-user threshold from 30-night baseline |
| Applying the filter on already-filtered intervals | Double-filtering removes more intervals than intended | Apply ectopic filter first, range filter second — never reverse |
| Using `f32` for intermediate squared differences | RMSSD squared differences at 2000 ms = 4,000,000 — overflows f32 at 16,777,216 | Use `f64` for all intermediate accumulations; the existing `sum: i64` in `I16SeriesSummary` is a correct precedent |
| Counting ectopic beats as invalid intervals | Ectopic beats should be interpolated (Kubios) or excluded; they affect SDNN differently from RMSSD | Follow the Lipponen-Tarvainen paper: interpolate for SDNN, exclude for RMSSD |
| Not flagging sessions with >5% ectopic removal | Quality degradation is invisible | Always emit `high_ectopic_removal_fraction` quality flag when >5% removed |

---

### Recovery — EWMA baseline

| Trap | What Goes Wrong | How to Catch |
|------|----------------|--------------|
| Initialising baseline from night 1 | Cold-start bias for 2–4 weeks | Require 7 nights before baseline is active |
| Using too-small α (e.g., 0.05) | Baseline too sluggish; misses seasonal changes | α = 0.1–0.15 is typical for 7–14 day effective window |
| Using too-large α (e.g., 0.3) | Baseline too reactive; daily noise passes through | Validate α against 90-night simulation: baseline should not change by >20% in one week |
| Non-idempotent baseline write | Double-update from retry | `UPDATE SET baseline = ? WHERE last_updated_date < ?` guard |
| Logistic squash with wrong inflection point | Recovery scores cluster near 50% or near extremes | Verify sigmoid inflection at HRV = baseline: f(1.0) should equal 0.5 |
| Baseline computed from non-sleep windows | Daytime HRV is lower; using it depresses baseline | Only use overnight/sleep window HRV for baseline |

---

### Calories — coefficient validation

| Trap | What Goes Wrong | How to Catch |
|------|----------------|--------------|
| Using Ghidra float32 literals as f64 | Off-by-epsilon per sample, compounding over sessions | Snap to nearest clean rational (1/57, 7/400, etc.); verify against Python float |
| Applying RMR formula (Mifflin-St Jeor) without sex | 15–20% RMR error for females | Use `profile_sex` as a required parameter; emit `sex_missing` quality flag |
| Mixing kcal/min with kcal/hour in MET conversions | 60× error in active calorie output | Always work in kcal/min units internally; only convert for display |
| Applying Harris-Benedict (1919) instead of Mifflin-St Jeor (1990) | 5–10% RMR overestimate | Use Mifflin-St Jeor; it's the ADA standard post-1990 |
| Zone MET values not matching device's HR zone boundaries | WHOOP zones are HRR-based, not absolute HR | Validate zone MET assignments against HR reserve fraction, not absolute BPM |

---

### Strain — TRIMP constants

| Trap | What Goes Wrong | How to Catch |
|------|----------------|--------------|
| Applying male constant to female user | ~15-25% strain underestimate for women | `profile_sex` required in `StrainInput`; emit `sex_unknown` quality flag |
| Using `average_hr` instead of `average_hr_reserve` in TRIMP | Absolute HR is not effort; must use HRR fraction | `ΔHR = (avg_hr - resting) / (max - resting)`; verify this is in [0,1] |
| Applying denominator calibration before 14 days of data | Least-squares with <14 points is unstable | Require minimum N sessions; use uncalibrated formula until N is reached |
| Least-squares calibration including outlier sessions | Illness/travel sessions distort calibration | Exclude sessions with quality flags before calibration |
| Confusing `score_0_to_21` with raw TRIMP minutes | Outputs are in different units | Keep raw TRIMP in `zone_load` field; scale to 0–21 range separately |

---

### Sleep — Cole-Kripke actigraphy

| Trap | What Goes Wrong | How to Catch |
|------|----------------|--------------|
| Using published Cole-Kripke coefficients on WHOOP IMU | Device-specific calibration mismatch; over-detects sleep | Validate on 5+ nights against WHOOP official stages |
| Applying filter on 1-second epochs with 100-sample IMU data | Cole-Kripke was designed for 1-minute epochs | Aggregate 100 1-second samples → 1-minute epoch before applying |
| Physiological constraints not applied | Impossible stage sequences (REM directly after wake) | Hard-code: min 10 min in any stage, REM not in first 60 min, transitions must be monotone |
| Sleep/wake threshold not adapted per user | High-motion sleepers are over-classified as awake | User-specific motion percentile threshold from 7-night baseline |
| I16 samples in raw ADU, not calibrated g | Motion intensity unit is wrong without calibration | WHOOP IMU: divide I16 by device sensitivity (nominally 1000 for ±16g range) |

---

### IMU pipeline — I16SeriesSummary extension

| Trap | What Goes Wrong | How to Catch |
|------|----------------|--------------|
| Changing `preview: Vec<i16>` in-place | Breaks all K10/K21 round-trip tests | Add `full_samples: Option<Vec<i16>>` as a new optional field |
| Requesting 100 samples from 8-byte BLE MTU fragment | BLE notification is 20 bytes max; need reassembly | `FrameAccumulator` already handles reassembly; verify reassembled frame has 100 samples before parsing |
| Assuming IMU mode produces only type-51 packets | Some firmware versions interleave type-40 | Handle both types simultaneously during IMU mode |
| Forgetting to send TOGGLE_IMU_MODE_OFF on session end | Device stays in IMU mode after disconnect | Add `stopImuMode()` call in `stopCapture()` and in `didDisconnectPeripheral` |
| I16 sum overflow at 100 samples | sum = 100 × 32767 = 3,276,700; fits i32 but not i16 | `I16SeriesSummary.sum` is already `i64` — correct; do not change to i32 |

---

## Prevention Strategy

How to catch each class of pitfall before it reaches production.

### 1. Algorithm Cross-Validation Baseline

Before shipping any algorithm, run it against the Python reference tools (`Rust/core/tools/reference/`) on at least 5 real sessions. The comparison must be documented:

```
Session ID | Python RMSSD | Rust RMSSD | Delta | Quality Flags Match?
```

Any delta >1 ms for HRV, >2 kcal for calories, >0.5 points for strain — investigate before shipping.

### 2. Quality Flag Coverage Test

Every algorithm implementation must have a test that exercises every defined quality flag path:

```rust
// Must trigger "high_ectopic_removal_rate" quality flag:
let input = HrvInput { rr_intervals_ms: vec![800.0, 400.0, 800.0, ...], ... }; // >5% ectopic
let result = goose_hrv_v1(&input);
assert!(result.quality_flags.contains("high_ectopic_removal_rate"));
```

### 3. Idempotency Tests for SQLite Writes

Every new SQLite write that carries state (EWMA baseline, calibration coefficients) must have an idempotency test:

```rust
call_rollup_bridge(date_key, write_metric: true);
let baseline_after_first = read_baseline();
call_rollup_bridge(date_key, write_metric: true); // same date
let baseline_after_second = read_baseline();
assert_eq!(baseline_after_first, baseline_after_second);
```

### 4. Protocol Round-Trip Tests for I16SeriesSummary Changes

Any change to `I16SeriesSummary` must pass:

```rust
let frame = build_k10_frame_with_n_samples(100);
let parsed = parse_frame(DeviceType::Goose, &frame).unwrap();
let json = serde_json::to_string(&parsed).unwrap();
let reparsed: ParsedFrame = serde_json::from_str(&json).unwrap();
assert_eq!(parsed, reparsed); // round-trip must be lossless
```

### 5. Sex-Dependent Constant Tests

For any algorithm that uses sex-dependent constants:

```rust
let male_result = goose_strain_v0(&input_with_sex("male"));
let female_result = goose_strain_v0(&input_with_sex("female"));
assert_ne!(male_result.output.score_0_to_21, female_result.output.score_0_to_21);
// Verify the ratio matches the theoretical TRIMP constant ratio
```

### 6. Coefficient Precision Verification

For each Ghidra-extracted constant:

```python
# Python reference script to verify coefficient precision
import struct
ghidra_value = 0.01748046875  # from Ghidra hex
target_value = 7/400  # nearest clean rational = 0.0175
relative_error = abs(ghidra_value - target_value) / target_value
assert relative_error < 0.001, f"Coefficient error {relative_error:.4%} exceeds 0.1%"
```

### 7. Concurrent Bridge Call Test

For any EWMA baseline update:

```rust
use std::thread;
let db_path = temp_db_path();
let handle1 = thread::spawn(|| call_recovery_rollup(db_path, date_key));
let handle2 = thread::spawn(|| call_recovery_rollup(db_path, date_key));
handle1.join(); handle2.join();
let baseline = read_baseline(db_path, date_key);
assert_eq!(baseline, expected_single_update_value); // not double-updated
```

---

## Phase-Specific Warnings

| Phase Topic | Pitfall # | Likely Pitfall | Mitigation |
|-------------|-----------|----------------|------------|
| HRV Lipponen-Tarvainen filter | 1 | Athletic users over-filtered; RMSSD artificially depressed | Adaptive thresholds; 5-night cross-validation before shipping |
| EWMA personal baseline | 2, 6, 10 | Cold-start bias; double-update corruption; concurrent write race | 7-night cold-start guard; idempotent write; `BEGIN EXCLUSIVE` transaction |
| Calorie coefficient validation | 4 | Ghidra float approximations compound over long sessions | Snap to clean rationals; 10-session validation against official labels |
| Strain TRIMP sex constants | 3 | Male constant applied to female users | `profile_sex` in `StrainInput`; sex-mismatch quality flag; ratio test |
| Cole-Kripke sleep staging | 5 | Device calibration mismatch; epochs at wrong timescale | No published coefficients on raw WHOOP IMU; 5-night validation; `uncalibrated` quality flag |
| IMU I16SeriesSummary extension | 7, 8, 11 | JSON payload overflow; `body_hex` schema break; protocol test failures | Add `full_samples` optional field; run `cargo test` after every struct change; measure JSON size |
| TOGGLE_IMU_MODE in startCapture | 9 | Type-51 packets parsed as Raw; gaps in HRV data | Feature flag defaults off; implement type-51 parsing first |
| Gen4 upstream arithmetic fixes | — | `as u16` truncation on large frame lengths; wrapping instead of trapping arithmetic | Review every `as u16`/`as u8` cast in `protocol.rs` for Gen4 path; use `u16::try_from(x)?` |
| body_hex K10/K21 exclusion | 8 | Silent Swift decoder break; existing round-trip tests don't cover K10/K21 body_hex | Add explicit `body_hex` assertions to K10/K21 tests before any change |
| Retain cycles in Swift closures | — | `[weak self]` missing in async closure that captures `GooseAppModel` or `HealthDataStore` | Audit every new `Task { [weak self] in ... }` that captures an algorithm result closure |

---

## Confidence Assessment

| Area | Confidence | Basis |
|------|------------|-------|
| HRV ectopic filter pitfalls | HIGH | Direct code inspection shows current HRV uses simple range filter; Lipponen-Tarvainen threshold literature well-established |
| EWMA baseline pitfalls | HIGH | Stateless bridge architecture confirmed in `CLAUDE.md`; idempotency gap visible in `recovery_rollup.rs` UPSERT pattern |
| Calorie coefficient pitfalls | HIGH | `energy_rollup.rs` shows current formula; Ghidra float-to-double precision is a known embedded reverse-engineering problem |
| Strain sex constant pitfalls | HIGH | `StrainInput` confirmed to have no `profile_sex` field; `EnergyDailyRollupOptions` does; gap is real |
| Cole-Kripke actigraphy pitfalls | MEDIUM | IMU data structure confirmed (I16SeriesSummary); Cole-Kripke calibration requirement is algorithm literature; no empirical validation data available |
| IMU JSON payload pitfalls | HIGH | `preview: Vec<i16>` capped at 8 confirmed in `protocol.rs` line 678; JSON size estimate is straightforward arithmetic |
| TOGGLE_IMU_MODE pitfalls | HIGH | Command 106 present but confirmed as never sent in production `startCapture`; type-51 parsing not implemented |
| Concurrent bridge pitfalls | MEDIUM | Multiple bridge instances confirmed from `CLAUDE.md`; SQLite WAL concurrency is well-understood; exact bridge call sequence for EWMA not yet implemented |

---

## Sources

- `Rust/core/src/protocol.rs` — `I16SeriesSummary` struct (lines 169–178); preview cap at 8 (line 678); K10/K21 parsing (lines 596–628); `body_hex` in `DataPacket` (line 515)
- `Rust/core/src/metrics.rs` — `goose_hrv_v0` range filter 300–2000 ms (line 784); `StrainInput` struct (no `profile_sex`); `RecoveryInput` baseline fields; `HrvFeatureOptions.baseline_min_days` (line 77)
- `Rust/core/src/energy_rollup.rs` — `resting_kcal` formula (`weight_kg * 22.0`, line 1160); `active_kcal` formula (MET conversion, line 1173); `profile_sex` in options (line 45)
- `Rust/core/src/recovery_rollup.rs` — UPSERT pattern for daily metrics (line 370); rolling average computation (line 1174); idempotency gap in double-call scenario
- `Rust/core/tests/protocol_tests.rs` — `preview: vec![1000, -1000, 200]` assertion (line 271); K10/K21 tests without `body_hex` assertion (lines 334–451)
- `GooseSwift/GooseBLEClient.swift` — `TOGGLE_IMU_MODE_ON` command (line 533); command 106 definition (line 591); `startCapture` does not send command 106
- `GooseSwift/MoreDataStore.swift` — `startCapture` implementation (line 230); no TOGGLE_IMU_MODE call
- `Rust/core/src/commands.rs` — `toggle_imu_mode` command definition (lines 865–866): `risk_gate: CriticalStateChange`
- `CLAUDE.md` — "Rust bridge is synchronous: `goose_bridge_handle_json` blocks the calling thread. Never call from `@MainActor` with expensive methods" — multiple `GooseRustBridge` instances architecture confirmed
- Algorithm literature: Lipponen & Tarvainen (2019) "A robust algorithm for heart rate variability time series artefact correction using novel beat classification" — threshold sensitivity analysis; Banister (1991) "Modeling elite athletic performance" — TRIMP sex constants; Cole et al. (1992) "Automatic sleep/wake identification from wrist activity" — epoch scale and calibration requirements

---

*Pitfalls research for: v5.0 Metrics Accuracy Algorithms*
*Researched: 2026-06-06*
