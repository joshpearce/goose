# Roadmap: Goose

## Milestones

- ✅ **v1.0 Remote Server + Upstream PRs** — Phases 1-5 (shipped 2026-06-03)
- ✅ **v2.0 Multi-Device & Platform Foundations** — Phases 6-8+8.1 (shipped 2026-06-04)
- ✅ **v3.0 Wearable UX, CI Hardening & RTC Sync** — Phases 9-15 (shipped 2026-06-05)
- ✅ **v4.0 Security, Performance & Coach Expansion** — Phases 16-19 (shipped 2026-06-06)
- ✅ **v5.0 Metrics Accuracy, IMU & Upstream Fixes** — Phases 20-35 (shipped 2026-06-08)
- ✅ **v6.0 UI Wiring, Algorithm Alignment & Parity Validation** — Phases 36-45 (shipped 2026-06-09)
- 🚧 **v7.0 Sync Correctness, Async & Sleep Sync** — Phases 46-51 (in progress)

## Phases

<details>
<summary>✅ v1.0 Remote Server + Upstream PRs (Phases 1-5) — SHIPPED 2026-06-03</summary>

Full details: `.planning/milestones/v1.0-ROADMAP.md`

</details>

<details>
<summary>✅ v2.0 Multi-Device & Platform Foundations (Phases 6-8+8.1) — SHIPPED 2026-06-04</summary>

Full details: `.planning/milestones/v2.0-ROADMAP.md`

Known deferred: WEAR-02 scan UI (v3.0), CR-02 per-row filter (v3.0), hardware BLE tests (no device)

</details>

<details>
<summary>✅ v3.0 Wearable UX, CI Hardening & RTC Sync (Phases 9-15) — SHIPPED 2026-06-05</summary>

Full details: `.planning/milestones/v3.0-ROADMAP.md`

</details>

<details>
<summary>✅ v4.0 Security, Performance & Coach Expansion (Phases 16-19) — SHIPPED 2026-06-06</summary>

Full details: `.planning/milestones/v4.0-ROADMAP.md`

Known deferred: COACH-06 device migration test, 4 streaming provider runtime tests, 3 localisation device tests

</details>

<details>
<summary>✅ v5.0 Metrics Accuracy, IMU & Upstream Fixes (Phases 20-35) — SHIPPED 2026-06-08</summary>

Full details: `.planning/milestones/v5.0-ROADMAP.md`

Key: HRV accuracy, Sleep staging (Cole-Kripke + 4-class), Strain/Calories (Ghidra-confirmed coefficients), V24 biometric decode, Exercise detection, Upload sync infrastructure, Readiness engine, Protocol corrections, Codebase audit (9 HIGH fixed), Cross-project review.

Known deferred: ALG-HRV-04, ALG-SLP-04, VAL-01 (human gates — require real WHOOP device data)

</details>

<details>
<summary>✅ v6.0 UI Wiring, Algorithm Alignment & Parity Validation (Phases 36-45) — SHIPPED 2026-06-09</summary>

Full details: `.planning/milestones/v6.0-ROADMAP.md`

Known deferred: ALG-HRV-04 real overnight cross-validation (v7.0), ALG-SLP-04 real overnight concordance (v7.0)

</details>

### 🚧 v7.0 Sync Correctness, Async & Sleep Sync (In Progress)

- [x] Phase 46: Upload Route Alignment (completed 2026-06-09)
- [x] Phase 47: Device ID Namespace Resolution (completed 2026-06-10)
- [x] Phase 48: Upload Sync Race Fix (completed 2026-06-10)
- [ ] Phase 49: HealthDataStore Async Migration
- [ ] Phase 50: Morning Band Sleep Sync
- [ ] Phase 51: Validation Gates (human — ALG-HRV-04 + ALG-SLP-04)

## Phase Details

### Phase 46: Upload Route Alignment

**Goal**: O servidor FastAPI tem os endpoints em falta que o iOS já chama — `POST /v1/ingest-frames` e `GET /v1/export/frames/{device_id}` — tornando o ciclo upload/import de raw frames funcionalmente completo.
**Depends on**: —
**Requirements**: ROUTE-01, ROUTE-02
**Source**: `.planning/quick/20260609-raw-frame-roundtrip/PLAN.md` (quick task já planeado)
**Success Criteria** (what must be TRUE):

  1. `POST /v1/ingest-frames` aceita um array de raw frame objects `{device_id, ts, frame_hex, packet_k}` e insere-os em `raw_evidence` com `ON CONFLICT DO NOTHING`; retorna `{inserted: N, skipped: M}`
  2. `GET /v1/export/frames/{device_id}` retorna frames paginados com cursor (`?after_ts=&limit=`) ordenados por `ts ASC`; response inclui `{frames: [...], next_cursor, total}`
  3. Ambos os endpoints requerem autenticação Bearer token (mesmo middleware existente)
  4. O iOS `importHistoricalDataFromServer` e `GooseUploadService.uploadRawFrames` usam estes endpoints sem erros 404/405
  5. Pytest suite existente (`server/ingest/tests/`) verde com novos testes para ambos os endpoints

**Plans**: 2 plans

- [x] 46-01-PLAN.md — Server: raw_frames table + POST /v1/ingest-frames + UNION read path + round-trip tests
- [x] 46-02-PLAN.md — Deploy + live smoke-test + iOS upload/import verification

---

### Phase 47: Device ID Namespace Resolution

**Goal**: O mismatch UUID (CoreBluetooth) vs device_model (BLE name) nos identificadores de dispositivo é resolvido — a coluna `device_uuid` existe na DB e o mapeamento é feito na ligação BLE.
**Depends on**: —
**Requirements**: DEVID-01, DEVID-02
**Success Criteria** (what must be TRUE):

  1. Schema migration adiciona `device_uuid TEXT` a `raw_evidence` e `decoded_frames`; filas existentes recebem `NULL` (nullable); index em `(device_uuid, ts)`
  2. No momento da ligação BLE, o `GooseBLEClient` extrai o UUID CoreBluetooth e passa-o ao `GooseAppModel` que resolve UUID ↔ device_model e guarda o mapeamento em `UserDefaults` (chave `goose.swift.device_uuid_map`)
  3. `CaptureFrameWriteQueue` e `GooseUploadService` passam `device_uuid` nos bridge calls e upload payloads respectivamente
  4. `GET /v1/export/frames/{device_id}` aceita tanto UUID como device_model como parâmetro (lookup bidireccional)
  5. `cargo test -p goose-core` verde; testes cobrem: migration roundtrip, insert com uuid, query por uuid, query por device_model

**Plans**: 3 plans (1 wave — parallel, zero file overlap)
Plans:

- [x] 47-01-PLAN.md — Rust storage layer: device_uuid migration, structs, insert/read, capture-import, upload bridge response (+ 5 tests) — DONE 2026-06-10
- [x] 47-02-PLAN.md — iOS wiring: BLE connectedPeripheralUUID, UserDefaults UUID↔model map, CaptureFrameWriteQueue, upload payload (checkpoint)
- [x] 47-03-PLAN.md — Server: raw_frames device_uuid migration, IngestFrame model, bidirectional export lookup (+ tests)

---

### Phase 48: Upload Sync Race Fix

**Goal**: A race condition em `performUpload` onde `hr_samples` são marcados como synced antes da confirmação do servidor é eliminada — rowIDs são capturados antes do request e `markHrSamplesSynced` só é chamado após 2xx.
**Depends on**: —
**Requirements**: SYNCR-01
**Success Criteria** (what must be TRUE):

  1. `GooseUploadService.performUpload` captura os rowIDs de `hr_samples` pendentes em `let rowIDs = ...` antes de construir o payload HTTP
  2. `markHrSamplesSynced(rowIDs)` é chamado apenas no `switch response { case .success: }` — nunca antes ou no `case .failure:`
  3. Uma falha HTTP 5xx ou timeout deixa os rows com `synced = 0` e eles são incluídos na próxima tentativa de upload
  4. Teste de unidade: mock do servidor retorna 503 → rows permanecem `synced = 0`; mock retorna 200 → rows ficam `synced = 1`
  5. `cargo test -p goose-core` verde (nenhuma regressão nos testes Rust do sync infrastructure)

**Plans**: 3 plans
Plans:
**Wave 1**

- [x] 48-01-PLAN.md — Rust TDD: test_pre_capture_does_not_mark_rows_inserted_during_race_window in sync_methods_tests
- [x] 48-02-PLAN.md — Swift fix: captureAllPendingRowIDs + markStreamsSynced refactor + URLSession-injectable init

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 48-03-PLAN.md — Swift unit tests: MockURLProtocol + test_upload503_leavesSynced0 + test_upload200_marksSynced1

---

### Phase 49: HealthDataStore Async Migration

**Goal**: Os 60+ call sites de bridge Rust em `HealthDataStore` são migrados de síncrono (`@MainActor`) para `async`/`await` num background actor — eliminando o risco de freeze na main thread.
**Depends on**: —
**Requirements**: ASYNC-01, ASYNC-02
**Success Criteria** (what must be TRUE):

  1. `HealthDataStore` é annotado com `@BackgroundActor` (ou usa `Task.detached` com actor isolation) — nenhum método de bridge corre na `@MainActor`
  2. Todos os 60+ call sites em `HealthDataStore+*.swift` (9 ficheiros) usam `await bridge.request(...)` — grep de `bridge.request` sem `await` retorna 0 resultados
  3. Os dashboards (Recovery V2, Sleep V2, Esforço, etc.) continuam a actualizar com dados corretos após a migração — nenhuma regressão visual
  4. `xcodebuild test` verde (ou build sem erros de compilação se não houver testes Swift)
  5. Xcode console não mostra "Publishing changes from background threads" após a migração

**Plans**: TBD

---

### Phase 50: Morning Band Sleep Sync

**Goal**: Ao ligar o WHOOP de manhã, o app lê automaticamente os frames históricos overnight da pulseira, extrai `gravity_x/y/z` dos frames K18/K24 validados, corre o Cole-Kripke pipeline, e grava `external_sleep_sessions` — dados de sono sem precisar do servidor.
**Depends on**: Phase 47 (device_uuid em raw_evidence)
**Requirements**: SLP-SYNC-01, SLP-SYNC-02, SLP-SYNC-03
**Success Criteria** (what must be TRUE):

  1. `gravity_x/y/z` dos frames K18/K24 (offsets 33–44 no body V24) são extraídos correctamente e validados contra pelo menos uma sessão de captura real com valores conhecidos — offsets confirmados antes de ir para produção
  2. Após a ligação WHOOP de manhã (detecção: primeira ligação do dia após 04:00 local), `GooseAppModel` dispara `syncBandSleepHistory()` que: (a) solicita frames históricos overnight via `GooseBLEClient`, (b) extrai gravity amostras, (c) corre `metrics.sleep_staging` via bridge, (d) insere em `external_sleep_sessions`
  3. O Sleep V2 dashboard mostra os dados sincronizados com a label "Sincronizado da pulseira" distinguindo de dados em tempo-real; noites sem sync mostram estado "A aguardar sincronização"
  4. Se o utilizador já tem frames overnight em SQLite (de captura nocturna), o sync usa esses dados directamente sem BLE request adicional
  5. `cargo test -p goose-core` verde; testes cobrem: extracção gravity dos offsets K24, insert `external_sleep_sessions`, não duplicar sessão existente

**Plans**: TBD

---

### Phase 51: Validation Gates (Human)

**Goal**: Fechar as gates manuais ALG-HRV-04 e ALG-SLP-04 — validação com dados overnight reais de pelo menos 5 noites com WHOOP físico conectado ao Goose iOS.
**Depends on**: Phase 50 (Morning Band Sleep Sync — desbloqueia dados overnight reais), Phase 47 (Device ID — garante sincronização correcta dos dados)
**Requirements**: VAL-HRV-01, VAL-SLP-01
**Human gate**: Requer dispositivo WHOOP físico + ≥5 noites de captura

**Success Criteria** (what must be TRUE):

  1. Golden fixtures gerados para ≥5 sessões overnight reais: `rr_golden_night_N.json` com RMSSD Python reference; `sleep_golden_night_N.json` com staging WHOOP oficial
  2. `|rust_rmssd - python_rmssd| <= 1.0 ms` para as ≥5 sessões → ALG-HRV-04 CLOSED
  3. Epoch agreement ≥70% entre Goose 4-class e WHOOP oficial para as ≥5 sessões → ALG-SLP-04 CLOSED
  4. Resultados documentados em `51-SUMMARY.md` com sessão datas, valores, e deltas tabelados

**Plans**: TBD (human gate — só depois de dados reais disponíveis)

---

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1–45 | v1.0–v6.0 | — | Complete | 2026-06-03 to 2026-06-09 |
| 46. Upload Route Alignment | v7.0 | 2/2 | Complete   | 2026-06-09 |
| 47. Device ID Namespace | v7.0 | 3/3 | Complete   | 2026-06-10 |
| 48. Upload Sync Race Fix | v7.0 | 3/3 | Complete   | 2026-06-10 |
| 49. HealthDataStore Async | v7.0 | 0/TBD | Not started | — |
| 50. Morning Band Sleep Sync | v7.0 | 0/TBD | Not started | — |
| 51. Validation Gates (human) | v7.0 | 0/TBD | Blocked (human gate) | — |

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

---

### Phase 999.6: body_hex Storage Optimization (absorbed into Phase 20 — v5.0)

Absorbed into Phase 20: Upstream Fixes & Storage (as PERF-05).
