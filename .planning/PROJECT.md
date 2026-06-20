# Goose — Multi-Device Biometric Platform

## What This Is

Fork of `b-nnett/goose`: an iOS app (SwiftUI + Rust core) that reads biometric data from WHOOP devices via BLE and persists it on a self-hosted server.
v1.0 delivered: FastAPI+TimescaleDB server, automatic iOS→server upload, integration of 9 upstream PRs.
v2.0 expanded: full WHOOP 4.0 (Gen4) support, Android JNI foundations, standard HR GATT pipeline.
v3.0 completed: HR monitor scan UI + independent capture, BLE stability, Recovery V2 dashboard, pt-PT localisation, WHOOP 4.0 RTC sync, SDNN accuracy fix.
v4.0 delivered: URL scheme security (deep link guard), full `@Observable` migration, four-provider Coach (ChatGPT/Claude/Custom/Gemini), complete pt-PT localisation for v4.0 strings.
v5.0 shipped (2026-06-08): Validated algorithm pipeline — HRV (BLE-gap-aware RMSSD + Lipponen-Tarvainen filter), Sleep staging (Cole-Kripke scale=0.001 + 4-class), Strain/Calories (empirically validated Keytel/H-B coefficients), V24 biometric decode (SpO2/skin_temp/resp/gravity2), Exercise detection (retroactive, Karvonen zones), Upload sync (synced flag + cursors), Readiness Engine (ACWR + Foster monotony). Schema v19. 128 Rust tests. 9 audit HIGH findings fixed.
v6.0 shipped (2026-06-09): All v5.0 Rust algorithms wired to SwiftUI dashboards — Readiness Engine, Sleep Staging (4-class hypnogram + AASM), V24 Biometrics, Exercise Sessions, Upload Sync UI, IMU Step Detection. Algorithm alignment: recovery Z-score weights, EWMA 14-night alpha, Cole-Kripke 30s epochs. Raw BLE frame upload/import (trust-chain). Test Connection + Import do servidor UI. 0 untranslated pt-PT strings.
v7.0 shipped (2026-06-10): Sync correctness + async migration — upload route pair complete (POST /v1/ingest-frames + GET export), device_uuid end-to-end (CoreBluetooth → SQLite → server), upload sync race fix (pre-capture rowIDs), HealthDataStore full async/await migration (60+ calls, GCD removed), morning band sleep sync (gravity K18/K24 extraction → Cole-Kripke → external_sleep_sessions). Algorithm defaults promoted to v1. Phase 51 (real-device validation) deferred — hardware gate.
v10.0 shipped (2026-06-13): Protocol parity + haptics + feature completeness — WHOOP 5.0 BLE manager refactor (GooseBLEHistoricalManager + GooseBLEDataValidator), haptic buzz primitive (cmd 0x13), BreatheView, Coach VOW nudges, Interval Timer, iOS notifications (sleep/workout/battery), HR decimation, Stress/ANS + Trends + Manual Workout screens, service layer protocols + mocks, smart alarm UI (HAP-03), wake-window RE-gated stub. Schema v20 (4 new SQLite tables). Code review fixes across 3 phases.
v11.0 shipped (2026-06-14): PR integration + code health + app polish — 7 fork PRs integrated (units, localisation, UUID hiding, ChatGPT auth, firmware recovery, warm-up progress, sync donut), 4 upstream PRs merged (main-thread offload, async FFI, scroll jitter fix), full codebase audit (7 documents + CRITICAL findings resolved), schema v21 indexes, lazy init, BLE auth retry (SEED-001), Debug 3-tab split, Logs & Export, Breathe haptics, live strain tile, resting HR floor (30 bpm), R22 battery display, HealthKit SQLite persistence.
v12.0 shipped (2026-06-19): Code Health & Protocol Foundation — DeviceKind/DeviceCapabilities/WireProtocol enum replacing 17 string comparisons, Gen4 battery via Event-48 + cmd 26, Rust crash safety (catch_unwind + unwrap→Result + deny lint), bridge.rs BridgeRouter per-domain handlers, store.rs domain stores (SleepStore/CaptureStore/MetricsStore), HealthDataStore ownership to GooseAppModel, BLETransport actor + DeviceCatalog, domain @Observable ViewModels, threading + protocol offset + algorithm coefficient comments. Phases 83–91.
v13.0 shipped (2026-06-20): Bug fixes, protocol reliability, device coverage & HealthKit export — auth exhaustion recovery (12-retry + Reconnect/Cancel alert), export OOM fix (writeManifestToDisk helpers), V24History packet parsing, 9 silent `try?` → `do/catch` error logging, WHOOP MG DeviceKind + name-based advertisement detection, HealthKit export (HR/HRV/SpO2/sleep) with opt-in toggle. Phases 92–97.

## Core Value

The user must be able to capture WHOOP data on iPhone and have it persisted automatically on their personal server — without depending on external infrastructure. Metrics (HRV, Recovery, Strain, Calorias, Sleep) must align with what WHOOP itself produces from the same raw data.

## Requirements

### Validated

- ✓ BLE GATT connection to WHOOP 5.0 and 4.0 devices — existing
- ✓ BLE frame parsing via Rust core (libgoose_core) — existing
- ✓ Local SQLite storage of captured frames — existing
- ✓ Home / Health / Coach / More tabs with SwiftUI — existing
- ✓ FastAPI+TimescaleDB server copied to `server/` and packaged in Docker — v1.0
- ✓ Multi-stage Docker image with named volumes (no DATA_ROOT) — v1.0
- ✓ GooseSwift sends decoded data to the server via POST /v1/ingest-decoded — v1.0
- ✓ URL/token configuration in the More tab with Keychain/UserDefaults persistence — v1.0
- ✓ Upload status visible in the More tab (health check + last upload + pending batches) — v1.0
- ✓ 9 upstream b-nnett/goose PRs integrated via git merge --no-ff — v1.0
- ✓ WHOOP 4.0 (Gen4): iOS app layer — command guards, generation field, onboarding, device view, upload device_generation "4.0" — v2.0 (GEN4-01 to GEN4-05)
- ✓ Android Port Foundations: Rust core compiles to aarch64-linux-android via cargo-ndk; JNI shim; panic=abort; ADR — v2.0 (ANDROID-01 to ANDROID-03)
- ✓ Server CI: pytest suite runs on GitHub Actions with real TimescaleDB container — v2.0 (CI-01)
- ✓ Rust 0x2A37 HR parser: `heart_rate_gatt_protocol.rs` with 10 integration tests — v2.0 (WEAR-01)
- ✓ iOS BLE HR monitor: dedicated CBCentralManager for 0x180D/0x2A37, off-@MainActor notification routing — v2.0 (WEAR-02 partial — no scan UI)
- ✓ Upload taxonomy: device_class: "HR_MONITOR", DeviceType::HrMonitor Rust variant, decoded hr/rr stream in upload payload — v2.0 (WEAR-03)
- ✓ BLE stability: FFI catch_unwind + panic=unwind; 24 MB storage cap; exponential reconnect backoff — v3.0
- ✓ HR monitor scan/connect UI + independent capture session — v3.0 (WEAR-04, WEAR-05, WEAR-06)
- ✓ WHOOP 4.0 RTC clock sync (BLE drift correction) — v3.0 (RTC-01)
- ✓ Recovery V2 dashboard with bridge-backed biometric data — v3.0 (DASH-01)
- ✓ pt-PT localisation (650+ static strings + dynamic status strings) — v3.0 (L10N-01, L10N-02)
- ✓ Recovery formula SDNN accuracy: rmssd_segment_aware, hkHRVSDNNMs rename, baseline normalisation — v3.0
- ✓ Deep link security: `allowsRemoteInvocation` guard blocks state-changing BLE commands — v4.0 (SEC-01)
- ✓ Full `@Observable` migration: GooseAppModel + HealthDataStore + GooseBLEClient; NavigationRequestObserver warning eliminated — v4.0 (PERF-01, PERF-02, PERF-03)
- ✓ Coach multi-provider: CoachProvider protocol; ChatGPT/Claude/Custom/Gemini; CoachProviderRegistry; provider picker UI — v4.0 (COACH-01 to COACH-06)
- ✓ pt-PT localisation for all v4.0 additions (128 new strings); onboarding skip button; startup non-blocking — v4.0 (L10N-03, PERF-04, UX-01)

### Validated (v5.0)

- ✓ HRV pipeline: rmssd_segment_aware BLE gap-aware, Lipponen-Tarvainen ectopic filter, tiered SWS window selection — v5.0 (ALG-HRV-01 to ALG-HRV-03; ALG-HRV-04 human gate pending)
- ✓ Recovery score v1: Z-score + logistic squash; EWMA baseline; cold-start gate; trust levels; Vermelho/Amarelo/Verde — v5.0 (ALG-REC-01 to ALG-REC-03)
- ✓ Calorias: Mifflin-St Jeor RMR; Keytel + H-B coefficients empirically validated — v5.0 (ALG-CAL-01, ALG-CAL-02)
- ✓ Strain: Tanaka HRmax + Banister TRIMP + fit_strain_denominator calibration helper — v5.0 (ALG-STR-01 to ALG-STR-03)
- ✓ Sleep metrics without staging: HR dip %, WASO, SOL, disturbance count; EWMA baseline engine — v5.0 (ALG-SLP-01, ALG-SLP-02)
- ✓ IMU data pipeline: I16SeriesSummary full_samples; gravity table schema v15; TOGGLE_IMU_MODE feature-flagged — v5.0 (IMU-01 to IMU-04)
- ✓ 4-class sleep staging: Cole-Kripke + cardiorespiratory features + physiological reimposition — v5.0 (ALG-SLP-03; ALG-SLP-04 human gate pending)
- ✓ body_hex excluded from K10/K21 cached JSON — v5.0 (PERF-05)
- ✓ Gen4 historical sync correctness fixes — v5.0 (SYNC-01 to SYNC-05)
- ✓ V24 biometric decode: SpO2, skin_temp, resp, gravity2; 4 new SQLite tables; uncalibrated flag — v5.0 (BIO-01 to BIO-04)
- ✓ Exercise detection: retroactive from HR+gravity, Karvonen zones, exercise_sessions table — v5.0 (EX-01 to EX-04)
- ✓ Upload sync: synced flag on 8 stream tables; two-namespace cursors; raw outbox prune invariant — v5.0 (SYNC-UP-01 to SYNC-UP-03)
- ✓ Readiness Engine: ACWR (7d/28d) + Foster monotony + 5-class level synthesis — v5.0 (RDY-01 to RDY-03)

### Validated (v6.0)

- ✓ Readiness Engine UI: Recovery dashboard mostra nível diário (rundown/strained/balanced/primed) — v6.0 (RDY-UI-01)
- ✓ Sleep Staging UI: hipnograma 4-class + AASM metrics no Sleep V2 — v6.0 (SLP-UI-01)
- ✓ V24 Biometrics UI: SpO2, skin temp, resp rate com badge "não calibrado" — v6.0 (BIO-UI-01)
- ✓ Exercise Sessions UI: lista de sessões detectadas em Esforço — v6.0 (EX-UI-01)
- ✓ Upload Sync UI: pending badge + Backfill + Agora no Servidor Remoto — v6.0 (SYNC-UI-01)
- ✓ IMU Step Detection UI: Steps card em Esforço com "via acelerómetro" — v6.0 (STEP-UI-01)
- ✓ Algorithm Alignment: recovery Z-score+logística, EWMA alpha 0.0483, Cole-Kripke 30s — v6.0 (ALG-ALIGN-01)
- ✓ HRV Parity Validation: synthetic fixtures criados; gate ALG-HRV-04 real overnight adiada para v7.0 — v6.0 (VAL-01)
- ✓ Sleep Staging Validation: synthetic fixtures criados; gate ALG-SLP-04 real overnight adiada para v7.0 — v6.0 (VAL-02)
- ✓ Raw BLE frame upload/import: trust-chain reconstruída via servidor; botão Import do servidor — v6.0
- ✓ Test Connection: verificação de auth inline (/healthz + /v1/devices) — v6.0
- ✓ pt-PT localização completa: 0 strings não traduzidas (era 49) — v6.0

### Validated (v8.0)

- ✓ Bug audit (v6.0–v7.0): 3 HIGH + 6 MEDIUM fixed; GooseRustBridge NSLock data race eliminated; main-thread FFI safety net added — v8.0 (AUDIT-01)
- ✓ BT Settings button: DeviceView opens iOS Bluetooth Settings directly — v8.0 (QT-01)
- ✓ CodeQL CI confirmed in .github/workflows/codeql.yml; HealthKit importer confirmed in MoreView — v8.0 (QT-02, QT-03)
- ✓ previewMissingData + applyPreviewState gated in #if DEBUG — v8.0 (SURF-01)
- ✓ HomeDashboardView: Device Status Card, Tools Grid, Evidence Footer — v8.0 (HOME-01, HOME-02, HOME-03)
- ✓ Coach score summaries grid (sleep/recovery/strain/stress) from live bridge — v8.0 (COACH-07)
- ✓ Daily journal with UserDefaults persistence, TextEditor, tag chips — v8.0 (COACH-08)
- ✓ Coach routes: Sleep Coach, Recovery Insights, Strain Guidance, Stress Guidance — v8.0 (COACH-09, COACH-10, COACH-11, COACH-12)
- ✓ Fabricated 55.0 bpm RHR baseline eliminated; real 7-night history or neutral 70.0 — v8.0 (BIO-05)
- ✓ Non-activity stress excludes HR samples within exercise session windows — v8.0 (ACT-01)
- ✓ Energy daily rollup persisted to SQLite via metrics.energy_daily_rollup — v8.0 (ENB-01)
- ✓ Calibration pipeline uses real train/holdout splits from calibration.evaluate_stored_labels — v8.0 (CAL-01)
- ✓ MorePrivacyView: ShareLink export + destructive confirmation for local data deletion — v8.0 (MORE-01)
- ✓ #Preview macros for HomeDashboardView (disconnected + populated) and More views — v8.0 (PREV-01)
- ✓ algorithmPreferences and referenceAlgorithmDefinitions wired to bridge catalog — v8.0 (HALG-01)
- ✓ bandSleepImportStatus replaces static "band sleep import not available" UI — v8.0 (BAND-01)
- ✓ Band-first sync: overnight poll loop removed; foreground-trigger + BGAppRefreshTask; cooldown guard — v8.0/v9.0 (Phase 60)

### Validated (v7.0)

- ✓ Upload route pair: POST /v1/ingest-frames + GET /v1/export/frames/{device_id} com cursor + auth — v7.0 (ROUTE-01, ROUTE-02)
- ✓ device_uuid end-to-end: CoreBluetooth UUID → raw_evidence + decoded_frames → servidor (bidirectional lookup) — v7.0 (DEVID-01, DEVID-02)
- ✓ Upload sync race fix: captureAllPendingRowIDs pré-HTTP; markStreamsSynced só após 2xx — v7.0 (SYNCR-01)
- ✓ HealthDataStore async migration: 60+ bridge calls → async/await; GCD queues removidos; zero sync calls @MainActor — v7.0 (ASYNC-01, ASYNC-02)
- ✓ V24History gravity extraction: gravity_x/y/z K18/K24 wired → gravity table → Cole-Kripke pipeline — v7.0 (SLP-SYNC-01 partial)
- ✓ Morning band sleep sync trigger: handleBLEConnectionStateChange → maybeScheduleMorningSleepSync → syncBandSleepHistory() — v7.0 (SLP-SYNC-02 partial)
- ✓ Sleep V2 "A aguardar sincronização" label confirmed in simulator — v7.0 (SLP-SYNC-03 partial)
- ✓ Algorithm defaults promoted: sleep v1, strain v1, recovery v1; readiness v1 added — v7.0

### Validated (v9.0)

- ✓ BLE bonding state machine: GooseBLEBondingManager 5-state (NotStarted/Started/Subscribed/Completed/Cancelled); bond-loss recovery; UserDefaults persistence — v9.0 (BLE-BOND-01)
- ✓ Per-sensor upload watermark: WatermarkType enum (rawFrames/decodedStreams); separate UserDefaults keys per type; atomic write on 2xx — v9.0 (UPLOAD-WM-01)
- ✓ NWPathMonitor upload gating: GooseNetworkMonitor; exponential backoff 1s/2s/4s/max 60s; isReachable published to GooseAppModel — v9.0 (NET-MON-01)
- ✓ GooseHRSanitizer: HR spike filter 25–220 BPM; onHRSpike callback; hrSpikeCount @MainActor — v9.0 (HR-SAN-01)
- ✓ StateMachine<State: Hashable, Event> generic type; GooseBLEBondingState migrated to Hashable — v9.0 (SM-01)

### Validated (v10.0)

- ✓ BLE5-03: GooseBLEHistoricalManager dedicated class — historical sync decoupled from GooseBLEClient — v10.0 (Phase 68)
- ✓ BLE5-04: GooseBLEDataValidator Swift struct — structural frame validation before Rust bridge — v10.0 (Phase 68)
- ✓ HAP-01: buzz(loops:) primitive via BLE cmd 0x13 on GooseBLEClient — v10.0 (Phase 70)
- ✓ HAP-03: Smart alarm UI in CoachSleepRouteView + writeAlarmCommand + buzz(loops:2) confirmation — v10.0 (Phase 73)
- ✓ FEAT-03: NotificationScheduler actor — sleep sync / workout detection / WHOOP battery ≤ 20% notifications — v10.0 (Phase 71)
- ✓ DATA-03: Stress/ANS tiles, TrendsDashboardView, ManualWorkoutEntrySheet on Phase 69 tables — v10.0 (Phase 72)
- ✓ DATA-04: HeartRateSeriesStore.decimatedSamples — stride/LTTB HR decimation for long sessions — v10.0 (Phase 71)

Known deferred (v10.0): BLE5-01/02 (hardware-gated — real WHOOP 5.0), HAP-02/DATA-02 (deferred), HAP-04 (RE-gated — BTSnoop + Ghidra), FEAT-01/02/ARCH-01 (partial), DATA-01 (schema migrated, Swift wiring partial)

### Validated (v11.0)

- ✓ Fork PR integration: UUID hiding in advanced sections, imperial/metric units, English source localisation, ChatGPT auth fix — v11.0 (PR-INT-01,03,04,05)
- ✓ Fork PR BLE/Sync: firmware-update device-info retry, honest warm-up progress, historical sync donut + protocol-driven completion — v11.0 (PR-INT-02,06,07)
- ✓ Upstream PR merge: main-thread offload, async FFI bridge calls, display-safety filter (scroll jitter eliminated) — v11.0 (PR-UP-01,02,03)
- ✓ Codebase map: 7 documents in `.planning/codebase/` covering architecture/stack/quality/concerns — v11.0 (AUDIT-01,02,03)
- ✓ Schema v21: covering indexes on metricSeries/journal/workout/appleDaily; lazy bridge init; BLE auth retry 2.5s — v11.0 (PERF-01,02,BLE-REL-01)
- ✓ Debug 3-tab split, Logs & Export rename, Breathe haptics (buzz/phase), live workout strain accumulator — v11.0 (POL-01,02,DEF-01,02)
- ✓ Resting HR floor: 30 bpm minimum in metric_features.rs (closes #130) — v11.0 (BUG-HR-01)
- ✓ Battery fix: R22 battery_pct in compact summary; 0xFF guard on 2A19 (closes #149) — v11.0 (BUG-BAT-01)
- ✓ HealthKit import persistence: scalars + 90-day history persisted to metric_series; restored on launch (closes #150) — v11.0 (BUG-HK-01)

Known deferred: Ph74/75 BLE device-gate tests; CAPSENSE-01, HAP-04, BLE5-01/02 hardware gates

### Validated (v12.0 — Code Health & Protocol Foundation)

- ✓ **BAT-01**: Gen4 WHOOP real battery % via Event-48 payload (offset 17, u16 LE / 10) — v12.0 (Phase 84)
- ✓ **BAT-02**: Gen4 GET_BATTERY_LEVEL command (cmd 26) response parsing as fallback path — v12.0 (Phase 84)
- ✓ **PROTO-01**: `WireProtocol { Gen4, Gen5 }` Rust enum replacing 17 string comparisons in Swift — v12.0 (Phase 83)
- ✓ **PROTO-02**: `DeviceKind { Whoop4, Whoop5, HrMonitor }` + `DeviceCapabilities` struct via bridge method — v12.0 (Phase 83)
- ✓ **PROTO-03**: DB migration normalising MAVERICK/PUFFIN → GOOSE; Swift `WhoopGeneration` → `connectedCapabilities` — v12.0 (Phase 83)
- ✓ **ARCH-01**: bridge.rs 509-arm dispatcher → `BridgeRouter` trait + per-domain handlers (metrics, sleep, capture, activity) — v12.0 (Phase 86)
- ✓ **ARCH-02**: store.rs 140 métodos → domain stores (SleepStore, CaptureStore, MetricsStore) + schema validation on open — v12.0 (Phase 87)
- ✓ **ARCH-03**: 133 `.unwrap()` → `Result<_, GooseError>` in bridge.rs + store.rs; `#[deny(clippy::unwrap_used)]` — v12.0 (Phase 85)
- ✓ **ARCH-04**: HealthDataStore owned by GooseAppModel (not AppShellView @StateObject); weak ref eliminated — v12.0 (Phase 88)
- ✓ **ARCH-05**: GooseBLEClient → `BLETransport` protocol + `BLESessionCoordinator` actor + `DeviceCatalog` — v12.0 (Phase 89)
- ✓ **ARCH-06**: GooseAppModel → domain `@Observable` objects (BLEState, SyncState, HealthState) — v12.0 (Phase 90)
- ✓ **COMM-01**: Protocol offset comments (WHOOP Event-48, cmd 26 layout) in Rust source — v12.0 (Phase 86)
- ✓ **COMM-02**: Threading invariant comments at bridge FFI boundary and GooseRustBridge usage sites — v12.0 (Phase 91)
- ✓ **COMM-03**: Algorithm coefficient comments (Banister eTRIMP, EWMA alpha, Cole-Kripke) in Rust source — v12.0 (Phase 91)

### Validated (v13.0 — Bug Fixes, Protocol Reliability, Device Coverage & HealthKit Export)

- ✓ **BUG-AUTH-01**: WHOOP 5.0 auth stuck state — 12-retry exhaustion counter + Reconnect/Cancel recovery alert — v13.0 (Phase 92)
- ✓ **BUG-EXP-01**: Export OOM — `writeManifestToDisk()` + `writeValidationSidecarsAfterManifest()` helpers; manifest passed by reference — v13.0 (Phase 92)
- ✓ **BUG-EXP-02**: `runFullRawExport()` safe export defaults preserved — v13.0 (Phase 92)
- ✓ **BUG-EXP-03**: Redundant `validate()` call in `createBundle()` removed — v13.0 (Phase 92)
- ✓ **BUG-EXP-04**: "Include Database" guard for DBs > 20 MB — v13.0 (Phase 92)
- ✓ **PROTO-V24**: `DataPacketBodySummary::V24History` variant alongside `NormalHistory` — v13.0 (Phase 93)
- ✓ **MG-01**: `WhoopMg` variant in `DeviceKind` + `DeviceCapabilities` with MG-specific flags — v13.0 (Phase 95)
- ✓ **MG-02**: Swift WHOOP MG name-based advertisement detection; `connectedCapabilities` updated; `onCapabilitiesUpdated` callback added to `BLETransport` — v13.0 (Phase 95)
- ✓ **BP-01**: 9 silent `try?` bridge calls → `do/catch` + `ble.record(level: .error, ...)` — v13.0 (Phase 96)
- ✓ **HK-01**: HR samples written to HealthKit (`HKQuantityTypeIdentifierHeartRate`) — v13.0 (Phase 97)
- ✓ **HK-02**: HRV written to HealthKit (`HKQuantityTypeIdentifierHeartRateVariabilitySDNN`) — v13.0 (Phase 97)
- ✓ **HK-03**: SpO2 written to HealthKit (`HKQuantityTypeIdentifierOxygenSaturation`) — v13.0 (Phase 97)
- ✓ **HK-04**: Sleep samples written to HealthKit (`HKCategoryTypeIdentifierSleepAnalysis`) — v13.0 (Phase 97)
- ✓ **HK-05**: HealthKit write toggle in More settings (opt-in, default off) — v13.0 (Phase 97)

### Active (v14.0 — Android Port, BLE Reliability & Protocol Depth)

**Historical Sync & BLE Reliability**
- [ ] **SYNC-08**: Gen5 historical routing fix — `historicalData` + `historicalIMUDataStream` dispatched to main handler when `isHistoricalSyncing == true`; 0 dropped body packets during active sync (#24)
- [ ] **SYNC-09**: Gen4 historical packet47 reassembly fix — no body dropped on service UUID `61080005` (#20)
- [ ] **SYNC-10**: HPS ring buffer fields (`ring_capacity`, `current_page`, `read_pointer`) parsed from `GET_DATA_RANGE` response; wrap-around detection implemented (#160)
- [ ] **SYNC-11**: `HISTORICAL_DATA_RESULT` ACK — device identity (8-byte payload) validated against connected device before accepting sync (#163)
- [ ] **SYNC-12**: HPS sync quality telemetry — throughput (bytes/s), burst duration, gap count logged per sync session (#162)
- [ ] **BLE-01**: MTU 247 requested + LE 2M PHY explicitly set on connect; effective MTU logged; throughput benefit measurable in sync speed (#159)
- [ ] **BLE-02**: Off-wrist detection via `GET_BODY_LOCATION_AND_STATUS` (cmd `0x54`); UI reflects on-wrist / off-wrist state (#161)

**Bug Fixes**
- [ ] **BUG-COACH-01**: Coach screen crash after setup — root cause identified and fixed; no crash on CoachView first load (#170)
- [ ] **GEN4-07**: Gen4 undecoded metrics — `respiratory_rate`, `skin_temp_delta_c`, HRV RR intervals decoded from Gen4 historical packet bytes; `MetricFeatures` populated (not always `None`) (#21)

**Protocol Cleanup (carried from v13.0)**
- [ ] **PROTO-08**: `PACKET_TYPE_*` constants → Rust enum with exhaustion check (`#[non_exhaustive]` or match guard) (#157)
- [ ] **PROTO-09**: Silent `_ => (None, vec![])` in `parse_data_packet_body_summary` → explicit arms with warning strings for unhandled `packet_k` values (#157)
- [ ] **PROTO-10**: `data_packet_domain()` and `parse_data_packet_body_summary()` in sync — every domain-annotated packet type gets a parse arm (#157)
- [ ] **PROTO-11**: Bridge routing → `CommandDefinition` registry; enum arms self-document expected decode path (#157)

**Android Port**
- [ ] **AND-01**: `android/` Kotlin/Compose project skeleton — 4-tab structure (Home/Health/Coach/More); `GooseBridge.kt` JNI wrapper with `System.loadLibrary("goose_core")` and `external fun handle(request: String): String` (#169)
- [ ] **AND-02**: Android BLE stack — `BluetoothGatt` connects to Gen4/Gen5/MG service UUIDs; packet framing + characteristic notification subscribe mirrors iOS `CoreBluetoothBLETransport` logic (#169)
- [ ] **AND-03**: Android historical sync — port `GooseBLEHistoricalManager` logic; `SYNC-08` routing fix applied; packet type 47 routed correctly on Android (#169)
- [ ] **AND-04**: Android metrics display + server upload — `GooseBridge.handle()` queries metrics; POST to configured server URL; parity with iOS v13.0 data surface (#169)
- [ ] **AND-05**: Android CI — `android-core.yml` APK build step uncommented; unsigned APK attached to GitHub releases on every `v*` tag (#169)

**Battery Level**
- [ ] **BAT-01**: Battery level displayed in iOS app for Gen4+Gen5 — event-48 (`~`every 8 min) + cmd-26 response + Gen5 R22 realtime all parsed; UI shows % (SEED-002)

**WHOOP MG Completion**
- [ ] **MG-03**: WHOOP MG historical sync fix — `#22` root cause (advertisement detection or sync routing) identified and fixed; detection hardened beyond name-only heuristic (SEED-006)

**Code Health**
- [ ] **ARCH-11**: Remaining 38 `.unwrap()` in production Rust replaced with `?` or `expect("invariant: …")`; 0 naked unwraps in non-test code (SEED-004 tail)
- [ ] **BP-03**: Rust SQLite connection pool — per-request `Connection::open()` eliminated in bridge handlers; `r2d2` or `deadpool` pool shared across calls (SEED-007 Gap 2)
- [ ] **AUDIT-01**: Bot audit findings (#59) verified against live codebase — `let_chains` syntax check, `partial_plan_state` and `EnergyCaptureValidationReport` completeness verified; genuine issues fixed

**Protocol Offset Comments**
- [ ] **COMM-04**: WHY comments at all empirical WHOOP byte offsets in Rust source — event-48 battery layout, cmd-26 response, Gen4 `61080005` characteristic framing, MG advertisement candidate byte (SEED-005)
- [ ] **COMM-05**: FFI safety contract comments at `goose_bridge_handle_json` (C FFI) and `Java_com_goose_core_GooseBridge_handle` (JNI) entry points (SEED-005)

### Deferred (hardware gate — sem device físico)

- [ ] ALG-HRV-04 / VAL-HRV-01: RMSSD cross-validated em ≥5 sessões overnight reais vs Python ref (delta ≤1 ms) — Phase 51
- [ ] ALG-SLP-04 / VAL-SLP-01: 4-class staging concordância ≥70% em ≥5 sessões overnight reais — Phase 51
- [ ] SLP-SYNC real-device: gravity offsets K24 confirmados contra captura real; "Sincronizado da pulseira" e2e — Phase 51
- [ ] CAPSENSE-01: Cap sense GATT UUID identification + on-wrist detection (WHPWhoopStrapOnWrist parity) — hardware gate; UUID not yet identified via Ghidra

### Out of Scope

- Upload queue persisted in SQLite to survive app restarts
- Background URLSession for upload when the app is suspended
- PRs back to upstream b-nnett/goose with fork fixes
- Server-side data analysis (dashboard, alerts) — out of scope
- Advanced authentication (OAuth, 2FA) — simple Bearer token is sufficient
- Offline mode — real-time is core value

## Context

- **Fork**: `tigercraft4/goose` is a fork of `https://github.com/b-nnett/goose`
- **Upstream open PRs**: #19 (rmssd_segment_aware, body_hex), #26 (Gen4 historical sync review)
- **my-whoop server**: `~/Documents/my-whoop/server/` — FastAPI, TimescaleDB; algorithm validation source at `~/Documents/my-whoop/server/ingest/app/analysis/`
- **Ghidra analysis**: WHOOP 5.37.0 IPA binary reverse-engineered (2026-06-01) — calorie coefficients confirmed (FINDINGS_5.md §GHIDRA-HB-01 + §GHIDRA-02)

## Constraints

- **iOS tech stack**: Swift / SwiftUI / URLSession — do not introduce external dependencies
- **Server tech stack**: FastAPI + TimescaleDB (maintain compatibility with existing my-whoop)
- **Git**: planning docs in git (commit_docs: true)
- **Server**: must run in Docker on the user's personal server

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Copy full server to server/ in Goose | Keep everything in one repo; simplify deployment with a single git pull | ✓ Good — v1.0 |
| Upload via native URLSession | No external iOS dependencies; URLSession is sufficient for POST JSON | ✓ Good — v1.0 |
| Simple Bearer token for server auth | Personal/private server; OAuth overhead unnecessary | ✓ Good — v1.0 |
| GOOSE_ prefix for env vars and containers | Aligned with fork repo; avoids confusion with my-whoop | ✓ Good — v1.0 |
| Docker named volumes (no DATA_ROOT) | Zero config for `docker compose up` | ✓ Good — v1.0 |
| mDNS .local for server hostname | Automatic LAN discovery; zero DNS config | ✓ Good — v1.0 |
| Phase ordering: Phase 17 @Observable before Phase 18 Coach | CoachView must consume @Observable pattern | ✓ Good — v4.0 |
| Four Coach providers in wave approach | Each provider independent; no merge conflicts on CoachProviderRegistry | ✓ Good — v4.0 |
| Google OAuth via WKWebView (no SDK) | Zero external dependency; user-supplied client_id; PKCE mandatory | ✓ Good — v4.0 |
| Inline L10N gap closure (9 strings, no new phase) | Faster than planning a new phase for 9-string fix | ✓ Good — v4.0 |

## Current Milestone: v14.0 — Android Port, BLE Reliability & Protocol Depth

**Goal:** Lançar Android (Kotlin/Compose + JNI, feature parity com iOS v13.0), fechar todos os bugs de historical sync em Gen4/Gen5, implementar BLE reliability (MTU, PHY, off-wrist), battery level, completar WHOOP MG, e limpar a protocol layer.

**Target features:**
- Historical sync: Gen5 routing fix (#24), Gen4 reassembly (#20), HPS ring buffer (#160), identity validation (#163), telemetry (#162)
- BLE reliability: MTU 247 + LE 2M PHY (#159), off-wrist detection (#161)
- Bug fixes: Coach crash (#170), Gen4 undecoded metrics (#21)
- Protocol cleanup: PROTO-08/09/10/11 (#157, carried from v13.0)
- Android port: android/ scaffold + JNI + BLE + sync + metrics + CI (#169)
- Battery level: event-48 + cmd-26 + R22 realtime (SEED-002)
- WHOOP MG: sync fix + detection hardened (#22, SEED-006)
- Code health: 38 unwraps → 0, connection pool, bot audit fixes (SEED-004 tail, SEED-007, #59)
- Comments: protocol offsets + FFI safety contracts (SEED-005)

---
*Last updated: 2026-06-20 after v13.0 milestone*

## Evolution

This document evolves at phase transitions and milestone checkpoints.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to record? → Add to Key Decisions
5. "What This Is" still accurate? → Update if it has drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Out of Scope audit — are the reasons still valid?
4. Update Context with current state
