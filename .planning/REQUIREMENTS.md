# Requirements — v16.0 Android UI Parity, Rust Architecture & Code Health

*Milestone:* v16.0
*Created:* 2026-06-28
*Status:* Active

## Active Requirements

### Android UI Parity (AND-UI)

- [ ] **AND-UI-01**: User can view Sleep dashboard with SleepV2 bevel + 14-day trends on Android (Compose — parity iOS SleepV2BevelTrendViews)
- [ ] **AND-UI-02**: User can view HRV timeline card + strain/recovery metric cards on Android (Jetpack Compose)
- [ ] **AND-UI-03**: User can access Coach tab with OAuth, AI chat, multi-provider selector on Android (parity iOS CoachChatModel/CoachProviderRegistry)
- [ ] **AND-UI-04**: User can configure server URL, view device identity, export data, and see BLE status on Android Settings screen

### Code Audit — Multi-Model (RUST-AUD)

- [ ] **RUST-AUD-01**: Opus + Gemini + Codex analyse Rust core + Android Kotlin in parallel → structured findings report (module organisation, god-files, JNI patterns, threading, null-safety, coroutine scope)
- [ ] **RUST-AUD-02**: Android architecture fixes applied from RUST-AUD-01 findings (JNI error propagation, coroutine scope hygiene, Compose state management)

### Android Best Practices (BP-AND)

- [ ] **BP-AND-01**: All JNI calls in GooseBridge.kt propagate errors — no silent `Result` discards
- [ ] **BP-AND-02**: WhoopBleClient + BleViewModel use `CoroutineScope(lifecycle)` — zero GlobalScope usage

### Android Comments (COMM-AND)

- [ ] **COMM-AND-01**: WHY comments in GooseBridge.kt JNI entry points (JNI SAFETY pattern, parameter trust, cleanup — parity with Rust COMM-05 from v14.0)
- [ ] **COMM-AND-02**: Protocol offset WHY comments in Android FrameReassembler/WhoopBleClient (parity Rust COMM-04 from v14.0)

## Future Requirements

- Android widget / Live Activity equivalent (Android 14 Dynamic Notifications) — deferred post v16.0
- Android background BLE sync without foreground service — deferred (OS restriction investigation needed)
- Android HealthConnect export parity with iOS HealthKit export — deferred

## Out of Scope

- iOS changes in v16.0 (iOS work resumes in v17.0)
- Server-side changes (no server work planned)
- WHOOP Gen5/MG specific Android support (v16.0 targets Gen4 parity; MG extension future seed)
- Play Store release (unsigned APK CI sufficient for now)

## Traceability

| REQ-ID | Phase | Status |
|--------|-------|--------|
| AND-UI-01 | Phase 129 | Pending |
| AND-UI-02 | Phase 129 | Pending |
| AND-UI-03 | Phase 130 | Pending |
| AND-UI-04 | Phase 131 | Pending |
| RUST-AUD-01 | Phase 127 | Pending |
| RUST-AUD-02 | Phase 128 | Pending |
| BP-AND-01 | Phase 128 | Pending |
| BP-AND-02 | Phase 128 | Pending |
| COMM-AND-01 | Phase 131 | Pending |
| COMM-AND-02 | Phase 131 | Pending |
