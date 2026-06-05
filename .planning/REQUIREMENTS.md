# Requirements: Goose v4.0 — Security, Performance & Coach Expansion

**Defined:** 2026-06-05
**Core Value:** Secure, performant, multi-provider AI coaching on top of the WHOOP data capture platform.

## Milestone Goal

Harden the URL scheme security, eliminate SwiftUI re-render overhead via @Observable migration, and expand the Coach tab to support multiple AI providers and user-configured endpoints.

## Requirements

### Security

- [ ] **SEC-01**: Deep links via `gooseswift://` URL scheme can only invoke **read-only** debug commands; state-changing commands (Bluetooth writes) are blocked from external callers (upstream PR #15 by kobemartin)

### Performance

- [ ] **PERF-01**: `GooseAppModel` uses Swift `@Observable` macro — views that do not access a changed property do not re-render (eliminates `objectWillChange` broadcast)
- [ ] **PERF-02**: `HealthDataStore` uses Swift `@Observable` macro — same per-property tracking benefit
- [ ] **PERF-03**: `Update NavigationRequestObserver tried to update multiple times per frame` warning eliminated at capture startup

### Coach Expansion

- [ ] **COACH-01**: `CoachProvider` protocol abstracts the AI provider — `send(messages:systemPrompt:) async throws -> AsyncStream<String>`
- [ ] **COACH-02**: Multiple named accounts per provider stored in Keychain with provider prefix
- [ ] **COACH-03**: At least one additional provider supported (Claude API by Anthropic)
- [ ] **COACH-04**: User-configured custom endpoint (OpenAI Chat Completions-compatible `POST /v1/chat/completions` with SSE streaming)
- [ ] **COACH-05**: Provider picker UI in More/Coach settings — shows configured accounts, lets user add/remove/select active account
- [ ] **COACH-06**: Existing single OpenAI key migrated to named account on first launch after upgrade

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SEC-01 | Phase 16 | Planned |
| PERF-01 | Phase 17 | Planned |
| PERF-02 | Phase 17 | Planned |
| PERF-03 | Phase 17 | Planned |
| COACH-01 | Phase 18 | Planned |
| COACH-02 | Phase 18 | Planned |
| COACH-03 | Phase 18 | Planned |
| COACH-04 | Phase 18 | Planned |
| COACH-05 | Phase 18 | Planned |
| COACH-06 | Phase 18 | Planned |
