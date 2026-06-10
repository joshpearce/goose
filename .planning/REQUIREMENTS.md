# Requirements: Goose v7.0

**Defined:** 2026-06-10
**Core Value:** O utilizador captura dados WHOOP no iPhone e tem-nos persistidos automaticamente no servidor pessoal — sem depender de infraestrutura externa. As métricas alinham com o que o WHOOP produz a partir dos mesmos dados brutos.

## v7 Requirements

### Upload Route Alignment

- [ ] **ROUTE-01**: O servidor FastAPI aceita `POST /v1/ingest-frames` com raw BLE frames e persiste-os no TimescaleDB — tornando o upload iOS de frames funcionalmente completo (issue #17)
- [ ] **ROUTE-02**: O servidor expõe `GET /v1/export/frames/{device_id}` com paginação cursor-based, permitindo ao iOS importar frames via trust-chain (issue #17)

### Device ID Namespace

- [ ] **DEVID-01**: A coluna `device_uuid` (UUID CoreBluetooth) existe em `raw_evidence` e `decoded_frames` e é preenchida em cada captura (issues #10, #18)
- [x] **DEVID-02**: O mapeamento UUID ↔ device_model é resolvido no momento da ligação BLE — upload e export usam o mesmo identificador consistente (issues #10, #18)

### Upload Sync Race Fix

- [ ] **SYNCR-01**: `performUpload` captura os rowIDs de `hr_samples` antes do HTTP request e só chama `markHrSamplesSynced` após confirmação 2xx do servidor — elimina blind-marking (issue #78)

### HealthDataStore Async Migration

- [ ] **ASYNC-01**: Todos os 60+ call sites de bridge em `HealthDataStore` (9 ficheiros Swift) são convertidos para `async`/`await` num background actor — zero chamadas síncronas Rust na `@MainActor` (issue #79)
- [ ] **ASYNC-02**: A UI continua a actualizar correctamente após a migração — nenhum freeze de main thread, dashboards respondem normalmente

### Morning Band Sleep Sync

- [ ] **SLP-SYNC-01**: Os campos `gravity_x/y/z` de frames K18/K24 (offsets 33–44) são promovidos de CANDIDATE para produção no parser Rust — validados contra captura real com valores conhecidos
- [ ] **SLP-SYNC-02**: Ao ligar o WHOOP de manhã (primeira ligação do dia), o app dispara automaticamente o pipeline "Sync from band" → `gravity_samples` nocturnos → Cole-Kripke → `external_sleep_sessions`
- [ ] **SLP-SYNC-03**: Os dados de sono sincronizados da pulseira são visíveis no Sleep V2 dashboard com a label "Sincronizado da pulseira" — distinguindo de dados em tempo-real

### Validation Gates (human — requerem dados reais)

- [ ] **VAL-HRV-01**: RMSSD Rust (`goose_hrv_v0`) vs Python reference (`my-whoop/hrv.py`) delta ≤1 ms em ≥5 sessões overnight reais capturadas pelo Goose iOS — fecha ALG-HRV-04
- [ ] **VAL-SLP-01**: Classificador 4-class com ≥70% concordância de época em ≥5 sessões overnight reais vs etapas oficiais WHOOP — fecha ALG-SLP-04

## v8 Requirements

### Deferred

- **BT-OPEN-01**: Botão BT abre as definições iOS de Bluetooth directamente (low priority, backlog)
- **VAL-SPO2-01**: SpO2 calibrado com curva RoR real (requer estudo de calibração com oxímetro de referência)
- **SPORT-01**: Classificação de desporto por sessão de exercício (corrida, ciclismo, HIIT, etc.)
- **AH-SYNC-01**: Apple Health bidireccional — importar dados históricos de HealthKit para `external_sleep_sessions`

## Out of Scope

| Feature | Reason |
|---------|--------|
| Upload queue em SQLite (persistente após crash) | URLSession já retry; overhead vs benefício baixo |
| Background URLSession para upload em suspenso | Requer entitlement adicional; Bearer token expira |
| PRs upstream para b-nnett/goose | Upstream inactivo; fork é o produto principal |
| Server-side analytics/dashboard | Out of scope — servidor é apenas storage |
| OAuth 2.0 full (PKCE + refresh) | Bearer token simples suficiente para servidor pessoal |
| Full Android app | Foundations em v2.0; app completa não planeada |
| Offline mode | Real-time é core value; sync matinal (Phase 50) cobre caso principal |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ROUTE-01 | Phase 46 | Pending |
| ROUTE-02 | Phase 46 | Pending |
| DEVID-01 | Phase 47 | Pending |
| DEVID-02 | Phase 47 | Complete |
| SYNCR-01 | Phase 48 | Pending |
| ASYNC-01 | Phase 49 | Pending |
| ASYNC-02 | Phase 49 | Pending |
| SLP-SYNC-01 | Phase 50 | Pending |
| SLP-SYNC-02 | Phase 50 | Pending |
| SLP-SYNC-03 | Phase 50 | Pending |
| VAL-HRV-01 | Phase 51 (human gate) | Pending |
| VAL-SLP-01 | Phase 51 (human gate) | Pending |

**Coverage:**

- v7 requirements: 12 total
- Mapped to phases: 12
- Unmapped: 0 ✓

---
*Requirements defined: 2026-06-10*
*Last updated: 2026-06-10 after initial definition*
