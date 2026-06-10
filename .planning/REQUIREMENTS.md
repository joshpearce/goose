# Requirements: v8.0 Quality, Completeness & Backlog Clearance

## Milestone Goal

Auditar o código recente para bugs, limpar quick tasks acumuladas, e completar todas as superfícies UI em falta que ficaram no backlog desde v1.0.

---

## v1 Requirements

### Bug Audit

- [ ] **AUDIT-01**: Code review de v6.0–v7.0 (fases 36–50) identifica e corrige bugs de correctness, data races e edge cases em Rust e Swift

### Quick Tasks

- [ ] **QT-01**: O utilizador consegue abrir as definições de Bluetooth do iOS directamente a partir do botão BT na app
- [ ] **QT-02**: O CodeQL corre automaticamente em PRs/pushes via GitHub Actions
- [ ] **QT-03**: O utilizador consegue importar dados do HealthKit via HealthKit Full Importer

### Home — Surfaces

- [ ] **HOME-01**: HomeDashboardView mostra Device Status Card com nome do device, estado da ligação, battery %, live HR, última sincronização e acção de reconnect quando desligado
- [ ] **HOME-02**: HomeDashboardView mostra Tools Grid com atalhos para Sleep Coach, Activity, Journal e Calibration — cada um reflecte o estado de readiness do bridge
- [ ] **HOME-03**: HomeDashboardView mostra Evidence Footer com versão do Rust core, caminho da store, modo de dados e provenance por família de métricas

### Coach — Routes e Conteúdo

- [ ] **COACH-07**: CoachSummaries implementa score summaries para sleep, recovery, strain e stress
- [ ] **COACH-08**: O utilizador consegue registar uma entrada de journal diária com prompt automático, tags opcionais e nota de texto persistida localmente
- [ ] **COACH-09**: Sleep Coach route mostra wind-down time, target bedtime, wake time e sleep debt/fulfillment
- [ ] **COACH-10**: Recovery Insights route mostra recovery score, HRV, RHR, respiratory rate, skin temp delta e recomendação determinística
- [ ] **COACH-11**: Strain Guidance route mostra strain score, target strain, exercício, daytime HR e orientação under/in/over-target
- [ ] **COACH-12**: Stress Guidance route mostra stress score, último HRV/HR, breakdown por nível e non-activity stress quando disponível

### Biometrics — Recovery Fix

- [ ] **BIO-05**: Recovery score usa z_rhr calculado de SpO2/resp/wrist temp reais dos pacotes V24 — elimina o baseline fabricado de 55.0 bpm

### Activity

- [ ] **ACT-01**: Stress windows são particionadas por limites de sessões de exercício para que o non-activity stress só use amostras de HR fora de exercício

### Persistência

- [ ] **ENB-01**: Daily stress windows e estado do Energy Bank são persistidos em SQLite com rows diárias para histórico de longo prazo

### Calibração

- [ ] **CAL-01**: O utilizador consegue correr uma calibration pipeline real com splits train/holdout a partir de métricas locais históricas — resultados não hardcoded

### Surface Cleanup

- [ ] **SURF-01**: `previewMissingData` e strings de preview só são avaliados em `#if DEBUG` — nenhum valor fabricado visível ao utilizador em builds de produção

### More Tab

- [ ] **MORE-01**: More tab completa as actions de capture imports, backfill fields, raw export com famílias seleccionáveis, e links de privacy (eliminação e export de dados)

### Previews

- [ ] **PREV-01**: Previews SwiftUI existem para HomeDashboardView, CoachView e More views — cada um com estados connected/populated, disconnected e no-data — verificados com simulator screenshot

### Health

- [ ] **HALG-01**: HealthDataStore implementa `algorithmPreferences` e `referenceAlgorithmDefinitions` wired ao bridge catalog

### Band Sleep

- [ ] **BAND-01**: Sleep records são ingeridos directamente de pacotes BLE (band sleep import path) — UI deixa de mostrar "band sleep import not available"

---

## Future Requirements

- ALG-HRV-04 / VAL-HRV-01: RMSSD cross-validated em ≥5 sessões overnight reais — hardware gate, Phase 51
- ALG-SLP-04 / VAL-SLP-01: 4-class staging concordância ≥70% em ≥5 sessões reais — hardware gate, Phase 51
- SLP-SYNC real-device: gravity offsets K24 confirmados contra captura real — hardware gate, Phase 51
- Energy Bank charge/drain rate calibration contra histórico de recuperação/sono/actividade
- Chat/AI backend para Coach (requer política de privacidade e estratégia de persistência)
- Upload queue persistido em SQLite para sobreviver a reinicios da app
- Background URLSession para upload com app suspensa

## Out of Scope

- PRs de volta ao upstream b-nnett/goose com fixes do fork
- Server-side data analysis (dashboards web, alertas)
- Advanced authentication (OAuth, 2FA) — Bearer token é suficiente
- Full Android app — fundações de arquitectura em v2.0 são suficientes
- Offline mode — real-time é o core value

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUDIT-01 | Phase 51 | Pending |
| QT-01 | Phase 52 | Pending |
| QT-02 | Phase 52 | Pending |
| QT-03 | Phase 52 | Pending |
| SURF-01 | Phase 52 | Pending |
| HOME-01 | Phase 53 | Pending |
| HOME-02 | Phase 53 | Pending |
| HOME-03 | Phase 53 | Pending |
| COACH-07 | Phase 54 | Pending |
| COACH-08 | Phase 54 | Pending |
| COACH-09 | Phase 55 | Pending |
| COACH-10 | Phase 55 | Pending |
| COACH-11 | Phase 55 | Pending |
| COACH-12 | Phase 55 | Pending |
| BIO-05 | Phase 56 | Pending |
| ACT-01 | Phase 56 | Pending |
| ENB-01 | Phase 57 | Pending |
| CAL-01 | Phase 57 | Pending |
| MORE-01 | Phase 58 | Pending |
| PREV-01 | Phase 58 | Pending |
| HALG-01 | Phase 58 | Pending |
| BAND-01 | Phase 59 | Pending |
