# Roadmap: Goose

## Milestones

- ✅ **v1.0 Remote Server + Upstream PRs** — Phases 1-5 (shipped 2026-06-03)
- ✅ **v2.0 Multi-Device & Platform Foundations** — Phases 6-8+8.1 (shipped 2026-06-04)
- ✅ **v3.0 Wearable UX, CI Hardening & RTC Sync** — Phases 9-15 (shipped 2026-06-05)
- ✅ **v4.0 Security, Performance & Coach Expansion** — Phases 16-19 (shipped 2026-06-06)
- ✅ **v5.0 Metrics Accuracy, IMU & Upstream Fixes** — Phases 20-35 (shipped 2026-06-08)
- ✅ **v6.0 UI Wiring, Algorithm Alignment & Parity Validation** — Phases 36-45 (shipped 2026-06-09)
- ✅ **v7.0 Sync Correctness, Async & Sleep Sync** — Phases 46-50 (shipped 2026-06-10)
- 🚧 **v8.0 Quality, Completeness & Backlog Clearance** — Phases 51-59 (in progress)

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

### v8.0 Quality, Completeness & Backlog Clearance (In Progress)

**Milestone Goal:** Audit recent code for bugs, clear accumulated quick tasks, and complete all missing UI surfaces that accumulated in the backlog since v6.0.

- [ ] **Phase 51: Bug Audit** - Code review of v6.0–v7.0 (phases 36–50) to find and fix correctness bugs, data races, and edge cases
- [ ] **Phase 52: Quick Tasks & Surface Cleanup** - Bluetooth Settings shortcut, CodeQL CI, HealthKit importer, and debug-only preview gating
- [ ] **Phase 53: Home Dashboard Completion** - Device Status Card, Tools Grid, and Evidence Footer in HomeDashboardView
- [ ] **Phase 54: Coach Score Summaries & Journal** - Score summary functions for all four metrics and daily journal with local persistence
- [ ] **Phase 55: Coach Routes** - Dedicated child views for Sleep Coach, Recovery Insights, Strain Guidance, and Stress Guidance
- [ ] **Phase 56: Biometrics & Activity** - Real z_rhr from V24 packet data and activity-masked non-activity stress computation
- [ ] **Phase 57: Persistence & Calibration** - SQLite persistence for stress history/Energy Bank and a real train/holdout calibration pipeline
- [ ] **Phase 58: More Tab, Previews & Health Algorithms** - Complete More tab actions, app-wide SwiftUI previews, and algorithm preference properties
- [ ] **Phase 59: Band Sleep Import** - Direct sleep record ingestion from BLE band packets

## Phase Details

### Phase 51: Bug Audit
**Goal**: Known bugs and correctness issues from v6.0–v7.0 (phases 36–50) are identified, documented, and fixed
**Depends on**: Phase 50
**Requirements**: AUDIT-01
**Success Criteria** (what must be TRUE):
  1. Every phase 36–50 is reviewed and a written audit report lists findings by severity (HIGH / MEDIUM / LOW)
  2. All HIGH findings are fixed and verified before this phase closes
  3. No data race or crash-class finding remains open
  4. MEDIUM findings are either fixed or explicitly deferred with a rationale
**Plans**: TBD

### Phase 52: Quick Tasks & Surface Cleanup
**Goal**: Three long-deferred quick tasks ship and debug-only preview strings are removed from production builds
**Depends on**: Phase 51
**Requirements**: QT-01, QT-02, QT-03, SURF-01
**Success Criteria** (what must be TRUE):
  1. Tapping the BT button in the app opens iOS Bluetooth Settings directly
  2. A CodeQL workflow runs automatically on every PR and push via GitHub Actions and reports findings
  3. The user can trigger a HealthKit full import from the app and data appears in local storage
  4. A production build contains no fabricated preview values visible to the user (previewMissingData is #if DEBUG-gated)
**Plans**: TBD
**UI hint**: yes

### Phase 53: Home Dashboard Completion
**Goal**: HomeDashboardView shows a complete live Device Status Card, a Tools Grid of shortcuts, and an Evidence Footer
**Depends on**: Phase 52
**Requirements**: HOME-01, HOME-02, HOME-03
**Success Criteria** (what must be TRUE):
  1. The Home tab shows a Device Status Card with live device name, connection state, battery percent, current HR, last sync time, and a reconnect action when disconnected — never static text
  2. The Home tab shows a Tools Grid with shortcuts to Sleep Coach, Activity, Journal, and Calibration, each reflecting its bridge readiness state
  3. The Home tab shows an Evidence Footer with Rust core version, local store path, data mode, and provenance per metric family — tapping opens More > Debug
**Plans**: TBD
**UI hint**: yes

### Phase 54: Coach Score Summaries & Journal
**Goal**: Coach tab shows score summaries for all four metrics and users can write and persist a daily journal entry
**Depends on**: Phase 53
**Requirements**: COACH-07, COACH-08
**Success Criteria** (what must be TRUE):
  1. The Coach tab displays score summaries for sleep, recovery, strain, and stress — each populated from live bridge data
  2. The user can open a daily journal entry, write a text note, add optional tags, and save it — the entry persists across app restarts
  3. The most recent journal entry for a given date is recoverable after relaunching the app
**Plans**: TBD
**UI hint**: yes

### Phase 55: Coach Routes
**Goal**: Coach tab has four dedicated child route views — Sleep Coach, Recovery Insights, Strain Guidance, and Stress Guidance — each populated from bridge data
**Depends on**: Phase 54
**Requirements**: COACH-09, COACH-10, COACH-11, COACH-12
**Success Criteria** (what must be TRUE):
  1. Sleep Coach route shows wind-down time, target bedtime, wake time, and sleep debt/fulfillment from local data
  2. Recovery Insights route shows recovery score, HRV, RHR, respiratory rate, skin temp delta, and a deterministic recommendation
  3. Strain Guidance route shows strain score, target strain, exercise duration, daytime HR, and under/in/over-target guidance
  4. Stress Guidance route shows stress score, last HRV/HR, breakdown by level, and non-activity stress when available
**Plans**: TBD
**UI hint**: yes

### Phase 56: Biometrics & Activity
**Goal**: Recovery score uses real resting HR derived from V24 packet data, and non-activity stress only uses HR samples outside detected exercise sessions
**Depends on**: Phase 51
**Requirements**: BIO-05, ACT-01
**Success Criteria** (what must be TRUE):
  1. The recovery score computation uses z_rhr calculated from real SpO2/resp/wrist-temp V24 packet data — the fabricated 55.0 bpm baseline is removed
  2. Non-activity stress is computed and displayed (no longer shows "non-activity stress requires HR samples and activity masks")
  3. Stress windows exclude HR samples that fall within detected exercise session boundaries
**Plans**: TBD

### Phase 57: Persistence & Calibration
**Goal**: Daily stress history and Energy Bank state are persisted in SQLite, and the calibration pipeline runs real train/holdout splits from local metric history
**Depends on**: Phase 56
**Requirements**: ENB-01, CAL-01
**Success Criteria** (what must be TRUE):
  1. Daily stress windows and Energy Bank state are written to SQLite and survive app restarts — long-range trend data is available after multiple days
  2. The calibration pipeline runs against local historical metrics, producing real train/holdout split results
  3. Calibration output values are derived from actual data — the hardcoded "4 train / 2 holdout | improved" string is removed
  4. Calibration results are gated on a completed run; no results are shown if calibration has not run
**Plans**: TBD

### Phase 58: More Tab, Previews & Health Algorithms
**Goal**: More tab actions are fully backed by Swift bridge, SwiftUI previews exist for Home/Coach/More with simulator screenshots, and algorithm preference properties are wired in HealthDataStore
**Depends on**: Phase 55
**Requirements**: MORE-01, PREV-01, HALG-01
**Success Criteria** (what must be TRUE):
  1. More tab capture import, backfill, raw export, and privacy actions are enabled and functional
  2. SwiftUI previews exist for HomeDashboardView, CoachView, and More views covering connected/populated, disconnected, and no-data states — each verified with a simulator screenshot
  3. HealthDataStore exposes algorithmPreferences and referenceAlgorithmDefinitions properties wired to the bridge catalog — the Health > Algorithms section can display primary algorithm selection and reference definitions
**Plans**: TBD
**UI hint**: yes

### Phase 59: Band Sleep Import
**Goal**: Sleep records are ingested directly from BLE band packets — the "band sleep import not available" message is gone and real sleep data appears
**Depends on**: Phase 57
**Requirements**: BAND-01
**Success Criteria** (what must be TRUE):
  1. After a BLE connection, sleep records from band packets are persisted locally via the band sleep import path
  2. The Sleep tab no longer shows "band sleep import not available" when band data is present
  3. Sleep data imported via band packets is consistent with data imported via the server path for the same session
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1–45 | v1.0–v6.0 | — | Complete | 2026-06-03 to 2026-06-09 |
| 46–50 | v7.0 | 18/18 | Complete | 2026-06-10 |
| 51. Bug Audit | v8.0 | 0/TBD | Not started | - |
| 52. Quick Tasks & Surface Cleanup | v8.0 | 0/TBD | Not started | - |
| 53. Home Dashboard Completion | v8.0 | 0/TBD | Not started | - |
| 54. Coach Score Summaries & Journal | v8.0 | 0/TBD | Not started | - |
| 55. Coach Routes | v8.0 | 0/TBD | Not started | - |
| 56. Biometrics & Activity | v8.0 | 0/TBD | Not started | - |
| 57. Persistence & Calibration | v8.0 | 0/TBD | Not started | - |
| 58. More Tab, Previews & Health Algorithms | v8.0 | 0/TBD | Not started | - |
| 59. Band Sleep Import | v8.0 | 0/TBD | Not started | - |

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
