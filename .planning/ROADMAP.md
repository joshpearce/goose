# Roadmap: Goose

## Milestones

- â **v1.0 Remote Server + Upstream PRs** â Phases 1-5 (shipped 2026-06-03)
- â **v2.0 Multi-Device & Platform Foundations** â Phases 6-8+8.1 (shipped 2026-06-04)
- â **v3.0 Wearable UX, CI Hardening & RTC Sync** â Phases 9-15 (shipped 2026-06-05)
- â **v4.0 Security, Performance & Coach Expansion** â Phases 16-19 (shipped 2026-06-06)
- â **v5.0 Metrics Accuracy, IMU & Upstream Fixes** â Phases 20-35 (shipped 2026-06-08)
- â **v6.0 UI Wiring, Algorithm Alignment & Parity Validation** â Phases 36-45 (shipped 2026-06-09)
- â **v7.0 Sync Correctness, Async & Sleep Sync** â Phases 46-50 (shipped 2026-06-10)
- â **v8.0 Quality, Completeness & Backlog Clearance** â Phases 51-59+60 (shipped 2026-06-11)
- ð§ **v9.0 BLE Reliability & Protocol Parity** â Phases 61-66 (in progress)

## Phases

<details>
<summary>â v1.0 Remote Server + Upstream PRs (Phases 1-5) â SHIPPED 2026-06-03</summary>

Full details: `.planning/milestones/v1.0-ROADMAP.md`

</details>

<details>
<summary>â v2.0 Multi-Device & Platform Foundations (Phases 6-8+8.1) â SHIPPED 2026-06-04</summary>

Full details: `.planning/milestones/v2.0-ROADMAP.md`

Known deferred: WEAR-02 scan UI (v3.0), CR-02 per-row filter (v3.0), hardware BLE tests (no device)

</details>

<details>
<summary>â v3.0 Wearable UX, CI Hardening & RTC Sync (Phases 9-15) â SHIPPED 2026-06-05</summary>

Full details: `.planning/milestones/v3.0-ROADMAP.md`

</details>

<details>
<summary>â v4.0 Security, Performance & Coach Expansion (Phases 16-19) â SHIPPED 2026-06-06</summary>

Full details: `.planning/milestones/v4.0-ROADMAP.md`

Known deferred: COACH-06 device migration test, 4 streaming provider runtime tests, 3 localisation device tests

</details>

<details>
<summary>â v5.0 Metrics Accuracy, IMU & Upstream Fixes (Phases 20-35) â SHIPPED 2026-06-08</summary>

Full details: `.planning/milestones/v5.0-ROADMAP.md`

Key: HRV accuracy, Sleep staging (Cole-Kripke + 4-class), Strain/Calories (Ghidra-confirmed coefficients), V24 biometric decode, Exercise detection, Upload sync infrastructure, Readiness engine, Protocol corrections, Codebase audit (9 HIGH fixed), Cross-project review.

Known deferred: ALG-HRV-04, ALG-SLP-04, VAL-01 (human gates â require real WHOOP device data)

</details>

<details>
<summary>â v6.0 UI Wiring, Algorithm Alignment & Parity Validation (Phases 36-45) â SHIPPED 2026-06-09</summary>

Full details: `.planning/milestones/v6.0-ROADMAP.md`

Known deferred: ALG-HRV-04 real overnight cross-validation (v7.0), ALG-SLP-04 real overnight concordance (v7.0)

</details>

<details>
<summary>â v7.0 Sync Correctness, Async & Sleep Sync (Phases 46-50) â SHIPPED 2026-06-10</summary>

Full details: `.planning/milestones/v7.0-ROADMAP.md`

Key: Upload round-trip (POST /v1/ingest-frames + GET export), device_uuid end-to-end, upload sync race fix, HealthDataStore full async migration (60+ calls), morning band sleep sync (gravity K18/K24 â Cole-Kripke â external_sleep_sessions).

Known deferred: Phase 51 (VAL-HRV-01, VAL-SLP-01, SLP-SYNC real-device validation) â hardware gate, requires WHOOP + â¥5 overnight sessions

</details>

<details>
<summary>✅ v8.0 Quality, Completeness & Backlog Clearance (Phases 51-59+60) — SHIPPED 2026-06-11</summary>

Full details: `.planning/milestones/v8.0-ROADMAP.md`

- [x] Phase 51: Bug Audit — 3 HIGH + 6 MEDIUM bugs fixed in v6.0–v7.0 code
- [x] Phase 52: Quick Tasks & Surface Cleanup — BT Settings, CodeQL CI, HealthKit importer, #if DEBUG gating
- [x] Phase 53: Home Dashboard Completion — Device Status Card, Tools Grid, Evidence Footer
- [x] Phase 54: Coach Score Summaries & Journal — metric highlight grid, daily journal with persistence
- [x] Phase 55: Coach Routes — Sleep Coach, Recovery Insights, Strain Guidance, Stress Guidance views
- [x] Phase 56: Biometrics & Activity — fabricated 55.0 bpm eliminated; exercise-masked stress
- [x] Phase 57: Persistence & Calibration — energy_daily_rollup to SQLite; real train/holdout calibration
- [x] Phase 58: More Tab, Previews & Health Algorithms — MorePrivacyView, #Preview macros, algorithmPreferences
- [x] Phase 59: Band Sleep Import — bandSleepImportStatus replaces static "not available" UI
- [x] Phase 60: Band-First Sync — overnight poll loop removed; foreground-trigger + BGAppRefreshTask

Known deferred: ble-api-misuse-state-restore debug session (awaiting_human_verify); hardware gates (VAL-HRV-01, VAL-SLP-01, SLP-SYNC)

</details>

### v9.0 BLE Reliability & Protocol Parity (Planned)

**Milestone Goal:** Close the critical architectural gaps identified by Ghidra RE of WHOOP v5.37.0. Phases derived from `.planning/research/whoop-re/WHOOP-GOOSE-CROSS-COMPARE.md`.

- [x] **Phase 60: Band-First Sync** - Align sync architecture with WHOOP's foreground-trigger + silent push + BGAppRefreshTask model; remove overnight poll loop (completed 2026-06-11)
- [x] **Phase 61: BLE Bonding State Machine** - Formal 5-state bonding manager (WHPBLEBondingManager parity); replace implicit OS bonding (completed 2026-06-11)
- [ ] **Phase 62: Upload Watermark per Sensor** - Per-type upload watermark to prevent re-uploads after crash/restart (WHPStrapLatestUploadedMetricDateKey parity)
- [ ] **Phase 63: Network Monitor & Upload Gating** - NWPathMonitor-based reachability gating + exponential backoff (WHPNetworkMonitor parity)
- [ ] **Phase 64: HR Data Sanitizer** - Swift-side HR spike filter before HeartRateSeriesStore (WHPHeartRateDataSanitizer parity)
- [ ] **Phase 65: Generic BLE State Machine** - Minimal StateMachine<State, Event> type; migrate BLE connection/bonding states into it (WHPStateMachine parity)
- [ ] **Phase 66: Cap Sense / On-Wrist Detection** - Ghidra investigation of cap sense GATT UUID; on-wrist flag on HR/HRV samples (WHPWhoopStrapOnWrist parity; blocked until UUID identified)

## Phase Details

### Phase 51: Bug Audit

**Goal**: Known bugs and correctness issues from v6.0âv7.0 (phases 36â50) are identified, documented, and fixed
**Depends on**: Phase 50
**Requirements**: AUDIT-01
**Success Criteria** (what must be TRUE):

  1. Every phase 36â50 is reviewed and a written audit report lists findings by severity (HIGH / MEDIUM / LOW)
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

  1. The Home tab shows a Device Status Card with live device name, connection state, battery percent, current HR, last sync time, and a reconnect action when disconnected â never static text
  2. The Home tab shows a Tools Grid with shortcuts to Sleep Coach, Activity, Journal, and Calibration, each reflecting its bridge readiness state
  3. The Home tab shows an Evidence Footer with Rust core version, local store path, data mode, and provenance per metric family â tapping opens More > Debug

**Plans**: TBD
**UI hint**: yes

### Phase 54: Coach Score Summaries & Journal

**Goal**: Coach tab shows score summaries for all four metrics and users can write and persist a daily journal entry
**Depends on**: Phase 53
**Requirements**: COACH-07, COACH-08
**Success Criteria** (what must be TRUE):

  1. The Coach tab displays score summaries for sleep, recovery, strain, and stress â each populated from live bridge data
  2. The user can open a daily journal entry, write a text note, add optional tags, and save it â the entry persists across app restarts
  3. The most recent journal entry for a given date is recoverable after relaunching the app

**Plans**: TBD
**UI hint**: yes

### Phase 55: Coach Routes

**Goal**: Coach tab has four dedicated child route views â Sleep Coach, Recovery Insights, Strain Guidance, and Stress Guidance â each populated from bridge data
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

  1. The recovery score computation uses z_rhr calculated from real SpO2/resp/wrist-temp V24 packet data â the fabricated 55.0 bpm baseline is removed
  2. Non-activity stress is computed and displayed (no longer shows "non-activity stress requires HR samples and activity masks")
  3. Stress windows exclude HR samples that fall within detected exercise session boundaries

**Plans**: TBD

### Phase 57: Persistence & Calibration

**Goal**: Daily stress history and Energy Bank state are persisted in SQLite, and the calibration pipeline runs real train/holdout splits from local metric history
**Depends on**: Phase 56
**Requirements**: ENB-01, CAL-01
**Success Criteria** (what must be TRUE):

  1. Daily stress windows and Energy Bank state are written to SQLite and survive app restarts â long-range trend data is available after multiple days
  2. The calibration pipeline runs against local historical metrics, producing real train/holdout split results
  3. Calibration output values are derived from actual data â the hardcoded "4 train / 2 holdout | improved" string is removed
  4. Calibration results are gated on a completed run; no results are shown if calibration has not run

**Plans**: TBD

### Phase 58: More Tab, Previews & Health Algorithms

**Goal**: More tab actions are fully backed by Swift bridge, SwiftUI previews exist for Home/Coach/More with simulator screenshots, and algorithm preference properties are wired in HealthDataStore
**Depends on**: Phase 55
**Requirements**: MORE-01, PREV-01, HALG-01
**Success Criteria** (what must be TRUE):

  1. More tab capture import, backfill, raw export, and privacy actions are enabled and functional
  2. SwiftUI previews exist for HomeDashboardView, CoachView, and More views covering connected/populated, disconnected, and no-data states â each verified with a simulator screenshot
  3. HealthDataStore exposes algorithmPreferences and referenceAlgorithmDefinitions properties wired to the bridge catalog â the Health > Algorithms section can display primary algorithm selection and reference definitions

**Plans**: TBD
**UI hint**: yes

### Phase 59: Band Sleep Import

**Goal**: Sleep records are ingested directly from BLE band packets â the "band sleep import not available" message is gone and real sleep data appears
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
| 1â45 | v1.0âv6.0 | â | Complete | 2026-06-03 to 2026-06-09 |
| 46â50 | v7.0 | 18/18 | Complete | 2026-06-10 |
| 51. Bug Audit | v8.0 | 0/TBD | Complete | 2026-06-11 |
| 52. Quick Tasks & Surface Cleanup | v8.0 | 0/TBD | Complete | 2026-06-11 |
| 53. Home Dashboard Completion | v8.0 | 0/TBD | Complete | 2026-06-11 |
| 54. Coach Score Summaries & Journal | v8.0 | 0/TBD | Complete | 2026-06-11 |
| 55. Coach Routes | v8.0 | 0/TBD | Complete | 2026-06-11 |
| 56. Biometrics & Activity | v8.0 | 0/TBD | Complete | 2026-06-11 |
| 57. Persistence & Calibration | v8.0 | 0/TBD | Complete | 2026-06-11 |
| 58. More Tab, Previews & Health Algorithms | v8.0 | 0/TBD | Complete | 2026-06-11 |
| 59. Band Sleep Import | v8.0 | 0/TBD | Complete | 2026-06-11 |
| 60. Band-First Sync | v8.0âv9.0 | 3/3 | Complete   | 2026-06-11 |
| 61. BLE Bonding State Machine | v9.0 | 3/3 | Complete   | 2026-06-11 |
| 62. Upload Watermark per Sensor | v9.0 | 0/TBD | Not started | - |
| 63. Network Monitor & Upload Gating | v9.0 | 0/TBD | Not started | - |
| 64. HR Data Sanitizer | v9.0 | 0/TBD | Not started | - |
| 65. Generic BLE State Machine | v9.0 | 0/TBD | Not started | - |
| 66. Cap Sense / On-Wrist Detection | v9.0 | 0/TBD | Not started | - |

## Backlog

### Phase 999.5: GooseAppModel @Observable Migration (promoted to Phase 17 â v4.0)

Promoted to Phase 17: @Observable Migration.

---

### Phase 999.4: Recovery V2 Completion (promoted to Phase 13 â v3.0)

Promoted to Phase 13: Recovery V2 Dashboard.

---

### Phase 999.3: Apply upstream PR #15 (promoted to Phase 16 â v4.0)

Promoted to Phase 16: Deep Link Security.

---

### Phase 999.2: Multi-Language Support (promoted to Phase 14 â v3.0)

Promoted to Phase 14: pt-PT Localisation.

---

### Phase 999.1: Coach Multi-Provider & Custom Endpoint (promoted to Phase 18 â v4.0)

Promoted to Phase 18: Coach Multi-Provider.

### Phase 60: Band-First Sync

**Goal:** Align Goose's BLE sync architecture with the WHOOP app's band-first model, eliminating the need for continuous overnight BLE capture. The band stores data onboard; the app fetches it opportunistically on foreground and via silent push, exactly as WHOOP does.

**Depends on:** Phase 59
**Plans:** 3/3 plans complete
Plans:
**Wave 1**

- [x] 60-01-PLAN.md â Delete overnight guard subsystem core (3 files + GooseAppModel state + overnight struct types)
- [x] 60-02-PLAN.md â Add band-first sync: BandFirstSync.swift (foreground trigger + BGAppRefreshTask handler), BGTask registration, Info.plist keys

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 60-03-PLAN.md â Wire foreground trigger + clean secondary overnight references; build clean (wave 2)

#### Background â Ghidra reverse engineering of WHOOP 5.37.0

The following was confirmed in the WHOOP binary (`Whoop` ARM64, 8621 functions) using Ghidra static analysis:

**Dimension 1 â Historical sync on foreground (not overnight polling)**

WHOOP calls `WHPBLEHistoricalDataManager` exclusively in `applicationWillEnterForeground`:

- String confirmed at `0x105cfc9bc`: `"WHPAppDelegate called WHPBLEHistoricalDataManager on applicationWillEnterForeground"`
- String confirmed at `0x105cfcbc3`: `"FETCH BLE DATA - Start"` (triggered at foreground entry)
- Cooldown guard confirmed at `0x105cfce05`: `"FETCH BLE DATA - Cancelled, last History Complete Event within %.fmin"` â prevents redundant fetches if a sync completed recently
- `WHPBLEHistoricalDataManager` lives in `Code/BLE/HistoricalStateMachine/WHPBLEHistoricalDataManager.swift` with its own state machine (confirmed via embedded source paths)

**Goose change:** remove the 30s overnight range poll loop from `GooseAppModel+OvernightRun.swift`; move BLE historical sync trigger to `applicationWillEnterForeground` / `scenePhase == .active`. Add the same cooldown guard (e.g. skip if last `HISTORY_COMPLETE` was within N minutes).

**Dimension 2 â Silent Push Notification (SPN) as background sync trigger**

WHOOP uses silent APNs pushes (`content-available: 1`, no alert) to wake the app and trigger BLE fetch without user interaction:

- Push type `"start-sync-data"` confirmed at `0x105cfcd6e`
- Handler confirmed at `0x105cfcd7e`: `"FETCH BLE DATA - Start From SPN"` â distinct log from the foreground path, same underlying fetch
- Cooldown applies to SPN path as well (same `FETCH BLE DATA - Cancelled` guard)
- Silent push handler is in `WHPAppDelegate(UIApplicationDelegate) application:didReceiveRemoteNotification:fetchCompletionHandler:` confirmed at `0x105cfcc52`
- Feature flag refresh also uses silent push: `"Refresh FF Silent Push Notification received."` at `0x105cfcd40`
- Community invite also uses silent push: `"Join Community Silent Push Notification received."` at `0x105cfce60`

**Goose server change:** after `daily.compute_day()` finishes, send a `content-available: 1` APNs push with type `"start-sync-data"` (or equivalent) to the registered device token. iOS wakes Goose in background â Goose triggers historical BLE fetch.

**iOS change:** implement `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` in `GooseSwiftApp` / `AppDelegate`; on `"start-sync-data"` type, call the same BLE foreground-sync path, then call `completionHandler(.newData)`.

**Dimension 3 â recovery_processed_v1 push (data delivery, not sync trigger)**

WHOOP sends a second push type when sleep/recovery computation finishes server-side:

- Push type key `"recovery_processed_v1"` confirmed at `0x105eab0e0`
- Payload structure confirmed in memory dump: outer key `"data_payload"` containing `"sleep_activity"` field
- Handler at `0x105cfccc0`: extracts `sleep_activity` object from `data_payload`, uses it to update the app's recovery/sleep state directly from the push payload (no BLE needed for this path)
- Log: `"[WHPAppDelegate %s] - Did Receive sleep Activity in recovery_processed notification. Sleep Activity: %@"`
- Membership changes also delivered via push: `"Membership Status Change Push Notification received."` at `0x105cfcd90`

**Goose equivalent:** Goose server sends a push after `compute_day()` with a JSON payload containing the computed `daily_metrics` row (recovery, sleep, strain, HRV). The Goose iOS app receives it in the background handler, writes to a local cache, and publishes to `HealthDataStore` on next foreground entry. This eliminates the polling-on-open pattern for daily metrics.

**Dimension 4 â overnight guard becomes supplementary**

WHOOP has NO overnight guard equivalent. The band stores raw sensor data autonomously; the app just downloads history when it opens or receives a `start-sync-data` SPN. There is no continuous overnight BLE connection.

**Goose change:** the overnight guard remains available for capture research / protocol validation (its current purpose per `MoreCaptureViews.swift`), but is removed from the primary sync path. Normal users never need to enable it. The primary sync path becomes: foreground trigger + SPN trigger (Dimensions 1 & 2).

#### Additional findings â ObjC_RESOLVED.txt symbol analysis

Full ObjC symbol table at: `.planning/research/whoop-re/ObjC_RESOLVED.txt` (8.4MB, 290k lines)
Generated by Ghidra decompilation of WHOOP 5.37.0 ARM64 binary. Contains: class names, instance variable names, Swift mangled type names, embedded source file paths (debug info survived stripping), string literals, method signatures.

**Source package structure confirmed from embedded debug paths:**

```
WhoopBluetooth/Sources/WhoopBluetooth/
  Devices & Device Publishers/Device Services/Historical Pull Service/
    HistoricalPullDeviceService.swift     â device-level BLE pull
    HistoricalPullReducer.swift           â processes received packets
    HistoricalPullValidator.swift         â validates received data
WhoopDataSyncing/Sources/WhoopDataSyncing/
  Data Timestamp Publishers/Watermarks/
    WatermarksInteractor.swift            â watermark CRUD
  Process Now/
    StoredWatermarksAtHistoryComplete.swift  â persists watermarks on HISTORY_COMPLETE
WhoopStrapServices/Sources/WhoopStrapServices/
  HistoricalPullService.swift             â strap-level orchestrator
WhoopBluetoothAnalytics/Sources/WhoopBluetoothAnalytics/
  Historical Pull/HistoricalPullAnalytics.swift
  Historical Pull Throughput/HistoricalPullThroughputAnalytics.swift
WhoopBackgroundTask/Sources/WhoopBackgroundTask/
  RuntimeBGAppRefreshTask.swift
  RuntimeBackgroundTaskRunner.swift
  RuntimeBackgroundTaskScheduler.swift
WhoopPushNotifications/Sources/WhoopPushNotifications/
  RecoveryProcessedPushNotificationResponder.swift
  PushNotificationHandlerObjCApapter.swift
  RuntimeStrapStateSnapshotWriter.swift
  PushNotificationPermissionsManager.swift
```

**Watermark data structure (from mangled symbol `012uncompressedB4Size...20watermarksByRevision`):**

- `watermarksByRevision: [Int: Date]` â dict from revision number (Int) to timestamp (Date)
- `ecgHighWaterMark: DateContainer<ISO8601...>?` â ECG-specific high watermark
- `anfHighWaterMark` â ANF (accelerometer/gyro?) high watermark
- `watermarksSubject: CurrentValueSubject<Watermarks, Never>` â Combine-based reactive state
- `clearAllWatermarks()` â exists as a static method (for reset/logout)
- `getWatermark(_:dataPipelineCheckpoint:) -> Date?` â query watermark by type + checkpoint

Goose's `synced` flag is the equivalent, but simpler (binary rather than per-revision timestamps). A watermark approach would allow partial re-sync.

**`HistoricalPullDeviceService` constructor signature (from mangled ivar):**
Takes `dataStore`, `activeHistoricalPullInfoProvider`, `configLoader`, `appForegroundPublisher`, `receiver`, `taskCreator` â the `appForegroundPublisher` is a `Combine.AnyPublisher<StitchingResult, Never>` which triggers the service when the app enters foreground. This is the Combine-based equivalent of Goose's imperative `applicationWillEnterForeground` call.

**A â BGAppRefreshTask (3rd background mechanism, not found via Ghidra strings alone)**

WHOOP ships a dedicated `WhoopBackgroundTask` framework with:

- `RuntimeBGAppRefreshTask` â implementation of `BGAppRefreshTask` (iOS `BackgroundTasks.framework`)
- `RuntimeBackgroundTaskRunner` â runs the task; logs `"ERROR: Could not schedule BGTask"` and `"WARNING: No BackgroundTask implementation found for identifier:"`
- `RuntimeBackgroundTaskScheduler` â schedules periodic BGAppRefreshTask wakeups with `BGTaskScheduler`
- `BackgroundTaskManager` â orchestrator in the main Whoop module
- `BGAppRefreshTaskRequest` + `BGTaskScheduler` both imported (confirmed from `_OBJC_CLASS_$_` symbols)

WHOOP therefore has **3 background triggers**, not 2:

1. `applicationWillEnterForeground` â foreground historical pull
2. `start-sync-data` silent push â SPN historical pull
3. `BGAppRefreshTask` â scheduled background wakeup (every few hours, iOS-controlled)

**Goose addition:** register a BGAppRefreshTask identifier in `Info.plist` (`BGTaskSchedulerPermittedIdentifiers`) and implement `BGAppRefreshTask` handler in `GooseSwiftApp.swift`. On wake: trigger historical BLE sync + server upload, then call `task.setTaskCompleted(success:)`.

**B â WhoopPushNotifications module classes (relevant for Goose's push handler)**

- `RecoveryProcessedPushNotificationResponder` â dedicated class for `recovery_processed_v1`; Goose needs an equivalent `DailyReadyPushResponder`
- `PushNotificationHandlerObjCAdapter` â routes push types to typed responders; Goose should follow this routing pattern
- `RuntimeStrapStateSnapshotWriter` â on push receipt, writes strap state snapshot for crash safety; Goose should write pending-sync state to UserDefaults before starting background work
- `PushNotificationPermissionsManager` â manages UNUserNotificationCenter authorisation
- `RuntimePushSettingsReporter` â reports push permission state to analytics

**C â WhoopDataSyncing watermark system**

WHOOP tracks upload progress via watermarks (not just `synced` flags):

- `anfHighWaterMark`, `ecgHighWaterMark`, `highWatermarkDate` â per-sensor high watermarks
- `StoredWatermarksAtHistoryCompleteExecutor` â persists watermarks atomically when `HISTORY_COMPLETE` fires
- `RuntimeWaterMarkReporter` â reports watermark state to server
- `ProcessNowReadyToUploadTrigger` â fires when data is ready (post-history-complete)
- Background data transmission uses separate BGTask per type: `"for console/events/processed/raw data transmission"`

WHOOP uploads incrementally (only data above the last watermark), which is more efficient than Goose's `synced=0` scan. This is a stretch-goal optimisation for Phase 60 â the `synced` flag is functionally equivalent but less granular.

**D â BTHR (Background Tracked Heart Rate) â separate feature**

Not relevant to Phase 60 but documented for reference:

- BTHR = continuous background HR monitoring via BLE strap (not historical download)
- Feature-flagged: `dwl_background_bthr`
- Has a timer (`bthrStopTime`) and cooldown (`"Background BTHR Timer Finished"`)
- Sends a disconnected notification (`bthr_disconnected`) when strap goes out of range
- Goose does NOT need to implement this â its overnight guard is a superset

**E â Approov API security**

WHOOP uses Approov (`ApproovURLSession`, `ApproovURLSessionAdapter`) for all server calls â certificate pinning + app attestation. Not relevant for Goose's self-hosted server but explains why direct API calls to WHOOP's servers are not feasible.

#### Implementation scope

**iOS (Swift):**

- Remove 30s range poll loop from `GooseAppModel+OvernightRun.swift`
- Add `scenePhase == .active` trigger to `GooseAppModel+Upload.swift` that fires `GooseBLEClient` historical sync
- Add cooldown guard (UserDefaults timestamp of last `HISTORY_COMPLETE`) â same pattern as WHOOP's `"FETCH BLE DATA - Cancelled, last History Complete Event within %.fmin"`
- Register for APNs in `GooseSwiftApp.swift`: `UIApplication.shared.registerForRemoteNotifications()`
- Implement `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`: handle `"start-sync-data"` (trigger BLE sync) and `"goose-daily-ready"` (cache metrics payload from push body)
- Register `BGAppRefreshTask` identifier in `Info.plist` (`BGTaskSchedulerPermittedIdentifiers: ["com.goose.swift.bg-sync"]`)
- Implement `BGAppRefreshTask` handler: schedule next wakeup + trigger historical BLE sync
- Write strap state snapshot to UserDefaults on push receipt before starting background work (mirrors WHOOP's `RuntimeStrapStateSnapshotWriter`)
- Store APNs device token in Keychain; upload to Goose server

**Server (FastAPI + TimescaleDB):**

- Add `device_tokens` table: `(device_id, apns_token, platform, updated_at)`
- Add `POST /v1/device-token` endpoint (Bearer-gated)
- After `daily.compute_day()` completes: call APNs HTTP/2 API with `content-available: 1` + `"goose-daily-ready"` payload containing the computed `daily_metrics` row
- Reuse same APNs call for `"start-sync-data"` type when new BLE data is ingested
- APNs credentials via env: `GOOSE_APNS_KEY_P8`, `GOOSE_APNS_KEY_ID`, `GOOSE_APNS_TEAM_ID`, `GOOSE_APNS_BUNDLE_ID`
- Add `server/ingest/app/apns.py` module using `httpx` async client (HTTP/2, APNs requires it)

**Plans:** 0 plans

### Phase 61: BLE Bonding State Machine

**Goal:** Replace the implicit OS bonding path with a formal bonding manager that tracks bond state through distinct steps, matching the `WHPBLEBondingManager` pattern from WHOOP (NotStarted â Started â Subscribed â Completed/Cancelled).

**Depends on:** Phase 60
**Requirements:** BLE-BOND-01
**WHOOP reference:** `WHPBLEBondingManager`, `WHPBLEBondingManagerProtocol`, states: `WHPBLEBondingNotStartedState`, `WHPBLEBondingStartedState`, `WHPBLEBondingSubscribedState`, `WHPBLEBondingCompletedState`, `WHPBLEBondingCancelledState`
**Success Criteria** (what must be TRUE):

1. A `GooseBLEBondingManager` type exists with the 5 formal states; bonding progress is observable from `GooseAppModel`
2. On BT reset or iOS reboot, the app detects bond loss, re-enters the bonding flow, and reconnects without user action
3. Bonding state is persisted across app restarts so the app can resume from the last known state
4. The existing string-based `connectionState` is replaced with the formal state machine output for the bonding portion

**Plans:** 3/3 plans complete
Plans:

**Wave 1**

- [x] 61-01-PLAN.md — Foundation: GooseBLEBondingState enum + GooseBLEBondingManager class + localized strings

**Wave 2** *(blocked on Wave 1)*

- [x] 61-02-PLAN.md — Integration: wire bonding manager into GooseBLEClient/delegate/commands + GooseAppModel observability + bond-loss detection

**Wave 3** *(blocked on Wave 2)*

- [x] 61-03-PLAN.md — Human-verify checkpoint: bond-loss recovery + persistence across restart

---

### Phase 62: Upload Watermark per Sensor

**Goal:** Track the last successfully uploaded timestamp per data type (raw frames, processed metrics) so restarts and partial uploads never re-send data already in TimescaleDB, matching WHOOP's `WHPStrapLatestUploadedMetricDateKey` / per-sensor high-water-mark pattern.

**Depends on:** Phase 61
**Requirements:** UPLOAD-WM-01
**WHOOP reference:** `WHPStrapLatestUploadedMetricDateKey`, `WHPStrapHighWaterMarkDateKey`, `WatermarksInteractor`, `StoredWatermarksAtHistoryComplete`, watermark shape `[Int: Date]` keyed by revision
**Success Criteria** (what must be TRUE):

1. A watermark is persisted (UserDefaults or SQLite) for each upload type (raw frames, daily metrics) and updated atomically on upload success
2. After a crash mid-upload, the next launch resumes from the watermark â no duplicate rows appear in TimescaleDB
3. The server-side `POST /v1/ingest-frames` endpoint rejects (or deduplicates) frames below the committed watermark
4. A reset path exists (`clearAllWatermarks`) for logout / device swap

**Plans:** 0 plans

---

### Phase 63: Network Monitor & Upload Gating

**Goal:** Gate all outbound uploads on network reachability, matching WHOOP's `WHPNetworkMonitor` pattern, and implement exponential-backoff retry so uploads fail visibly rather than silently when offline.

**Depends on:** Phase 62
**Requirements:** NET-MON-01
**WHOOP reference:** `WHPNetworkMonitor`, `WHPAccountCanUploadDataStatusChanged` notification (WHOOP also gates on account authorisation)
**Success Criteria** (what must be TRUE):

1. A `GooseNetworkMonitor` wraps `NWPathMonitor` and publishes a `isReachable: Bool` to `GooseAppModel`
2. Upload is not attempted when `isReachable == false`; queued work is retried automatically when connectivity returns
3. Upload failures due to server error (5xx) use exponential backoff (1s, 2s, 4s, max 60s) with a visible error state in the UI
4. Upload is gated on a non-empty device token (APNs registration must have succeeded at least once)

**Plans:** 0 plans

---

### Phase 64: HR Data Sanitizer

**Goal:** Add a Swift-side heart rate sanitization step between raw BLE notification bytes and `HeartRateSeriesStore`, matching WHOOP's `WHPHeartRateDataSanitizer`, to suppress physiologically impossible spikes before they reach the UI or Rust algorithms.

**Depends on:** Phase 60
**Requirements:** HR-SAN-01
**WHOOP reference:** `WHPHeartRateDataSanitizer`, `WHPHeartRateDecimator2` (decimation is a stretch goal)
**Success Criteria** (what must be TRUE):

1. A `GooseHRSanitizer` type filters HR samples outside a configurable valid range (e.g. 25â220 BPM) before they enter `HeartRateSeriesStore`
2. Spike samples are logged (OSLog) and counted in a debug counter visible in More > Debug
3. The live HR display never shows a value outside the valid range during normal wear
4. Sanitizer thresholds are constants (`static let`) not hard-coded literals

**Plans:** 0 plans

---

### Phase 65: Generic BLE State Machine

**Goal:** Extract a lightweight reusable `StateMachine<State, Event>` type (matching `WHPStateMachine` + `WHPStateMachineState` + `WHPStateMachineEventDefinition`) and migrate the BLE connection and bonding state into it, replacing the ad-hoc string status scattered across `GooseBLEClient`.

**Depends on:** Phase 61
**Requirements:** SM-01
**WHOOP reference:** `WHPStateMachine`, `WHPStateMachineState`, `WHPStateMachineEventDefinition`
**Note:** Previously flagged as over-engineering for the codebase's current size â added at user request. Scope is deliberately minimal: one generic type + migration of BLE connection/bonding states only. No broader adoption beyond BLE layer unless a future phase warrants it.
**Success Criteria** (what must be TRUE):

1. A `StateMachine<State: Hashable, Event>` struct exists in `GooseBLETypes.swift` or a new `GooseStateMachine.swift`
2. BLE connection states (from Phase 61's bonding manager + existing connection states) are expressed as `StateMachine` instances
3. Invalid state transitions are asserted in DEBUG builds; in RELEASE they are no-ops that log an OSLog error
4. No reduction in observable behaviour â existing UI reflecting connection state continues to work

**Plans:** 0 plans

---

### Phase 66: Cap Sense / On-Wrist Detection

**Goal:** Identify the GATT characteristic for WHOOP's capacitive skin-contact sensor (cap sense) via Ghidra and implement on-wrist detection in Goose, matching `WHPWhoopStrapCapSenseSuccessNotification` / `CapSenseFailed`, so physiological data is only trusted when the band is being worn.

**Depends on:** Phase 60
**Requirements:** CAPSENSE-01
**WHOOP reference:** `WHPWhoopStrapCapSenseSuccessNotification`, `WHPWhoopStrapCapSenseFailed`, `WHPWhoopStrapOnWrist`, `WHPWhoopStrapOffWrist`, `WHPWhoopStrapSensorsStatusLiveChangedNotification`
**Note:** GATT characteristic UUID for cap sense is not yet identified â this phase begins with a Ghidra investigation step. If the characteristic cannot be identified from the binary, the phase is blocked and deferred.
**Success Criteria** (what must be TRUE):

1. The cap sense GATT characteristic UUID is identified via Ghidra static analysis and documented in `.planning/research/whoop-re/`
2. `GooseBLEClient` subscribes to the cap sense characteristic and publishes `isOnWrist: Bool` to `GooseAppModel`
3. HR and HRV samples acquired while `isOnWrist == false` are flagged in SQLite (`on_wrist = 0`) and excluded from strain/recovery computations
4. The Device Status Card (Phase 53) shows an off-wrist indicator when detected

**Plans:** 0 plans

---

### Phase 999.6: body_hex Storage Optimization (absorbed into Phase 20 â v5.0)

Absorbed into Phase 20: Upstream Fixes & Storage (as PERF-05).
