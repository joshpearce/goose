# Phase 50: Morning Band Sleep Sync - Context

**Gathered:** 2026-06-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Morning Band Sleep Sync: quando o WHOOP liga de manhã (primeira ligação após 04:00 local), o app sincroniza automaticamente os frames históricos overnight da pulseira, extrai gravity_x/y/z dos frames K18/K24 (body V24), corre o pipeline Cole-Kripke 4-class, e persiste `external_sleep_sessions` — dados de sono sem servidor.

O que esta phase entrega:
- Gravity extraction wired no `capture.import_frame_batch` bridge (V24History branch)
- Morning auto-sync trigger em GooseAppModel (connectionState observer + UserDefaults date guard)
- `syncBandSleepHistory()` em GooseAppModel+SleepSync.swift — SQLite-first flow
- `bandSleepImportStatus` actualizado com "Sincronizado da pulseira" / "A aguardar sincronização"
- Cargo tests para gravity extraction, insert external_sleep_sessions, sem duplicados

</domain>

<decisions>
## Implementation Decisions

### Gravity Extraction Path
- Inline no V24History branch de `capture.import_frame_batch` em bridge.rs (análogo ao K10 accel extraction)
- Extrair gravity_x/y/z (já disponíveis em DataPacketBodySummary::V24History) e acumular no vector gravity; inserir via insert_gravity_rows no final do batch
- gravity2_x/y/z (bytes 49–60) inserir em gravity2_samples quando present
- device_id: usar active_device_id passado ao import_frame_batch (mesmo padrão que HR/RR)

### Morning Sync Trigger
- Observer connectionState em GooseAppModel (padrão existente): quando muda para "connected" verificar condições
- Condições: hora local > 04:00 E Calendar.current.isDateInToday(lastSyncDate) == false (ou lastSyncDate == nil)
- UserDefaults key: `goose.swift.last_band_sleep_sync_date` (Data)
- Drop+reconnect mesmo dia: idempotente — não dispara se lastBandSleepSyncDate == hoje
- Escrita do UserDefaults: ao iniciar syncBandSleepHistory (não ao completar, para evitar retry loop)

### syncBandSleepHistory Flow
- Localização: novo ficheiro GooseAppModel+SleepSync.swift
- Janela overnight: ontem 20:00 local → hoje 12:00 local (cobre a maioria dos padrões de sono)
- SQLite-first: chamar gravity_rows_between antes de pedir BLE. Se rows >= 100 → usar dados existentes, skip BLE request
- Se rows < 100: disparar ble.startHistoricalSync() e aguardar (observar historicalSyncStatus == "complete")
- Após dados disponíveis: chamar bridge metrics.sleep_staging → inserir em external_sleep_sessions via store.insert_external_sleep_session com source="band_ble"
- Coordenação com overnight guard: syncBandSleepHistory só corre quando overnightGuardActive == false
- Status updates via store.markBandSleepSyncRequested / markBandSleepSyncFailed

### Sleep V2 Dashboard Label
- Usar bandSleepImportStatus existente (zero UI nova necessária)
- Quando sync completa com sucesso: bandSleepImportStatus = "Sincronizado da pulseira"
- Estado inicial / sem sync: "A aguardar sincronização" (substituir "No band sync yet" inicial)
- SleepV2BandSyncCard já exibe este campo — sem alterações de UI necessárias

### Claude's Discretion
- Staging method a usar no external_sleep_session.provenance_json: {"source":"band_ble","auto_sync":true}
- Se sleep_staging retornar staging_method "no_imu" (gravity vazia) → não inserir sessão, marcar como "A aguardar sincronização"
- Threshold de 100 gravity rows pode ser ajustado empiricamente

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `GooseBLEClient.startHistoricalSync()` — dispara historical sync BLE; `historicalSyncStatus` observable
- `HealthDataStore.refreshSleepAfterBandSync(packetCount:)` — já chama runPacketInputs + runSleepScore + runSleepStaging
- `HealthDataStore.markBandSleepSyncRequested()` / `markBandSleepSyncFailed()` — já existe
- `store.insert_external_sleep_session` — bridge Rust já implementado
- `metrics.sleep_staging` bridge — lê gravity da tabela, corre 4-class, retorna stage_minutes + efficiency
- `store.gravity_rows_between` bridge — disponível para o SQLite-first check

### Established Patterns
- GooseAppModel extensions por domain: GooseAppModel+SleepSync.swift segue padrão existente (+OvernightRun, +HealthCapture, etc.)
- UserDefaults keys: reverse-DNS estático `static let` no tipo encapsulante
- connectionState observer: pattern em GooseAppModel+Lifecycle.swift (linha 147 mostra padrão de observação)
- Bridge calls: sempre com database_path; nunca em @MainActor — usar await bridge.requestAsync
- V24History no bridge.rs (~linha 3420): branch já extrai HR, RR, SpO2, skin_temp, resp — gravity_x/y/z estão no struct mas não são extraídos ainda

### Integration Points
- bridge.rs `V24History` branch (adicionar gravity accumulation análogo ao K10 accel ~linha 3380)
- GooseAppModel.connectionState (observer existente em +Lifecycle.swift)
- GooseAppModel.overnightGuardActive (guard para não interferir)
- HealthDataStore.bandSleepImportStatus (@Published, exibido em SleepV2BandSyncCard)
- external_sleep_sessions: source field para distinguir "band_ble" de outros imports

</code_context>

<specifics>
## Specific Ideas

- "Sincronizado da pulseira" e "A aguardar sincronização" são as strings exactas para o dashboard (pt-PT, sem localização adicional necessária nesta phase)
- O threshold de 100 gravity rows para SQLite-first é um default razoável (~4s de dados a 25Hz)
- A janela overnight 20:00→12:00 pode capturar até 16h — mais do que suficiente para detectar sono nocturno
- gravity2_samples (bytes 49–60): inserir quando presente, não bloquear se ausente

</specifics>

<deferred>
## Deferred Ideas

- gravity2_samples análise (segunda tripla) — inserir apenas, análise para fase futura
- Calibração do threshold de gravity rows (100 samples) — empírico, ajustar com dados reais
- UI adicional além do bandSleepImportStatus — card separado no dashboard principal está fora do scope desta phase
- K21 gravity extraction — deferred conforme comentário existente no bridge.rs

</deferred>
