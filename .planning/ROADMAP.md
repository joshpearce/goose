# Roadmap: Goose

## Milestones

- ✅ **v1.0 Servidor Remoto + PRs Upstream** — Phases 1-5 (shipped 2026-06-03)

## Phases

<details>
<summary>✅ v1.0 Servidor Remoto + PRs Upstream (Phases 1-5) — SHIPPED 2026-06-03</summary>

- [x] Phase 1: Server Infrastructure (3/3 plans) — completed 2026-06-03
- [x] Phase 2: iOS Server Settings (2/2 plans) — completed 2026-06-03
- [x] Phase 3: iOS Upload Client (3/3 plans) — completed 2026-06-03
- [x] Phase 4: Upload Status Feedback (2/2 plans) — completed 2026-06-03
- [x] Phase 5: Upstream PR Integration (4/4 plans) — completed 2026-06-03

Full details: `.planning/milestones/v1.0-ROADMAP.md`

</details>

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Server Infrastructure | v1.0 | 3/3 | Complete | 2026-06-03 |
| 2. iOS Server Settings | v1.0 | 2/2 | Complete | 2026-06-03 |
| 3. iOS Upload Client | v1.0 | 3/3 | Complete | 2026-06-03 |
| 4. Upload Status Feedback | v1.0 | 2/2 | Complete | 2026-06-03 |
| 5. Upstream PR Integration | v1.0 | 4/4 | Complete | 2026-06-03 |

### Phase 6: WHOOP 4.0 (Gen4) Support

**Goal:** Expor o suporte Gen4 no connect flow iOS — o utilizador consegue ligar, capturar e fazer upload de dados de um WHOOP 4.0 com a mesma experiência que o 5.0. O Rust core e protocolo já suportam Gen4 completamente (DeviceType::Gen4, header 4-byte, CRC8, UUID 61080001-8D6D-82B8-614A-1C8CB0F8DCC6). Falta o app-layer iOS: onboarding reconhece WHOOP 4.0, BLE client escaneia o UUID de serviço Gen4, e a geração é classificada e propagada corretamente.
**Mode:** mvp
**Depends on:** Phase 3
**References:** `/Users/francisco/Documents/my-whoop/ios/OpenWhoop/BLE/` — padrões BLE Gen4 existentes; `Rust/core/src/protocol.rs` — DeviceType::Gen4 já implementado
**Requirements**: GEN4-01, GEN4-02, GEN4-03, GEN4-04, GEN4-05
**Success Criteria** (what must be TRUE):
  1. Utilizador com WHOOP 4.0 consegue ligar o dispositivo na app (onboarding e connect flow)
  2. BLE scan inclui UUID de serviço Gen4 (61080001-8D6D-82B8-614A-1C8CB0F8DCC6)
  3. Frames Gen4 são capturados, parseados e escritos em SQLite corretamente
  4. Upload envia `device_generation: "4.0"` no payload (servidor já aceita)
**Plans:** TBD

### Phase 7: Android Port Foundations

**Goal:** Estabelecer as fundações de arquitetura que não fecham a porta a um port Android no futuro, sem fazer uma reescrita agora. O Rust core já compila para targets Android (aarch64-linux-android, armv7-linux-androideabi) via Cargo. Formalizar a FFI bridge para suportar JNI, documentar os pontos de extensão da arquitetura, e validar que o Rust core funciona num emulador Android. Contexto: upstream issues #2 e #9.
**Mode:** mvp
**Depends on:** Phase 6
**Requirements**: ANDROID-01, ANDROID-02, ANDROID-03
**Success Criteria** (what must be TRUE):
  1. `cargo build --target aarch64-linux-android` produz biblioteca estática sem erros
  2. Documentação da FFI bridge descreve como integrar com JNI (Kotlin/Android)
  3. ADR documenta as escolhas arquiteturais que facilitam (ou não fecham) o port Android
**Plans:** TBD

### Phase 8: Additional Wearables Support

**Goal:** Adicionar suporte a um segundo tipo de wearable além do WHOOP (ex: Amazfit Helio Strap ou Fitbit Air), validando que a arquitetura Rust core + BLE pipeline é extensível. Rust core trata de parsing e SQLite; a camada BLE iOS é modular por serviço GATT. Contexto: upstream issue #14.
**Mode:** mvp
**Depends on:** Phase 6
**Requirements**: WEAR-01, WEAR-02, WEAR-03
**Success Criteria** (what must be TRUE):
  1. Utilizador consegue ligar um segundo tipo de dispositivo e ver dados capturados na app
  2. Rust core tem módulo de parsing separado para o novo dispositivo (sem contaminar o módulo WHOOP)
  3. Pipeline BLE→SQLite→upload funciona para o novo dispositivo com o mesmo servidor
**Plans:** TBD
