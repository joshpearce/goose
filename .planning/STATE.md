---
gsd_state_version: 1.0
milestone: v5.0
milestone_name: Metrics Accuracy, IMU & Upstream Fixes
status: executing
stopped_at: v4.0 shipped ✅ — v5.0 not yet started
last_updated: "2026-06-06T21:10:49.951Z"
last_activity: 2026-06-06 -- Phase 19 execution started
progress:
  total_phases: 9
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-04)

**Core value:** The user captures WHOOP data on iPhone and it is automatically persisted on their personal server — without depending on external infrastructure.
**Current focus:** Phase 19 — pt-pt-localisation-completion

## Current Position

Phase: 19 (pt-pt-localisation-completion) — EXECUTING
Plan: 1 of 1
Status: Ready to execute
Last activity: 2026-06-06 -- Phase 19 execution started

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 31 (v1.0 + v2.0 combined)
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 08.1 | 2 | — | — |
| 08 | 4 | — | — |
| 07 | 4 | — | — |
| 09 | 4 | - | - |
| 10 | 3 | - | - |
| 10.1 | 1 | - | - |
| 11 | 2 | - | - |
| 12 | 1 | - | - |
| 13 | 1 | - | - |
| 14 | 4 | - | - |
| 15 | 1 | - | - |
| 16 | 1 | - | - |
| 17 | 4 | ~62m | ~15m |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*

## Accumulated Context

### Roadmap Evolution

- Phase 15 added: Recovery Formula V2 (SDNN Accuracy) — rename variable, remove /1.2 population approximation, track SDNN baselines natively in goose_recovery_v0 (triggered by upstream review feedback OKKHALIL3, PR #5)

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- v3.0 Phase 9 first: FIX-01 (Rust-only, zero risk) unblocks HR capture testing; FIX-02+FIX-03 must be stable before HR scan UI ships
- v3.0 Phase 12 (RTC sync) and Phase 13 (Recovery V2) have no mutual dependency — parallelisable
- v3.0 Phase 14 (pt-PT) last: all v3.0 UI strings must be stable before localisation extraction
- Phase 14 Plan 01: Use String(localized:) instead of LocalizedStringKey for String-returning properties — preserves compatibility with String consumers (CoachTips, HealthScoreDateViews, HomeDashboardView)
- Phase 14 Plan 01: xcstrings keys use full English literal strings to match source code exactly
- Phase 14 Plan 03: Wave 3 added 328 entries (543 total); @Published status strings deferred to Wave 4
- Phase 17 Plan 02: @Bindable required on CalibrationHealthView when @Observable class property needs Picker binding; nonisolated(unsafe) on NSObjectProtocol observer enables deinit cleanup; lazy var incompatible with @Observable — convert to init-assigned var
- Phase 17 Plan 03: @Bindable local var in View.body is the correct pattern when an @Observable object is passed as plain var parameter and needs $ binding; three onChange modifiers replace MoreDataStore Combine MergeMany pipeline
- Phase 17 Plan 04: Wave 4 verification-only — global sweep passed with zero legacy wrappers; PERF-03 is a manual runtime check (launch app, connect WHOOP, start capture, confirm no NavigationRequestObserver warning in Xcode console)

### Pending Todos

- Open question: CR-02 Option A (JOIN path) vs Option B (denormalised column) — decide at Phase 9 planning
- Open question: HR scan UI placement — Health tab sheet vs. dedicated More tab entry — decide at Phase 10 planning
- Open question: Gen4 RTC command numbers (`.get = 11`, `.set = 10`) — confirm against physical device at Phase 12

### Blockers/Concerns

- RTC sync command numbers are inferred (LOW confidence) — needs device validation before Phase 12 ships
- `discoveredHRDevices` data race (BT queue vs. main thread) — RESOLVED by Phase 10.1 guards (Commands.swift + Parsing.swift)

## Deferred Items

Items acknowledged and deferred at v4.0 milestone close on 2026-06-06:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| verification_gap | Phase 09 — human BLE device tests | human_needed | v3.0 close |
| verification_gap | Phase 18 — Coach streaming tests (Claude, Custom, Gemini, provider switching) | human_needed | v4.0 close |
| verification_gap | Phase 19 — pt-PT simulator language switch + reinstall/onboarding | human_needed | v4.0 close |
| quick_task | 260603-tqd-add-test-and-import-actions-to-remote-se | missing | v2.0 close |
| todo | 2026-06-03-remote-server-test-and-import-actions | missing | v2.0 close |
| todo | bt-button-open-settings | low priority | v2.0 close |

Items carried forward from v3.0 milestone close (2026-06-05):

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| quick_task | 260603-rls-adicionar-codeql-no-git | missing | v2.0 close |
| quick_task | 260603-s5w-add-healthkitfullimporter-swift-to-goose | missing | v2.0 close |
| uat_gap | Phase 08 — hardware BLE tests | partial (no device) | v2.0 close |

## Session Continuity

Last session: 2026-06-06T15:30:00.000Z
Stopped at: v4.0 shipped ✅ — v5.0 not yet started
Next: /gsd-new-milestone to start v5.0
