# Goose — Multi-Device Biometric Platform

## What This Is

Fork of `b-nnett/goose`: an iOS app (SwiftUI + Rust core) that reads biometric data from WHOOP devices via BLE and persists it on a self-hosted server.
v1.0 delivered: FastAPI+TimescaleDB server, automatic iOS→server upload, integration of 9 upstream PRs.
v2.0 expanded: full WHOOP 4.0 (Gen4) support, Android JNI foundations, standard HR GATT pipeline.
v3.0 completed: HR monitor scan UI + independent capture, BLE stability, Recovery V2 dashboard, pt-PT localisation, WHOOP 4.0 RTC sync, SDNN accuracy fix.
v4.0 delivered: URL scheme security (deep link guard), full `@Observable` migration, four-provider Coach (ChatGPT/Claude/Custom/Gemini), complete pt-PT localisation for v4.0 strings.
v5.0 shipped (2026-06-08): Validated algorithm pipeline — HRV (BLE-gap-aware RMSSD + Lipponen-Tarvainen filter), Sleep staging (Cole-Kripke scale=0.001 + 4-class), Strain/Calories (Ghidra-confirmed Keytel/H-B coefficients), V24 biometric decode (SpO2/skin_temp/resp/gravity2), Exercise detection (retroactive, Karvonen zones), Upload sync (synced flag + cursors), Readiness Engine (ACWR + Foster monotony). Schema v19. 128 Rust tests. 9 audit HIGH findings fixed.

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

### Active (v5.0)

- [ ] HRV pipeline accuracy: rmssd_segment_aware extended for BLE gaps > 3 s; Lipponen-Tarvainen ectopic filter; tiered SWS window selection (ALG-HRV-01 to ALG-HRV-04)
- [ ] Recovery score Z-score + logistic model: EWMA baseline; cold-start gate; trust levels; Vermelho/Amarelo/Verde bands (ALG-REC-01 to ALG-REC-03)
- [ ] Calorias — Mifflin-St Jeor RMR; Keytel + Harris-Benedict coefficients validated against WHOOP 5.37.0 binary (Ghidra MCP) (ALG-CAL-01, ALG-CAL-02)
- [ ] Strain — Tanaka HRmax + Banister TRIMP + personal denominator calibration (ALG-STR-01 to ALG-STR-03)
- [ ] Sleep metrics without staging: HR dip %, WASO, SOL, REM latency, disturbance count (ALG-SLP-01, ALG-SLP-02)
- [ ] IMU data pipeline: I16SeriesSummary full samples; gravity table in SQLite; TOGGLE_IMU_MODE_ON/OFF in startCapture (IMU-01 to IMU-04)
- [ ] 4-class sleep staging: Cole-Kripke + cardiorespiratory features + physiological reimposition (ALG-SLP-03, ALG-SLP-04)
- [ ] body_hex storage optimization: exclude body_hex from K10/K21 cached JSON (PERF-05)
- [ ] Gen4 historical sync upstream fixes: retain inversion, wrapping overflow, padding, confinement, UUID normalisation (SYNC-01 to SYNC-05)

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

## Current State (v4.0)

**Shipped:** 2026-06-06
- Deep link security: `allowsRemoteInvocation` guard in GooseAppModel+Lifecycle.swift (SEC-01)
- @Observable migration: 68 @Published removed; `@Environment(GooseAppModel.self)` throughout; per-property SwiftUI re-render (PERF-01/02/03)
- Coach multi-provider: CoachProvider protocol + CoachProviderRegistry + 4 providers + CoachSettingsSheet picker (COACH-01–06)
- pt-PT complete: 128 new strings; onboarding Keychain fix; startup unblocked (L10N-03, PERF-04, UX-01)
- 148 Swift files, 73 Rust files
- Known deferred: COACH-06 device migration test, 4 streaming provider runtime tests, PERF-03 runtime confirmation, 3 localisation device tests

**v3.0 baseline** (shipped 2026-06-05): HR monitor UX, BLE stability, Recovery V2, pt-PT infrastructure, WHOOP 4.0 RTC sync, SDNN accuracy

---
*Last updated: 2026-06-06 — v4.0 milestone shipped*

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
