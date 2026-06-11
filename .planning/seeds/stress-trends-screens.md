---
name: stress-trends-screens
description: Three SwiftUI screens with no algorithm work — Stress/ANS view (algo already in Rust), Long-range Trends dashboard, Manual Workout Entry sheet
metadata:
  type: seed
  trigger_condition: when planning v10.0 milestone scope
  planted_date: 2026-06-11
---

## Idea

Implement three SwiftUI screens that are **pure presentation** — the underlying algorithms and data already exist in the Goose Rust core. These are among the fastest paths to visible feature improvements.

## Screen 1 — Stress / ANS View (highest ROI)

**Algorithm already exists.** `goose_stress_v0` is implemented at `Rust/core/src/metrics.rs:2434` with the exact logistic z-score model:
```
z = 0.60 * zHRV - 0.20 * zRHR
score = 100 / (1 + exp(-1.6 * (z + 0.20)))
```

Only the SwiftUI screen is missing. Reference: `NoopApp/noop` — `Strand/Screens/StressView.swift` (30KB).

**UI elements to build:**
- 180° animated semicircular gauge (blue → mint → amber → red) showing today's score 0–100
- Daily trend area chart (14-day default, W/M/3M/6M/1Y/ALL selector)
- 14-day sparkline (same as recovery sparkline pattern in `HomeScoreViews.swift`)
- "Calm Time" stat: percentage of last 30 days scoring <40
- Two tiles: RHR with delta vs 30-day baseline; HRV with delta vs baseline
- "What drives this?" explainer card (static copy + dynamic driver from HRV/RHR z-scores)

Data source: `bridge.call("metrics.goose_stress_v0", args: {database_path, ...})` — same pattern as recovery/readiness calls in `HealthDataStore`.

**Effort: 2 days.** Zero algorithm work.

## Screen 2 — Long-range Trends Dashboard

Multi-range, multi-metric trend view. Reference: `Strand/Screens/TrendsView.swift` (17KB). Goose has `HealthDataStore+Trends.swift` and individual trend views per metric; what's missing is a unified dashboard.

**UI elements:**
- Hero Recovery area chart (fixed 0-100 scale, always at top)
- Small-multiples grid: HRV, RHR, Daily Strain — each with auto-padded ±12% span
- Per-card footer: mean / peak / low / active days in selected window
- Time windows anchored to **today's local date** (not latest record): W / M / 3M / 6M / 1Y / ALL
- Empty-window handling: auto-widen to next populated range + "sparse — widened to [range]" caption
- YearHeatStrip (seeded in `noop-feature-import.md`) — recovery heatmap at bottom

**Prerequisite:** `metricSeries` table (seeded in `journal-workout-datastore.md`) for clean per-key range queries.

**Effort: 3 days.**

## Screen 3 — Manual Workout Entry Sheet

Auto-detection by `PassiveActivityDetector` has false positives and false negatives. Users need a way to log missed workouts and correct detected ones. Reference: `Strand/Screens/ManualWorkoutSheet.swift` (9.6KB).

**Fields (5-field sheet, presented as a `.sheet`):**
- Sport (picker: Running, Cycling, Strength, HIIT, Swimming, Yoga, Other…)
- Start time (DatePicker, max: now)
- Duration (1–1440 minutes, Stepper)
- Avg HR (25–250 bpm, optional)
- Calories (0–20000 kcal, optional)

**Key patterns from NOOP:**
- `WorkoutSource.preservingCaptured`: when editing a strap-detected session, keep the real captured strain hidden — never overwrite real strain with a user estimate
- `saveManualWorkout(replacing: existingSession?)`: on sport/start change, delete old row by natural key before inserting new

Entry point: "Add workout" button in the Fitness/Activity tab; long-press on a detected session to "Edit".

**Prerequisite:** `workout` table (seeded in `journal-workout-datastore.md`).

**Effort: 1.5 days.**

## Implementation order

1. Stress view (self-contained, zero prerequisites)
2. Manual Workout Entry sheet (after `workout` table exists)
3. Trends dashboard (after `metricSeries` table exists, YearHeatStrip component)

## Files to create

- `GooseSwift/HealthStressViews.swift` — Stress/ANS screen (gauge, trend chart, tiles)
- `GooseSwift/FitnessManualWorkoutSheet.swift` — workout entry/edit sheet
- `GooseSwift/HealthTrendsDashboardView.swift` — long-range trends dashboard
- (update) `GooseSwift/HealthDataStore+StressEnergy.swift` — add `runStressV0()` if not present

## Related seeds

- `journal-workout-datastore.md` — `workout` + `metricSeries` tables are prerequisites
- `noop-feature-import.md` — YearHeatStrip component for Trends bottom section
