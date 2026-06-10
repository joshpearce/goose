# Goose Swift MVP: Home

Source map: Flutter `TodayView`, Flutter `GooseShell` Overview tab, Swift `AppShellView` Home tab, Swift `DeviceView`.

MVP rule: Home is the daily command center. It should show today's live state first, use real connected-device and local metric data when present, and fall back to empty, stale, or unavailable states where no Swift data bridge exists yet.

## Parent View Contract

- [x] Create a dedicated `HomeView.swift` or split `HomeDashboardView` out of `AppShellView.swift` — `HomeDashboardView.swift` is the dedicated view.
- [x] Keep this tab behind the Swift `Home` tab item.
- [x] Use `NavigationStack` routes for device, score detail, health monitor, timeline item, activity, and settings.
- [ ] Define a `HomeSnapshot` value type that can be populated from `GooseAppModel`, `GooseBLEClient`, and Rust/local store calls — not defined; the view uses `HealthMetricSnapshot` directly.
- [x] Add loading, empty, stale, and unavailable states per section; do not use sample data at runtime — snapshot system enforces this.
- [ ] Add previews for connected, disconnected, no-data, and populated real-data days.
- [x] Add accessibility labels for every tappable card and date/device control — device toolbar button has `accessibilityLabel` + `accessibilityValue`; score views have labels.

## Top Chrome And Date

- [x] Show selected date with previous/next day controls — `ScoreDateTitleButton` with `showingScoreDatePicker`.
- [x] Add date picker route/sheet equivalent to Flutter `TodayView._pickDate` — `ScoreDatePickerSheet`.
- [ ] Show busy/sync indicator when device or metric refresh is running.
- [x] Add device toolbar button with connected/disconnected color state — `deviceToolbarTint` green/red.
- [x] Tapping the device button opens `DeviceView`.
- [ ] Define one shared relative-time formatter for `lastSyncAt`, battery, HR, and metric refreshes — `HomeFormatting.swift` exists but the unified formatter is not implemented.

## Device Status Card

Not implemented as an inline section on `HomeDashboardView`. Device information is accessible via the toolbar button → `DeviceView`. The items below remain open:

- [ ] Show active device name from `ble.activeDeviceName`.
- [ ] Show connection state from `ble.connectionState`.
- [ ] Show reconnect state from `ble.reconnectState`.
- [ ] Show battery percent from `ble.batteryLevelPercent`.
- [ ] Show live HR from `ble.liveHeartRateBPM`.
- [ ] Show last sync from `ble.lastSyncAt`.
- [ ] Include quick action to scan/reconnect when disconnected.
- [ ] Keep copy live: no static "Connected" text unless BLE state says connected/ready.

## Today Score Stack

- [x] Add Sleep score card/gauge — `datedHomeSnapshot(for: .sleep)`.
- [x] Add Recovery score card/gauge — `datedHomeSnapshot(for: .recovery)`.
- [x] Add Strain score card/gauge — `datedHomeSnapshot(for: .strain)`.
- [ ] Preserve strain denominator semantics: Flutter normalizes strain from a 21-point scale to percent for some visuals.
- [x] Show HRV summary — included in `scoreSnapshots` passed to `HomeDailyScoreCard`.
- [x] Parse score values into numeric + status + provenance fields — `HealthMetricSnapshot` carries value, status, and provenance.
- [x] Tapping Sleep opens Health > Sleep detail — `openScore` / `openHealth` routing.
- [x] Tapping Recovery opens Health > Recovery detail.
- [x] Tapping Strain opens Health > Strain detail.
- [ ] Include provenance badges per metric family when a provenance summary function is available.

## Daily Outlook / Coach Teaser

- [x] Show readiness summary from `metricInputReadinessSummary()` — via `CoachTipFactory.homeTip`.
- [x] Show input next action from `metricInputReadinessNextActionSummary()`.
- [x] Show score next action from `packetDerivedScoreNextActionSummary()`.
- [x] Provide a clear route into Coach for the day's recommendation — `openCoach` callback.
- [x] Provide a clear route into Capture when the next action needs fresh data — `CoachTip` handles this.
- [x] Provide missing-data copy when readiness is missing or pending — tip system empty states.

## Stress And Energy

- [x] Show Stress summary from `todayStressScoreSummary()` — `landingSnapshot(for: .stress)`.
- [x] Link Stress card to Health > Stress detail — `openStress: { openHealth(.stress) }`.
- [x] Add Energy Bank card — `landingSnapshot(for: .energyBank)`.
- [ ] Track Energy Bank data points: energy level, stress value, total charged, total drained, primary sleep contribution, usage window.
- [x] Add unavailable chart state until Swift has the energy time-series bridge — snapshot system handles unavailable.
- [x] Show coaching copy only from computed/local data or explicit missing-data state.

## Health Monitor Preview

- [x] Show Latest HR from `latestHeartRateSummary()` or BLE live HR — in `cachedHealthMonitorSnapshots`.
- [x] Show HRV.
- [x] Show Recovery.
- [x] Show Stress.
- [x] Show Sleep.
- [x] Link card to Health > Health Monitor — `openSnapshot: openHealthMonitorSnapshot`.
- [x] Include preview/stale state if any child metric is missing — snapshot unavailable states.

## Daily Timeline

- [x] Add primary sleep row: start/end, duration, score/status — `HomeTimelineSection(sleep: homeSnapshot(for: .sleep))`.
- [x] Add activity/strain row: activity summary, strain, calories/energy where available.
- [x] Add recovery row: score, HRV, resting HR where available.
- [x] Preserve Flutter routes: sleep tap, activity tap, recovery tap — `openSleep`, `openActivity`, `openRecovery`.
- [x] Make timeline rows data-driven — `activities: model.homeActivityTimelineItems`.
- [x] Add empty timeline state for first-run devices — `activities.isEmpty` handled in `HomeTimelineViews.swift`.

## Tools Grid

Not implemented in `HomeDashboardView`.

- [ ] Add Sleep Coach shortcut to Coach/Sleep planning.
- [ ] Add Activity shortcut to Capture or activity entry flow.
- [ ] Add Journal shortcut to Coach/Journal prompt.
- [ ] Add Calibration shortcut to More/Algorithms or Health/Calibration.
- [ ] Surface each tool's readiness state, not just a static label.

## Evidence Footer

Not implemented in `HomeDashboardView`.

- [ ] Show Rust core version from `model.rustStatus`.
- [ ] Show local database/store path or "pending".
- [ ] Show mode: local data, live device, imported capture, or unavailable.
- [ ] Link to More > Debug when evidence/provenance is tapped.
- [ ] Include latest HR, sleep, recovery, and strain provenance when present.

## Parallel Agent Tasks

- [x] Agent Home-A: Extract `HomeDashboardView` into `HomeView.swift` and keep behavior unchanged — `HomeDashboardView.swift` is the dedicated view.
- [ ] Agent Home-B: Define `HomeSnapshot` and parse summary strings into typed display fields — not defined as a dedicated type.
- [x] Agent Home-C: Build the daily score stack and navigation to Health child pages.
- [x] Agent Home-D: Build Health Monitor preview and Daily Timeline.
- [ ] Agent Home-E: Build Tools grid and Evidence footer.
- [ ] Agent Home-F: Add previews and simulator screenshot checks for connected/disconnected/no-data states.

## Acceptance Checks

- [x] Home builds without touching Health/Coach/More internals.
- [x] Home can render with no device connected — unavailable snapshot states cover this.
- [x] Home updates live HR/battery/connection without relaunch — `onChange(of: model.ble.liveHeartRateBPM)`.
- [ ] Every card either links somewhere useful or is explicitly disabled with an empty-state reason — Tools Grid and Evidence Footer sections are missing.
- [ ] Simulator screenshots cover populated, disconnected, and no-data states.
