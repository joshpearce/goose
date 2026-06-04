# Research Summary — Goose v3.0

**Synthesized from:** STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md
**Date:** 2026-06-04
**Confidence:** HIGH

---

## Executive Summary

Goose v3.0 adds seven targeted capabilities to an existing iOS + Rust BLE app. All features build on infrastructure already present — **no new frameworks, no new Rust crates, no new server dependencies required.** Every feature can be built with CoreBluetooth, rusqlite 0.37, SwiftUI, and DispatchQueue patterns already used in the project.

---

## Stack Additions

**None required.** All v3.0 features are achievable with the existing stack:

| Feature | Mechanism | Note |
|---------|-----------|------|
| HR scan UI | SwiftUI List + CoreBluetooth (already present) | Pattern in `ConnectionView.swift` |
| HR independent capture | `GooseAppModel` gate decoupling | Pure Swift, no new deps |
| CR-02 device_id filter | rusqlite query fix (already present) | Rust-only change |
| Recovery V2 dashboard | Existing bridge methods + new HealthDataStore extension | No new Rust code |
| pt-PT localisation | `.xcstrings` String Catalog (Xcode 15+, iOS 17+) | No SPM packages |
| WHOOP 4.0 RTC sync | `writeClockCommand` already implemented for Gen4 | Caller addition only |
| BLE reconnect backoff | `DispatchWorkItem` + `asyncAfter` (pattern already used in project) | No new APIs |

---

## Feature Table Stakes vs Differentiators

### HR Monitor Scan/Connect UI
- **Table stakes:** Scan list showing device name + RSSI, tap to connect, loading state, error state
- **Differentiators:** RSSI-sorted list (already in manager), connection status badge
- **Anti-features:** Auto-pairing on first scan (user must confirm)

### HR Monitor Independent Capture
- **Table stakes:** HR frames captured independently of WHOOP session state
- **Differentiators:** Per-device isolation via CR-02 device_id
- **Anti-features:** Merging HR + WHOOP frames into same capture session

### BLE Reconnect Backoff (PR #18)
- **Table stakes:** Exponential delay (1→2→4→8→16→32→60s cap), 10-attempt circuit breaker, manual retry button
- **Differentiators:** `ReconnectBackoffBanner` with countdown + attempt count, "Stop Retrying" button
- **Critical:** Must apply to both `GooseBLEClient+CentralDelegate` AND `GooseBLEHRMonitorManager`

### WHOOP 4.0 RTC Sync (issue #17)
- **Table stakes:** Auto-trigger on `connectionState == "ready"` for Gen4, drift threshold check, `.get` then `.set` sequence
- **Note:** Infrastructure 90% complete; only a caller is missing in `processDiscoveredCharacteristics`

### Recovery V2 Dashboard
- **Table stakes:** Hero score, HRV, RHR, timeline, 7-day trend
- **Status:** `RecoveryV2OverviewPage` scaffold exists; bridge methods exist; `HealthDataStore+RecoveryV2.swift` extension missing

### pt-PT Localisation
- **Table stakes:** All user-visible strings in pt-PT
- **Critical:** Zero localisation infrastructure exists (no `.xcstrings`, no `.lproj`); 310+ hardcoded literals; 51 `String(localized:)` calls already ready
- **Must split into two sub-phases:** static catalog extraction first, dynamic `@Published` status strings second

---

## Architecture — Integration Points & Build Order

### New Components
| Component | Type | Note |
|-----------|------|------|
| `HRMonitorScanView.swift` | SwiftUI View | New file |
| `HealthDataStore+RecoveryV2.swift` | Extension | New file |
| `GooseBLEClient+CentralDelegate.swift` backoff | Modified | Add `scheduleReconnectWithBackoff` |
| `GooseBLEHRMonitorManager` backoff | Modified | Mirror WHOOP backoff pattern |
| `Localizable.xcstrings` | New | String Catalog |

### Modified Components
| Component | Change | Risk |
|-----------|--------|------|
| `GooseAppModel+NotificationPipeline.swift:170` | Decouple HR frame gate from `activeHealthPacketCapture` | Medium |
| `GooseBLEClient.swift` | Add `@Published var discoveredHRDevices` forwarded from manager | Low |
| `capture_import.rs:400` | Pass real `active_device_id` instead of `None` | Low (Rust only) |
| `processDiscoveredCharacteristics` | Call `sendRTCSyncIfNeeded()` for Gen4 | Low |

### Recommended Build Order
1. **CR-02 device_id fix** — Rust-only, zero risk, unblocks HR capture testing
2. **BLE reconnect backoff** — Infrastructure, must be stable before HR scan UI ships
3. **HR scan UI + independent capture** — Depends on 1 + 2; fixes data race in `discoveredHRDevices`
4. **WHOOP 4.0 RTC auto-sync** — Standalone, Gen4-isolated, hooks into characteristics path
5. **Recovery V2 dashboard** — Self-contained, bridge methods already in Rust
6. **pt-PT localisation** — Last, when all v3.0 UI strings are stable

Steps 4 and 5 have no mutual dependency — can be done in parallel.

---

## Watch Out For

| Pitfall | Severity | Phase |
|---------|----------|-------|
| `discoveredHRDevices` data race — mutated on BT queue, read from main thread | HIGH | Phase 3 |
| Two CBCentralManagers share `coreBluetoothQueue` — HR notifications serialised behind WHOOP | HIGH | Phase 3 |
| CR-02 is a schema problem — `active_device_id` is NULL at session start, not a query bug | HIGH | Phase 1 |
| Recovery V2 bridge on `@MainActor` will freeze UI — must use background dispatch pattern | HIGH | Phase 5 |
| pt-PT: 310+ literals, no `.xcstrings` — split into 2 sequential sub-phases | HIGH | Phase 6 |
| RTC sync: must send `.get` first, wait for response, then `.set` — never write time blindly | HIGH | Phase 4 |
| BLE backoff: `DispatchWorkItem` cancel at `didConnect` + `didFailToConnect` + user stop | MEDIUM | Phase 2 |
| HR monitor `didDisconnectPeripheral` does nothing today — backoff not applied | HIGH | Phase 2 |

---

## Open Questions for Implementation

- **Gen4 RTC command numbers:** Confirm `.get = 11`, `.set = 10` against physical device (issue #17 has no technical detail)
- **CR-02 Option A vs B:** JOIN path (no schema migration) vs denormalised `device_id` column — decide at implementation
- **HR scan UI placement:** Health tab sheet vs. dedicated More tab entry
- **Backfill:** Should CR-02 fix backfill existing sessions where `active_device_id = NULL`?

---

## Research Confidence

| Area | Confidence | Notes |
|------|-----------|-------|
| Stack (no new deps) | HIGH | Verified against all feature requirements |
| HR scan UI gap | HIGH | Direct code inspection; gap confirmed |
| CR-02 root cause | HIGH | Line 400 `capture_import.rs` confirmed |
| BLE backoff design | HIGH | Pattern confirmed from existing project workItems |
| RTC sync completeness | HIGH | Infrastructure confirmed; command numbers TBD |
| Recovery V2 wiring gap | HIGH | Scaffold + bridge confirmed; extension missing |
| pt-PT scale | HIGH | 310+ literals confirmed via grep |
| Gen4 RTC command numbers | LOW | Inferred from existing code; needs device validation |
