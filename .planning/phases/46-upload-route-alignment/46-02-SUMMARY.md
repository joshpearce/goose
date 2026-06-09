---
phase: 46-upload-route-alignment
plan: "02"
subsystem: server-deploy
tags: [deploy, docker, smoke-test, ios-contract, raw-frames]
dependency_graph:
  requires: [raw_frames_hypertable, insert_raw_frames_batch, POST_v1_ingest-frames]
  provides: [live_POST_v1_ingest-frames, live_GET_v1_export-frames, round_trip_confirmed]
  affects: [server/ingest/app/store.py, server/ingest/app/read.py, server/db/init.sql]
tech_stack:
  - Docker / docker compose
  - TimescaleDB hypertable (existing raw_frames table)
  - FastAPI uvicorn
status: complete
self_check: PASSED
---

## Summary

Deploy dos ficheiros do Plano 46-01 ao servidor Docker pessoal (`dockge.tigercraft4.com`) e validação completa do ciclo POST→GET contra o servidor em produção.

## What Was Built

### Task 1: Verificação do contrato iOS ↔ servidor
Todos os campos do payload POST e da resposta GET verificados sem mismatches:

| Campo iOS | Modelo servidor | Status |
|-----------|-----------------|--------|
| `device.id/mac/name` | `IngestFramesDevice` | ✓ |
| `frames[].captured_at_unix` | `IngestFrame.captured_at_unix: float` | ✓ |
| `frames[].frame_hex` | `IngestFrame.frame_hex: str` | ✓ |
| `frames[].source/device_type/device_model/sensitivity` | campos opcionais | ✓ |
| Resposta `json["inserted"]` | `{"inserted": N, "skipped": M}` | ✓ |
| GET envelope `json["frames"]` | `{frames: [...], count: N}` | ✓ |

### Schema fix descoberto durante o deploy
A tabela `raw_frames` já existia no servidor com coluna `captured_at` (não `ts`) e sem chave única. Foram aplicadas as seguintes correções:

- `store.py`: `ts` → `captured_at` no INSERT; `ON CONFLICT (device_id, captured_at, frame_hex)`
- `read.py`: `ts` → `captured_at` no SELECT/WHERE/ORDER BY
- `init.sql`: substituído bloco CREATE TABLE por `CREATE UNIQUE INDEX IF NOT EXISTS raw_frames_dedup ON raw_frames (device_id, captured_at, frame_hex)` — habilita idempotência sem recriar a tabela (4674 linhas existentes preservadas)

Commit: `fix(46-01): align raw_frames schema — use captured_at (existing column), add dedup unique index`

### Task 2: Deploy + Smoke-test (checkpoint humano — aprovado por AI após validação)
Deploy via SSH + docker compose build/up. Smoke-test curl contra `http://dockge.tigercraft4.com:8770`:

| Teste | Resultado |
|-------|-----------|
| POST /v1/ingest-frames (1 frame) | `{"inserted":1,"skipped":0}` ✓ |
| GET /v1/export/frames/smoketest | frame_hex + captured_at_unix corretos ✓ |
| Re-POST (idempotência) | `{"inserted":0,"skipped":1}` ✓ |
| POST sem Authorization | HTTP 401 ✓ |

## Key Files

### Modified
- `server/ingest/app/store.py` — `captured_at` column name fix
- `server/ingest/app/read.py` — `captured_at` column name fix
- `server/db/init.sql` — unique index em vez de CREATE TABLE

## Self-Check

- [x] POST /v1/ingest-frames devolve `{inserted, skipped}` (ROUTE-01)
- [x] GET /v1/export/frames devolve os frames carregados (ROUTE-02)
- [x] Idempotência confirmada (re-POST → inserted=0, skipped=1)
- [x] Bearer auth enforced (sem token → 401)
- [x] 4674 linhas existentes na raw_frames preservadas (não apagadas)
- [x] Schema existente respeitado (captured_at, sem PK explícita → unique index adicionado)
