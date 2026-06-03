# Goose — Multi-Device Biometric Platform

## What This Is

Fork of `b-nnett/goose`: an iOS app (SwiftUI + Rust core) that reads biometric data from WHOOP devices via BLE and persists it on a self-hosted server.
v1.0 delivered: FastAPI+TimescaleDB server, automatic iOS→server upload, integration of the 9 upstream PRs.
v2.0 expands: full WHOOP 4.0 (Gen4) support in the iOS app, foundations for an Android port via JNI, and validation of pipeline extensibility for additional wearables.

## Current Milestone: v2.0 Multi-Device & Platform Foundations

**Goal:** Expand the app beyond the WHOOP 5.0 — full Gen4 support, foundations for an Android port, and validation of pipeline extensibility for new wearables.

**Target features:**
- WHOOP 4.0 (Gen4): onboarding recognises Gen4, BLE scan includes the Gen4 UUID, frames captured and uploaded with device_generation "4.0"
- Android Port Foundations: Rust core compiles to aarch64-linux-android, FFI bridge documented for JNI, architecture ADR
- Additional Wearables: second wearable type supported E2E (BLE→SQLite→upload) with a separate Rust module

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

### Active (v2.0)

- [ ] WHOOP 4.0 (Gen4): onboarding + BLE scan + capture + upload (GEN4-01 to GEN4-05)
- [ ] Android Port Foundations: Rust core JNI-ready + FFI docs + ADR (ANDROID-01 to ANDROID-03)
- [ ] Additional Wearables: second wearable E2E + separate Rust module (WEAR-01 to WEAR-03)

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
- **Upstream open issues (4)**: #2 (Android discussion), #8 (WHOOP 4.0?), #9 (multiplatform), #11 (License + Gen4)
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

## Current State (v1.0)

**Shipped:** 2026-06-03
- `server/` — FastAPI+TimescaleDB self-hosted, multi-stage Docker, named volumes, GOOSE_* prefix
- `GooseSwift/RemoteServerPersistence.swift` — URL (UserDefaults), Bearer token (Keychain), upload toggle
- `GooseSwift/MoreRemoteServerViews.swift` — configuration UI + status feedback in the More tab
- `GooseSwift/GooseUploadService.swift` — automatic upload with 1s/2s/4s retry
- `GooseSwift/GooseAppModel+Upload.swift` — hook into the BLE pipeline + health check on startup
- 9 upstream PRs integrated (including PR #12 FFI threading)

**E2E pending:** `docker compose up --build` in `server/` + curl /healthz (requires active Docker Desktop)
**Hardware pending:** BLE→upload→TimescaleDB flow (requires physical WHOOP + active server)

---
*Last updated: 2026-06-03 — v2.0 milestone started*

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
