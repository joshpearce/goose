# Phase 129: Android Sleep & Health UI - Context

**Gathered:** 2026-06-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace the Android HealthScreen text stub with real Compose UI: SleepV2 bevel + 14-day trend (AND-UI-01) and HRV timeline + strain/recovery metric cards (AND-UI-02). All within the existing HealthScreen tab — no new nav tab. Uses Vico for charts, `metrics.daily_recovery_metrics` for 14-day history.

</domain>

<decisions>
## Implementation Decisions

### Charts Library
- **D-01:** Add Vico chart library (`com.patrykandpatrick.vico:compose` + `compose-m3`) to `android/app/build.gradle.kts`. Vico is Compose-native, supports LineChart and ColumnChart, integrates with Material3. Use `rememberChartEntryModelProducer()` + `Chart()` composable.

### Screen Layout
- **D-02:** Sleep section goes at the top of HealthScreen; Health metric cards (HRV, strain, recovery) below. Layout: `LazyColumn` with sections. No new tab — HealthScreen expands vertically.

### Data Source for 14-day Trends
- **D-03:** Use `metrics.daily_recovery_metrics` bridge method for 14-day sleep/HRV/recovery/strain history. Single bridge call returns array of daily entries. Parse JSON array for the last 14 nights.

### Sleep Bevel Layout (AND-UI-01)
- **D-04:** SleepV2 bevel = Card with:
  - Top row: sleep score % (large), duration (hh:mm), quality label
  - 14-day trend: Vico LineChart with sleep score per night (y-axis 0–100%)
  - Empty state: "No sleep data yet — wear your WHOOP overnight"

### Health Cards (AND-UI-02)
- **D-05:** HRV timeline: Card with HRV (rmssd) value + Vico LineChart for 14-day HRV trend
- **D-06:** Strain card: Card with strain score (0–21 scale) + colour-coded indicator
- **D-07:** Recovery card: Card with recovery % + colour indicator (red/yellow/green)
- **D-08:** Empty state for all cards: show "—" placeholder text, no crash

### Bridge Methods
- **D-09:** Primary: `metrics.daily_recovery_metrics` → returns last N days of daily metrics. Parse for sleep_score, hrv_rmssd, strain_score, recovery_score per day.
- **D-10:** Fallback for latest values: existing `queryScore()` calls in MetricsViewModel for single-day current values (already implemented).

### MetricsViewModel Extensions
- **D-11:** Add to MetricsViewModel: `val dailyHistory: StateFlow<List<DailyMetrics>>` — fetched via `metrics.daily_recovery_metrics` with `days: 14`. `DailyMetrics` data class: `date: String, sleepScore: Float?, hrvRmssd: Float?, strainScore: Float?, recoveryScore: Float?`.

### Claude's Discretion
- Exact Vico version (use latest stable from Context7/docs at plan time)
- Color scheme for charts (follow GooseTheme Material3 colorScheme)
- Card elevation and padding (follow existing Android UI conventions)
- Whether SleepScreen.kt or stays in HealthScreen.kt file (prefer keeping in HealthScreen.kt initially)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### iOS Reference (parity target)
- `GooseSwift/SleepV2BevelTrendViews.swift` (if exists) — iOS Sleep bevel layout to mirror
- `GooseSwift/HealthDashboardViews.swift` — iOS Health dashboard cards layout

### Android Files to Modify
- `android/app/src/main/kotlin/com/goose/app/ui/HealthScreen.kt` — primary screen to expand
- `android/app/src/main/kotlin/com/goose/app/viewmodel/MetricsViewModel.kt` — add dailyHistory StateFlow
- `android/app/build.gradle.kts` — add Vico dependency
- `android/gradle/libs.versions.toml` — add Vico version entry

### Bridge
- `Rust/core/src/bridge/mod.rs` — confirm `metrics.daily_recovery_metrics` method signature

### Requirements
- `.planning/REQUIREMENTS.md` — AND-UI-01, AND-UI-02

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `MetricsViewModel.queryScore()` already handles bridge call pattern + error logging — extend same pattern for `daily_recovery_metrics`
- `GooseTheme.kt` provides Material3 colorScheme — use for chart colors
- Compose Material3 BOM already in deps — use `Card`, `Text`, `LazyColumn` from material3

### Established Patterns
- Bridge calls always on `Dispatchers.IO` via `viewModelScope.launch(Dispatchers.IO)`
- StateFlows with null default until first bridge response
- Empty state with "—" placeholder (established in HealthScreen stub)
- `GooseBridge.safeHandle()` returns JSON; check `ok` field before parsing `result`

### Integration Points
- `AppViewModel` or `MetricsViewModel` feeds `HealthScreen` via StateFlows through `MainActivity` → `AppShell` → `HealthScreen`
- Phase 128 hardened this pipeline — all StateFlows now use `collectAsStateWithLifecycle()`

</code_context>

<specifics>
## Specific Ideas

- Vico `LineChart` for 14-day trends — x-axis = day index (0–13), y-axis = metric value
- Recovery card colour: green ≥ 67%, yellow ≥ 34%, red < 34% (matches iOS logic)
- Strain card colour: zones match iOS (blue/green/yellow/orange/red by strain value)
- Sleep score trend: simple line, no fill needed for MVP
- HRV timeline: show rmssd values, not SDNN (matches iOS HRV display)

</specifics>

<deferred>
## Deferred Ideas

- Separate Sleep tab (out of scope for Phase 129 — stays within HealthScreen)
- Sleep staging hypnogram (v17.0 scope)
- Interactive chart zoom/pan (deferred)
- Workout history cards (v17.0 or later)

</deferred>

---

*Phase: 129-Android Sleep & Health UI*
*Context gathered: 2026-06-28*
