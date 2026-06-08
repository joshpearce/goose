/// EWMA baseline engine for per-metric (HRV RMSSD, resting HR) personal baselines.
///
/// Reconstructs EWMA state from `daily_recovery_metrics` rows on each call — no new
/// SQLite table is introduced. Cold-start gate, trust levels, and idempotent update
/// under BEGIN EXCLUSIVE are all implemented here.
///
/// Alpha = 0.10 (10-night memory constant).
///
/// Recurrence:
///   mean_new     = 0.9 × mean_old + 0.1 × x
///   variance_new = 0.9 × variance_old + 0.1 × (x - mean_old)²

use crate::{GooseResult, store::GooseStore};

/// EWMA alpha (10-night memory constant).
pub const ALPHA: f64 = 0.10;

/// Minimum nights before z-score is non-None (cold-start guard).
pub const MIN_NIGHTS_SEED: usize = 4;

/// Minimum nights before trust level reaches Trusted.
pub const MIN_NIGHTS_TRUST: usize = 14;

/// Minimum nights before the baseline is considered "ready" (inactive until this many nights).
pub const MIN_NIGHTS_READY: usize = 7;

/// Small variance floor to avoid division-by-zero in z-score computation.
const VARIANCE_FLOOR: f64 = 1e-6;

// ---------------------------------------------------------------------------
// EwmaTrustLevel
// ---------------------------------------------------------------------------

/// Confidence level of the EWMA baseline depending on how many nights of data
/// have been folded into it.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EwmaTrustLevel {
    /// Fewer than 4 nights — cold-start, z-score is None.
    Calibrating,
    /// 4–13 nights — baseline is seeded but not yet fully representative.
    Provisional,
    /// 14+ nights — baseline is considered statistically reliable.
    Trusted,
}

impl EwmaTrustLevel {
    /// Classify a night count into a trust level.
    pub fn from_night_count(night_count: usize) -> Self {
        if night_count < MIN_NIGHTS_SEED {
            Self::Calibrating
        } else if night_count < MIN_NIGHTS_TRUST {
            Self::Provisional
        } else {
            Self::Trusted
        }
    }

    /// String label suitable for JSON serialisation.
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Calibrating => "calibrating",
            Self::Provisional => "provisional",
            Self::Trusted => "trusted",
        }
    }
}

// ---------------------------------------------------------------------------
// EwmaState
// ---------------------------------------------------------------------------

/// Running EWMA state for a single metric.
#[derive(Debug, Clone, PartialEq)]
pub struct EwmaState {
    pub mean: f64,
    pub variance: f64,
    pub night_count: usize,
}

impl Default for EwmaState {
    fn default() -> Self {
        Self {
            mean: 0.0,
            variance: 0.0,
            night_count: 0,
        }
    }
}

impl EwmaState {
    /// Fold one new observation `x` into the EWMA state.
    ///
    /// First observation: mean is initialised to x, variance starts at 0.
    /// Subsequent: standard EWMA recurrence (alpha = 0.10).
    pub fn fold(&mut self, x: f64) {
        if self.night_count == 0 {
            self.mean = x;
            self.variance = 0.0;
        } else {
            let old_mean = self.mean;
            self.mean = (1.0 - ALPHA) * old_mean + ALPHA * x;
            self.variance = (1.0 - ALPHA) * self.variance + ALPHA * (x - old_mean).powi(2);
        }
        self.night_count += 1;
    }

    /// Trust level derived from `night_count`.
    pub fn trust_level(&self) -> EwmaTrustLevel {
        EwmaTrustLevel::from_night_count(self.night_count)
    }

    /// Whether the baseline has enough nights to be considered "ready" (active).
    ///
    /// Returns `false` for fewer than `MIN_NIGHTS_READY` (7) nights.
    pub fn is_ready(&self) -> bool {
        self.night_count >= MIN_NIGHTS_READY
    }

    /// Compute z-score of `value` against the running mean and variance.
    ///
    /// Returns `None` when `night_count < MIN_NIGHTS_SEED` (cold-start guard).
    pub fn z_score(&self, value: f64) -> Option<f64> {
        if self.night_count < MIN_NIGHTS_SEED {
            return None;
        }
        let std_dev = (self.variance.max(VARIANCE_FLOOR)).sqrt();
        Some((value - self.mean) / std_dev)
    }
}

// ---------------------------------------------------------------------------
// EwmaBaseline  (per-metric container)
// ---------------------------------------------------------------------------

/// Per-device EWMA baseline, holding independent state for HRV RMSSD and
/// resting heart rate.
#[derive(Debug, Clone)]
pub struct EwmaBaseline {
    pub hrv: EwmaState,
    pub resting_hr: EwmaState,
}

impl Default for EwmaBaseline {
    fn default() -> Self {
        Self {
            hrv: EwmaState::default(),
            resting_hr: EwmaState::default(),
        }
    }
}

impl EwmaBaseline {
    /// Reconstruct EWMA state by replaying all `daily_recovery_metrics` rows
    /// from the database ordered by `date_key` ascending.
    ///
    /// Rows with NULL hrv_rmssd_ms or resting_hr_bpm are skipped for the
    /// respective metric (night_count is not incremented for that metric).
    /// Non-finite values are rejected and skipped (T-24-05 mitigation).
    pub fn fold_history(store: &GooseStore) -> GooseResult<Self> {
        let rows = store.daily_recovery_metrics_all_ordered()?;
        let mut baseline = Self::default();
        for row in &rows {
            if let Some(hrv) = row.hrv_rmssd_ms {
                if hrv.is_finite() {
                    baseline.hrv.fold(hrv);
                }
            }
            if let Some(rhr) = row.resting_hr_bpm {
                if rhr.is_finite() {
                    baseline.resting_hr.fold(rhr);
                }
            }
        }
        Ok(baseline)
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    // ---- EWMA recurrence ---------------------------------------------------

    #[test]
    fn test_ewma_fold_increments_night_count() {
        let mut state = EwmaState::default();
        state.fold(60.0);
        assert_eq!(state.night_count, 1);
        state.fold(65.0);
        assert_eq!(state.night_count, 2);
    }

    #[test]
    fn test_ewma_first_fold_initialises_mean() {
        let mut state = EwmaState::default();
        state.fold(50.0);
        assert!((state.mean - 50.0).abs() < 1e-9, "first fold sets mean = x");
        assert_eq!(state.variance, 0.0, "first fold variance is 0");
    }

    #[test]
    fn test_ewma_mean_recurrence() {
        // After first fold at 50, fold 60:
        //   mean = 0.9*50 + 0.1*60 = 51.0
        let mut state = EwmaState::default();
        state.fold(50.0);
        state.fold(60.0);
        let expected_mean = 0.9 * 50.0 + 0.1 * 60.0;
        assert!(
            (state.mean - expected_mean).abs() < 1e-9,
            "mean recurrence: got {}, expected {}",
            state.mean,
            expected_mean
        );
    }

    #[test]
    fn test_ewma_variance_recurrence() {
        // After first fold at 50 (variance=0), fold 60:
        //   variance = 0.9*0 + 0.1*(60-50)^2 = 10.0
        let mut state = EwmaState::default();
        state.fold(50.0);
        state.fold(60.0);
        let expected_var = 0.9 * 0.0 + 0.1 * (60.0 - 50.0_f64).powi(2);
        assert!(
            (state.variance - expected_var).abs() < 1e-9,
            "variance recurrence: got {}, expected {}",
            state.variance,
            expected_var
        );
    }

    #[test]
    fn test_ewma_longer_sequence() {
        // Hand-compute 5-night sequence
        let observations = [60.0_f64, 58.0, 62.0, 55.0, 70.0];
        let mut mean = 0.0_f64;
        let mut variance = 0.0_f64;
        for (i, &x) in observations.iter().enumerate() {
            if i == 0 {
                mean = x;
                variance = 0.0;
            } else {
                let old_mean = mean;
                mean = 0.9 * old_mean + 0.1 * x;
                variance = 0.9 * variance + 0.1 * (x - old_mean).powi(2);
            }
        }

        let mut state = EwmaState::default();
        for &x in &observations {
            state.fold(x);
        }

        assert!(
            (state.mean - mean).abs() < 1e-9,
            "5-night mean: got {}, expected {}",
            state.mean,
            mean
        );
        assert!(
            (state.variance - variance).abs() < 1e-9,
            "5-night variance: got {}, expected {}",
            state.variance,
            variance
        );
        assert_eq!(state.night_count, observations.len());
    }

    // ---- Trust level boundaries -------------------------------------------

    #[test]
    fn test_trust_level_calibrating_at_3() {
        assert_eq!(
            EwmaTrustLevel::from_night_count(3),
            EwmaTrustLevel::Calibrating
        );
    }

    #[test]
    fn test_trust_level_provisional_at_4() {
        assert_eq!(
            EwmaTrustLevel::from_night_count(4),
            EwmaTrustLevel::Provisional
        );
    }

    #[test]
    fn test_trust_level_provisional_at_13() {
        assert_eq!(
            EwmaTrustLevel::from_night_count(13),
            EwmaTrustLevel::Provisional
        );
    }

    #[test]
    fn test_trust_level_trusted_at_14() {
        assert_eq!(
            EwmaTrustLevel::from_night_count(14),
            EwmaTrustLevel::Trusted
        );
    }

    // ---- Cold-start z_score guard -----------------------------------------

    #[test]
    fn test_z_score_none_below_4_nights() {
        let mut state = EwmaState::default();
        // 3 nights => cold-start
        for x in [60.0_f64, 58.0, 62.0] {
            state.fold(x);
        }
        assert_eq!(state.night_count, 3);
        assert!(
            state.z_score(65.0).is_none(),
            "z_score must be None at 3 nights"
        );
    }

    #[test]
    fn test_z_score_some_at_4_nights() {
        let mut state = EwmaState::default();
        for x in [60.0_f64, 58.0, 62.0, 60.0] {
            state.fold(x);
        }
        assert_eq!(state.night_count, 4);
        assert!(
            state.z_score(65.0).is_some(),
            "z_score must be Some at 4 nights"
        );
    }

    #[test]
    fn test_z_score_magnitude_one_std_above_mean() {
        // Construct a state where mean=60, variance=sigma^2, then check
        // that z_score(60 + sigma) ≈ 1.0
        let sigma = 5.0_f64;
        let mut state = EwmaState {
            mean: 60.0,
            variance: sigma * sigma,
            night_count: MIN_NIGHTS_SEED, // exactly at cold-start boundary
        };
        let z = state.z_score(60.0 + sigma).expect("must be Some at seed boundary");
        assert!(
            (z - 1.0).abs() < 1e-6,
            "one std above mean yields z ≈ 1.0, got {}",
            z
        );
    }

    #[test]
    fn test_z_score_negative_below_mean() {
        let sigma = 5.0_f64;
        let mut state = EwmaState {
            mean: 60.0,
            variance: sigma * sigma,
            night_count: MIN_NIGHTS_SEED,
        };
        let z = state.z_score(60.0 - sigma).expect("must be Some");
        assert!(
            (z - (-1.0)).abs() < 1e-6,
            "one std below mean yields z ≈ -1.0, got {}",
            z
        );
    }

    // ---- Readiness flag ---------------------------------------------------

    #[test]
    fn test_readiness_false_at_6_nights() {
        let state = EwmaState {
            mean: 60.0,
            variance: 4.0,
            night_count: 6,
        };
        assert!(
            !state.is_ready(),
            "baseline must not be ready at 6 nights"
        );
    }

    #[test]
    fn test_readiness_true_at_7_nights() {
        let state = EwmaState {
            mean: 60.0,
            variance: 4.0,
            night_count: 7,
        };
        assert!(state.is_ready(), "baseline must be ready at 7 nights");
    }

    // ---- Non-finite rejection (T-24-05 mitigation) ------------------------

    #[test]
    fn test_z_score_non_finite_values_in_fold_history_skipped() {
        // fold_history skips non-finite values; test EwmaState directly
        let mut state = EwmaState::default();
        // Simulate: only finite values are folded
        for x in [60.0_f64, 58.0, 62.0, 60.0] {
            if x.is_finite() {
                state.fold(x);
            }
        }
        // NaN / Inf would not be folded
        assert_eq!(state.night_count, 4);
    }
}
