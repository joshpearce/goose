# Roadmap: Goose

## Milestones

- ✅ **v1.0 Remote Server + Upstream PRs** — Phases 1-5 (shipped 2026-06-03)
- ✅ **v2.0 Multi-Device & Platform Foundations** — Phases 6-8+8.1 (shipped 2026-06-04)
- ✅ **v3.0 Wearable UX, CI Hardening & RTC Sync** — Phases 9-15 (shipped 2026-06-05)
- ✅ **v4.0 Security, Performance & Coach Expansion** — Phases 16-19 (shipped 2026-06-06)
- ✅ **v5.0 Metrics Accuracy, IMU & Upstream Fixes** — Phases 20-35 (shipped 2026-06-08)
- ✅ **v6.0 UI Wiring, Algorithm Alignment & Parity Validation** — Phases 36-45 (shipped 2026-06-09)
- ✅ **v7.0 Sync Correctness, Async & Sleep Sync** — Phases 46-50 (shipped 2026-06-10)

## Phases

<details>
<summary>✅ v1.0 Remote Server + Upstream PRs (Phases 1-5) — SHIPPED 2026-06-03</summary>

Full details: `.planning/milestones/v1.0-ROADMAP.md`

</details>

<details>
<summary>✅ v2.0 Multi-Device & Platform Foundations (Phases 6-8+8.1) — SHIPPED 2026-06-04</summary>

Full details: `.planning/milestones/v2.0-ROADMAP.md`

Known deferred: WEAR-02 scan UI (v3.0), CR-02 per-row filter (v3.0), hardware BLE tests (no device)

</details>

<details>
<summary>✅ v3.0 Wearable UX, CI Hardening & RTC Sync (Phases 9-15) — SHIPPED 2026-06-05</summary>

Full details: `.planning/milestones/v3.0-ROADMAP.md`

</details>

<details>
<summary>✅ v4.0 Security, Performance & Coach Expansion (Phases 16-19) — SHIPPED 2026-06-06</summary>

Full details: `.planning/milestones/v4.0-ROADMAP.md`

Known deferred: COACH-06 device migration test, 4 streaming provider runtime tests, 3 localisation device tests

</details>

<details>
<summary>✅ v5.0 Metrics Accuracy, IMU & Upstream Fixes (Phases 20-35) — SHIPPED 2026-06-08</summary>

Full details: `.planning/milestones/v5.0-ROADMAP.md`

Key: HRV accuracy, Sleep staging (Cole-Kripke + 4-class), Strain/Calories (Ghidra-confirmed coefficients), V24 biometric decode, Exercise detection, Upload sync infrastructure, Readiness engine, Protocol corrections, Codebase audit (9 HIGH fixed), Cross-project review.

Known deferred: ALG-HRV-04, ALG-SLP-04, VAL-01 (human gates — require real WHOOP device data)

</details>

<details>
<summary>✅ v6.0 UI Wiring, Algorithm Alignment & Parity Validation (Phases 36-45) — SHIPPED 2026-06-09</summary>

Full details: `.planning/milestones/v6.0-ROADMAP.md`

Known deferred: ALG-HRV-04 real overnight cross-validation (v7.0), ALG-SLP-04 real overnight concordance (v7.0)

</details>

<details>
<summary>✅ v7.0 Sync Correctness, Async & Sleep Sync (Phases 46-50) — SHIPPED 2026-06-10</summary>

Full details: `.planning/milestones/v7.0-ROADMAP.md`

Key: Upload round-trip (POST /v1/ingest-frames + GET export), device_uuid end-to-end, upload sync race fix, HealthDataStore full async migration (60+ calls), morning band sleep sync (gravity K18/K24 → Cole-Kripke → external_sleep_sessions).

Known deferred: Phase 51 (VAL-HRV-01, VAL-SLP-01, SLP-SYNC real-device validation) — hardware gate, requires WHOOP + ≥5 overnight sessions

</details>

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1–45 | v1.0–v6.0 | — | Complete | 2026-06-03 to 2026-06-09 |
| 46–50 | v7.0 | 18/18 | Complete | 2026-06-10 |
| 51. Validation Gates (human) | v7.0 | 0/TBD | Blocked (human gate) | — |

## Backlog

### Phase 999.5: GooseAppModel @Observable Migration (promoted to Phase 17 — v4.0)

Promoted to Phase 17: @Observable Migration.

---

### Phase 999.4: Recovery V2 Completion (promoted to Phase 13 — v3.0)

Promoted to Phase 13: Recovery V2 Dashboard.

---

### Phase 999.3: Apply upstream PR #15 (promoted to Phase 16 — v4.0)

Promoted to Phase 16: Deep Link Security.

---

### Phase 999.2: Multi-Language Support (promoted to Phase 14 — v3.0)

Promoted to Phase 14: pt-PT Localisation.

---

### Phase 999.1: Coach Multi-Provider & Custom Endpoint (promoted to Phase 18 — v4.0)

Promoted to Phase 18: Coach Multi-Provider.

---

### Phase 999.6: body_hex Storage Optimization (absorbed into Phase 20 — v5.0)

Absorbed into Phase 20: Upstream Fixes & Storage (as PERF-05).

---

### Phase 999.7: Band Sleep Import

Primary sleep import directly from band packets — nightly sleep records persisted locally from BLE, not HealthKit fallback. UI explicitly shows `"band sleep import not available"` (`HealthDataStore+Sleep.swift`). Sleep stage timeline already works via bridge (`sleep_v1`); the missing piece is the band→SQLite ingestion path.

---

### Phase 999.8: SpO2 / Resp Rate / Wrist Temperature Packet Semantics

Recovery score currently falls back to `z_hrv`-only because `z_rhr`, SpO2, respiratory rate, and wrist temperature are absent or unresolved from band packets. Comment in `HealthDataStore+Recovery.swift:95` confirms the fabricated `55.0` baseline biases `z_rhr`. Requires resolving V24 packet field semantics for these three streams and wiring them into the recovery computation.

---

### Phase 999.9: Activity Masking for Stress

Non-activity stress is explicitly `.unavailable("non-activity stress requires HR samples and activity masks")` (`HealthDataStore+StaticSnapshots.swift:61`). Requires splitting stress windows by activity session boundaries so the non-activity stress trend is computed from non-exercise HR only.

---

### Phase 999.10: Energy Bank and Stress History Persistence

Daily stress windows and Energy Bank state are currently computed in memory only — no SQLite persistence. Long-range Energy Bank trends and charge/drain rate calibration against stored recovery, sleep, and activity history require persisted daily rows.

---

### Phase 999.11: Real Calibration Pipeline

`calibrationRunComplete` is a static boolean; `"4 train / 2 holdout | improved"` is a hardcoded string in `HealthDataStore+CoachSummaries.swift:728`. Holdout is explicitly `.unavailable("calibration holdout not computed")`. Requires implementing actual calibration runs with train/holdout splits from local metric history, and gating calibration outputs on a completed run.

---

### Phase 999.12: Runtime Surface Cleanup

`previewMissingData` is evaluated at runtime in `HealthDataStore+Snapshots.swift` and affects snapshot provenance strings. Debug preview-only strings must be removed or gated behind `#if DEBUG` before TestFlight builds. Verify no fabricated values surface to users.

---

### Phase 999.13: Home — Missing Surfaces

`HomeDashboardView` is missing three sections present in the Flutter original and the Home spec:

**Device Status Card** (inline on Home, not DeviceView): show active device name (`ble.activeDeviceName`), connection state, reconnect state, battery percent, live HR, last sync, and a scan/reconnect quick action when disconnected. Copy must be live — never static "Connected" text.

**Tools Grid**: Sleep Coach shortcut, Activity shortcut, Journal shortcut, Calibration shortcut. Each row should surface its readiness state from the underlying bridge.

**Evidence Footer**: Rust core version (`model.rustStatus`), local store path, data mode (local / live device / imported / unavailable), provenance summary for HR, sleep, recovery, strain. Tapping opens More > Debug.

**Supporting gaps**: `HomeSnapshot` value type is not defined — the view uses `HealthMetricSnapshot` directly. Strain denominator semantics (Flutter normalises from 21-point scale to percent) not preserved. Provenance badges per metric family not shown. Busy/sync indicator missing during device or metric refresh. Shared relative-time formatter (`HomeFormatting.swift` exists but the unified formatter is absent). Energy Bank specific data points (total charged, total drained, primary sleep contribution, usage window) not confirmed surfaced.

---

### Phase 999.14: Coach — Content Routes and Score Summaries

`CoachView.swift` implements Today Recommendation and Metric Highlights but has no dedicated child route views for the remaining Coach sections.

**Score summary functions missing** (block Metric Highlights completion): `todaySleepScoreSummary()`, `todayRecoveryScoreSummary()`, `todayStrainScoreSummary()`, `todayStressScoreSummary()` — none implemented in `HealthDataStore+CoachSummaries.swift`.

**Journal**: daily journal prompt from score/action summary; optional tags (stressors, training, sleep quality, symptoms, recovery blockers); text note entry; local persistence; last saved entry per date; expose to Sleep/Recovery insight surfaces.

**Sleep Coach route**: wind-down time, target bedtime, wake time, sleep need fulfillment/debt. `sleepV1ScheduleSummary()` and `sleepV1DebtSummary()` exist in `CoachSummaries` and are used in `CoachTips.swift` but not wired into a dedicated child view.

**Recovery Insights route**: recovery score/status, resting HRV, resting HR, respiratory rate/baseline, skin temp delta, missing vitals explicit, deterministic recommendation, links to Health > Recovery and Health > Calibration.

**Strain Guidance route**: strain score, target strain, exercise duration, daytime HR, total energy, step count, under/in/over-target guidance, link to Health > Strain.

**Stress Guidance route**: stress score, last HRV/HR, breakdown (High/Medium/Low), non-activity stress and sleep stress when available, link to Health > Stress.

**Data Gaps completion**: `unavailableHealthSyncMetricSummary()` exists in `MoreDataStore` but is not wired into `CoachView`. Capture requirement and one-action-per-gap routing incomplete.

**Resources**: deterministic native resource cards for Sleep, Recovery, Strain, Stress, Cardio Load — no marketing copy.

**Future Chat Boundary**: placeholder protocol for future chat messages; "Ask Coach" input disabled or routed to deterministic suggested questions until a backend, privacy policy, and persistence strategy exist.

---

### Phase 999.15: More — Remaining Gaps

**Capture imports**: import capture file, import command evidence file, import emulator log, and validated sample/read command actions are present as rows but marked disabled. Requires Swift bridge backing for each action.

**Health Sync**: editable backfill start/end fields not implemented. Existing Goose records count not surfaced.

**Raw Export**: editable fields for capture sessions, packet types, sensor signals, metric families, algorithm IDs, algorithm versions not confirmed. Named data family chip UI (`raw_evidence`, `decoded_frames`, `packet_timeline`, `metric_inputs`, `algorithm_runs`, `calibration_labels`, `calibration_runs`, `sqlite`) not confirmed — `selectedRawFamilies` exists. Recent capture sessions as shortcut rows not implemented. Bundle validation, zip validation, and sanitised privacy status rows absent.

**Debug**: frame parse status and payload not explicitly surfaced (only CRC and warnings shown). UI coverage status, deferred surfaces, property suite/perf budget rows, and command evidence import/gate sweep/capture plan absent.

**Privacy**: data deletion and export links not implemented.

---

### Phase 999.16: App-wide Previews and Simulator Screenshots

No SwiftUI `#Preview` blocks exist for `HomeDashboardView`, `CoachView` (beyond "Signed out"), or any `More*View`. Required states:

- **Home**: connected + populated, disconnected, no-data first-run
- **Coach**: no-data, capture-needed, populated
- **More**: default, connected device, debug-heavy

Each preview must be verified with a simulator screenshot via XcodeBuildMCP before TestFlight builds. `HealthPreviews.swift` exists for Health — same pattern needed for other tabs.

---

### Phase 999.17: Health — Algorithm Preference Properties

`algorithmPreferences` and `referenceAlgorithmDefinitions` properties are not yet implemented in `HealthDataStore` (referenced in `health.md` spec). The Algorithms section in Health cannot show primary algorithm selection or list reference definitions until these properties are wired from the bridge catalog.
