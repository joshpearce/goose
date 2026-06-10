# Phase 49: HealthDataStore Async Migration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-10
**Phase:** 49-HealthDataStore Async Migration
**Areas discussed:** Approach, Scope, Estratégia de migração, DispatchQueues, Verificação

---

## Abordagem de migração

| Option | Description | Selected |
|--------|-------------|----------|
| @BackgroundActor global actor | Criar global actor; mudar HealthDataStore para @BackgroundActor | |
| bridge.request async wrap | GooseRustBridge.requestValue fica async throws com Task.detached interno | ✓ |
| Minimal: nonisolated async methods | Manter @MainActor; converter refresh methods para nonisolated async | |

**User's choice:** Recomendação de Claude — bridge.request async wrap
**Notes:** Claude recomendou esta abordagem como a mais limpa: HealthDataStore mantém @MainActor, o FFI corre em Task.detached, todos os call sites ficam com `await`. Satisfaz SC-01 e SC-02 do ROADMAP sem risco de regressão na UI.

---

## Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Todos os 60+ call sites | Zero grep sem await no final | ✓ |
| Apenas refresh methods principais | Migrar só entry points (~10 métodos) | |
| Confirmar freeze real primeiro | Verificar warnings antes de migrar | |

**User's choice:** Todos os 60+ call sites
**Notes:** Migração completa — zero ocorrências de bridge.request sem await.

---

## Estratégia de migração

| Option | Description | Selected |
|--------|-------------|----------|
| Wave por ficheiro | Plan 1: GooseRustBridge; Plans 2-N: grupos de HealthDataStore+*.swift | ✓ |
| Big-bang num só plano | Migrar todos os 18 ficheiros num único plano | |

**User's choice:** Wave por ficheiro
**Notes:** Abordagem incremental para verificação de compilação entre waves.

---

## DispatchQueues existentes

| Option | Description | Selected |
|--------|-------------|----------|
| Remover | Remover packetInputQueue e heartRateTimelineQueue após migração | ✓ |
| Manter como backup | Deixar declaradas sem uso | |

**User's choice:** Remover
**Notes:** Zero código morto após migração.

---

## Verificação

| Option | Description | Selected |
|--------|-------------|----------|
| Build limpo + simulador smoke test | xcodebuild + dashboards no simulador | ✓ |
| Só build | Zero erros de compilação suficientes | |

**User's choice:** Build limpo + simulador smoke test
**Notes:** Recovery V2, Sleep V2, e Esforço devem popular com dados.

---

## Claude's Discretion

- Batching exacto dos HealthDataStore+*.swift em planos
- Se usar `requestAsync` aditivo ou substituir `request` directamente
- Se usar `nonisolated` wrapper ou instância directa no bridge

## Deferred Ideas

None — discussion stayed within phase scope.
