# Stack Research — v10.0

**Domain:** iOS biometric app (Swift/SwiftUI + Rust core); no external Swift dependencies
**Researched:** 2026-06-12
**Confidence:** HIGH

---

## Constraint recap

All Swift additions must use only system frameworks — no SPM packages, no CocoaPods, no
Carthage. Rust core additions stay inside `Rust/core/` as new modules or extensions to
existing ones. The constraint is pre-existing project policy, not a v10.0 decision.

---

## Swift / iOS additions

### System frameworks — NEW (not currently imported by the app)

| Framework | Purpose in v10.0 | Which feature | Notes |
|-----------|-----------------|---------------|-------|
| `UserNotifications` (full use) | Schedule and fire local notifications | FEAT-03 | Already imported for onboarding permission request. v10.0 is the first time `UNUserNotificationCenter` is used for actual scheduling (`UNCalendarNotificationTrigger`, `UNTimeIntervalNotificationTrigger`). No new import statement — framework is already present. |

`CoreHaptics` is NOT needed. Strap haptic commands go via BLE cmd `0x13` puffin frame,
not through the phone's haptic engine. `UIImpactFeedbackGenerator` already used in
`LiveActivityContentView.swift` for phone-side feedback; no new haptics framework is
required for v10.0.

### System frameworks — already present, extended usage

| Framework | Extended use in v10.0 | Notes |
|-----------|----------------------|-------|
| `SwiftUI` | 3 new screens (Stress/ANS additions, Trends Dashboard, Manual Workout Entry), Breathe UI, Interval Timer, Coach VOW card | SwiftUI Charts not used — existing `HealthChartPrimitives.swift` sparkline primitives reused |
| `UserNotifications` | `NotificationScheduler` actor (3 notification types) | Onboarding already requests `.alert + .badge + .sound`; no new permission categories needed |
| `BackgroundTasks` | Battery notification rescheduling on BLE wake | `bluetooth-central` background mode already declared; `BGAppRefreshTask` already registered. BLE background wake allows rescheduling `UNCalendarNotificationTrigger` before app is killed again |
| `Network` | No change — `GooseNetworkMonitor` already complete | — |
| `Foundation` | `actor` keyword for `NotificationScheduler`; `DateComponents` for `UNCalendarNotificationTrigger`; `DateInterval` for wake-window bounds | All standard Foundation |
| `XCTest` | New test cases in `GooseSwiftTests/` for service layer mocks | Target `T40000000000000000000001` already exists in `GooseSwift.xcodeproj`; `@testable import GooseSwift` already used in existing tests |

### New Swift types — all use only system frameworks

**BLE protocol layer (BLE5-01 to BLE5-04):**

| Type | File | Pattern | Notes |
|------|------|---------|-------|
| `GooseBLEHistoricalManager` | `GooseSwift/GooseBLEHistoricalManager.swift` | `final class`, owns sync lifecycle | Decouples historical offload from `GooseBLEClient`; calls existing BLE commands via `GooseBLEManaging` protocol |
| `GooseBLEDataValidator` | `GooseSwift/GooseBLEDataValidator.swift` | `struct`, synchronous gate | Runs between raw BLE bytes and `CaptureFrameWriteQueue`; checks frame type set, byte length bounds, CRC result from Rust, sequence gap |
| `buzz(loops:)` | `GooseSwift/GooseBLEClient+Commands.swift` | Method addition (~15 lines) | cmd `0x13` puffin frame, 12-byte payload confirmed on real hardware via NOOP `HapticPayloads.swift`; prerequisite for all HAP-* features |

**Haptics / alarm layer (HAP-01 to HAP-04):**

| Type | File | Pattern | Notes |
|------|------|---------|-------|
| `GooseBLEClient+Haptics.swift` | new extension file | Follows existing `+Commands` pattern | `runHapticsPattern(id:)`, `stopHaptics()` — implements after `get_all_haptics_pattern` response decoded (RE gate) |
| `GooseWakeWindowManager` | `GooseSwift/GooseWakeWindowManager.swift` | `final class` | Wake-window orchestration, sleep-stage poll fallback, `hasTriggeredSmartAlarmForWindow` guard; depends on `SetAlarmInfoCommandPacketRev4` RE (open gap) |

**Notifications (FEAT-03):**

| Type | File | Pattern | Notes |
|------|------|---------|-------|
| `NotificationScheduler` | `GooseSwift/NotificationScheduler.swift` | `actor` | Owns all 3 notification types (sleep summary, workout detected, WHOOP battery low); actor prevents concurrent rescheduling race; uses `UNUserNotificationCenter` |

**Coach (FEAT-01):**

| Type | File | Pattern | Notes |
|------|------|---------|-------|
| `GooseCoachVOWView` | `GooseSwift/GooseCoachVOWView.swift` | SwiftUI `View` | Consumes `coach.vow_message` bridge method; string keys mapped to `Localizable.xcstrings` |

**NoopApp features (FEAT-02):**

| Type | File | Pattern | Notes |
|------|------|---------|-------|
| Breathe screen | `GooseSwift/BreatheView.swift` | SwiftUI `View` | Port from NOOP `BreathingView.swift` (18 KB, pure SwiftUI); replace `StrandDesign` → Goose primitives; wire `bleClient.buzz(loops:)` via `GooseAppModel` |
| Interval Timer | `GooseSwift/IntervalTimerView.swift` | SwiftUI `View` | Port from NOOP `IntervalTimerView.swift` (15 KB); same adaptation as Breathe |

**Data layer (DATA-01 to DATA-04):**

| Type | File | Pattern | Notes |
|------|------|---------|-------|
| `GooseStrainAccumulator` | `GooseSwift/GooseStrainAccumulator.swift` | `actor` | Subscribes to `WhoopDataSignalPipeline`; incremental Tanaka/Banister formula (coefficients already in Rust); publishes `liveSessionStrain: Double`; resets on session start/stop |
| `GooseHRDecimator` | `GooseSwift/GooseHRDecimator.swift` | `struct`, pure function | LTTB (Largest Triangle Three Buckets) algorithm; 3-tier resolution (raw <30 min; 60:1 for 30 min–4 h; 300:1 for >4 h); operates on in-memory series before chart render |
| Stress/ANS additions | extend `HealthRecoveryStressViews.swift` | SwiftUI `View` additions | "Calm Time" stat, baseline-delta tiles, W/M/3M/6M/1Y/ALL range selector — additive to existing `StressV2OverviewPage` |
| Trends Dashboard | `GooseSwift/HealthTrendsDashboardView.swift` | SwiftUI `View` | Hero recovery area chart + small-multiples grid (HRV, RHR, Strain) + YearHeatStrip component at bottom |
| Manual Workout Entry | `GooseSwift/FitnessManualWorkoutSheet.swift` | `.sheet` SwiftUI `View` | 5-field entry (sport, start, duration, avg HR, calories); `WorkoutSource.preservingCaptured` pattern from NOOP |

**Service layer / DI (ARCH-01):**

| Type | File | Pattern | Notes |
|------|------|---------|-------|
| `GooseBLEManaging` | `GooseSwift/GooseBLEManaging.swift` | `protocol` | Extracted from `GooseBLEClient`; connection state, send command, record |
| `GooseRustBridging` | `GooseSwift/GooseRustBridging.swift` | `protocol` | Extracted from `GooseRustBridge`; `request(_:)`, `requestAsync(_:)` |
| `GooseAppServicing` | `GooseSwift/GooseAppServicing.swift` | `protocol` | Composition root; wraps `GooseBLEManaging` + `GooseRustBridging` + `HealthDataStore` |
| `GooseBLEClientMock` | `GooseSwiftTests/Mocks/GooseBLEClientMock.swift` | Test-target type | In-memory, no CoreBluetooth; `#if DEBUG` or test target only |
| `GooseRustBridgeMock` | `GooseSwiftTests/Mocks/GooseRustBridgeMock.swift` | Test-target type | Returns fixture JSON; enables unit tests for `PassiveActivityDetector`, `CaptureFrameWriteQueue` |

---

## Rust core additions

No new crate dependencies. All v10.0 Rust work extends existing modules or adds new
modules within `Rust/core/src/`. `Cargo.toml` stays unchanged.

### New modules

| Module | File | Purpose | Depends on |
|--------|------|---------|-----------|
| `vow` | `Rust/core/src/vow.rs` | Coach VOW rule-based decision tree; `coach.vow_message` bridge method; returns `{category, title_key, body_key}` JSON | `metrics.rs` (reads latest scores), `bridge.rs` (dispatch) |

### Modified modules

| Module | File | Change | Feature |
|--------|------|--------|---------|
| `protocol.rs` | existing | Add `0x10` R22 arm alongside `0x9a`/`0x9b`; split `18` out of `7 | 9 | 12 | 18` NormalHistory arm → `parse_v18_body()` | BLE5-01, BLE5-02 |
| `historical_sync.rs` | existing | Add 86400 s stale-clock threshold check → 300 s grid snap; EVENT type-48 timestamp bypass; check `store.rs` and `step_counter.rs` for duplicate offset-conversion sites | BLE5-02 |
| `store.rs` | existing | 4 new table creates in `run_migrations()`: `journal`, `workout`, `appleDaily`, `metricSeries`; insert/query helpers per table | DATA-01 |
| `bridge.rs` | existing | New dispatch arms: `journal.*`, `workout.*`, `apple_daily.*`, `metric_series.*`, `coach.vow_message` | DATA-01, FEAT-01 |
| `metrics.rs` | existing | Write computed daily scores to `metricSeries` as a side-effect of existing metric runs | DATA-01 |

### Rust dependency versions — no changes

| Crate | Version in Cargo.toml | Status |
|-------|-----------------------|--------|
| `rusqlite` | `0.40` (bundled) | Unchanged — new tables via `run_migrations()` |
| `serde` / `serde_json` | `1.0` | Unchanged — VOW and journal bridge responses use existing JSON envelope |
| `thiserror` | `2.0` | Unchanged |
| `crc32fast` | `1.4` | Unchanged |
| `hex` | `0.4` | Unchanged |
| `sha2` | `0.11` | Unchanged |
| `zip` | `8.6` | Unchanged |
| `tungstenite` | `0.29` (non-Android) | Unchanged |
| `tempfile` (dev) | `3.13` | Unchanged |

---

## What NOT to add

| Avoid | Why | Use instead |
|-------|-----|-------------|
| `CoreHaptics` | Phone-side haptic engine; strap buzz is BLE cmd `0x13`, not `CHHapticEngine` | `puffinCommandFrame()` + `buzz(loops:)` in `GooseBLEClient+Commands.swift` |
| Any SPM package for charts/graphs | Violates no-external-dependency constraint; existing `HealthChartPrimitives.swift` sparklines cover all v10.0 chart needs | `HealthSparkline` + existing chart primitives |
| GRDB or any Swift SQLite wrapper | Dual-write risk — Rust+rusqlite is the single persistence layer | Rust bridge methods for all new tables |
| StrandAnalytics Swift (from NoopApp) | Goose Rust core has more complete and validated algorithm implementations; Swift duplicates create two sources of truth | Existing Rust bridge metric methods |
| `WKWebView` for Breathe / Interval Timer | NOOP sources are pure SwiftUI — no web layer | Direct SwiftUI port |
| `UNPushNotificationTrigger` / APNs | No server-side push infrastructure planned | `UNCalendarNotificationTrigger` + `UNTimeIntervalNotificationTrigger` |
| New `Info.plist` background modes | `bluetooth-central` covers battery notification rescheduling on BLE wake; `BGAppRefreshTask` already handles band sync | No `Info.plist` additions needed |
| `ndarray` / `nalgebra` / `statrs` in Rust | LTTB decimation and VOW decision tree are O(n) iteration; no matrix algebra required | `f64` stdlib |
| `rand` in Rust | No stochastic algorithms in scope | — |

---

## Open RE gaps that gate specific implementations

Not stack choices — RE tasks that must complete before implementation starts. Listed here
because they determine phase sequencing (phases behind these gates cannot start in parallel
with the RE work).

| Gate | Feature blocked | RE task |
|------|-----------------|---------|
| `STRAP_DRIVEN_ALARM_EXECUTED` event-57 payload | HAP-03 smart alarm UI confirmation/feedback | BLE capture: arm alarm for T+2 min via existing `writeAlarmCommand()`, wait for strap fire, parse handle `0x0022`/`0x0027` inbound packet |
| `SetAlarmInfoCommandPacketRev4` wire layout | HAP-04 wake-window engine (`GooseWakeWindowManager`) | Protocol analysis of `SetAlarmInfoCommandPacketRev4` + BLE capture of WHOOP app setting a windowed alarm |
| R22 6-byte `extra` field meaning | BLE5-01 RR interval extraction from WHOOP 5.0 6-byte variant | Second BLE capture during known workout with simultaneous WHOOP app HR/RR ground truth |
| `HapticsPatternType` enum values | HAP-02 advanced haptic pattern system beyond `[47, 152]` | Send `get_all_haptics_pattern` (cmd `0x3F`) to live WHOOP 5.0, parse response payload |

---

## Installation

No new packages. No changes to `Cargo.toml`. No changes to `Info.plist` or `GooseSwift.xcodeproj` capabilities.

For `GooseSwiftTests/Mocks/`: create directory and add new mock files to the existing
`GooseSwiftTests` Xcode target (target already present as `T40000000000000000000001`).

```bash
# Verify Rust toolchain before modifying protocol.rs / store.rs
rustup show        # must be >= 1.96 (Cargo.toml rust-version)
rustup target list --installed  # aarch64-apple-ios + aarch64-apple-ios-sim must be present

# Run Rust tests after protocol.rs / store.rs / historical_sync.rs changes
cd /Users/francisco/Documents/goose/Rust/core && cargo test
```

---

## Sources

- `.planning/seeds/` — all 16 seed files read directly; authored from hardware observation + NoopApp source review (HIGH confidence)
- `Rust/core/Cargo.toml` — confirmed current dependency versions
- `GooseSwift.xcodeproj/project.pbxproj` — confirmed `GooseSwiftTests` target `T40000000000000000000001` exists; `GooseSwiftTests/` directory contains 10 existing test files
- `Rust/core/src/protocol.rs:567` — confirmed `7 | 9 | 12 | 18` NormalHistory arm; `0x10` not handled
- `Rust/core/src/protocol.rs:890–893` — confirmed `STRAP_DRIVEN_ALARM_EXECUTED` named, field-level parse incomplete
- `R of `journal`, `workout`, `appleDaily`, `metricSeries` tables
- `Rust/core/src/commands.rs:592,767,788,795` — confirmed `run_haptic_pattern_maverick`, `run_haptics_pattern`, `stop_haptics`, `get_all_haptics_pattern` catalogued but not wired to Swift
- `Rust/core/src/bridge.rs` — confirmed no `coach.vow_message` dispatch arm
- `GooseSwift/GooseBLEClient.swift:612–637` — confirmed `AlarmCommandKind`, `AlarmHapticsPattern` exist; `buzz(loops:)` not present
- `GooseSwift/OnboardingPermissions.swift` — confirmed `UserNotifications` already imported; `.alert + .badge + .sound` already requested

---
*Stack research for: Goose v10.0 — Protocol Parity, Haptics & Feature Completeness*
*Researched: 2026-06-12*
