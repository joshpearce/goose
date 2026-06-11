# Goose — Multi-Device Biometric Platform

## What This Is

Fork of `b-nnett/goose`: an iOS app (SwiftUI + Rust core) that reads biometric data from WHOOP devices via BLE and persists it on a self-hosted server.
v1.0 delivered: FastAPI+TimescaleDB server, automatic iOS→server upload, integration of 9 upstream PRs.
v2.0 expanded: full WHOOP 4.0 (Gen4) support, Android JNI foundations, standard HR GATT pipeline.
v3.0 completed: HR monitor scan UI + independent capture, BLE stability, Recovery V2 dashboard, pt-PT localisation, WHOOP 4.0 RTC sync, SDNN accuracy fix.
v4.0 delivered: URL scheme security (deep link guard), full `@Observable` migration, four-provider Coach (ChatGPT/Claude/Custom/Gemini), complete pt-PT localisation for v4.0 strings.
v5.0 shipped (2026-06-08): Validated algorithm pipeline — HRV (BLE-gap-aware RMSSD + Lipponen-Tarvainen filter), Sleep staging (Cole-Kripke scale=0.001 + 4-class), Strain/Calories (Ghidra-confirmed Keytel/H-B coefficients), V24 biometric decode (SpO2/skin_temp/resp/gravity2), Exercise detection (retroactive, Karvonen zones), Upload sync (synced flag + cursors), Readiness Engine (ACWR + Foster monotony). Schema v19. 128 Rust tests. 9 audit HIGH findings fixed.
v6.0 shipped (2026-06-09): All v5.0 Rust algorithms wired to SwiftUI dashboards — Readiness Engine, Sleep Staging (4-class hypnogram + AASM), V24 Biometrics, Exercise Sessions, Upload Sync UI, IMU Step Detection. Algorithm alignment: recovery Z-score weights, EWMA 14-night alpha, Cole-Kripke 30s epochs. Raw BLE frame upload/import (trust-chain). Test Connection + Import do servidor UI. 0 untranslated pt-PT strings.
v7.0 shipped (2026-06-10): Sync correctness + async migration — upload route pair complete (POST /v1/ingest-frames + GET export), device_uuid end-to-end (CoreBluetooth → SQLite → server), upload sync race fix (pre-capture rowIDs), HealthDataStore full async/await migration (60+ calls, GCD removed), morning band sleep sync (gravity K18/K24 extraction → Cole-Kripke → external_sleep_sessions). Algorithm defaults promoted to v1. Phase 51 (real-device validation) deferred — hardware gate.

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
- ✓ Calorias: Mifflin-St Jeor RMR; Keytel + H-B coefficients Ghidra-confirmed — v5.0 (ALG-CAL-01, ALG-CAL-02)
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

### Active (v10.0 — Protocol Parity, Haptics & Feature Completeness)

- [ ] BLE5-01: WHOOP 5.0 R22 packet parsing — fix missing metrics for WHOOP 5.0 users (issue #92)
- [ ] BLE5-02: V18 per-second historical decode + stale-clock dedup
- [ ] BLE5-03: GooseBLEHistoricalManager dedicated class — decouple historical sync from GooseBLEClient
- [ ] BLE5-04: Swift-side BLE data validator before Rust/SQLite ingestion
- [ ] HAP-01: buzz(loops:) primitive via cmd 0x13 — prerequisite for all haptic features
- [ ] HAP-02: Breathe screen + AdvancedHaptic/HapticHeartbeat paced vibration
- [ ] HAP-03: Smart alarm via BLE-commanded strap vibration
- [ ] HAP-04: Wake-window engine: sleep state polling + autonomous haptic at optimal moment
- [ ] FEAT-01: Coach VOW messages — contextual nudges computed from bridge data in Coach tab
- [ ] FEAT-02: NoopApp features: Breathe UI, Interval Timer, Metric Explorer
- [ ] FEAT-03: iOS local notifications: sleep summary, workout detection, WHOOP battery
- [ ] DATA-01: 4 SQLite tables: journal (daily behaviours), workout (sport-tagged log), appleDaily (HealthKit provenance), metricSeries (schema-free)
- [ ] DATA-02: Realtime strain accumulation — live Swift-side accumulator mirroring WHPBiotelemetry
- [ ] DATA-03: Stress/ANS view, Long-range Trends dashboard, Manual Workout Entry (3 SwiftUI screens)
- [ ] DATA-04: HR sample decimation for HeartRateSeriesStore (memory + chart performance)
- [ ] ARCH-01: Protocol-based service layer + mock infrastructure for unit testing

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
- Full Android app — architecture foundations only in v2.0
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

## Current Milestone: v10.0 Protocol Parity, Haptics & Feature Completeness

**Goal:** Close WHOOP 5.0 protocol gaps (R22/v18 packets, historical manager refactor), activate haptic hardware commands on the strap (buzz, Breathe, smart alarm, wake-window), and deliver the deferred feature completeness items from v9.0 seeds (Coach VOW, NoopApp features, iOS notifications, SQLite tables, Stress/Trends screens, HR decimation, service layer DI).

**Target features:**
- BLE5-01 to BLE5-04: WHOOP 5.0 R22/v18 protocol support + GooseBLEHistoricalManager + data validator
- HAP-01 to HAP-04: Haptic buzz primitive + Breathe screen + smart alarm + wake-window engine
- FEAT-01 to FEAT-03: Coach VOW messages + NoopApp features + iOS local notifications
- DATA-01 to DATA-04: 4 SQLite tables + realtime strain + Stress/Trends screens + HR decimation
- ARCH-01: Protocol-based service layer + mock infrastructure

---
*Last updated: 2026-06-11 after v9.0 milestone*

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
