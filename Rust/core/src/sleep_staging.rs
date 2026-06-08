// Sleep staging: actigraphy spine using Cole-Kripke (1992) binary wake/sleep classifier.
// Reference: Cole, R.J. et al. "Automatic sleep/wake identification from wrist activity."
// Sleep 1992; 15(5): 461-469.
//
// This file is intentionally pure (no DB access). The bridge wrapper in bridge.rs
// calls gravity_rows_between and passes the tuples here.

use serde::{Deserialize, Serialize};

// ---------------------------------------------------------------------------
// Named constants — never inline these at call sites
// ---------------------------------------------------------------------------

/// Multiplicative scale factor applied to each activity count before the
/// Cole-Kripke weighted sum. Default 1.0 (uncalibrated). Adjust once real
/// WHOOP overnight staging data is available.
pub const COLE_KRIPKE_SCALE_FACTOR: f64 = 1.0;

/// Wake threshold: D >= 1.0 → wake epoch (Cole 1992).
pub const COLE_KRIPKE_WAKE_THRESHOLD: f64 = 1.0;

/// Duration of each actigraphy epoch in minutes.
pub const COLE_KRIPKE_EPOCH_MINUTES: f64 = 1.0;

/// Staging method emitted in every output that has at least one epoch.
pub const STAGING_METHOD_ACTIGRAPHY: &str = "actigraphy_uncalibrated";

/// Staging method emitted when the gravity window contained no rows.
pub const STAGING_METHOD_NO_IMU: &str = "no_imu_data";

// Cole-Kripke 7-term weighted coefficients (w[-4..+2]).
// D = (1/100) * sum_k(COEFFS[k+4] * scaled_count[epoch + offset_k])
// offsets: -4, -3, -2, -1, 0, +1, +2
const COLE_KRIPKE_COEFFS: [f64; 7] = [106.0, 54.0, 58.0, 76.0, 230.0, 74.0, 67.0];
const COLE_KRIPKE_OFFSETS: [i64; 7] = [-4, -3, -2, -1, 0, 1, 2];

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Input to the pure sleep-staging classifier.
/// `database_path` lives only in `SleepStagingBridgeArgs`; it is not needed
/// by the algorithm itself.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SleepStagingInput {
    pub device_id: String,
    pub sleep_start_ts: f64,
    pub sleep_end_ts: f64,
}

/// One classified 1-minute epoch.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SleepEpoch {
    /// Unix timestamp (seconds) of the epoch start.
    pub ts: f64,
    /// Inter-sample magnitude-difference activity count (unit-less).
    pub activity_count: f64,
    /// "wake" or "sleep" (binary spine; Plan 26-02 extends to 4 classes).
    pub stage: String,
}

/// Output of `stage_sleep`.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SleepStagingOutput {
    pub epochs: Vec<SleepEpoch>,
    /// Either `STAGING_METHOD_ACTIGRAPHY` or `STAGING_METHOD_NO_IMU`.
    pub staging_method: String,
    /// Fraction of epochs classified as wake (0.0 when no epochs).
    pub wake_fraction: f64,
    /// Total minutes classified as sleep.
    pub sleep_minutes: f64,
}

// ---------------------------------------------------------------------------
// Public entry point — pure, no DB access
// ---------------------------------------------------------------------------

/// Classify a sleep window into 1-minute wake/sleep epochs.
///
/// `rows` is a slice of (ts, x, y, z) tuples already fetched from the gravity
/// table ordered by ts ascending. Units: ts in seconds (Unix), x/y/z in g.
///
/// Returns a [`SleepStagingOutput`] with `staging_method = STAGING_METHOD_NO_IMU`
/// when `rows` is empty.
pub fn stage_sleep(input: &SleepStagingInput, rows: &[(f64, f64, f64, f64)]) -> SleepStagingOutput {
    if rows.is_empty() {
        return SleepStagingOutput {
            epochs: vec![],
            staging_method: STAGING_METHOD_NO_IMU.to_string(),
            wake_fraction: 0.0,
            sleep_minutes: 0.0,
        };
    }

    // Build activity counts per 1-minute epoch.
    let activity_counts = compute_activity_counts(input.sleep_start_ts, rows);

    if activity_counts.is_empty() {
        // Rows existed but all fell before sleep_start_ts or into a single
        // degenerate epoch with no consecutive pairs.
        return SleepStagingOutput {
            epochs: vec![],
            staging_method: STAGING_METHOD_ACTIGRAPHY.to_string(),
            wake_fraction: 0.0,
            sleep_minutes: 0.0,
        };
    }

    // Apply Cole-Kripke 7-term weighted classifier.
    let n = activity_counts.len();
    let mut epochs: Vec<SleepEpoch> = Vec::with_capacity(n);

    for i in 0..n {
        let d = cole_kripke_d_score(i, &activity_counts);
        let stage = if d >= COLE_KRIPKE_WAKE_THRESHOLD {
            "wake"
        } else {
            "sleep"
        };
        let (epoch_idx, _count) = activity_counts[i];
        let ts = input.sleep_start_ts + epoch_idx as f64 * (COLE_KRIPKE_EPOCH_MINUTES * 60.0);
        epochs.push(SleepEpoch {
            ts,
            activity_count: _count,
            stage: stage.to_string(),
        });
    }

    let total = epochs.len() as f64;
    let wake_count = epochs.iter().filter(|e| e.stage == "wake").count() as f64;
    let sleep_count = epochs.iter().filter(|e| e.stage == "sleep").count() as f64;

    SleepStagingOutput {
        epochs,
        staging_method: STAGING_METHOD_ACTIGRAPHY.to_string(),
        wake_fraction: if total > 0.0 { wake_count / total } else { 0.0 },
        sleep_minutes: sleep_count * COLE_KRIPKE_EPOCH_MINUTES,
    }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Bucket gravity rows into 1-minute epochs and compute per-epoch activity
/// counts as the sum of inter-sample magnitude differences.
///
/// Returns a sorted `Vec<(epoch_index, activity_count)>` where `epoch_index`
/// is floor((ts - sleep_start_ts) / 60).
fn compute_activity_counts(sleep_start_ts: f64, rows: &[(f64, f64, f64, f64)]) -> Vec<(i64, f64)> {
    use std::collections::BTreeMap;

    // (epoch_index) -> (prev_magnitude: Option<f64>, cumulative_count: f64)
    let mut epoch_state: BTreeMap<i64, (Option<f64>, f64)> = BTreeMap::new();

    for &(ts, x, y, z) in rows {
        let offset = ts - sleep_start_ts;
        let epoch_idx = (offset / (COLE_KRIPKE_EPOCH_MINUTES * 60.0)).floor() as i64;

        let mag = (x * x + y * y + z * z).sqrt();
        let entry = epoch_state.entry(epoch_idx).or_insert((None, 0.0));

        if let Some(prev_mag) = entry.0 {
            entry.1 += (mag - prev_mag).abs();
        }
        // Update prev_magnitude for this epoch.
        entry.0 = Some(mag);
    }

    epoch_state
        .into_iter()
        .map(|(idx, (_prev, count))| (idx, count))
        .collect()
}

/// Compute the Cole-Kripke D score for epoch `i`.
///
/// D = (1/100) * Σ_k ( COEFFS[k] * scaled_count(i + OFFSETS[k]) )
///
/// Out-of-range neighbours contribute 0.
fn cole_kripke_d_score(i: usize, activity_counts: &[(i64, f64)]) -> f64 {
    let n = activity_counts.len() as i64;
    let mut d = 0.0_f64;
    for (coeff, &offset) in COLE_KRIPKE_COEFFS.iter().zip(COLE_KRIPKE_OFFSETS.iter()) {
        let neighbour = i as i64 + offset;
        let c = if neighbour >= 0 && neighbour < n {
            COLE_KRIPKE_SCALE_FACTOR * activity_counts[neighbour as usize].1
        } else {
            0.0
        };
        d += coeff * c;
    }
    d / 100.0
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn make_input(sleep_start_ts: f64, sleep_end_ts: f64) -> SleepStagingInput {
        SleepStagingInput {
            device_id: "dev-test".to_string(),
            sleep_start_ts,
            sleep_end_ts,
        }
    }

    // T1: empty rows → no_imu_data, empty epochs, zeros
    #[test]
    fn empty_rows_yields_no_imu_data() {
        let input = make_input(0.0, 3600.0);
        let output = stage_sleep(&input, &[]);
        assert_eq!(output.staging_method, STAGING_METHOD_NO_IMU);
        assert!(output.epochs.is_empty(), "epochs must be empty");
        assert_eq!(output.sleep_minutes, 0.0);
        assert_eq!(output.wake_fraction, 0.0);
    }

    // T2: still epoch (constant g vector) yields activity_count ≈ 0.0
    #[test]
    fn still_epoch_activity_count_is_zero() {
        let start = 1_000_000.0_f64;
        // 10 samples at constant (0, 0, 1g) — all in epoch 0
        let rows: Vec<(f64, f64, f64, f64)> = (0..10)
            .map(|i| (start + i as f64, 0.0, 0.0, 1.0))
            .collect();
        let input = make_input(start, start + 600.0);
        let output = stage_sleep(&input, &rows);

        assert!(!output.epochs.is_empty(), "should have at least one epoch");
        for epoch in &output.epochs {
            assert!(
                epoch.activity_count.abs() < 1e-9,
                "still epoch must have near-zero count, got {}",
                epoch.activity_count
            );
        }
    }

    // T3: Cole-Kripke D score — high-motion epoch (all 7 window epochs very active) → wake;
    //     still epoch (all 7 window neighbours zero, single epoch) → sleep
    #[test]
    fn cole_kripke_classifies_wake_and_sleep() {
        let start = 0.0_f64;
        let epoch_secs = COLE_KRIPKE_EPOCH_MINUTES * 60.0;

        // Build 7 high-motion epochs (epoch indices 0..6).
        // Each needs D >= 1.0 for the centre epoch.
        // D = (1/100)*(106*c0 + 54*c1 + ... ) where all neighbours are active.
        // Use a magnitude change of 1.0 per sample to get activity_count >= 1 per epoch.
        // With SCALE_FACTOR=1.0 and all 7 neighbours = 1.0:
        // D = (1/100)*(106+54+58+76+230+74+67) = (1/100)*665 = 6.65 >= 1.0 → wake
        let mut rows: Vec<(f64, f64, f64, f64)> = Vec::new();
        for epoch in 0..7i64 {
            let t0 = start + epoch as f64 * epoch_secs;
            // Two samples per epoch: magnitude 0 then magnitude 1 → activity_count = 1.0
            rows.push((t0, 0.0, 0.0, 0.0));
            rows.push((t0 + 1.0, 1.0, 0.0, 0.0));
        }
        let end = start + 7.0 * epoch_secs;
        let input = make_input(start, end);
        let output = stage_sleep(&input, &rows);

        // Centre epoch (index 3) should be wake.
        let centre = &output.epochs[3];
        assert_eq!(
            centre.stage, "wake",
            "high-motion epoch must be wake, D should be >= 1.0"
        );

        // T3b: single still epoch with no high-motion neighbours → sleep
        let rows_still: Vec<(f64, f64, f64, f64)> = vec![(start, 0.0, 0.0, 1.0), (start + 1.0, 0.0, 0.0, 1.0)];
        let input_still = make_input(start, start + epoch_secs);
        let output_still = stage_sleep(&input_still, &rows_still);
        assert_eq!(output_still.epochs[0].stage, "sleep", "still epoch must be sleep");
    }

    // T4: edge handling — epochs near start/end do not panic
    #[test]
    fn edge_epochs_do_not_panic() {
        let start = 0.0_f64;
        let epoch_secs = COLE_KRIPKE_EPOCH_MINUTES * 60.0;
        // Only 2 epochs — indices 0 and 1 — to exercise window clamping
        let mut rows: Vec<(f64, f64, f64, f64)> = Vec::new();
        for epoch in 0..2i64 {
            let t0 = start + epoch as f64 * epoch_secs;
            rows.push((t0, 0.0, 0.0, 0.0));
            rows.push((t0 + 1.0, 1.0, 0.0, 0.0));
        }
        let input = make_input(start, start + 2.0 * epoch_secs);
        // Must not panic
        let output = stage_sleep(&input, &rows);
        assert_eq!(output.epochs.len(), 2);
    }

    // T5: non-empty rows → staging_method ALWAYS "actigraphy_uncalibrated"
    #[test]
    fn non_empty_rows_always_actigraphy_uncalibrated() {
        let start = 0.0_f64;
        let rows: Vec<(f64, f64, f64, f64)> = vec![(start, 0.0, 0.0, 1.0), (start + 1.0, 0.0, 0.0, 1.0)];
        let input = make_input(start, start + 3600.0);
        let output = stage_sleep(&input, &rows);
        assert_eq!(
            output.staging_method, STAGING_METHOD_ACTIGRAPHY,
            "non-empty rows must always emit actigraphy_uncalibrated"
        );
        assert_ne!(output.staging_method, STAGING_METHOD_NO_IMU);
    }

    // T6: wake_fraction and sleep_minutes are computed correctly
    #[test]
    fn wake_fraction_and_sleep_minutes_are_correct() {
        let start = 0.0_f64;
        let epoch_secs = COLE_KRIPKE_EPOCH_MINUTES * 60.0;

        // Build 7 high-motion epochs (all will be wake for centre; varies at edges).
        // For this test use 2 epochs:
        //   epoch 0: still → sleep
        //   epoch 1: high-motion — but only 1 of the 7-window slots (index 0) is non-zero
        //     D(epoch1) = (1/100)*(74*c2 + 67*c3) given offset table:
        //     epoch1's neighbours: index 1-4=-3 (OOB)=0, 1-3=-2 (OOB)=0, 1-2=-1(OOB)=0,
        //                          1-1=0=epoch0=still=0, 1+0=1, 1+1=2(OOB)=0, 1+2=3(OOB)=0
        //     D(epoch1) = (1/100)*(230*c1 + 74*0 + 67*0) = (1/100)*(230*1.0) = 2.3 → wake
        //     D(epoch0) = (1/100)*(230*c0 + 74*c1) = (1/100)*(230*0 + 74*1.0) = 0.74 → sleep
        // So: 1 wake, 1 sleep → wake_fraction=0.5, sleep_minutes=1.0
        let mut rows: Vec<(f64, f64, f64, f64)> = Vec::new();
        // epoch 0: still (0 activity)
        rows.push((start, 0.0, 0.0, 1.0));
        rows.push((start + 1.0, 0.0, 0.0, 1.0));
        // epoch 1: 1.0 activity
        let t1 = start + epoch_secs;
        rows.push((t1, 0.0, 0.0, 0.0));
        rows.push((t1 + 1.0, 1.0, 0.0, 0.0));

        let input = make_input(start, start + 2.0 * epoch_secs);
        let output = stage_sleep(&input, &rows);

        assert_eq!(output.epochs.len(), 2);
        let wake_count = output.epochs.iter().filter(|e| e.stage == "wake").count();
        let sleep_count = output.epochs.iter().filter(|e| e.stage == "sleep").count();
        // Verify fractions match counts
        assert_eq!(
            output.wake_fraction,
            wake_count as f64 / 2.0,
            "wake_fraction must equal wake_count/total"
        );
        assert_eq!(
            output.sleep_minutes,
            sleep_count as f64 * COLE_KRIPKE_EPOCH_MINUTES,
            "sleep_minutes must equal sleep_count * EPOCH_MINUTES"
        );
    }
}
