# Goose — Multi-Device Biometric Platform

## What This Is

Fork of `b-nnett/goose`: an iOS app (SwiftUI + Rust core) that reads biometric data from WHOOP devices via BLE and persists it on a self-hosted server.
v1.0 delivered: FastAPI+TimescaleDB server, automatic iOS→server upload, integration of the 9 upstream PRs.
v2.0 expands: full WHOOP 4.0 (Gen4) support in the iOS app, foundations for an Android port via JNI, and validation of pipeline extensibility for additional wearables.
v3.0 completes: HR monitor UX (scan UI, independent capture session), device_id filter fix, Recovery V2 dashboard, pt-PT localisation, and WHOOP 4.0 RTC clock sync.

## Current Milestone: v3.0 Wearable UX, CI Hardening & RTC Sync

**Goal:** Complete the HR monitor UX (scan UI, independent capture session), fix CR-02 device_id filter, deliver Recovery V2 dashboard, add pt-PT localisation, and sync the WHOOP 4.0 clock via BLE (upstream issue #17).

**Target features:**
- HR monitor scan/connect UI (WEAR-02 completion — no scan UI in v2.0)
- HR monitor independent capture session (not gated on WHOOP session)
- CR-02 real per-row device_id filter (v2.0 reverted to no-op)
- Recovery V2 dashboard with bridge-backed data
- Multi-language support (pt-PT localisation)
- WHOOP 4.0 RTC sync — send current time via BLE to fix clock drift (upstream issue #17)
- BLE reconnect backoff — exponential backoff + 10-attempt circuit breaker (upstream PR #18)
- BLE reconnection backoff — exponential backoff + 10-attempt circuit breaker (upstream PR #18)

## Core Value

The user must be able to capture WHOOP data on iPhone and have it persisted automatically on their personal server — without depending on external infrastructure.

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

### Validated (v2.0)

- ✓ WHOOP 4.0 (Gen4): iOS app layer — command guards, generation field, onboarding, device view, upload device_generation "4.0" — v2.0 (GEN4-01 to GEN4-05)
- ✓ Android Port Foundations: Rust core compiles to aarch64-linux-android via cargo-ndk; JNI shim; panic=abort; ADR — v2.0 (ANDROID-01 to ANDROID-03)
- ✓ Server CI: pytest suite runs on GitHub Actions with real TimescaleDB container — v2.0 (CI-01)
- ✓ Rust 0x2A37 HR parser: `heart_rate_gatt_protocol.rs` with 10 integration tests — v2.0 (WEAR-01)
- ✓ iOS BLE HR monitor: dedicated CBCentralManager for 0x180D/0x2A37, off-@MainActor notification routing — v2.0 (WEAR-02 partial — no scan UI)
- ✓ Upload taxonomy: device_class: "HR_MONITOR", DeviceType::HrMonitor Rust variant, decoded hr/rr stream in upload payload — v2.0 (WEAR-03)

### Active (v3.0)

- [ ] HR monitor scan/connect UI — `startHRMonitorScan()` has no caller, `discoveredHRDevices` not rendered (WEAR-02 completion)
- [ ] HR monitor independent capture session — frames currently gated on WHOOP activeHealthPacketCapture
- [ ] CR-02 real per-row device_id filter — reverted to no-op in v2.0 (namespace mismatch)
- [ ] Recovery V2 dashboard with bridge-backed data (phase 999.4)
- [ ] pt-PT localisation — multi-language support
- [ ] WHOOP 4.0 RTC sync — send current time via BLE to fix clock drift (upstream issue #17)
- [ ] BLE reconnect backoff — exponential backoff + 10-attempt circuit breaker (upstream PR #18); apply to both WHOOP and HR monitor delegates
- [ ] FFI panic safety — `catch_unwind` + `panic = "unwind"` in release so panics return JSON error instead of crashing (upstream PR #19)
- [ ] Storage retention cap — reduce raw evidence retention from 512 MB to 24 MB to prevent SQLite bloat on large history syncs (upstream PR #19)

### Deferred (v3+)

- [ ] Upload queue persisted in SQLite to survive app restarts
- [ ] Background URLSession for upload when the app is suspended
- [ ] PRs back to upstream b-nnett/goose with fork fixes

### Out of Scope

- Server-side data analysis (dashboard, alerts) — out of scope
- Advanced authentication (OAuth, 2FA) — simple Bearer token is sufficient
- Full Android app — architecture foundations only in v2.0

## Context

- **Fork**: `tigercraft4/goose` is a fork of `https://github.com/b-nnett/goose`
- **Upstream open PRs (9)**: #1 (fix timeout/duration), #3 (FFI docs), #4 (scroll perf), #5 (Apple Health), #6 (Rust CI), #7 (list_methods RPC), #10 (CI + bug fixes), #12 (FFI threading), #13 (Windows compat)
- **Upstream open issues (5)**: #2 (Android discussion), #8 (WHOOP 4.0?), #9 (multiplatform), #11 (License + Gen4), #17 (RTC clock sync WHOOP 4.0)
- **my-whoop server**: already exists at `/Users/francisco/Documents/my-whoop/server/` — FastAPI, TimescaleDB, Dockerfile, docker-compose.yml
- **Server API**: `POST /v1/ingest-decoded` with Bearer token, receives already-decoded data
- **iOS upload**: GooseSwift already has `remote_bind_enabled` as a placeholder but without upload implementation

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
| GOOSE_ prefix (instead of WHOOP_) for env vars and containers | Aligned with the fork repo; avoids confusion with the original my-whoop | ✓ Good — v1.0 |
| Docker named volumes (no DATA_ROOT) | Zero config for `docker compose up`; simpler for self-hosted | ✓ Good — v1.0 |
| mDNS .local for server hostname | Automatic discovery on the local network; zero DNS config | ✓ Good — v1.0 |
| PR #12 FFI threading integrated last | After Phases 2+3+4 executed; no conflict with upload client | ✓ Good — v1.0 |

## Current State (v2.0)

**Shipped:** 2026-06-04
- WHOOP Gen4 iOS support: `WearableDescriptor.whoopGen4`, `GooseDiscoveredDevice.generation`, Gen4 upload path
- Android JNI foundations: `Rust/core/src/bridge.rs` android module, `Cargo.toml` cfg-gates, CI job
- Standard HR GATT support: `heart_rate_gatt_protocol.rs`, `GooseBLEClient+HRMonitor.swift`, upload hr/rr stream
- Gap closure Phase 8.1: `capture_import.rs` HrMonitor branch, `unix_from_iso8601` helper
- 89 files modified, +8011 lines, 11 plans

**v1.0 baseline** (shipped 2026-06-03): FastAPI+TimescaleDB server, iOS upload client, 9 upstream PRs integrated

**Known deferred (v3.0):** HR monitor scan UI, independent capture session, CR-02 per-row filter

---
*Last updated: 2026-06-04 — v3.0 milestone started*

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
