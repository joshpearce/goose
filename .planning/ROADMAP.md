# Roadmap: Goose

## Milestones

- ✅ **v1.0 Remote Server + Upstream PRs** — Phases 1-5 (shipped 2026-06-03)
- ✅ **v2.0 Multi-Device & Platform Foundations** — Phases 6-8+8.1 (shipped 2026-06-04)
- ✅ **v3.0 Wearable UX, CI Hardening & RTC Sync** — Phases 9-15 (shipped 2026-06-05)
- ✅ **v4.0 Security, Performance & Coach Expansion** — Phases 16-19 (shipped 2026-06-06)
- 📋 **v5.0 Metrics Accuracy, IMU & Upstream Fixes** — Phases 20-32 (backlog)

## Phases

<details>
<summary>✅ v1.0 Remote Server + Upstream PRs (Phases 1-5) — SHIPPED 2026-06-03</summary>

- [x] Phase 1: Server Infrastructure (3/3 plans) — completed 2026-06-03
- [x] Phase 2: iOS Server Settings (2/2 plans) — completed 2026-06-03
- [x] Phase 3: iOS Upload Client (3/3 plans) — completed 2026-06-03
- [x] Phase 4: Upload Status Feedback (2/2 plans) — completed 2026-06-03
- [x] Phase 5: Upstream PR Integration (4/4 plans) — completed 2026-06-03

Full details: `.planning/milestones/v1.0-ROADMAP.md`

</details>

<details>
<summary>✅ v2.0 Multi-Device & Platform Foundations (Phases 6-8+8.1) — SHIPPED 2026-06-04</summary>

- [x] Phase 6: WHOOP Gen4 iOS Support (3/3 plans) — completed 2026-06-03
- [x] Phase 7: Android Port Foundations + CI (4/4 plans) — completed 2026-06-03
- [x] Phase 8: Additional Wearables E2E (4/4 plans) — completed 2026-06-03
- [x] Phase 8.1: Gap closure WEAR-01/WEAR-03 (2/2 plans) — completed 2026-06-04

Full details: `.planning/milestones/v2.0-ROADMAP.md`

Known deferred: WEAR-02 scan UI (v3.0), CR-02 per-row filter (v3.0), hardware BLE tests (no device)

</details>

<details>
<summary>✅ v3.0 Wearable UX, CI Hardening & RTC Sync (Phases 9-15) — SHIPPED 2026-06-05</summary>

- [x] Phase 9: BLE Stability & Data Integrity (4/4 plans) — completed 2026-06-04
- [x] Phase 10: HR Monitor Scan/Connect UI (3/3 plans) — completed 2026-06-05
- [x] Phase 10.1: BLE Main-Thread Publishing Fix (1/1 plans) — completed 2026-06-05
- [x] Phase 11: HR Monitor Independent Capture (2/2 plans) — completed 2026-06-05
- [x] Phase 12: WHOOP 4.0 RTC Clock Sync (1/1 plans) — completed 2026-06-05
- [x] Phase 13: Recovery V2 Dashboard (1/1 plans) — completed 2026-06-05
- [x] Phase 14: pt-PT Localisation (4/4 plans) — completed 2026-06-05
- [x] Phase 15: Recovery Formula V2 SDNN (1/1 plans) — completed 2026-06-05

Full details: `.planning/milestones/v3.0-ROADMAP.md`

</details>

<details>
<summary>✅ v4.0 Security, Performance & Coach Expansion (Phases 16-19) — SHIPPED 2026-06-06</summary>

- [x] Phase 16: Deep Link Security (1/1 plans) — completed 2026-06-05
- [x] Phase 17: @Observable Migration (4/4 plans) — completed 2026-06-05
- [x] Phase 18: Coach Multi-Provider (6/6 plans) — completed 2026-06-06
- [x] Phase 19: pt-PT Localisation Completion (1/1 plans) — completed 2026-06-06

Full details: `.planning/milestones/v4.0-ROADMAP.md`

Known deferred: COACH-06 device migration test, 4 streaming provider runtime tests, 3 localisation device tests

</details>

<details>
<summary>📋 v5.0 Metrics Accuracy, IMU & Upstream Fixes (Phases 20-32) — BACKLOG</summary>

- [x] **Phase 20: Upstream Fixes & Storage** (2/2 plans) — SYNC-01 ✓, SYNC-02 ✓, SYNC-03 ✓, SYNC-04 ✓, SYNC-05 ✓, PERF-05 ✓
- [x] **Phase 21: IMU Data Foundation** (2/2 plans) — IMU-01 ✓, IMU-02 ✓ (IMU-03, IMU-04 deferred)
- [~] **Phase 22: HRV Accuracy** (3/3 plans done) — ALG-HRV-01 ✓, ALG-HRV-02 ✓, ALG-HRV-03 ✓, ALG-HRV-04 manual gate pending
- [~] **Phase 23: Strain & Calories** (2/3 plans) — ALG-STR-01 ✓, ALG-STR-02 ✓, ALG-STR-03 ✓, ALG-CAL-01 pending, ALG-CAL-02 pending
- [ ] **Phase 24: Sleep Metrics Without Staging + Baselines** — ALG-SLP-01, ALG-SLP-02
- [ ] **Phase 25: Recovery Score v1** — ALG-REC-01, ALG-REC-02, ALG-REC-03
- [ ] **Phase 26: Sleep Staging** — ALG-SLP-03, ALG-SLP-04
- [ ] **Phase 27: V24 Biometric Decode** — BIO-01, BIO-02, BIO-03, BIO-04
- [ ] **Phase 28: Exercise Detection** — EX-01, EX-02, EX-03, EX-04
- [ ] **Phase 29: Upload Sync Infrastructure** — SYNC-UP-01, SYNC-UP-02, SYNC-UP-03
- [ ] **Phase 30: Readiness Engine** — RDY-01, RDY-02, RDY-03
- [ ] **Phase 31: Protocol Corrections (noop)** — PROTO-01, PROTO-02, PROTO-03
- [ ] **Phase 32: HRV Parity Validation** — VAL-01

</details>

## Phase Details

### Phase 9: BLE Stability & Data Integrity

**Goal**: BLE connections are resilient, HR monitor frames are stored with correct per-row device identifiers, FFI panics return JSON errors instead of crashing, and storage growth is bounded
**Depends on**: Phase 8.1 (v2.0 complete)
**Requirements**: FIX-01, FIX-02, FIX-03, FIX-04, FIX-05
**Success Criteria** (what must be TRUE):

  1. HR monitor frames written to the database contain a non-NULL `device_id` matching the connected HR monitor device
  2. After a WHOOP disconnection, the app retries with exponential backoff (1 s base, doubles, 60 s cap) and stops after 10 attempts, showing attempt count in the UI
  3. After an HR monitor disconnection, the same backoff parameters apply and the UI reflects reconnect state
  4. User can tap a manual retry button to restart reconnection at any time, and a stop button to abort it
  5. A Rust panic in the FFI layer returns a structured JSON error instead of terminating the app process
  6. Raw evidence payload retention is capped at 24 MB; a large history sync does not balloon the SQLite database**Plans**: 4 plans

**Wave 1**

  - [x] 09-01-PLAN.md — FFI panic safety (catch_unwind + panic=unwind) and storage.compact_raw_evidence bridge method (FIX-04, FIX-05 Rust)

**Wave 2** *(blocked on Wave 1 completion)*

  - [x] 09-02-PLAN.md — Propagate active_device_id into capture_sessions (FIX-01 Rust/CR-02)

**Wave 3** *(blocked on Wave 2 completion)*

  - [x] 09-03-PLAN.md — ReconnectBackoff + WHOOP reconnect UI + storage compaction call sites + active_device_id arg (FIX-02, FIX-05 Swift, FIX-01 Swift)

**Wave 4** *(blocked on Wave 3 completion)*

  - [x] 09-04-PLAN.md — HR monitor reconnect backoff + ConnectionView HR row (FIX-03)

### Phase 10: HR Monitor Scan/Connect UI

**Goal**: Users can discover and connect nearby HR monitors from within the app
**Depends on**: Phase 9
**Requirements**: WEAR-04, WEAR-05
**Success Criteria** (what must be TRUE):

  1. User can initiate an HR monitor scan from the app and see a live list of discovered devices showing device name and RSSI
  2. The scan list updates in real time as devices appear and disappear
  3. User can tap a device in the list to initiate a connection to that HR monitor
  4. The UI shows connection progress and confirms when the HR monitor is connected

**Plans**: 3 plans
**UI hint**: yes

Plans:

- [x] 10-01-PLAN.md — Promote HR monitor BLE state to @Published, add connecting/disconnect/fail handling, test scaffold
- [x] 10-02-PLAN.md — Build HRMonitorView (scan list, connect sheet, connected panel) + on-device verification
- [x] 10-03-PLAN.md — Wire HRMonitorView into the More tab Device section (MoreRoute.hrMonitor)

### Phase 10.1: BLE Main-Thread Publishing Fix (INSERTED)

**Goal:** All `@Published` property mutations in `GooseBLEClient+Commands.swift` and `GooseBLEClient+Parsing.swift` happen on the main thread, eliminating the runtime "Publishing changes from background threads" warnings produced by CoreBluetooth callbacks.
**Requirements**: BLE-MT-01, BLE-MT-02, BLE-MT-03
**Depends on:** Phase 10
**Plans:** 1/1 plans complete
**Success Criteria** (what must be TRUE):

  1. No "Publishing changes from background threads is not allowed" runtime warnings appear when the app is connected to a WHOOP or HR monitor
  2. `updateConnectionState`, `updateActiveDeviceName`, and all other `@Published`-mutating methods in `GooseBLEClient+Commands.swift` dispatch mutations to the main thread
  3. `GooseBLEClient+Parsing.swift` line 430 equivalent mutation is also dispatched to main thread
  4. No existing BLE behaviour or reconnect logic is broken

Plans:

- [x] 10.1-01-PLAN.md — Main-thread guards on all @Published mutators in GooseBLEClient+Commands.swift and +Parsing.swift; resolve duplicate updateReconnectState warning; cargo test -p goose-core gate

### Phase 11: HR Monitor Independent Capture

**Goal**: Users can run an HR monitor capture session without requiring an active WHOOP session
**Depends on**: Phase 9, Phase 10
**Requirements**: WEAR-06
**Success Criteria** (what must be TRUE):

  1. HR monitor frames are captured and stored when no WHOOP session is active
  2. HR monitor capture starts and stops independently of the WHOOP session lifecycle
  3. Captured HR monitor data (BPM and RR intervals) appears in the upload payload regardless of WHOOP session state

**Plans**: 2 plans

**Wave 1**

  - [x] 11-01-PLAN.md — Add .hrMonitor capture mode + startHRMonitorCapture/stopHRMonitorCapture without WHOOP gate (D-01, D-03)

**Wave 2** *(blocked on Wave 1 completion)*

  - [x] 11-02-PLAN.md — Auto-start/stop on hrConnectionState via onHRConnectionStateChange callback + D-04 upload verification + cargo test gate (D-02, D-04)

### Phase 12: WHOOP 4.0 RTC Clock Sync

**Goal**: WHOOP 4.0 clock drift is automatically corrected after each BLE connection
**Depends on**: Phase 9
**Requirements**: RTC-01
**Success Criteria** (what must be TRUE):

  1. After connecting a WHOOP 4.0, the app automatically reads the device clock and compares it to iPhone time
  2. When drift exceeds the configured threshold, the app writes the current iPhone time to the WHOOP 4.0 via BLE
  3. The sync is silent (no user prompt required) and does not interrupt normal BLE data capture

**Plans**: TBD

### Phase 13: Recovery V2 Dashboard

**Goal**: Users can view a live Recovery V2 dashboard with bridge-backed biometric data
**Depends on**: Phase 9
**Requirements**: DASH-01
**Success Criteria** (what must be TRUE):

  1. User can see a hero recovery score on the Recovery V2 dashboard derived from live bridge data
  2. User can see current HRV and resting heart rate values, not placeholder zeros
  3. User can see a 7-day trend of recovery scores on the dashboard

**Plans**: TBD
**UI hint**: yes

### Phase 14: pt-PT Localisation

**Goal**: All user-visible text in the app is presented in European Portuguese
**Depends on**: Phase 10, Phase 11, Phase 13 (all UI stable)
**Requirements**: L10N-01, L10N-02
**Success Criteria** (what must be TRUE):

  1. All static UI text strings are stored in a `Localizable.xcstrings` String Catalog and rendered in pt-PT when the device language is Portuguese (Portugal)
  2. Dynamic status strings (BLE connection state, sync state, upload state) displayed in the UI appear in pt-PT
  3. No hardcoded English text remains visible in the main user-facing UI flows

**Plans**: 4 plans
**UI hint**: yes

**Wave 1**

- [x] 14-01-PLAN.md — Infrastructure: create Localizable.xcstrings, register pt-PT in project.pbxproj, fix GooseAppTab.title + MoreRoute.title/subtitle to String(localized:), translate tab + More-route titles/subtitles (L10N-01)

**Wave 2** *(blocked on Wave 1 completion — shared Localizable.xcstrings)*

- [x] 14-02-PLAN.md — Static catalog translations: Home dashboard, Health families (Recovery V2, Sleep V2, Cardio, Strain, Stress), Coach view (~150 strings) (L10N-01)

**Wave 3** *(blocked on Wave 2 completion — shared Localizable.xcstrings)*

- [x] 14-03-PLAN.md — Static catalog translations: More tab, Connection/Device/HR Monitor, Capture/Debug/Raw Export, Onboarding (~150 strings) (L10N-01)

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 14-04-PLAN.md — LocalizedStatusStrings.swift (14 @Published display extensions, D-04) + display-site rewiring + MoreStatusKind.title + final sweep + xcodebuild verification (L10N-02)

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Server Infrastructure | v1.0 | 3/3 | Complete | 2026-06-03 |
| 2. iOS Server Settings | v1.0 | 2/2 | Complete | 2026-06-03 |
| 3. iOS Upload Client | v1.0 | 3/3 | Complete | 2026-06-03 |
| 4. Upload Status Feedback | v1.0 | 2/2 | Complete | 2026-06-03 |
| 5. Upstream PR Integration | v1.0 | 4/4 | Complete | 2026-06-03 |
| 6. WHOOP Gen4 iOS Support | v2.0 | 3/3 | Complete | 2026-06-03 |
| 7. Android Port Foundations + CI | v2.0 | 4/4 | Complete | 2026-06-03 |
| 8. Additional Wearables E2E | v2.0 | 4/4 | Complete | 2026-06-03 |
| 8.1. Gap closure WEAR-01/WEAR-03 | v2.0 | 2/2 | Complete | 2026-06-04 |
| 9. BLE Stability & Data Integrity | v3.0 | 4/4 | Complete    | 2026-06-04 |
| 10. HR Monitor Scan/Connect UI | v3.0 | 3/3 | Complete    | 2026-06-04 |
| 10.1. BLE Main-Thread Publishing Fix | v3.0 | 1/1 | Complete    | 2026-06-04 |
| 11. HR Monitor Independent Capture | v3.0 | 2/2 | Complete    | 2026-06-05 |
| 12. WHOOP 4.0 RTC Clock Sync | v3.0 | 1/1 | Complete    | 2026-06-05 |
| 13. Recovery V2 Dashboard | v3.0 | 1/1 | Complete    | 2026-06-05 |
| 14. pt-PT Localisation | v3.0 | 4/4 | Complete | 2026-06-05 |
| 15. Recovery Formula V2 SDNN | v3.0 | 1/1 | Complete | 2026-06-05 |
| 16. Deep Link Security | v4.0 | 1/1 | Complete | 2026-06-05 |
| 17. @Observable Migration | v4.0 | 4/4 | Complete | 2026-06-05 |
| 18. Coach Multi-Provider | v4.0 | 6/6 | Complete | 2026-06-06 |
| 19. pt-PT Localisation Completion | v4.0 | 1/1 | Complete | 2026-06-06 |
| 20. Upstream Fixes & Storage | v5.0 | 2/2 | Complete   | 2026-06-06 |
| 21. IMU Data Foundation | v5.0 | 3/3 | Complete   | 2026-06-06 |
| 22. HRV Accuracy | v5.0 | 3/3 | Complete   | 2026-06-06 |
| 23. Strain & Calories | v5.0 | 3/3 | Complete   | 2026-06-08 |
| 24. Sleep Metrics Without Staging + Baselines | v5.0 | 2/2 | Complete   | 2026-06-08 |
| 25. Recovery Score v1 | v5.0 | 2/2 | Complete   | 2026-06-08 |
| 26. Sleep Staging | v5.0 | 0/2 | Planned | — |
| 27. V24 Biometric Decode | v5.0 | 0/0 | Not started | — |
| 28. Exercise Detection | v5.0 | 0/0 | Not started | — |
| 29. Upload Sync Infrastructure | v5.0 | 0/0 | Not started | — |
| 30. Readiness Engine | v5.0 | 0/0 | Not started | — |
| 31. Protocol Corrections (noop) | v5.0 | 0/0 | Not started | — |
| 32. HRV Parity Validation | v5.0 | 0/0 | Not started | — |

## Backlog

### Phase 999.5: GooseAppModel @Observable Migration (promoted to Phase 17 — v4.0)

Promoted to Phase 17: @Observable Migration.

---

### Phase 999.4: Recovery V2 Completion (promoted to Phase 13 — v3.0)

Promoted to Phase 13: Recovery V2 Dashboard.

---

### Phase 999.3: Apply upstream PR #15 (promoted to Phase 16 — v4.0)

Promoted to Phase 16: Deep Link Security.

---

### Phase 999.2: Multi-Language Support (promoted to Phase 14 — v3.0)

Promoted to Phase 14: pt-PT Localisation.

---

### Phase 999.1: Coach Multi-Provider & Custom Endpoint (promoted to Phase 18 — v4.0)

Promoted to Phase 18: Coach Multi-Provider.

### Phase 15: Recovery Formula V2 (SDNN Accuracy)

**Goal:** Corrigir a fórmula `goose_recovery_v0` — renomear `hrvRmssdMs` para `hkHRVSDNNMs` para reflectir a métrica real da Apple Watch, remover a conversão `/1.2` (aproximação populacional SDNN→RMSSD), e normalizar os baselines directamente em SDNN para eliminar desvios individuais no score de recuperação. Inclui também a implementação de `rmssd_segment_aware` (cálculo fisiologicamente correcto de RMSSD a partir de RR intervals segmentados).
**Requirements**: TBD
**Depends on:** Phase 13
**Reference:** [OKKHALIL3 review comment — PR #5](https://github.com/b-nnett/goose/pull/5#discussion_r3359064144); [po-sc PR #19 commits 303f329 / rmssd_segment_aware](https://github.com/b-nnett/goose/pull/19#issuecomment-4632805440)
**Plans:** 1/1 plans complete

**Scope:**

1. `rmssd_segment_aware(segments: &[Vec<f64>], min_pairs: usize) -> Option<f64>` — implementar no `Rust/core/src/metrics.rs`. Calcula RMSSD apenas dentro de cada segmento (janela de captura), nunca entre janelas distintas. Inclui filtro de artefactos (banda 300–2000 ms, regra de Malik 20%). A ausência desta função no fork causa inflação de RMSSD quando existem múltiplas janelas de captura.
2. Unit tests cobrindo: banda fisiológica (300/2000 ms), regra de Malik (diferença relativa > 20% rejeita o par), invariante cross-window (beats de janelas diferentes nunca são diferenciados).
3. Renomear `hrvRmssdMs` → `hkHRVSDNNMs`, remover conversão `/1.2`, normalizar baselines em SDNN.

Plans:

- [x] TBD (run /gsd-plan-phase 15 to break down) (completed 2026-06-05)

---

### Phase 999.6: body_hex Storage Optimization (absorbed into Phase 20 — v5.0)

Absorbed into Phase 20: Upstream Fixes & Storage (as PERF-05).

---

## 📋 v5.0 Metrics Accuracy, IMU & Upstream Fixes (Backlog)

**Milestone Goal:** Port validated algorithms from `my-whoop` into the Rust core — confirmed against WHOOP 5.37.0 IPA via Ghidra and peer-reviewed literature — so each metric (HRV, Recovery, Strain, Calories, Sleep) produces values aligned with WHOOP from the same raw data.

**Source:** `~/Documents/my-whoop/server/ingest/app/analysis/` — Python pipeline with complete accuracy remodel (2026-05-26). Calorie coefficients confirmed byte-by-byte against `Whoop` binary AARCH64 via Ghidra MCP (2026-06-01, `FINDINGS_5.md` §GHIDRA-HB-01 and §GHIDRA-02).

---

### Phase 20: Upstream Fixes & Storage

**Goal**: The Gen4 historical sync implementation is corrected and the `body_hex` duplication in cached JSON is eliminated — cleaning the foundation before algorithm work begins.
**Depends on**: Phase 19
**Requirements**: SYNC-01, SYNC-02, SYNC-03, SYNC-04, SYNC-05, PERF-05
**Success Criteria** (what must be TRUE):

  1. The `onHistoricalSyncCompleted` closure in `AppShellView.swift` captures `healthStore` weakly and clears itself on `.onDisappear`, verified by code inspection and confirmed the retain cycle is resolved
  2. All `gen4HistoricalPageSeq` increment sites in `GooseBLEClient+HistoricalHandlers.swift` use wrapping arithmetic (`&+=`), verified by search — no mixing of wrapping and trapping operators
  3. `WhoopGeneration.detect` lowercases the UUID string before the `hasPrefix("61080002")` comparison, verified by unit test asserting uppercase input still detects Gen4 correctly
  4. `body_hex` assertions are added to K10/K21 protocol tests first; then `body_hex` is excluded from the cached parsed-payload JSON for K10/K21 frames in `parse_frame_batch` — `cargo test` green before and after
  5. `cargo test -p goose-core` and `xcodebuild` both pass after all 6 fixes

**Plans**: 2 plans

Plans:

- [x] 20-01-PLAN.md — Wave 1: Gen4 historical-sync correctness fixes SYNC-01..SYNC-05 (Swift; verify-then-document/fix against actual fork symbols)
- [x] 20-02-PLAN.md — Wave 2: PERF-05 body_hex exclusion for K10/K21 in protocol.rs (Rust, test-first)

---

### Phase 21: IMU Data Foundation

**Goal**: Full IMU acceleration samples flow from WHOOP BLE frames through the Rust parser into the SQLite `gravity` table — unblocking sleep staging and any future motion-based analysis.
**Depends on**: Phase 20
**Requirements**: IMU-01, IMU-02, IMU-03, IMU-04
**Success Criteria** (what must be TRUE):

  1. `I16SeriesSummary` in `protocol.rs` carries a `full_samples: Option<Vec<i16>>` field; the existing `preview` field and all existing K10/K21 protocol tests pass without modification
  2. The `gravity` table exists in the SQLite schema (migration v14 → v15) with columns `(device_id TEXT, ts REAL, x REAL, y REAL, z REAL)` and an index on `(device_id, ts)`; `insert_gravity_rows` and `gravity_rows_between` bridge methods are callable and covered by `cargo test`
  3. K21/K10 frames decoded in `bridge.rs` populate the gravity Vec with LSB-to-g converted rows (factor ~3900, configurable) instead of the existing empty-Vec placeholder
  4. TOGGLE_IMU_MODE (command 106) is implemented in `protocol.rs` for type-51 packets and feature-flagged off by default — sending the command does not corrupt the packet stream when the flag is disabled
  5. `cargo test -p goose-core` green; tests cover: `full_samples` preservation of all 100 values, LSB-to-g conversion, gravity row insert and time-range query

**Plans**: 3 plans

Plans:

- [x] 21-01-PLAN.md — Wave 1: I16SeriesSummary full_samples field + summarize_i16_series population (protocol.rs) (IMU-01)
- [x] 21-02-PLAN.md — Wave 1: gravity table schema v15 + insert_gravity_rows + gravity_rows_between (store.rs) (IMU-02)
- [x] 21-03-PLAN.md — Wave 2: K10 gravity LSB→g extraction + bridge methods + IMU-04 doc (bridge.rs) (IMU-03, IMU-04)

---

### Phase 22: HRV Accuracy

**Goal**: Overnight RMSSD uses BLE-gap-aware segmentation, ectopic beat filtering with adaptive thresholds, and tiered SWS window selection — and the output is cross-validated to within 1 ms of the Python reference.
**Depends on**: Phase 21
**Requirements**: ALG-HRV-01, ALG-HRV-02, ALG-HRV-03, ALG-HRV-04
**Source**: `my-whoop/server/ingest/app/analysis/hrv.py` — `rmssd_ms()`, `clean_rr()`, `nightly_hrv()`
**Success Criteria** (what must be TRUE):

  1. `rmssd_segment_aware` treats any gap > 3 s between consecutive RR timestamps as a segment boundary; successive differences that cross a boundary are excluded — RMSSD is not inflated by BLE dropouts, verified by unit test with an injected 4 s gap
  2. Lipponen-Tarvainen ectopic beat filter is reimplemented in Rust (no FFI): local median of previous N intervals ± Malik 20% threshold (`|RR_i − median| > 0.2 × median` → reject); 300–2000 ms range gate applied first; `ectopic_filter_removal_fraction` exposed in `HrvOutput` and observable in Recovery V2 dashboard
  3. `HrvInput` accepts an optional `stage_segments` field; tiered SWS window selection uses (1) last deep-sleep episode >= 5 min, (2) weighted mean of all deep episodes, (3) full-night fallback — `window_tier_used` ∈ {`last_sws`, `weighted_sws`, `full_night`} present in `HrvOutput`; unit tests cover all three tiers
  4. Frequency-domain features (`hf_power`, `lf_power`, `lf_hf_ratio`) computed via Welch periodogram (HF band 0.15–0.4 Hz, LF band 0.04–0.15 Hz) from clean RR series; used as inputs to sleep staging classifier (Phase 26); exposed as optional fields in `HrvOutput`
  5. Rust RMSSD output delta vs `my-whoop` Python reference is <= 1 ms on >= 5 real overnight sessions before the phase is closed — cross-validation result documented in phase notes
  6. `cargo test -p goose-core` green; tests cover: gap boundary rejection, Malik threshold (exact 20% boundary cases), ectopic filter removal fraction, all three SWS window tiers, HF/LF band boundaries

**Plans**: 3 plans

Plans:

- [x] 22-01-PLAN.md — Wave 1: BLE gap-aware RR segmentation — rr_timestamps_s on HrvInput + segment-aware RMSSD (ALG-HRV-01)
- [x] 22-02-PLAN.md — Wave 2: Lipponen-Tarvainen ectopic filter per segment (Rust reimplementation, Malik 20% rule) + ectopic_filter_removal_fraction in HrvOutput (ALG-HRV-02)
- [x] 22-03-PLAN.md — Wave 3: Tiered SWS window selection + window_tier_used in HrvOutput + Welch HF/LF/LFHF frequency features + ALG-HRV-04 cross-validation doc comment (ALG-HRV-03, ALG-HRV-04)

---

### Phase 23: Strain & Calories

**Goal**: Strain uses Tanaka HRmax and Banister TRIMP with sex-specific constants; a personal denominator calibration helper is available; calorie computation uses Mifflin-St Jeor RMR and Ghidra-confirmed Keytel/Harris-Benedict coefficients.
**Depends on**: Phase 21
**Requirements**: ALG-STR-01, ALG-STR-02, ALG-STR-03, ALG-CAL-01, ALG-CAL-02
**Source**: `my-whoop/server/ingest/app/analysis/strain.py`, `calories.py`
**Success Criteria** (what must be TRUE):

  1. `StrainInput` carries a `profile_sex` field; `tanaka_hrmax(age) = 208 - 0.7 * age` is the default HRmax; `estimate_hrmax_from_history` returns the 99.5th percentile when >= 600 trailing samples are available, else Tanaka, else 220-age — `hrmax_source` ∈ {`observed`, `tanaka`, `fallback`} present in output; unit test confirms Tanaka differs from 220-age by >= 2 bpm for age > 40
  2. Karvonen `%HRR = (HR − RHR) / (HRmax − RHR) × 100`, clamped [0, 100], is the per-sample intensity input; active/resting split threshold is `%HRR >= 30` (30% HRR conventional light-activity cut-off)
  3. Edwards 5-zone TRIMP accumulates zone weights 1–5 at HRR cut-offs [50, 60, 70, 80, 90]%; zone-time percentages (`zone_time_pct: BTreeMap<u8, f64>`) are computed and always sum to 100; exposed in `StrainOutput`
  4. Banister TRIMP uses continuous exponential weighting `weight = k × exp(b × %HRR)` with sex-specific b: male=1.92, female=1.67; the `banister_trimp_uncalibrated` quality flag is present; a test asserts male and female TRIMP outputs differ by the expected ratio for identical HR traces
  5. `fit_strain_denominator` fits the denominator D in `strain = 21 × ln(TRIMP+1) / ln(D)` from >= 2 (TRIMP, strain_WHOOP) pairs via least-squares and is exposed as a bridge calibration method; default D=7201 (theoretical max)
  6. `rmr_mifflin_st_jeor(weight_kg, height_cm, age, sex)` is implemented in `energy_rollup.rs`; a quality flag is emitted when `profile_height_cm` is absent; the existing `weight_kg * 22.0` proxy is replaced; active EE (Keytel) and resting EE (Harris-Benedict) split on the 30% HRR threshold
  7. Keytel and Harris-Benedict coefficients in `energy_rollup.rs` match the Ghidra-confirmed AARCH64 values exactly (Keytel men: -55.0969, 0.6309, 0.1988, 0.2017; women: -20.4022, 0.4472, -0.1263, 0.0740; H-B men: 88.362, 13.397, 479.9, -5.677; women: 447.593, 9.247, 309.8, -4.330), verified by test asserting exact coefficient values; Keytel EE clamped >= 0, HR capped at HRmax; convert kJ/min → kcal/s via ÷ (60 × 4.184)
  8. `cargo test -p goose-core` green; tests cover: Karvonen %HRR boundaries, zone assignment at cut-off edges, Banister sex ratio, Keytel coefficient exact values

**Plans**: 3 plans

Plans:

- [x] 23-01-PLAN.md — Wave 1: profile_sex/profile_age on StrainInput + Tanaka HRmax + estimate_hrmax_from_history + effective-HRmax resolver (ALG-STR-01)
- [x] 23-02-PLAN.md — Wave 2: Banister TRIMP (sex constants) + fit_strain_denominator + goose_strain_v1 bridge method (ALG-STR-02, ALG-STR-03)
- [x] 23-03-PLAN.md — Wave 3: Mifflin-St Jeor RMR + Keytel/Harris-Benedict Ghidra coefficients + profile_height_cm wiring (ALG-CAL-01, ALG-CAL-02)

---

### Phase 24: Sleep Metrics Without Staging + Baselines

**Goal**: Sleep quality metrics (HR dip, WASO, SOL, disturbance count) are computed from existing HR data and surfaced in the Sleep V2 dashboard; the EWMA baseline engine required by Recovery is implemented and idempotent.
**Depends on**: Phase 21
**Requirements**: ALG-SLP-01, ALG-SLP-02
**Source**: `my-whoop/server/ingest/app/analysis/sleep.py`, `baselines.py`, `daily.py`
**Success Criteria** (what must be TRUE):

  1. `SleepScoreOutput` exposes `heart_rate_dip_pct` (rolling 5-min min HR during in-bed window vs pre-sleep RHR), `waso_minutes` (wake-after-sleep-onset: sum of post-onset wake epochs × 30 s), `sol_minutes` (sleep-onset latency: first sustained sleep epoch), `disturbance_count` (number of distinct post-onset wake runs), and `rem_latency_minutes`; all fields populated (not null) for sessions with >= 50% HR coverage; the Sleep V2 dashboard displays them
  2. EWMA baseline engine in `baselines.rs` implements per-metric state with **Winsorized center** (14-night half-life α ≈ 0.0483) and **EWMA-of-absolute-deviation spread** (21-night half-life); per-metric σ-floors: HRV=5 ms, RHR=2 bpm, resp=0.3 BrPM; Winsor gate clamps input to ± 3σ before folding; hard-reject gate skips nights where `|value − mean| > 5σ`
  3. Per-metric configs in `METRIC_CFG` table: each entry carries `min_val`, `max_val`, `floor_spread`, `half_life_center_nights`, `half_life_spread_nights`; metrics keyed as `"hrv"`, `"resting_hr"`, `"resp"`; `deviation()` returns `(z_score, delta, ratio)` for a value vs baseline
  4. Cold-start gates: MIN_NIGHTS_SEED=4 (status=`provisional`), MIN_NIGHTS_TRUST=14 (status=`trusted`), STALE_DAYS=14 (status=`stale` if last update > 14 days ago); baseline returns `None` until MIN_NIGHTS_SEED reached; `fold_history()` rebuilds baseline from a list of historical daily values
  5. Concurrent write safety: EWMA update uses `BEGIN EXCLUSIVE` transaction; double-update on the same date is prevented by a `WHERE last_updated_date < ?` guard (idempotent)
  6. `cargo test -p goose-core` green; tests cover: HR dip nadir (rolling 5-min window), WASO = 0 when no wake-after-onset, disturbance count, Winsor gate clamping, hard-reject at 5σ, cold-start gate at exactly 4 nights, idempotent write, stale flag after 14 days

**Plans**: 2 plans

Plans:

- [x] 24-01-PLAN.md — Wave 1: HR-threshold sleep metric helpers (heart_rate_dip_pct, waso_from_hr, sol_from_hr, hr_disturbance_count) in metrics.rs + SleepScoreOutput fields + sleep_window_feature wiring + Sleep V2 dashboard surfacing (ALG-SLP-01)
- [x] 24-02-PLAN.md — Wave 1: baselines.rs EWMA engine (alpha 0.10, cold-start, trust levels) + fold_history from daily_recovery_metrics + idempotent BEGIN EXCLUSIVE update + store.ewma_baseline_* bridge methods (ALG-SLP-02)

**UI hint**: yes

> Planning note: ALG-SLP-02 was planned to the binding REQUIREMENTS.md + 24-CONTEXT scope
> (EWMA mean/variance, alpha 0.10, hrv/resting_hr, cold-start >= 4 / trust >= 14, idempotent
> EXCLUSIVE write). The richer success-criteria #2/#3 above (Winsorized center, EWMA-of-abs-
> deviation spread, METRIC_CFG table, resp metric, stale flag) are additive refinements not
> present in the ALG-SLP-02 requirement text; surface to the developer if they should be
> pulled into this phase rather than Phase 25 (Recovery) where the σ-spread is consumed.

---

### Phase 25: Recovery Score v1

**Goal**: The Recovery score is computed from a personal EWMA baseline using Z-score normalisation and logistic squash, with trust levels and colour bands visible in the dashboard.
**Depends on**: Phase 22, Phase 24
**Requirements**: ALG-REC-01, ALG-REC-02, ALG-REC-03
**Source**: `my-whoop/server/ingest/app/analysis/recovery.py` — `recovery_score()`, `resting_hr()`
**Success Criteria** (what must be TRUE):

  1. `goose_recovery_v1` in `metrics.rs` computes weighted composite Z-score: `Z = 0.60·Z_HRV + 0.20·Z_RHR + 0.05·Z_resp + 0.15·Z_sleep_perf`; missing terms are dropped and weights renormalised; logistic squash: `score = 100 / (1 + exp(−1.6 × (Z + 0.20)))`; when Z = 0 the output is approximately 58% (within 0.5%); the bridge method is callable from Swift via `HealthDataStore+Recovery.swift`
  2. Z_RHR is **inverted** (lower RHR = better recovery): `Z_RHR = (baseline_RHR − RHR_night) / σ_RHR`; Z_sleep_perf uses sleep efficiency centred at 0.85, σ=0.12: `Z_sleep_perf = (efficiency − 0.85) / 0.12`
  3. Each z-score normalised against the personal EWMA baseline from `baselines.rs`, not a population mean; cold-start gate returns `null` for < 4 nights of valid baseline history (MIN_NIGHTS_SEED); population fallback value RECOVERY_POPULATION_MEAN=58.0 available but must be flagged with `trust=calibrating`
  4. `RecoveryScoreOutput` trust level transitions: `calibrating` (< 4 nights) → `provisional` (4–13 nights) → `trusted` (>= 14 nights); `RecoveryV2DashboardView` shows "A calibrar" state when trust is `calibrating`
  5. Colour bands: Verde >= 67, Amarelo 34–66, Vermelho < 34; dashboard reflects correct band colour for any given score
  6. `cargo test -p goose-core` green; tests cover: Z=0 produces ~58%, Z_RHR inversion, weight renormalisation with one missing term, cold-start null, trust level transitions at exact night thresholds, all three colour bands

**Plans**: 2 plans

**Wave 1**

  - [x] 25-01-PLAN.md — Rust: RecoveryV1Input/Output + ColourBand + goose_recovery_v1 (Z-score + logistic squash, cold-start None) + metrics.goose_recovery_v1 bridge method (ALG-REC-01, ALG-REC-02)

**Wave 2** *(blocked on Wave 1 completion)*

  - [x] 25-02-PLAN.md — Swift: HealthDataStore+Recovery.swift + RecoveryV2OverviewPage "A calibrar" state + colour band indicator (ALG-REC-03)

**UI hint**: yes

---

### Phase 27: V24 Biometric Decode

**Goal**: All biometric fields in V24 HISTORICAL_DATA packets (packet_k == 24) are extracted — SpO2 red/IR, skin temperature raw, respiratory raw, signal quality, skin contact — stored in dedicated SQLite tables and exposed via bridge methods, unlocking cardiorespiratory inputs for sleep staging and HRV.
**Depends on**: Phase 21
**Requirements**: BIO-01, BIO-02, BIO-03, BIO-04
**Source**: `my-whoop/re/verify_v24.py` (verified byte offsets, V12/V24 layout, 762 real records); `my-whoop/server/ingest/app/analysis/units.py` (conversion formulas); `my-whoop/server/ingest/app/store.py` (table schema reference)
**Success Criteria** (what must be TRUE):

  1. `DataPacketBodySummary` for packet_k == 24 carries all V24 fields at verified byte offsets (data = pkt[3:]): `spo2_red` u16 @ data[61], `spo2_ir` u16 @ data[63], `skin_temp_raw` u16 @ data[65], `ambient` u16 @ data[67], `resp_raw` u16 @ data[73], `sig_quality` u16 @ data[75], `skin_contact` u8 @ data[48], `ppg_green` u16 @ data[26], `ppg_red_ir` u16 @ data[28], RR intervals up to 4 × u16 @ data[16+2i] (skip zeros) — verified by unit test with synthetic V24 payload matching `verify_v24.py::decode_v24()` output
  2. All biometrics gated on `skin_contact == 1`; samples where skin_contact == 0 are stored with a `contact=false` flag but excluded from unit conversion output and downstream HRV/sleep computations
  3. Four new SQLite tables added via schema migration: `spo2_samples(device_id TEXT, ts REAL, red INTEGER, ir INTEGER)`, `skin_temp_samples(device_id TEXT, ts REAL, raw INTEGER)`, `resp_samples(device_id TEXT, ts REAL, raw INTEGER)`, `sig_quality_samples(device_id TEXT, ts REAL, quality INTEGER, contact INTEGER)` — each with `UNIQUE(device_id, ts)` + `INSERT OR IGNORE`, index on `(device_id, ts)`
  4. Bridge methods `insert_v24_biometric_batch` and `v24_biometric_samples_between(device_id, start_ts, end_ts)` callable from Swift and covered by `cargo test` with insert + query roundtrip
  5. Physical unit helpers with mandatory `quality_flag: "uncalibrated"` in all outputs: SpO2 ratio-of-ratios windowed (AC = MAD-based robust spread, DC = mean, R = (AC_red/DC_red)/(AC_ir/DC_ir), SpO2 = 110 − 25·R, clamp [70, 100], defaults a=110 b=25 TI SLAA655); `skin_temp_celsius` linear slope (default slope un-calibrated, reference raw≈930 → 33°C); `resp_rate_bpm` Welch spectral (0.1–0.5 Hz band, 1 Hz input, no calibration needed)
  6. Plausibility gates reject samples before storage: SpO2 [70, 100]%, skin_temp_celsius [25, 40]°C, resp_raw within device ADC bounds [0, 65535]; gate failures logged as warnings, not hard errors
  7. `cargo test -p goose-core` green; tests cover: all field offsets against synthetic payload, skin_contact gate, insert+query roundtrip per table, SpO2 ratio-of-ratios at known R values, uncalibrated flag always present, plausibility gate rejection

**Plans**: TBD

---

### Phase 28: Exercise Detection

**Goal**: Workout sessions are detected retroactively from HR + gravity data, Karvonen zones are computed per bout, and calories are accumulated per session — exposing `exercise_sessions` rows with strain, zone breakdown, and calorie estimates.
**Depends on**: Phase 21, Phase 23
**Requirements**: EX-01, EX-02, EX-03, EX-04
**Source**: `my-whoop/server/ingest/app/analysis/exercise.py` — `detect_exercise_sessions()`, `ExerciseSession`
**Success Criteria** (what must be TRUE):

  1. `detect_exercise_sessions(hr_samples, gravity_samples, profile)` detects sustained windows where HR > (RHR + 30 bpm margin) AND rolling-mean gravity activity magnitude > motion threshold (0.01 g/sample), with nearest-neighbour temporal alignment between HR and gravity streams (± 5 s tolerance); sessions shorter than MIN_EXERCISE_MIN=10 min are rejected
  2. Adjacent sessions separated by a gap < MERGE_GAP_S=60 s are merged into a single session; the merged session recomputes all metrics; bouts where Edwards zone 2–5 (≥ 60% HRR) fraction < MIN_INTENSITY_Z2PLUS=50% are discarded as non-exercise (guard: skip if HRmax unknown)
  3. Per-session metrics in `ExerciseSession`: `avg_hr`, `peak_hr`, `duration_s`, `avg_hrr_pct`, `hrmax`, `hrmax_source` ∈ {`observed`, `tanaka`, `fallback`}, `zone_time_pct: BTreeMap<u8, f64>` (Edwards 5-zone percentages summing to 100), `strain` (from Phase 23 Banister TRIMP + logarithmic scale), `calories_kcal` (active Keytel + resting Harris-Benedict split on 30% HRR threshold)
  4. Detected sessions are persisted in an `exercise_sessions` SQLite table (migration from Phase 23): `(device_id TEXT, start_ts REAL, end_ts REAL, duration_s REAL, avg_hr REAL, peak_hr REAL, strain REAL, calories_kcal REAL, zone_time_pct_json TEXT, hrmax_source TEXT)`; bridge methods `insert_exercise_session` and `exercise_sessions_between` covered by `cargo test`
  5. Resting HR fallback: if no sleep session available, use 10th percentile of the day's HR values as RHR proxy; `rhr_source` ∈ {`sleep_session`, `daily_p10`, `profile_override`} present in session output
  6. `cargo test -p goose-core` green; tests cover: HR + gravity alignment (±5 s), merge gap bridging, intensity qualification gate, zone percentages sum to 100, calories positive and physically plausible (> 0 kcal for 30 min at 70% HRR)

**Plans**: TBD

---

### Phase 26: Sleep Staging

**Goal**: A 4-class (wake/light/deep/REM) sleep hypnogram is derived from IMU gravity data and cardiorespiratory features, with a mandatory uncalibrated quality flag and validation against >= 5 real overnight sessions.
**Depends on**: Phase 21, Phase 22
**Requirements**: ALG-SLP-03, ALG-SLP-04
**Source**: `my-whoop/server/ingest/app/analysis/sleep.py` — `detect_sleep()`; `sleep_features.py` — `classify_epochs()`
**Success Criteria** (what must be TRUE):

  1. Cole-Kripke actigraphy spine on **30 s epochs** (not 1 min) from `full_samples`: activity counts = sum of |Δg| per epoch (gravity change-magnitude, threshold 0.01 g/sample); 7-epoch sliding window with te Lindert weights `[activity/100, clip 300]`; threshold classifies each epoch as `sleep` or `wake`; `staging_method_actigraphy_uncalibrated` quality flag is mandatory — shipping without it is a blocker
  2. Per-epoch cardiorespiratory feature vector: HR mean, HR low percentile (p25), HR high percentile (p70), RMSSD (from Phase 22 segment-aware), HF power (0.15–0.4 Hz from Phase 22 Welch), LF/HF ratio, respiratory rate variability (std of resp_raw window), clock proxy (fractional position in the night 0–1); features normalised to [0, 1] per-session
  3. Rule-based 4-class classifier (transparent seam for future ML): wake epoch → stay `wake`; sleep epoch with RMSSD > HRV_HIGH_THR (p70 personal) AND HF > HF_HIGH_THR AND low motion → `deep`; sleep epoch with irregular resp variability AND late clock proxy (> 0.4) → `rem`; remaining sleep epochs → `light`
  4. Physiological reimposition after per-epoch classification: (a) no REM in first 15 min of sleep, (b) deep sleep concentrated in first 1/3 of sleep period, (c) minimum 5-min segment merge (≤ 10 epochs same class → absorbed into neighbour), (d) forbidden transitions suppressed (deep→REM direct: insert light bridge epoch)
  5. AASM metrics computed from the final hypnogram: TST, sleep efficiency (TST/TIB), SOL, WASO, REM latency, stage_minutes per class; surfaced in Sleep V2 dashboard
  6. Epoch-level agreement with WHOOP official stages >= 70% on >= 5 overnight sessions before the phase is closed — known literature ceiling for EEG-free methods is 65–73%; validation result documented in phase notes
  7. `cargo test -p goose-core` green; tests cover: Cole-Kripke activity count computation, 7-epoch window weights, stillness threshold, all four reimposition rules, AASM metric derivation from synthetic hypnogram

**Plans**: 2 plans
**UI hint**: yes

**Wave 1**

  - [ ] 26-01-PLAN.md — Cole-Kripke binary actigraphy spine: sleep_staging.rs module, activity-count computation, 1-min epochs, 7-term weighted D score, wake/sleep classification, metrics.sleep_staging bridge method (ALG-SLP-03)

**Wave 2** *(blocked on Wave 1 — shared sleep_staging.rs)*

  - [ ] 26-02-PLAN.md — 4-class classifier (wake/light/deep/rem) + physiological reimposition (no early REM, min 5-min merge) + AASM metrics (TST/efficiency/SOL/WASO/stage_minutes) + ALG-SLP-04 human cross-validation gate (ALG-SLP-04)

---

### Phase 29: Upload Sync Infrastructure

**Goal**: Per-row `synced` flag on all stream tables prevents backfilled rows from being stranded by highwater cursors; a two-namespace cursor design separates upload tracking from pull tracking; the raw outbox invariant guarantees unsynced frames are never pruned.
**Depends on**: Phase 21
**Requirements**: SYNC-UP-01, SYNC-UP-02, SYNC-UP-03
**Source**: `tigercraft4/noop` — `WhoopStore` v5 migration (`synced` flag), `Cursors.swift` (two-namespace design), `RawOutbox.swift` (`pruneRaw` invariant)
**Success Criteria** (what must be TRUE):

  1. Schema migration adds `synced INTEGER NOT NULL DEFAULT 0` to all 8 stream tables (`hr_samples`, `rr_intervals`, `spo2_samples`, `skin_temp_samples`, `resp_samples`, `gravity_samples`, `events`, `battery`); existing rows receive `synced = 0`; upload marks rows `synced = 1` after confirmed server receipt
  2. Cursor table uses two namespaces: `highwater:<stream>` for upload tracking, `read:<stream>` for server-pull tracking — the two never collide; a row inserted by backfill (older timestamp) is correctly picked up by the upload cursor because it uses `WHERE synced = 0` rather than `WHERE ts > highwater`
  3. Raw evidence prune logic deletes only rows where `synced = 1` (server confirmed); unsynced rows are never pruned regardless of age — verified by test asserting that a prune call on unsynced rows leaves them intact
  4. `cargo test -p goose-core` green; tests cover: backfill row not stranded by highwater, cursor namespace isolation, prune-safe invariant

**Plans**: TBD

---

### Phase 30: Readiness Engine

**Goal**: A daily readiness level (5-class) is derived from ACWR (acute:chronic workload ratio) and Foster training monotony, giving the user a forward-looking load management signal alongside recovery.
**Depends on**: Phase 23, Phase 25
**Requirements**: RDY-01, RDY-02, RDY-03
**Source**: `tigercraft4/noop` — `ReadinessEngine.swift`; sports science literature (Foster 1998 monotony index, Hulin 2016 ACWR injury-risk zones)
**Success Criteria** (what must be TRUE):

  1. `ReadinessInput` carries `daily_strain: Vec<(date, f64)>` (trailing 28 days minimum); `acwr(strains)` computes acute load (7-day mean) / chronic load (28-day mean), clamped to a safe range; returns `None` when < 28 days of data available
  2. `foster_monotony(week_strains)` returns `mean / std` for the 7-day window; monotony flag set when result ≥ 2.0 (Foster 1998 threshold); returns `None` when std = 0 or < 3 days of data
  3. `ReadinessOutput.level` ∈ `{rundown, strained, balanced, primed, unknown}` with deterministic synthesis rules: `rundown` when ACWR ≥ 1.5 OR (ACWR ≤ 0.8 AND recovery trend down); `primed` when ACWR ∈ [0.8, 1.3] AND monotony < 2.0 AND recovery trusted; `strained` when any single bad signal; `balanced` otherwise; `unknown` when insufficient data
  4. ACWR injury-risk zones documented in output: < 0.8 (under-training), 0.8–1.3 (optimal), 1.3–1.5 (caution), ≥ 1.5 (danger); `acwr_zone` field present in `ReadinessOutput`
  5. `cargo test -p goose-core` green; tests cover: ACWR zone boundaries, monotony flag at exactly 2.0, rundown rule, primed rule, unknown when < 28 days

**Plans**: TBD

---

### Phase 31: Protocol Corrections (noop)

**Goal**: Three protocol-level findings from `tigercraft4/noop` cross-verification are applied to the Phases 26 and 27 implementations: exact Cole-Kripke weights, the second gravity triplet (`gravity2`), and the resp stream dependency for sleep staging.
**Depends on**: Phase 26, Phase 27
**Requirements**: PROTO-01, PROTO-02, PROTO-03
**Source**: `tigercraft4/noop` — `SleepStager.swift` (Cole-Kripke constants), `whoop_protocol.json` (V24 gravity2 offsets)
**Success Criteria** (what must be TRUE):

  1. Cole-Kripke weights corrected to exact noop/literature values: `[106, 54, 58, 76, 230, 74, 67]`, scale=0.001, look-back 4 epochs, look-forward 2 epochs, sleep threshold < 1.0 (replaces the vague `[activity/100, clip 300]` placeholder); unit test asserts the D-score for a known activity sequence matches the expected value
  2. V24 `gravity2` second triplet extracted: `gravity2_x` (f32 @ data[49]), `gravity2_y` (f32 @ data[53]), `gravity2_z` (f32 @ data[57]); stored in a `gravity2_samples` table with the same schema and constraints as `gravity_samples`; bridge methods `insert_gravity2_batch` and `gravity2_samples_between` covered by `cargo test`
  3. Sleep staging Phase 26 verification: the classifier uses `resp_raw` window (from Phase 27) as a mandatory RRV (respiratory rate variability) input; a missing resp stream degrades gracefully (RRV feature set to `None`, classifier falls back to 3-class wake/deep/light without REM) rather than erroring
  4. `cargo test -p goose-core` green; tests cover: exact D-score with known weights, gravity2 insert+query roundtrip, resp-missing graceful degradation

**Plans**: TBD

---

### Phase 32: HRV Parity Validation

**Goal**: Rust `goose_hrv_v0` RMSSD output is cross-validated against the my-whoop Python reference on ≥ 5 real overnight sessions captured by the Goose iOS app, closing the ALG-HRV-04 manual gate from Phase 22.
**Depends on**: Phase 22 (implementation), Phase 29 (synced upload of real RR data to server)
**Requirements**: VAL-01
**Source**: `tigercraft4/noop` — `HistoricalStreamsParityTests` (parity fixture pattern); `my-whoop/server/ingest/app/analysis/hrv.py` (Python reference)
**Success Criteria** (what must be TRUE):

  1. Golden fixture files (`rr_golden_night_<N>.json`, N=1..5) generated from 5 real overnight WHOOP sessions captured by the Goose iOS app: each file contains `rr_intervals_ms: [f64]`, `rr_timestamps_s: [f64]`, `python_rmssd_ms: f64` computed by `my-whoop/hrv.py::rmssd_ms(clean_rr(...))`
  2. Rust integration test `hrv_parity_vs_python_golden` loads each fixture, calls `goose_hrv_v0` with the same RR + timestamp data, and asserts `|rust_rmssd - python_rmssd| <= 1.0 ms` for all 5 sessions
  3. ALG-HRV-04 gate documented as CLOSED in phase notes with session dates, RMSSD values, and deltas tabulated
  4. `cargo test -p goose-core` green including the 5 parity tests

**Plans**: TBD

---
