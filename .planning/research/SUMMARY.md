# Project Research Summary

**Project:** Goose v10.0 — Protocol Parity, Haptics & Feature Completeness
**Domain:** WHOOP-style BLE biometric companion app (iOS + Rust core)
**Researched:** 2026-06-12
**Confidence:** HIGH (FEATURES.md fully verified against live codebase; STACK/ARCHITECTURE/PITFALLS reflect v5.0 but remain structurally valid)

---

## Executive Summary

Goose v10.0 is the feature-completeness milestone for this WHOOP companion iOS app. The research identified a clear set of protocol gaps that silently break WHOOP 5.0 users today (R22 packet type 0x10 unhandled, v18 historical frames silently discarded), plus a haptic primitive (`buzz(loops:)`, command 0x13) that is confirmed present in hardware but entirely absent from Swift — its addition unblocks four downstream features in a single ~2-hour task. The recommended approach is to sequence work in five waves ordered by dependency and RE risk: protocol fixes first (no RE risk, pure Rust, highest user impact), then the haptic primitive and its immediate dependents, then data-foundation schema migrations, then coaching and notification infrastructure, and finally the alarm wake-window engine which is gated behind a mandatory protocol analysis session.

The primary architectural risk is that the existing Rust bridge is stateless and synchronous. New SQLite tables (journal, workout, appleDaily, metricSeries) must follow the established migration pattern in `store.rs` and every new state-bearing write must be idempotent, because multiple `GooseRustBridge` instances can call the same bridge method concurrently. The haptic and BLE protocol work is pure Swift + Rust extension on top of patterns that already exist; the main risk is the alarm wake-window feature, which requires a confirmed understanding of `SetAlarmInfoCommandPacketRev4` field layout before any implementation begins. HAP-04 must not be bundled with HAP-03.

A secondary risk is scope creep from the NOOP reference codebase. Several NOOP features (YearHeatStrip heatmap, WHOOP CSV import, Metric Explorer, AdvancedHaptic/HapticHeartbeat pattern system) are tempting ports but should be explicitly deferred to v11.0. The v10.0 milestone is already substantial: two Rust protocol fixes, a haptic primitive + two haptic screens, four new SQLite tables, realtime strain accumulation, a NotificationScheduler actor, Coach VOW messages, BLE data validator, a GooseBLEHistoricalManager refactor, a service-layer protocol abstraction, and a smart alarm UI.

---

## Key Findings

### Recommended Stack

No new dependencies are needed for v10.0. The existing Cargo.toml (`rusqlite 0.37`, `serde 1.0`, `serde_json 1.0`, `thiserror 2.0`) is sufficient for all Rust work including new schema migrations, bridge methods, and algorithm additions. The Swift side requires no new frameworks: URLSession, CoreBluetooth, UNUserNotificationCenter, and ActivityKit are already linked.

**Core technologies:**
- `rusqlite 0.37` — all new SQLite tables (journal, workout, appleDaily, metricSeries) follow the existing migration pattern; no ORM needed
- `serde_json` — all new bridge methods follow the existing `AlgorithmRunResult<T>` JSON envelope; no protocol changes
- `UNUserNotificationCenter` — already permission-granted in onboarding; only the `NotificationScheduler` actor is missing
- Swift `actor` type — preferred for `NotificationScheduler` and `GooseBLEHistoricalManager` to get compile-time isolation guarantees
- No additions to `Cargo.toml`; all arithmetic for any algorithm extension is expressible in `f64` stdlib

### Expected Features

All "missing" claims in the seed were verified against the live codebase before being accepted. No false positives.

**Must have — P1 (table stakes or high-leverage unblocks):**
- R22 packet parsing (Rust, type 0x10) — WHOOP 5.0 users get zero metrics today; pure Rust fix
- v18 historical per-second decode — WHOOP 5.0 historical offload is silently discarded; Rust-only
- `buzz(loops:)` haptic primitive (cmd 0x13) — 4 features depend on this single ~15-line function
- Breathe screen with strap haptic cues — flagship haptic feature; NOOP BreathingView reference available
- 4 SQLite tables (journal, workout, appleDaily, metricSeries) — foundation for 5+ features
- Realtime strain accumulation during workout — live UX gap; formula already in Rust
- iOS local notifications (sleep summary, workout, battery) — UNUserNotificationCenter auth already in onboarding

**Should have — P2:**
- Interval Timer with haptic cues (depends on buzz primitive)
- Smart alarm UI — single-shot, using existing `AlarmCommandKind` + `writeAlarmCommand()` infra
- Coach VOW messages — local rule-based; Rust decision tree + new CoachVOWView
- Stress view enhancements (Calm Time tile, delta-baseline tiles, range selector)
- Manual Workout Entry sheet (depends on workout table)
- Long-range Trends Dashboard (depends on metricSeries table)
- GooseBLEHistoricalManager refactor — decouples historical sync from active BLE connection
- Swift BLE data validator (GooseBLEDataValidator) — approx 1 day
- Protocol-based service layer + mocks + 2 test cases (GooseBLEManaging + GooseRustBridging)

**Defer to v11.0+:**
- Wake-window engine (HAP-04) — RE-gated: `SetAlarmInfoCommandPacketRev4` layout unknown
- AdvancedHaptic / HapticHeartbeat pattern system — RE prerequisite before implementation
- WHOOP CSV import — meaningful effort, not user-blocking
- YearHeatStrip heatmap (FEAT-02b)
- Metric Explorer + Correlation Engine — 7-10 days; needs metricSeries table to exist first
- HR sample decimation (LTTB) — conditional on Instruments evidence

### Architecture Approach

v10.0 extends the existing layered architecture without changing its fundamental shape. The Rust bridge remains stateless, the Swift side remains `@MainActor` for all UI mutations with dedicated `DispatchQueue` instances for BLE and pipeline work, and new features slot into the existing extension-file pattern (`GooseAppModel+*.swift`, `HealthDataStore+*.swift`). New components are: a `NotificationScheduler` actor, a `GooseBLEHistoricalManager` that wraps the historical sync logic currently embedded in `GooseAppModel`, a `GooseBLEDataValidator` struct that gates frames before the Rust bridge, and a `GooseStrainAccumulator` actor for realtime strain during workouts.

**Major new/modified components:**
1. `protocol.rs` — R22 (0x10) packet parsing + v18 historical per-second decode
2. `store.rs` — 4 new SQLite tables via schema migration (version bump required)
3. `bridge.rs` — new dispatch methods for realtime strain, Coach VOW, historical sync
4. `GooseBLEClient+Haptics.swift` — `buzz(loops:)` command 0x13 wrapper (new extension file)
5. `NotificationScheduler` (new Swift actor) — wires sleep/workout/battery triggers to UNUserNotificationCenter
6. `GooseBLEHistoricalManager` (new Swift class) — decoupled historical sync; depends on ARCH-01 protocol
7. `GooseBLEDataValidator` (new Swift struct) — frame validation gate before Rust bridge
8. `GooseStrainAccumulator` (new Swift actor) — per-sample HR accumulation to live strain score

### Critical Pitfalls

1. **HAP-03 and HAP-04 bundled in the same phase** — HAP-04 is RE-gated; bundling it with the single-shot alarm UI risks blocking delivery of HAP-03. Keep them in separate phases.

2. **State-bearing SQLite writes not idempotent** — any new table updated by multiple concurrent `GooseRustBridge` instances must wrap read-modify-write in `BEGIN EXCLUSIVE` or use a single atomic SQL expression. Applies to metricSeries inserts and any future EWMA baseline.

3. **Service layer protocols (ARCH-01) shipped without test targets** — protocols without tests are dead weight. ARCH-01 must include mocks + at least 2 test cases in the same phase; do not ship protocols alone.

4. **R22 / v18 Rust changes break existing `protocol_tests.rs` assertions** — run `cargo test -- protocol_tests` after every `protocol.rs` change; all new packet types must have round-trip tests.

5. **`TOGGLE_IMU_MODE` (cmd 106) enabled without type-51 parser** — if IMU mode is inadvertently enabled in `startCapture`, type-51 packets fall through as Raw frames creating silent HRV data gaps. Keep behind a feature flag defaulting to `false`.

---

## Implications for Roadmap

Based on dependency graph and risk profile from FEATURES.md:

### Phase 1: Protocol Parity (WHOOP 5.0 fixes)
**Rationale:** Independent of everything else; no RE risk; fixes existing users with zero working metrics. Highest user impact per effort. R22 and v18 tracks can be done in parallel.
**Delivers:** WHOOP 5.0 realtime metrics (R22 / BLE5-01) + full historical offload (v18 / BLE5-02)
**Addresses:** BLE5-01, BLE5-02
**Avoids:** Protocol round-trip test failures — run `cargo test -- protocol_tests` after every change

### Phase 2: Haptic Primitive + Haptic Screens
**Rationale:** `buzz(loops:)` is the single highest-leverage primitive — one ~15-line Swift function unblocks Breathe, Interval Timer, and alarm feedback. HAP-01 must be first task; HAP-02 and FEAT-02a follow immediately within the same phase.
**Delivers:** `buzz(loops:)` command, Breathe screen with strap cues, Interval Timer with haptic cues
**Addresses:** HAP-01, HAP-02, FEAT-02a
**Avoids:** Shipping haptic screens before the primitive exists; conflating HAP-03 with HAP-04

### Phase 3: Data Foundation
**Rationale:** Four SQLite tables are prerequisites for Manual Workout Entry, Trends Dashboard, and Coach VOW context. Single Rust migration keeps schema version consistent. Realtime strain accumulation shares this phase — it depends only on WhoopDataSignalPipeline (already exists).
**Delivers:** Schema migration with 4 new tables, `GooseStrainAccumulator`, Stress view enhancements
**Addresses:** DATA-01 (a-d), DATA-02, DATA-03a
**Avoids:** Schema fragmentation across multiple migrations

### Phase 4: Screens on New Foundation
**Rationale:** Manual Workout Entry and Long-range Trends Dashboard depend on Phase 3 tables. Can begin immediately after Phase 3 lands.
**Delivers:** Manual Workout Entry sheet, Long-range Trends Dashboard
**Addresses:** DATA-03b, DATA-03c
**Avoids:** Building screens before their data layer exists

### Phase 5: Coaching, Notifications & Structural Features
**Rationale:** Coach VOW and iOS notifications share the "passive intelligence" theme. BLE structural improvements ship together so the protocol abstraction is immediately exercised by mocks and tests — ARCH-01 is worthless without test targets.
**Delivers:** Coach VOW messages, NotificationScheduler actor, GooseBLEHistoricalManager, GooseBLEDataValidator, service-layer protocols + mocks + 2 tests
**Addresses:** FEAT-01, FEAT-03, BLE5-03, BLE5-04, ARCH-01
**Avoids:** Shipping ARCH-01 protocols without test targets

### Phase 6: Smart Alarm UI (HAP-03 only)
**Rationale:** Single-shot alarm UI builds on `AlarmCommandKind` + `writeAlarmCommand()` infrastructure that already exists. Kept separate from HAP-04 to prevent RE dependency from blocking delivery.
**Delivers:** Alarm arm/cancel UI in Sleep Coach, strap confirmation buzz via `buzz(loops:)`
**Addresses:** HAP-03
**Avoids:** Bundling HAP-04 (RE-gated) into this phase

### Phase 7 (RE-gated): Wake-Window Engine
**Rationale:** HAP-04 requires two discrete RE sessions before implementation can begin. RE-01 (BTSnoop capture of `STRAP_DRIVEN_ALARM_EXECUTED`) and RE-02 (Ghidra decompilation of `SetAlarmInfoCommandPacketRev4`) are explicit standalone tasks that gate this phase.
**Delivers:** Smart alarm wake-window (lightest-sleep firing), `GooseWakeWindowManager`
**Addresses:** HAP-04
**Avoids:** Implementing unknown wire format

### Phase Ordering Rationale

- Phase 1 is first because it has zero dependencies and fixes users immediately.
- Phase 2 is second because the haptic primitive is tiny with enormous downstream unlock value.
- Phase 3 precedes Phases 4 and 5 because schema migrations must land before any screen or bridge method that reads the new tables.
- Phase 5 groups structural/coaching work after the data layer is stable; ARCH-01 protocols are most useful once GooseBLEHistoricalManager exists to exercise them.
- Phase 6 is isolated to prevent HAP-04 RE risk from delaying HAP-03.
- Phase 7 is explicitly gated behind two completed RE sessions.

### Research Flags

Phases needing RE sessions before implementation tasks are written:
- **Phase 7 (Wake-Window Engine):** RE-01 and RE-02 must complete and be documented before any implementation tickets are created.

Phases with well-documented patterns (skip research-phase):
- **Phase 1:** R22/v18 parsing follows established `protocol.rs` patterns; issue #92 provides BTSnoop ground truth for R22.
- **Phase 2:** NOOP `BreathingView` + `IntervalTimerView` are available as reference; `buzz(loops:)` is hardware-confirmed.
- **Phase 3:** SQLite migration pattern is well-established; no novel architecture.
- **Phase 5:** `UNUserNotificationCenter` patterns are iOS stdlib; service-layer protocol patterns follow standard Swift conventions.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | No new dependencies needed; verified against live Cargo.toml and Xcode project |
| Features | HIGH | All "missing" claims grep-verified against live codebase 2026-06-12; NOOP reference available |
| Architecture | HIGH | Existing component map authoritative; new components follow established patterns |
| Pitfalls | HIGH | Critical pitfalls derived from live code inspection and established patterns |
| Wake-Window (HAP-04) | LOW | Wire format unknown; RE sessions are prerequisites |
| Cole-Kripke / IMU staging | MEDIUM | Device calibration mismatch is algorithm-literature risk; no empirical validation data |

**Overall confidence:** HIGH for Phases 1-6; LOW for Phase 7 until RE sessions complete.

### Gaps to Address

- **`SetAlarmInfoCommandPacketRev4` field layout** — unknown until RE-02 (Ghidra decompilation + BTSnoop ground-truth capture). Do not write HAP-04 implementation tasks until resolved.
- **`STRAP_DRIVEN_ALARM_EXECUTED` event parse** — unknown until RE-01 (BTSnoop capture at alarm-fire time on handle `0x0022`/`0x0027`).
- **v18 stale-clock dedup logic** — mentioned in FEATURES.md alongside the decode; needs explicit implementation spec during Phase 1 planning.
- **GooseStrainAccumulator formula inputs** — `WhoopDataSignalPipeline` publishes per-sample HR; confirm sufficient granularity during Phase 3 planning.

---

## Sources

### Primary (HIGH confidence)
- Live codebase grep verification — `GooseSwift/`, `Rust/core/src/` — 2026-06-12
- `.planning/seeds/*.md` — 16 seeds reviewed; all claims cross-checked with grep before acceptance
- NOOP reverse-engineering findings (hardware-confirmed on MG): `HapticPayloads.swift`, `BreathingView.swift`, `IntervalTimerView.swift`
- Issue #92 (darylbleach) — BTSnoop capture confirming R22 type 0x10 on WHOOP 5.0

### Secondary (MEDIUM confidence)
- Ghidra analysis of WHOOP 5.37.0 IPA (2026-06-11) — `WhoopSleepCoach`, `WhoopVow`, `WhoopLocalNotifications`, `WHPBLEProcessDataValidator` classes
- `.planning/PROJECT.md` — v10.0 active requirements list
- `.planning/research/PITFALLS.md` (v5.0) — integration pitfalls; structurally applicable to v10.0

### Tertiary (LOW confidence — validation required)
- Cole-Kripke actigraphy calibration on WHOOP IMU — needs 5-night empirical validation before shipping sleep staging
- `SetAlarmInfoCommandPacketRev4` wire layout — requires RE-02 session before HAP-04 implementation

---
*Research completed: 2026-06-12*
*Ready for roadmap: yes*
