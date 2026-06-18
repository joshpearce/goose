---
gsd_state_version: 1.0
milestone: v12.0
milestone_name: milestone
status: executing
stopped_at: Phase 87 Plan 02 complete — sleep domain in store/sleep.rs (commit 764cb04)
last_updated: "2026-06-15T14:00:16.329Z"
last_activity: 2026-06-15 -- Phase 87 Plan 02 complete — sleep domain moved to store/sleep.rs
progress:
  total_phases: 9
  completed_phases: 4
  total_plans: 27
  completed_plans: 26
  percent: 44
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-13)

**Core value:** The user captures WHOOP data on iPhone and it is automatically persisted on their personal server — without depending on external infrastructure. Metrics align with WHOOP from the same raw data.
**Current focus:** Phase 87 — store-rs-split

## Current Position

Phase: 87 (store-rs-split) — EXECUTING
Plan: 3 of 6 (Plan 02 complete)
Status: Ready to execute
Last activity: 2026-06-15 -- Phase 87 Plan 02 complete — sleep domain moved to store/sleep.rs

Progress: [██████████] 100%

## Performance Metrics

**Velocity:**

- Total plans completed: 33 (v1.0–v7.0 combined)
- Average duration: —
- Total execution time: —

**Recent Trend:**

- Last 5 plans: Phase 83 P06, Phase 83 P05, Phase 83 P04, Phase 83 P03, Phase 83 P02
- Trend: Stable

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- v12.0 roadmap: Phase 83 uses 83-CONTEXT.md which has all design decisions finalised — run /gsd-plan-phase 83 directly without a research step
- v12.0 roadmap: Phase 85 (ARCH-03, Rust crash safety) is independent of the PROTO phases and can start after Phase 82; sequenced here at Phase 85 to avoid merge conflicts with bridge.rs split
- v12.0 roadmap: Phase 86 (bridge.rs split) depends on Phase 85 so the split inherits Result-typed handlers; COMM-01 collocated here because offset comments belong at the handler call sites
- v12.0 roadmap: Phase 87 (store.rs split) follows Phase 86 to avoid merge conflicts in the dispatcher; ARCH-02 is cleanest when ARCH-01 boundary is stable
- v12.0 roadmap: Phase 88 (Swift ownership) is independent of Rust refactor; sequenced after Phase 87 to allow parallel planning but avoid source conflicts
- v12.0 roadmap: Phase 89 (BLE actor) depends on Phase 83 (DeviceCapabilities) and Phase 88 (ownership); both preconditions must be met for DeviceCatalog to be meaningful
- v12.0 roadmap: Phase 90 (domain ViewModels) depends on Phase 88 and Phase 89; splits GooseAppModel only after ownership and actor boundaries are stable
- v12.0 roadmap: Phase 91 (COMM-02/03 comments) follows Phase 87; threading comments safest after store split stabilises module boundaries; algorithm comments have no dependency but grouped here for a clean comment-only pass
- v12.0 roadmap: BAT-01/BAT-02 grouped into Phase 84 (after Phase 83) because DeviceCapabilities.battery_via_event48 and battery_via_cmd26 fields are the correct dispatch mechanism
- v11.0 roadmap: Phase 74 and 75 run in parallel from Phase 73 (no dependency between UX/i18n batch and BLE/sync batch of fork PRs)
- v11.0 roadmap: Phase 76 (upstream PRs) depends on Phase 74 to avoid merge conflicts — UX changes land first
- v11.0 roadmap: Phase 77 (audit) follows Phase 76 so it covers the freshest codebase state including all PR integrations
- v11.0 roadmap: Phase 78 (PERF + BLE-REL) after audit so any performance findings from audit feed directly into the optimisation work
- v11.0 roadmap: Phase 79 (polish + deferred) last — DEF-01/DEF-02 complete HAP-02/DATA-02 which were explicitly deferred from v10.0
- [Phase 83-01]: WireProtocol in protocol.rs (co-located with DeviceType); DeviceKind and DeviceCapabilities in new capabilities.rs (avoids growing bridge.rs before Phase 86 split)
- [Phase 83-02]: Migration step 22 unit tests placed in internal #[cfg(test)] module in store.rs (not store_tests.rs) — private `conn` field access required for WHERE-filtered COUNT queries
- [Phase 83-04]: WireProtocol/HistoricalSyncKind use String,Decodable with explicit raw values matching Rust JSON snake_case — avoids custom init(from:); whoopGenerationFromCapabilities() uses internal visibility (not private) so sibling extension files can call it
- [Phase 83]: Wire-level guards use wireProtocol; historical-protocol guards use historicalSync — separation matches plan D-08 design intent
- [Phase ?]: [Phase 84-02]: Event-48 battery dispatch gated on batteryViaEvent48 == true AND wireProtocol == .gen4 — Gen5 shares the batteryViaEvent48 flag so wireProtocol guard is mandatory
- [Phase 84-03]: Cmd 26 auto-send gated on batteryViaCMD26 && wireProtocol == .gen4 — Gen5 also has batteryViaCMD26=true (RESEARCH Pitfall 5); historicalDirectWriteBridge reused; project.pbxproj must be manually updated when adding new Swift source files
- [Phase ?]: [Phase 85-02]: store.rs test .unwrap() converted to .expect(); allow shield removed — store.rs now exposed to deny lint
- [Phase ?]: [Phase 85-04]: capabilities.rs test .unwrap() converted to .expect() with call-site-specific messages; shield removal proves no production .unwrap() remains
- [Phase 85-06]: Pre-existing export_tests failures (sensor_sample_rows 18 vs expected 19) confirmed not caused by Phase 85 — export_tests.rs was not modified during Phase 85; root cause is Phase 84 schema/fixture change; needs separate debug session
- [Phase 87-02]: Made 9 store helper functions pub(super) to expose to sleep submodule without widening public API; pre-existing cargo test --locked failures in mod.rs test code confirmed unrelated to this split

### Roadmap Evolution

- v12.0 Phases 83–91 defined 2026-06-14: Protocol refactor (83), Gen4 battery (84), Rust crash safety (85), bridge.rs split + protocol comments (86), store.rs split (87), Swift ownership (88), BLE actor (89), domain ViewModels (90), threading + algorithm comments (91)
- v11.0 Phases 74–79 defined 2026-06-13: Fork PR integration (2 batches), upstream PR integration, codebase audit, performance + BLE reliability, polish + deferred features
- v10.0 Phases 67–73 defined 2026-06-12: Protocol parity (Rust-only), BLE refactor + validator, data foundation, haptic primitive + Breathe, coaching/notifications/decimation cluster, screens + service layer, smart alarm + RE-gated wake-window
- Phase 66 added (v9.0): Cap Sense / On-Wrist Detection — DEFERRED hardware gate (CAPSENSE-01)
- Phase 60 added: Band-First Sync — align Goose BLE sync architecture with WHOOP app (foreground trigger + BGAppRefreshTask)

### Pending Todos

- None

### Blockers/Concerns

- HAP-04 (Phase 73, wake-window): RE-gated — do not write implementation tasks until BTSnoop capture of `STRAP_DRIVEN_ALARM_EXECUTED` and Ghidra decompile of `SetAlarmInfoCommandPacketRev4` are complete
- Phase 66 (Cap Sense): hardware-gated — requires real WHOOP 5.x device; deferred indefinitely
- Hardware gate reminder: ALG-HRV-04, ALG-SLP-04, SLP-SYNC real-device remain deferred (hardware gate)

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
| Phase 86 P04 | 25 min | 1 tasks | 1 files |
| Phase 86-bridge-rs-split-protocol-comments P05 | 20 min | 2 tasks | 2 files |
| Phase 87 P05 | 35 min | 1 tasks | 2 files |

## Quick Tasks Completed

| Date | Slug | Description | Commit |
|------|------|-------------|--------|
| 2026-06-11 | ci-cleanup-add-dependabot | Remove rust-core-ci.yml (duplicate); add dependabot.yml + swift-build.yml | f629dd7 |
| 2026-06-13 | 260613-owu | Wrap HealthPreviewRouteHost in #if DEBUG to fix Release build CI on v10.0 tag | d6b7d1f |

## Session Continuity

Last session: 2026-06-15T14:00:16.323Z
Stopped at: Phase 87 Plan 02 complete — sleep domain in store/sleep.rs (commit 764cb04)
Resume file: .planning/phases/87-store-rs-split/87-03-PLAN.md
Next action: Execute 87-03 (next domain split in Wave 2)

## Operator Next Steps

- Phase 85 gate plan complete — ARCH-03 SC1 (lint) and SC2 (catch_unwind) confirmed. SC3 partial: 2 pre-existing export_tests failures (sensor_sample_rows 18 vs 19) not caused by Phase 85.
- Run /gsd-debug to investigate export_tests sensor_sample_rows failures before /gsd-verify-work
- After verification: proceed to Phase 86 (bridge.rs split)
