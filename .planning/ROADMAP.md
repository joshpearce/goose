# Roadmap: Goose

## Milestones

- ✅ **v1.0 Remote Server + Upstream PRs** — Phases 1-5 (shipped 2026-06-03)
- ✅ **v2.0 Multi-Device & Platform Foundations** — Phases 6-8+8.1 (shipped 2026-06-04)
- ✅ **v3.0 Wearable UX, CI Hardening & RTC Sync** — Phases 9-15 (shipped 2026-06-05)
- ✅ **v4.0 Security, Performance & Coach Expansion** — Phases 16-19 (shipped 2026-06-06)
- 📋 **v5.0 Metrics Accuracy, IMU & Upstream Fixes** — Phases 20-26 (backlog)

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
<summary>📋 v5.0 Metrics Accuracy, IMU & Upstream Fixes (Phases 20-26) — BACKLOG</summary>

- [ ] **Phase 20: Upstream Fixes & Storage** (2 plans) — SYNC-01, SYNC-02, SYNC-03, SYNC-04, SYNC-05, PERF-05
- [ ] **Phase 21: IMU Data Foundation** — IMU-01, IMU-02, IMU-03, IMU-04
- [ ] **Phase 22: HRV Accuracy** — ALG-HRV-01, ALG-HRV-02, ALG-HRV-03, ALG-HRV-04
- [ ] **Phase 23: Strain & Calories** — ALG-STR-01, ALG-STR-02, ALG-STR-03, ALG-CAL-01, ALG-CAL-02
- [ ] **Phase 24: Sleep Metrics Without Staging + Baselines** — ALG-SLP-01, ALG-SLP-02
- [ ] **Phase 25: Recovery Score v1** — ALG-REC-01, ALG-REC-02, ALG-REC-03
- [ ] **Phase 26: Sleep Staging** — ALG-SLP-03, ALG-SLP-04

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
| 21. IMU Data Foundation | v5.0 | 2/3 | In Progress|  |
| 22. HRV Accuracy | v5.0 | 0/0 | Not started | — |
| 23. Strain & Calories | v5.0 | 0/0 | Not started | — |
| 24. Sleep Metrics Without Staging + Baselines | v5.0 | 0/0 | Not started | — |
| 25. Recovery Score v1 | v5.0 | 0/0 | Not started | — |
| 26. Sleep Staging | v5.0 | 0/0 | Not started | — |

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
- [ ] 21-03-PLAN.md — Wave 2: K10 gravity LSB→g extraction + bridge methods + IMU-04 doc (bridge.rs) (IMU-03, IMU-04)

---

### Phase 22: HRV Accuracy

**Goal**: Overnight RMSSD uses BLE-gap-aware segmentation, ectopic beat filtering with adaptive thresholds, and tiered SWS window selection — and the output is cross-validated to within 1 ms of the Python reference.
**Depends on**: Phase 21
**Requirements**: ALG-HRV-01, ALG-HRV-02, ALG-HRV-03, ALG-HRV-04
**Success Criteria** (what must be TRUE):

  1. `rmssd_segment_aware` treats any gap > 3 s between consecutive RR timestamps as a segment boundary; successive differences that cross a boundary are excluded — RMSSD is not inflated by BLE dropouts, verified by unit test with an injected 4 s gap
  2. Lipponen-Tarvainen ectopic beat filter is the primary filter: local median reference ± adaptive threshold rejects ectopic beats before the 300–2000 ms range gate; `ectopic_filter_removal_fraction` is exposed in `HrvOutput` and observable in the Recovery V2 dashboard
  3. `HrvInput` accepts an optional `stage_segments` field; tiered SWS window selection uses (1) last deep-sleep episode >= 5 min, (2) weighted mean of all deep episodes, (3) full-night fallback — unit tests cover all three tiers
  4. Rust RMSSD output delta vs `my-whoop` Python reference is <= 1 ms on >= 5 real overnight sessions before the phase is closed — cross-validation result documented in phase notes
  5. `cargo test -p goose-core` green; tests cover: gap boundary rejection, ectopic filter removal fraction, all three SWS window tiers

**Plans**: TBD

---

### Phase 23: Strain & Calories

**Goal**: Strain uses Tanaka HRmax and Banister TRIMP with sex-specific constants; a personal denominator calibration helper is available; calorie computation uses Mifflin-St Jeor RMR and Ghidra-confirmed Keytel/Harris-Benedict coefficients.
**Depends on**: Phase 21
**Requirements**: ALG-STR-01, ALG-STR-02, ALG-STR-03, ALG-CAL-01, ALG-CAL-02
**Success Criteria** (what must be TRUE):

  1. `StrainInput` carries a `profile_sex` field; `tanaka_hrmax(age) = 208 - 0.7 * age` is the default HRmax formula throughout the strain pipeline; `estimate_hrmax_from_history` returns the 99.5th percentile when >= 600 samples are available — unit test confirms Tanaka differs from 220-age by >= 2 bpm for age > 40
  2. `banister_trimp_zone_midpoint` is implemented with b=1.92 (male) / b=1.67 (female); the `banister_trimp_zone_midpoint_approximation` quality flag is present in output; a test asserts male and female TRIMP outputs differ by the expected constant ratio for the same session
  3. `fit_strain_denominator` fits the denominator D in `21 * ln(TRIMP+1) / ln(D)` from >= 2 (TRIMP, strain_WHOOP) pairs via least-squares and is exposed as a bridge calibration method
  4. `rmr_mifflin_st_jeor(weight_kg, height_cm, age, sex)` is implemented in `energy_rollup.rs`; a quality flag is emitted when `profile_height_cm` is absent; the existing `weight_kg * 22.0` proxy is replaced
  5. Keytel and Harris-Benedict coefficients in `energy_rollup.rs` match the Ghidra-confirmed values exactly (Keytel men: -55.0969, 0.6309, 0.1988, 0.2017; women: -20.4022, 0.4472, -0.1263, 0.0740; H-B men: 88.362, 13.397, 479.9, -5.677; women: 447.593, 9.247, 309.8, -4.330), verified by test asserting exact coefficient values
  6. `cargo test -p goose-core` green

**Plans**: TBD

---

### Phase 24: Sleep Metrics Without Staging + Baselines

**Goal**: Sleep quality metrics (HR dip, WASO, SOL, disturbance count) are computed from existing HR data and surfaced in the Sleep V2 dashboard; the EWMA baseline engine required by Recovery is implemented and idempotent.
**Depends on**: Phase 21
**Requirements**: ALG-SLP-01, ALG-SLP-02
**Success Criteria** (what must be TRUE):

  1. `SleepScoreOutput` exposes `heart_rate_dip_pct`, `waso_minutes`, `sol_minutes`, `rem_latency_minutes`, and `disturbance_count`; all fields are populated (not null) for sessions with sufficient HR coverage (>= 50%); the Sleep V2 dashboard displays them
  2. `baselines.rs` implements an EWMA state struct with alpha=0.1; `fold_history()` rebuilds baseline from `daily_recovery_metrics` rows; the baseline is inactive (returns null) until 7 nights of valid data are available
  3. Concurrent write safety is enforced: the EWMA update uses `BEGIN EXCLUSIVE` transaction or an atomic SQL expression; a double-update on the same date is prevented by a `WHERE last_updated_date < ?` guard
  4. `cargo test -p goose-core` green; tests cover: HR dip with correct nadir, WASO = 0 when no wake-after-onset, cold-start gate at exactly 7 nights, idempotent write (same date called twice produces same baseline value)

**Plans**: TBD
**UI hint**: yes

---

### Phase 25: Recovery Score v1

**Goal**: The Recovery score is computed from a personal EWMA baseline using Z-score normalisation and logistic squash, with trust levels and colour bands visible in the dashboard.
**Depends on**: Phase 22, Phase 24
**Requirements**: ALG-REC-01, ALG-REC-02, ALG-REC-03
**Success Criteria** (what must be TRUE):

  1. `goose_recovery_v1` in `metrics.rs` implements `score = 100 / (1 + exp(-1.6 * (Z + 0.20)))`; when Z = 0 the output is approximately 58% (within 0.5%); the bridge method is callable from Swift via `HealthDataStore+Recovery.swift`
  2. Each z-score is normalised against the personal EWMA baseline from `baselines.rs`, not a population mean; cold-start gate returns `null` for < 4 nights of valid baseline history
  3. The `RecoveryScoreOutput` trust level transitions correctly: `calibrating` (< 4 nights) → `provisional` (4–13 nights) → `trusted` (>= 14 nights); the `RecoveryV2DashboardView` shows an "A calibrar" state when trust is `calibrating`
  4. Colour bands are applied correctly: Verde >= 67, Amarelo 34–66, Vermelho < 34; the dashboard reflects the correct band colour for any given score
  5. `cargo test -p goose-core` green; tests cover: Z=0 produces ~58%, cold-start null, trust level transitions, all three colour bands

**Plans**: TBD
**UI hint**: yes

---

### Phase 26: Sleep Staging

**Goal**: A 4-class (wake/light/deep/REM) sleep hypnogram is derived from IMU gravity data and cardiorespiratory features, with a mandatory uncalibrated quality flag and validation against >= 5 real overnight sessions.
**Depends on**: Phase 21
**Requirements**: ALG-SLP-03, ALG-SLP-04
**Success Criteria** (what must be TRUE):

  1. `sleep_staging.rs` implements the Cole-Kripke actigraphy classifier on 1-minute aggregated epochs from `full_samples`; the `staging_method_actigraphy_uncalibrated` quality flag is mandatory and always present in output — shipping without it is a blocker
  2. The 4-class classifier (wake/light/deep/REM) uses cardiorespiratory features per 30 s epoch; physiological reimposition is applied (minimum 5-min segment merge, no REM in first 15 min, forbidden-transition suppression)
  3. AASM metrics are computed from the hypnogram: TST, sleep efficiency, SOL, WASO, REM latency, and stage_minutes per class
  4. Epoch-level agreement with WHOOP official stages is >= 70% on >= 5 overnight sessions before the phase is closed — validation result documented in phase notes
  5. `cargo test -p goose-core` green; tests cover: Cole-Kripke activity computation, stillness threshold, short-run merge, physiological reimposition rules

**Plans**: TBD

---
