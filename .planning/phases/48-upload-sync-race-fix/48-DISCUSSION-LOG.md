# Phase 48: Upload Sync Race Fix - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-10
**Phase:** 48-upload-sync-race-fix
**Areas discussed:** Scope do fix, Estratégia de teste

---

## Scope do fix

| Option | Description | Selected |
|--------|-------------|----------|
| Só hr_samples (SYNCR-01 estrito) | Fix mínimo: capturar rowIDs de hr_samples antes do HTTP. As outras streams não têm markSynced implementado — deixar para fase futura. | |
| Todas as streams com synced flag | Verificar quais streams têm synced=0/1 no schema Rust e corrigir todas ao mesmo tempo. | ✓ |

**User's choice:** Todas as streams com synced flag
**Notes:** Generalizar o pre-capture pattern para qualquer stream que tenha coluna synced no schema.

---

## Estratégia de teste

| Option | Description | Selected |
|--------|-------------|----------|
| Rust tests apenas (cargo test) | Adicionar testes Rust para sync.rows_pending_upload e sync.mark_synced correctness. Sem Swift unit tests. | |
| Adicionar Swift XCTest target | Criar GooseSwiftTests no Xcode project. URLProtocol mock: 503→rows=0, 200→rows=1. | ✓ |
| Mock inline em GooseUploadService | URLSession injectável, sem test target, validação manual. | |

**User's choice:** Adicionar Swift XCTest target
**Notes:** Testa a camada de orquestração Swift (não apenas a lógica Rust). Requer criação de novo test target no xcodeproj.

---

## Claude's Discretion

- Nome exacto do test target e configuração do XCTest
- URLProtocol vs constructor injection para URLSession mock
- Descoberta de streams com synced flag (grep schema Rust)

## Deferred Ideas

- Fix de uploadRawFrames com pre-capture de frame IDs (raw frames não têm synced flag actualmente)
- Auditoria de idempotência de sync em todas as streams
