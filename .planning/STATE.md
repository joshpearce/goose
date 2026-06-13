---
gsd_state_version: 1.0
milestone: v11.0
milestone_name: PR Integration, Code Health & App Polish
status: planning
last_updated: "2026-06-13T16:55:43.575Z"
last_activity: 2026-06-13
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-11)

**Core value:** The user captures WHOOP data on iPhone and it is automatically persisted on their personal server — without depending on external infrastructure. Metrics align with WHOOP from the same raw data.
**Current focus:** Phase 73 — Smart Alarm + Wake-Window Engine

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-06-13 — Completed quick task 260613-owu: wrap HealthPreviewRouteHost in #if DEBUG to fix Release CI

## Performance Metrics

**Velocity:**

- Total plans completed: 33 (v1.0–v7.0 combined)
- Average duration: —
- Total execution time: —

**Recent Trend:**

- Last 5 plans: Phase 65 P01, Phase 64 P02, Phase 64 P01, Phase 63 P02, Phase 63 P01
- Trend: Stable

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- v10.0 roadmap: Phase 67 is first because it has zero dependencies and fixes WHOOP 5.0 users who currently see no realtime metrics
- v10.0 roadmap: HAP-04 (wake-window) kept in Phase 73 alongside HAP-03 but explicitly RE-gated — implementation must not begin until BTSnoop + Ghidra sessions complete
- v10.0 roadmap: ARCH-01 (service layer) assigned to Phase 72 so GooseBLEHistoricalManager (Phase 68) exists to exercise the protocols at test-writing time
- v10.0 roadmap: DATA-04 (HR decimation) grouped with Phase 71 (FEAT cluster) rather than Phase 69 (data foundation) — no schema dependency; it is a read-path optimisation
- v10.0 roadmap: DATA-03 (Stress/Trends/Manual Workout screens) assigned to Phase 72 which depends on Phase 69 (tables must exist before screens read them)
- Phase 65 Plan 01: StateMachine<State: Hashable, Event> struct; GooseBLEBondingState promoted from Equatable to Hashable; transition(to:) total + maps to GooseBLEBondingEvent before machine.handle()
- Phase 64 Plan 01: GooseHRSanitizer static value type; WHOOP parity range 25-220 BPM; onHRSpike callback (not Combine); hrSpikeCount on @MainActor via Task hop
- Phase 62 Plan 02: effectiveSince gate inside service (not call site); watermark writes on 2xx only per type; clearAllUploadWatermarks resets both keys + lastUploadAt
- Phase 62 Plan 01: WatermarkType enum with rawFrames/decodedStreams cases; separate UserDefaults keys per type; Foundation-only store
- Phase 61 Plan 02: Non-bonding error strings remain direct updateConnectionState calls; .notStarted on every disconnect; bondingState computed on GooseAppModel (no @Published)
- Phase 61 Plan 01: GooseBLEBondingManager is plain final class with callback (not @Observable); UserDefaults keys owned by manager type; .cancelled persists as notStarted (Pitfall 5)
- [Phase ?]: Callback pattern (not Combine) for GooseNetworkMonitor.onReachabilityChange — consistent with GooseBLEBondingManager
- [Phase ?]: isReachable initialised to true to avoid false upload block before first async NWPath update
- [Phase ?]: Upload exponential backoff capped at 60s per delay, 7 total attempts, prevents battery drain on persistent 5xx

### Roadmap Evolution

- v10.0 Phases 67–73 defined 2026-06-12: Protocol parity (Rust-only), BLE refactor + validator, data foundation, haptic primitive + Breathe, coaching/notifications/decimation cluster, screens + service layer, smart alarm + RE-gated wake-window
- Phase 66 added (v9.0): Cap Sense / On-Wrist Detection — DEFERRED hardware gate (CAPSENSE-01)
- Phase 60 added: Band-First Sync — align Goose BLE sync architecture with WHOOP app (foreground trigger + BGAppRefreshTask)

### Pending Todos

- None — Phase 67 is the first v10.0 plan to write

### Blockers/Concerns

- HAP-04 (Phase 73, wake-window): RE-gated — do not write implementation tasks until BTSnoop capture of `STRAP_DRIVEN_ALARM_EXECUTED` and Ghidra decompile of `SetAlarmInfoCommandPacketRev4` are complete
- Phase 66 (Cap Sense): hardware-gated — requires real WHOOP 5.x device; deferred indefinitely
- Hardware gate reminder: ALG-HRV-04, ALG-SLP-04, SLP-SYNC real-device remain deferred (hardware gate)

## Deferred Items

Items deferred from previous milestones:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| debug_session | ble-api-misuse-state-restore | awaiting_human_verify | v8.0 close |
| hardware_gate | Phase 51 — VAL-HRV-01, VAL-SLP-01, SLP-SYNC real-device | blocked | v7.0 close |
| hardware_gate | Phase 66 — CAPSENSE-01 on-wrist detection | blocked | v9.0 close |
| re_gate | Phase 73 — HAP-04 wake-window engine | re_required | v10.0 roadmap |
| verification_gap | Phase 22 — ALG-HRV-04 RMSSD parity (≥5 real sessions) | human_needed | v5.0 close |
| verification_gap | Phase 26 — ALG-SLP-04 4-class staging validation | human_needed | v5.0 close |
| Phase 71-coach-vow-noopapp-notifications-hr-decimation P02 | 5 min | 2 tasks | 4 files |
| Phase 71-coach-vow-noopapp-notifications-hr-decimation P04 | 9min | 2 tasks | 6 files |
| Phase 72 P02 | 17 min | 2 tasks | 10 files |
| Phase 73 P01 | 5 min | 2 tasks | 3 files |

Items acknowledged and deferred at v10.0 milestone close on 2026-06-13:

| Category | Item | Status |
|----------|------|--------|
| debug_session | ble-api-misuse-state-restore | awaiting_human_verify |
| debug_session | rust-ci-linux-test-failures | investigating |
| uat_gap | Phase 73 — 73-UAT.md | partial |
| verification_gap | Phase 68 — 68-VERIFICATION.md | human_needed |
| verification_gap | Phase 70 — 70-VERIFICATION.md | human_needed |
| quick_task | historical-sync-direct-write | missing |
| quick_task | fix-imu-step-count | missing |
| seed | SEED-001-ble-auth-retry-insufficientAuthentication | dormant |
| requirement | BLE5-01 — WHOOP 5.0 realtime metrics (R22 type 0x10) | hardware_needed |
| requirement | BLE5-02 — WHOOP 5.0 historical import without duplicates | hardware_needed |
| requirement | HAP-02 — Breathe screen with paced haptic feedback | deferred |
| requirement | HAP-04 — Wake-window engine | re_gated |
| requirement | FEAT-01 — Coach VOW nudges | partial |
| requirement | FEAT-02 — Breathe UI + Interval Timer + Metric Explorer | partial |
| requirement | DATA-01 — Journal/workout/appleDaily/metricSeries SQLite tables | partial |
| requirement | DATA-02 — Realtime strain accumulator on workout screen | deferred |
| requirement | ARCH-01 — Protocol abstractions + mocks + unit tests | partial |

## Quick Tasks Completed

| Date | Slug | Description | Commit |
|------|------|-------------|--------|
| 2026-06-11 | ci-cleanup-add-dependabot | Remove rust-core-ci.yml (duplicate); add dependabot.yml + swift-build.yml | f629dd7 |
| 2026-06-13 | 260613-owu | Wrap HealthPreviewRouteHost in #if DEBUG to fix Release build CI on v10.0 tag | d6b7d1f |

## Session Continuity

Last session: 2026-06-12T18:24:14Z
Stopped at: Completed 73-02-PLAN.md
Resume file: None
Next action: Phase 73 complete — HAP-04 stub done; functional implementation RE-gated pending BTSnoop + Ghidra

## Operator Next Steps

- Start the next milestone with /gsd-new-milestone
