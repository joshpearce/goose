# Requirements: Goose — Code Health & Protocol Foundation

**Defined:** 2026-06-14
**Milestone:** v12.0
**Core Value:** O utilizador captura dados WHOOP no iPhone e tem-nos persistidos automaticamente no servidor pessoal — sem depender de infraestrutura externa. Métricas alinham com o que o WHOOP produz dos mesmos dados raw.

## v1 Requirements

### Battery (SEED-002)

- [ ] **BAT-01**: Gen4 real battery % via Event-48 (type 48) payload — offset 17 u16 LE / 10; guard raw ≤ 1100; displayed in UI replacing the always-100% value
- [ ] **BAT-02**: Gen4 GET_BATTERY_LEVEL (cmd 26) response parsing — payload[2..4] u16 LE / 10; guard count ≥ 4; used as fallback when Event-48 not yet received

### Protocol Architecture (SEED-003)

- [ ] **PROTO-01**: `WireProtocol { Gen4, Gen5 }` Rust enum exposed to Swift; replaces 17 `rustDeviceType == "GEN4"` string comparisons in GooseAppModel+NotificationPipeline.swift and GooseBLEClient extension files
- [ ] **PROTO-02**: `DeviceKind { Whoop4, Whoop5, HrMonitor }` + `DeviceCapabilities` struct in Rust; bridge method `device.capabilities(device_kind)` called after GATT discovery; cached as `connectedCapabilities: DeviceCapabilities?` in GooseBLEClient
- [ ] **PROTO-03**: DB migration normalises MAVERICK/PUFFIN device_type → GOOSE on upgrade; `parse_device_type()` rejects MAVERICK/PUFFIN with error; `activeDeviceGeneration: WhoopGeneration` replaced by `connectedCapabilities` guards in Swift

### Architecture — Rust (SEED-004 Fase A+B)

- [ ] **ARCH-01**: bridge.rs 509-arm `match` dispatcher → `BridgeRouter` trait + handlers split into domain files (`bridge/metrics.rs`, `bridge/sleep.rs`, `bridge/capture.rs`, `bridge/activity.rs`, `bridge/debug.rs`); bridge.rs reduced to ~100 lines of routing
- [ ] **ARCH-02**: store.rs 140 public methods → domain stores sharing `Arc<Connection>` (`SleepStore`, `CaptureStore`, `MetricsStore`, `ActivityStore`) in `store/` subdirectory; runtime schema version validation on SQLite open
- [ ] **ARCH-03**: 133 `.unwrap()` calls in production code (bridge.rs 71, store.rs 62) → `Result<_, GooseError>`; `#[cfg_attr(not(test), deny(clippy::unwrap_used))]` added; `catch_unwind` safety net on bridge dispatcher entry point

### Architecture — Swift (SEED-004 Fase C)

- [ ] **ARCH-04**: `HealthDataStore` owned by `GooseAppModel` (strong reference); `AppShellView` no longer creates `@StateObject private var healthStore`; `GooseSwiftApp` injects via `.environmentObject(model.healthStore)`; weak back-reference and circular closures eliminated
- [ ] **ARCH-05**: `GooseBLEClient` refactored to `BLETransport` protocol + `BLESessionCoordinator` actor + `DeviceCatalog` struct; all Gen4/Gen5 branching centralised in `DeviceCatalog`; `CoreBluetoothBLETransport` concrete implementation
- [ ] **ARCH-06**: `GooseAppModel` split into domain `@Observable` objects (`BLEState`, `SyncState`, `HealthState`); SwiftUI views observe only the relevant domain object; high-frequency BLE updates (HR at 1Hz) no longer invalidate unrelated views

### Code Comments (SEED-005)

- [ ] **COMM-01**: Protocol offset comments added at each WHOOP wire-format decode site in `protocol.rs` and `bridge.rs` — Event-48 battery layout (offsets 17/21/26), cmd 26 response, R22 battery_pct field; includes empirical verification date and source reference
- [ ] **COMM-02**: Threading invariant comments added at `GooseRustBridge` usage sites and frame reassembly buffer — explains synchronous FFI, multiple-instance pattern, `@MainActor` dispatch requirement, `NSLock` guards
- [ ] **COMM-03**: Algorithm coefficient comments added in `metric_features.rs` for Banister eTRIMP (1.92/1.67 gender coefficients), EWMA alpha (0.0483 = 14-night half-life), Cole-Kripke scale (0.001); includes bibliographic references

## v2 Requirements

### Architecture — Future

- **ARCH-07**: GooseBLEClient+Parsing.swift frame reassembly buffer migrated to Swift-only (removes Rust bridge round-trip for partial frames)
- **ARCH-08**: `GooseAppModel` startup sequence made fully lazy — BLE, Rust bridge, and HealthStore initialised off critical path

### Hardware-gated

- **VAL-01**: ALG-HRV-04 / VAL-HRV-01 real overnight RMSSD cross-validation (≥5 sessions, delta ≤1 ms vs Python ref) — requires physical WHOOP device
- **VAL-02**: ALG-SLP-04 / VAL-SLP-01 4-class staging real overnight concordance ≥70% — requires physical WHOOP device

## Out of Scope

| Feature | Reason |
|---------|--------|
| New user-facing features | This milestone is 100% internal code health — no UI changes except battery display |
| GooseBLEClient+HistoricalHandlers.swift full rewrite | SEED-004 Phase C (ARCH-05) covers protocol; historical sync state machine deferred |
| Server-side changes | All changes are iOS app and Rust core only |
| Android / JNI updates | Out of scope for code health milestone |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| BAT-01 | TBD | Pending |
| BAT-02 | TBD | Pending |
| PROTO-01 | Phase 83 | Pending |
| PROTO-02 | Phase 83 | Pending |
| PROTO-03 | Phase 83 | Pending |
| ARCH-01 | TBD | Pending |
| ARCH-02 | TBD | Pending |
| ARCH-03 | TBD | Pending |
| ARCH-04 | TBD | Pending |
| ARCH-05 | TBD | Pending |
| ARCH-06 | TBD | Pending |
| COMM-01 | TBD | Pending |
| COMM-02 | TBD | Pending |
| COMM-03 | TBD | Pending |

**Coverage:**
- v1 requirements: 14 total
- Mapped to phases: 14
- Unmapped: 0 ✓ (roadmapper will assign phases)

---
*Requirements defined: 2026-06-14*
*Last updated: 2026-06-14 after milestone v12.0 goal gathering*
