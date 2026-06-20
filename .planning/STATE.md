---
gsd_state_version: 1.0
milestone: v13.0
milestone_name: Bug Fixes, Protocol Reliability, Device Coverage & HealthKit Export
current_phase: 0
status: Awaiting next milestone
stopped_at: Phase 97 executed — all v13.0 phases complete
last_updated: "2026-06-20T21:34:53.313Z"
last_activity: 2026-06-20
last_activity_desc: Milestone v13.0 completed and archived
progress:
  total_phases: 6
  completed_phases: 6
  total_plans: 16
  completed_plans: 16
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-19)

**Core value:** The user captures WHOOP data on iPhone and it is automatically persisted on their personal server — without depending on external infrastructure. Metrics align with WHOOP from the same raw data.
**Current focus:** v13.0 — Phase 92 (Export & Auth Bug Fixes)

## Current Position

Phase: Milestone v13.0 complete
Plan: —
Status: Awaiting next milestone
Last activity: 2026-06-20 — Milestone v13.0 completed and archived

## Performance Metrics

**Velocity:**

- Total plans completed: 38 (v12.0 complete)
- Average duration: —
- Total execution time: —

**Recent Trend:**

- Last 5 plans: Phase 91 P02, Phase 91 P01, Phase 90 P04, Phase 90 P03, Phase 90 P02
- Trend: Stable

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- v13.0 roadmap: Phase 92 groups export OOM (#155) + auth stuck (#154) — both are Swift-only fixes with no Rust dependency; fastest to ship together
- v13.0 roadmap: Phase 93 groups HR data investigation (#156) + protocol.rs cleanup (#157) — protocol audit may reveal root cause of #156
- v13.0 roadmap: Phase 94 groups Gen4 metric parsing (#21) + packet47 reassembly (#20) — both touch Gen4 protocol paths in the same Rust files
- v13.0 roadmap: Phase 95 is WHOOP MG DeviceKind (SEED-006, #22) — isolated new variant; no dependency on other phases
- v13.0 roadmap: Phase 96 is best practices (SEED-007) — Swift silent try? + Rust connection pool; orthogonal to protocol work
- v13.0 roadmap: Phase 97 is HealthKit Export (#109) — depends on Phase 96 (bridge reliability); new HKHealthStore writes need error handling done right
- [Phase ?]: authExhausted added to BLETransport protocol (get set) for existential binding
- [Phase ?]: Used peripheral.name?.lowercased().contains(' mg') for MG detection (candidate_MG_advertisement_byte_unverified per D-03)
- [Phase ?]: Added onCapabilitiesUpdated callback to BLETransport protocol to propagate MG generation label from transport to GooseAppModel.bleState

### Roadmap Evolution

- v13.0 Phases 92–97 defined 2026-06-19: Export+auth fixes (92), HR+protocol (93), Gen4 completeness (94), WHOOP MG (95), best practices (96), HealthKit export (97)
- v12.0 Phases 83–91 defined 2026-06-14: Protocol refactor (83), Gen4 battery (84), Rust crash safety (85), bridge.rs split + protocol comments (86), store.rs split (87), Swift ownership (88), BLE actor (89), domain ViewModels (90), threading + algorithm comments (91)

### Pending Todos

- None

### Blockers/Concerns

- HAP-04 (Phase 73, wake-window): protocol-analysis-gated — do not write implementation tasks until BLE capture of `STRAP_DRIVEN_ALARM_EXECUTED` and protocol analysis of `SetAlarmInfoCommandPacketRev4` are complete
- Phase 66 (Cap Sense): hardware-gated — requires real WHOOP 5.x device; deferred indefinitely
- Hardware gate reminder: ALG-HRV-04, ALG-SLP-04, SLP-SYNC real-device remain deferred (hardware gate)
- WHOOP MG (Phase 95): MG advertisement byte layout not yet confirmed — needs research before planning

## Deferred Items

Items deferred from previous milestones:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| debug_session | ble-api-misuse-state-restore | awaiting_human_verify | v8.0 close |
| debug_session | rust-ci-linux-test-failures | investigating | v10.0 close |
| hardware_gate | Phase 51 — VAL-HRV-01, VAL-SLP-01, SLP-SYNC real-device | blocked | v7.0 close |
| hardware_gate | Phase 66 — CAPSENSE-01 on-wrist detection | blocked | v9.0 close |
| re_gate | Phase 73 — HAP-04 wake-window engine | re_required | v10.0 roadmap |
| verification_gap | Phase 22 — ALG-HRV-04 RMSSD parity (≥5 real sessions) | human_needed | v5.0 close |
| verification_gap | Phase 26 — ALG-SLP-04 4-class staging validation | human_needed | v5.0 close |
| uat_gap | Phase 73 — 73-UAT.md | partial | v10.0 close |
| verification_gap | Phase 68 — 68-VERIFICATION.md | human_needed | v10.0 close |
| verification_gap | Phase 70 — 70-VERIFICATION.md | human_needed | v10.0 close |
| quick_task | historical-sync-direct-write | missing | v10.0 close |
| quick_task | fix-imu-step-count | missing | v10.0 close |
| debug_session | export_tests-sensor_sample_rows-18_vs_19 | investigating | Phase 85 gate |
| Phase 92 P03 | 6m | 2 tasks | 5 files |
| Phase 92-export-auth-bug-fixes P02 | 5 min | 2 tasks | 3 files |
| Phase 95 P02 | 20 min | 2 tasks | 8 files |
| Phase 96 P01 | 6 min | 3 tasks | 6 files |

## Quick Tasks Completed

| Date | Slug | Description | Commit |
|------|------|-------------|--------|
| 2026-06-11 | ci-cleanup-add-dependabot | Remove rust-core-ci.yml (duplicate); add dependabot.yml + swift-build.yml | f629dd7 |
| 2026-06-13 | 260613-owu | Wrap HealthPreviewRouteHost in #if DEBUG to fix Release build CI on v10.0 tag | d6b7d1f |

## Session Continuity

Last session: 2026-06-20T16:24:59.861Z
Stopped at: Phase 97 executed — all v13.0 phases complete
Resume file: .planning/phases/97-healthkit-export-bevel-integration/97-VERIFICATION.md
Next action: /gsd-discuss-phase 92 or /gsd-plan-phase 92

## Operator Next Steps

- Start the next milestone with /gsd-new-milestone
