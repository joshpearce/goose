# Goose — Servidor Remoto + Contribuições Upstream

## What This Is

Fork do `b-nnett/goose`: app iOS (SwiftUI + Rust core) que lê dados biométricos de dispositivos WHOOP via BLE.
Este milestone adiciona três capacidades ao fork: (1) servidor self-hosted FastAPI+TimescaleDB para armazenar dados biométricos, (2) upload automático desses dados do iOS para o servidor, (3) review e integração dos PRs abertos do upstream `b-nnett/goose`.

## Core Value

O utilizador deve poder capturar dados WHOOP no iPhone e tê-los persistidos automaticamente no seu servidor pessoal — sem depender de infraestrutura externa.

## Requirements

### Validated

- ✓ BLE GATT connection a dispositivos WHOOP 5.0 e 4.0 — existing
- ✓ Parsing de frames BLE via Rust core (libgoose_core) — existing
- ✓ Armazenamento local SQLite de frames capturados — existing
- ✓ Tabs Home / Health / Coach / More com SwiftUI — existing
- ✓ Servidor FastAPI+TimescaleDB copiado para `server/` e empacotado em Docker — v1.0
- ✓ Docker image multi-stage com named volumes (sem DATA_ROOT) — v1.0
- ✓ GooseSwift envia dados decodificados ao servidor via POST /v1/ingest-decoded — v1.0
- ✓ Configuração de URL/token na tab More com persistência Keychain/UserDefaults — v1.0
- ✓ Estado de upload visível na tab More (health check + último upload + batches pendentes) — v1.0
- ✓ 9 PRs do upstream b-nnett/goose integrados via git merge --no-ff — v1.0

### Active

- [ ] Fila de upload persistida em SQLite para sobreviver ao restart da app (v2)
- [ ] Background URLSession para upload quando a app está suspensa (v2)
- [ ] PRs de volta ao upstream b-nnett/goose com as correções do fork (v2)

### Out of Scope

- Análise de dados no servidor (dashboard, alertas) — fora deste milestone
- Suporte Android — discutido no upstream mas fora do scope do fork agora
- Autenticação avançada (OAuth, 2FA) — Bearer token simples é suficiente

## Context

- **Fork**: `tigercraft4/goose` é fork de `https://github.com/b-nnett/goose`
- **Upstream open PRs (9)**: #1 (fix timeout/duration), #3 (FFI docs), #4 (scroll perf), #5 (Apple Health), #6 (Rust CI), #7 (list_methods RPC), #10 (CI + bug fixes), #12 (FFI threading), #13 (Windows compat)
- **Upstream open issues (4)**: #2 (Android discussion), #8 (WHOOP 4.0?), #9 (multiplatform), #11 (License + Gen4)
- **Servidor my-whoop**: já existe em `/Users/francisco/Documents/my-whoop/server/` — FastAPI, TimescaleDB, Dockerfile, docker-compose.yml
- **API do servidor**: `POST /v1/ingest-decoded` com Bearer token, recebe dados já decodificados
- **Upload iOS**: o GooseSwift já tem `remote_bind_enabled` como placeholder mas sem implementação de upload

## Constraints

- **Tech stack iOS**: Swift / SwiftUI / URLSession — não introduzir dependências externas
- **Tech stack servidor**: FastAPI + TimescaleDB (manter compatibilidade com my-whoop existente)
- **Git**: planning docs no git (commit_docs: true)
- **Servidor**: deve correr em Docker no servidor pessoal do utilizador

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Copiar servidor completo para server/ no Goose | Manter tudo num repo; facilitar deploy numa única operação git pull | ✓ Good — v1.0 |
| Upload via URLSession nativo | Sem dependências externas no iOS; URLSession é suficiente para POST JSON | ✓ Good — v1.0 |
| Bearer token simples para auth do servidor | Servidor pessoal/privado; overhead OAuth desnecessário | ✓ Good — v1.0 |
| Prefixo GOOSE_ (em vez de WHOOP_) para env vars e containers | Alinhado com o repo fork; evita confusão com o my-whoop original | ✓ Good — v1.0 |
| Named volumes Docker (sem DATA_ROOT) | Zero config para `docker compose up`; mais simples para self-hosted | ✓ Good — v1.0 |
| mDNS .local para hostname do servidor | Descoberta automática na rede local; zero config DNS | ✓ Good — v1.0 |
| PR #12 FFI threading integrado por último | Após Phases 2+3+4 executadas; sem conflito com upload client | ✓ Good — v1.0 |

## Current State (v1.0)

**Shipped:** 2026-06-03
- `server/` — FastAPI+TimescaleDB self-hosted, Docker multi-stage, named volumes, GOOSE_* prefix
- `GooseSwift/RemoteServerPersistence.swift` — URL (UserDefaults), Bearer token (Keychain), upload toggle
- `GooseSwift/MoreRemoteServerViews.swift` — UI de configuração + feedback de estado na tab More
- `GooseSwift/GooseUploadService.swift` — upload automático com retry 1s/2s/4s
- `GooseSwift/GooseAppModel+Upload.swift` — hook no pipeline BLE + health check ao arrancar
- 9 PRs do upstream integrados (incluindo PR #12 FFI threading)

**E2E pendente:** `docker compose up --build` em `server/` + curl /healthz (requer Docker Desktop activo)
**Hardware pendente:** Fluxo BLE→upload→TimescaleDB (requer WHOOP físico + servidor activo)

---
*Last updated: 2026-06-03 após v1.0 milestone*

## Evolution

Este documento evolui nas transições de fase e marcos de milestone.

**Após cada transição de fase** (via `/gsd-transition`):
1. Requirements invalidados? → Mover para Out of Scope com razão
2. Requirements validados? → Mover para Validated com referência de fase
3. Novos requirements emergidos? → Adicionar a Active
4. Decisões a registar? → Adicionar a Key Decisions
5. "What This Is" ainda preciso? → Atualizar se derivou

**Após cada milestone** (via `/gsd-complete-milestone`):
1. Revisão completa de todas as secções
2. Core Value check — ainda a prioridade certa?
3. Auditoria Out of Scope — razões ainda válidas?
4. Atualizar Context com estado atual
