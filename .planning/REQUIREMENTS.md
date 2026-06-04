# Requirements: Goose v3.0

**Defined:** 2026-06-04
**Core Value:** The user must be able to capture WHOOP data on iPhone and have it persisted automatically on their personal server — without depending on external infrastructure.

## v3.0 Requirements

### WEAR — HR Monitor UX

- [ ] **WEAR-04**: User can view a scan list of nearby HR monitors (device name + RSSI) and initiate a scan from the app
- [ ] **WEAR-05**: User can tap a device in the scan list to connect the HR monitor
- [ ] **WEAR-06**: User can run an HR monitor capture session independently, without requiring an active WHOOP session

### FIX — Bug Fixes & Tech Debt

- [ ] **FIX-01**: HR monitor frames are stored with the correct non-NULL `device_id` per row (CR-02 fix in `capture_import.rs`)
- [ ] **FIX-02**: WHOOP BLE reconnection uses exponential backoff (1 s base, doubles, 60 s cap, 10-attempt circuit breaker) with manual retry and stop buttons in the UI
- [ ] **FIX-03**: HR monitor BLE reconnection uses the same exponential backoff parameters as WHOOP (applied to `GooseBLEHRMonitorManager`)

### RTC — WHOOP 4.0 Clock Sync

- [ ] **RTC-01**: WHOOP 4.0 clock is automatically synced to iPhone time after BLE connection when clock drift exceeds the configured threshold (resolves upstream issue #17)

### DASH — Recovery V2 Dashboard

- [ ] **DASH-01**: User can view Recovery V2 dashboard with HRV, RHR, hero score, and 7-day trend, backed by live bridge data from Rust

### L10N — pt-PT Localisation

- [ ] **L10N-01**: All static UI text literals are translated to European Portuguese (pt-PT) via Xcode String Catalog (`.xcstrings`)
- [ ] **L10N-02**: All dynamic status strings (`@Published` BLE state, connection state, sync state) are displayed in pt-PT at the view layer

## v4.0 Requirements (Deferred)

### Upload Reliability

- **UPLD-01**: Upload queue persisted in SQLite to survive app restarts
- **UPLD-02**: Background URLSession for upload when app is suspended
- **UPLD-03**: Sync cursor/watermark to resume partial uploads

### Platform

- **ANDROID-01**: Full Android app UI (architecture foundations only in v2.0)
- **UPSTREAM-01**: PRs back to upstream b-nnett/goose with fork fixes

### Wearables

- **WEAR-EXT-01**: Third wearable + generic `Wearable` protocol

## Out of Scope

| Feature | Reason |
|---------|--------|
| Server-side dashboard / alerts | Not core to data capture value |
| Advanced authentication (OAuth, 2FA) | Simple Bearer token is sufficient for personal server |
| Auto-pairing HR monitor on first scan | User must confirm connection explicitly |
| Full Android app | Architecture foundations only in v2.0 |
| pt-PT for diagnostic/log strings (in `record(...)` calls) | Logs are developer-facing; translating them adds noise without benefit |

## Traceability

Populated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FIX-01 | — | Pending |
| FIX-02 | — | Pending |
| FIX-03 | — | Pending |
| WEAR-04 | — | Pending |
| WEAR-05 | — | Pending |
| WEAR-06 | — | Pending |
| RTC-01 | — | Pending |
| DASH-01 | — | Pending |
| L10N-01 | — | Pending |
| L10N-02 | — | Pending |

**Coverage:**
- v3.0 requirements: 10 total
- Mapped to phases: 0 (pending roadmap)
- Unmapped: 10 ⚠

---
*Requirements defined: 2026-06-04*
*Last updated: 2026-06-04 — v3.0 initial definition*
