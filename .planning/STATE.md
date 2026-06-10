---
gsd_state_version: 1.0
milestone: v7.0
milestone_name: Sync Correctness, Async & Sleep Sync
status: shipped
last_updated: "2026-06-10T22:00:00.000Z"
last_activity: 2026-06-10 -- v7.0 SHIPPED — Phases 46-50 complete, 18 plans; Phase 51 deferred (hardware gate)
progress:
  total_phases: 5
  completed_phases: 5
  total_plans: 18
  completed_plans: 18
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-09)

**Core value:** The user captures WHOOP data on iPhone and it is automatically persisted on their personal server — without depending on external infrastructure. Metrics align with WHOOP from the same raw data.
**Current focus:** Phase 50 — Morning Band Sleep Sync

## Current Position

Milestone: v7.0 — Sync Correctness, Async & Sleep Sync
Phase: 50 (Morning Band Sleep Sync) — COMPLETE
Plan: 3 of 3 complete (human visual verification approved)
Status: Phase 50 complete — advancing to Phase 51 (human gate, requires physical WHOOP device)
Last activity: 2026-06-10 -- Phase 50 COMPLETE — human approved "A aguardar sincronização" in SleepV2BandSyncCard; SLP-SYNC-01, SLP-SYNC-02, SLP-SYNC-03 satisfied

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
| Phase 20-upstream-fixes-storage P02 | 20min | 2 tasks | 2 files |
| Phase 21-imu-data-foundation P01 | 8 | 2 tasks | 2 files |
| Phase 21-imu-data-foundation P03 | 18 | 2 tasks | 2 files |
| Phase 22-hrv-accuracy P02 | 5 | 2 tasks | 3 files |
| Phase 22-hrv-accuracy P03 | 35 | 2 tasks | 8 files |
| Phase 23-strain-calories P01 | 25 | 2 tasks | 7 files |
| Phase 23-strain-calories P02 | 10 | 2 tasks | 3 files |
| Phase 23-strain-calories P03 | 14 | 2 tasks | 3 files |
| Phase 24-sleep-metrics-baselines P01 | 32 | 3 tasks (TDD+UI) | 10 files |
| Phase 24-sleep-metrics-baselines P02 | 45 | 3 tasks (TDD) | 4 files |
| Phase 26-sleep-staging P01 | 16min | 2 tasks | 3 files |
| Phase 26-sleep-staging P02 | 27min | 2 tasks (Task 3 human) | 2 files |
| Phase 27 P01 | 15 | 2 tasks | 5 files |
| Phase 27 P03 | 20 | 2 tasks | 2 files |
| Phase 28 P03 | 25 | 2 tasks | 2 files |
| Phase 29 P01 | 15 | 1 task | 2 files |
| Phase 29 P02 | 15 | 2 tasks | 2 files |
| Phase 47 P01 | 55 | 2 tasks (TDD) | 19 files |
| Phase 47 P03 | 3 | 2 tasks | 6 files |
| Phase 49 P01 | 2 | 2 tasks | 1 files |
| Phase 49 P02 | 8 | 2 tasks | 2 files |
| Phase 49-healthdatastore-async-migration P03 | 4min | 2 tasks | 6 files |
| Phase 49-healthdatastore-async-migration P04 | 8min | 2 tasks | 5 files |
| Phase 49-healthdatastore-async-migration P05 | 2min | 3 tasks | 5 files |
| Phase 49-healthdatastore-async-migration P06 | 3min | 2 tasks | 2 files |
| Phase 49-healthdatastore-async-migration P07 | 45 | 4 tasks | 11 files |
| Phase 50-morning-band-sleep-sync P01 | 40min | 2 tasks | 3 files |
| Phase 50-morning-band-sleep-sync P02 | 30min | 2 tasks | 6 files |
| Phase 50-morning-band-sleep-sync P03 | 20min | 2 tasks (auto + human-verify) | 0 files |

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
- Phase 20 Plan 01: SYNC-01 and SYNC-05 were already-satisfied in the fork (weak captures already present, both Gen4 UUID paths already lowercase); SYNC-02 was a real change (three &+= conversions); SYNC-03 and SYNC-04 were doc-comment additions only
- [Phase ?]: PERF-05: body_hex excluded for K10/K21 via matches!(packet_k, Some(10) | Some(21)); empty String sentinel; downstream consumers (timeline.rs non_empty, bridge.rs body_byte_count) handle empty string safely
- [Phase ?]: PERF-05 K21 test: build_v5_payload_frame adds alignment padding (1038 mod 4 = 2 bytes); K21 RED-baseline uses !is_empty() instead of exact hex comparison; K10 (1288 bytes, no padding) uses exact comparison
- [Phase ?]: full_samples field added to I16SeriesSummary: all 100 IMU samples now survive parse layer; preview unchanged
- Phase 23 Plan 02: goose_strain_v1 component weights: edwards_zone_load=0.50, average_hr_reserve=0.20, banister_trimp=0.30 (balanced blend, calibration deferred)
- Phase 23 Plan 02: fit_strain_denominator uses closed-form OLS on m=1/ln(D) (exact, O(n), no convergence issues vs iterative)
- Phase 24 Plan 02: EWMA baseline state is always reconstructed from daily_recovery_metrics (no new table); ewma_baseline_update inserts a local_estimate row picked up by fold_history; date-key guard prevents double-update (T-24-04)
- Phase 24 Plan 01: baseline_awake_hr_bpm used as resting_hr proxy for HR-threshold helpers; sol_from_hr requires first_hr_offset correction when window_hr_series doesn't start at minute 0; rem_latency_minutes deferred to Phase 26; bridge tests updated for new HR-threshold scores
- Phase 22 Plan 03: SWS window selection: select_sws_window returns (tier, Vec<usize>) indices into stage_segments; index-proportional mapping when rr_timestamps_s absent; Tier 2 recency = chronological concat; SWS runs before 300-2000 ms gate
- Phase 22 Plan 03: ALG-HRV-04 is a manual gate only (code comment above goose_hrv_v0); phase remains open until >= 5 real session deltas <= 1 ms are recorded in 22-03-SUMMARY.md
- [Phase ?]: Activity count uses inter-sample magnitude difference; COLE_KRIPKE_SCALE_FACTOR exposed as named const for future calibration
- Phase 26 Plan 02: 4-class classifier built on Cole-Kripke spine; HR feature alignment via nearest-timestamp; physiological reimposition runs after per-epoch classification (rule a then b, fixed-point for cascades); ALG-SLP-04 manual gate = >= 5 sessions at >= 70% epoch agreement vs WHOOP
- [Phase ?]: 27-03: Plausibility gates live at bridge layer with warning strings
- [Phase ?]: 27-03: quality_flag='uncalibrated' mandatory on all V24 physical unit outputs
- [Phase ?]: 27-03: sig_quality excluded from upload payload; biometrics.insert_v24_batch stores it locally
- Phase 29 Plan 02: ParsedPayload uses #[serde(tag = "kind", rename_all = "snake_case")] — internally tagged; test fixtures must use {"kind":"data_packet",...} not {"DataPacket":{...}}
- Phase 29 Plan 02: GooseError has no From<serde_json::Error>; use json!{} macro for infallible struct serialisation in bridge handlers
- Phase 47 Plan 01: device_uuid uses Option<&'a str> on RawEvidenceInput (not Option<String>); index references captured_at (not ts — raw_evidence has no ts column); PRAGMA user_version not bumped; existing callsites use device_uuid: None (backward compatible)
- [Phase ?]: Phase 49 Plan 01: requestAsync/requestValueAsync added as additive wrappers (Task.detached) so sync FFI never runs on @MainActor; nonisolated(unsafe) on lastTiming not needed (build clean)
- [Phase ?]: Phase 49 Plan 02: packetInputBridgeReports now nonisolated static async (21 awaited calls); runPacketInputs now async func; in-file callers use Task { await } shims; external callers (AppShellView, HealthDashboardViews) deferred to 49-07
- [Phase ?]: sleepArgs extracted as local let before first await in runPacketScores to avoid redundant merging calls post-suspension
- [Phase ?]: HealthRecoveryStressViews.swift: runPacketScores+runRecoveryV1 wrapped in Task; runReadinessV1+runV24Biometrics remain bare calls until 49-04/05 migrate them
- Phase 49 Plan 04: liveStrainReport captured before first await in runReadinessV1 to preserve @MainActor state snapshot; runReadinessV1 merged into existing Task{} in HealthRecoveryStressViews alongside runPacketScores+runRecoveryV1
- Phase 49 Plan 05: runV24Biometrics merged into existing Task{} in HealthRecoveryStressViews alongside runPacketScores+runRecoveryV1+runReadinessV1; HealthMetricFamilyStrainViews bare calls wrapped in Task{} as minimal shims (full refactor deferred to 49-07)
- Phase 49 Plan 06: cardioLoadActivitySessions + cardioLoadActivityMetricsByName + sleepScoreReport converted to async; databasePath captured before await; dead-code finding (zero callers) confirmed — no cascade updates required
- Phase 50 Plan 02: historicalSyncStatus polling (1s intervals, max 120 attempts) chosen over onHistoricalSyncCompleted to avoid AppShellView single-slot conflict (Pitfall #3); weak var healthStore added to GooseAppModel — set by AppShellView in onAppear
- Phase 50 Plan 02: sleep_id format band_ble.{deviceId}.{yyyy-MM-dd} deterministic; UserDefaults written before first await to prevent retry loops on drop+reconnect

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

Items acknowledged and deferred at v5.0 milestone close on 2026-06-08:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| verification_gap | Phase 22 — ALG-HRV-04 RMSSD parity (≥5 real sessions) | human_needed | v5.0 close |
| verification_gap | Phase 24 — VERIFICATION.md human_needed | human_needed | v5.0 close |
| verification_gap | Phase 32 — VAL-01 HRV parity golden fixtures | deferred | v5.0 close |
| verification_gap | Phase 26 — ALG-SLP-04 4-class staging validation | human_needed | v5.0 close |
| quick_task | 260603-tqd-add-test-and-import-actions-to-remote-se | missing | v2.0 close |
| todo | 2026-06-03-remote-server-test-and-import-actions | ui | v2.0 close |
| todo | bt-button-open-settings | low | v2.0 close |
| algorithm | Recovery formula alignment (linear vs Z-score+logistic) | v6.0 backlog | v5.0 close |
| algorithm | EWMA half-life correction (14-night = 0.0483 vs 0.10) | v6.0 backlog | v5.0 close |
| algorithm | Sleep epoch 30s resolution (currently 1 min) | v6.0 backlog | v5.0 close |

## Session Continuity

Last session: 2026-06-10T20:10:00.000Z
Status: Phase 50 COMPLETE — human visual verification approved; "A aguardar sincronização" confirmed in SleepV2BandSyncCard; SLP-SYNC-01, SLP-SYNC-02, SLP-SYNC-03 satisfied
Next: Phase 51 (Validation Gates) — human gate requiring physical WHOOP device and ≥5 overnight capture sessions
