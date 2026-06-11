# Feature Research — v10.0 Protocol Parity, Haptics & Feature Completeness

**Domain:** WHOOP-style health/fitness iOS companion app (BLE biometric capture)
**Researched:** 2026-06-12
**Confidence:** HIGH — all claims verified against live codebase; seed "missing" claims cross-checked
with grep/ls before being accepted.

---

## Codebase Verification Notes

Before this document was written, all seed claims of "missing" or "not yet implemented" were
verified against the live codebase. Key findings:

| Seed claim | Verified status |
|---|---|
| `buzz(loops:)` not yet in Swift | CONFIRMED ABSENT — no 0x13 / RUN_HAPTIC_PATTERN in any Swift file |
| Breathe / Interval Timer screens absent | CONFIRMED ABSENT — no BreathingView or IntervalTimerView file |
| GooseBLEHistoricalManager absent | CONFIRMED ABSENT — file does not exist |
| GooseBLEDataValidator absent | CONFIRMED ABSENT — file does not exist |
| Service layer protocols absent | CONFIRMED ABSENT — GooseBLEManaging/GooseRustBridging/GooseAppServicing do not exist |
| GooseStrainAccumulator absent | CONFIRMED ABSENT — no liveSessionStrain or GooseStrainAccumulator |
| GooseHRDecimator absent | CONFIRMED ABSENT — no LTTB / decimation layer in HeartRateSeriesStores.swift |
| metricSeries / appleDaily tables absent | CONFIRMED ABSENT — not in store.rs |
| Long-range Trends Dashboard absent | CONFIRMED ABSENT — no HealthTrendsDashboardView |
| Manual Workout Entry sheet absent | CONFIRMED ABSENT — no ManualWorkoutSheet or ManualWorkout file |
| GooseWakeWindowManager absent | CONFIRMED ABSENT — file does not exist |
| GooseCoachVOWView / vow_message absent | CONFIRMED ABSENT — no VOW in Swift or Rust |
| WHOOP CSV importer absent | CONFIRMED ABSENT — no CSV import file |
| R22 packet parsing absent | CONFIRMED ABSENT — type 0x10 not handled in Rust parser |
| v18 historical decode absent | CONFIRMED — v18 silently grouped with v7/9/12 in NormalHistory arm (protocol.rs:567) |
| Alarm SET/GET/RUN Swift infra | CONFIRMED PRESENT — AlarmCommandKind enum + writeAlarmCommand() exist |
| StressV2OverviewPage | CONFIRMED PRESENT — HealthRecoveryStressViews.swift exists |
| UNUserNotificationCenter permission | CONFIRMED PRESENT in onboarding — but no NotificationScheduler for sleep/workout/battery events |
| GooseBLEBondingManager, GooseNetworkMonitor, GooseHRSanitizer | CONFIRMED PRESENT (v9.0 delivered) |

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features that a serious WHOOP companion app must have. Missing any of these makes the app
feel like a prototype.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Real-time HR + HRV during live capture | Core BLE data flow; already exists | — | Already shipped |
| Recovery / Strain / Sleep dashboards | Core biometric outputs; already exists | — | Already shipped |
| WHOOP 5.0 R22 packet metrics | WHOOP 5.0 users get no metrics today (issue #92) | LOW | Rust-only fix; BLE subscription already correct |
| v18 historical per-second decode | WHOOP 5.0 historical offload is silently discarded | MEDIUM | protocol.rs + historical_sync.rs; stale-clock dedup included |
| Real-time strain accumulation during workout | WHOOP shows live strain; Goose shows stale value | MEDIUM | Swift-side accumulator; formula already in Rust |
| iOS local notifications (sleep summary, workout, battery) | Users need in-context alerts without opening app | MEDIUM | UNUserNotificationCenter auth already in onboarding; need NotificationScheduler actor |
| Stress / ANS view enhancements | StressV2OverviewPage exists; "Calm Time" stat + Δ-baseline tiles + range selector missing | LOW | Additive only to existing screen — 0.5 days |
| Manual Workout Entry | False positives/negatives in passive detection; users need correction | MEDIUM | Depends on `workout` table |
| SQLite schema: journal + workout + appleDaily + metricSeries | Foundation for correlation, sport log, HealthKit provenance, Metric Explorer | MEDIUM | Pure Rust schema migration; no BLE/algorithm work |

### Differentiators (Competitive Advantage)

Features not expected by default but that significantly raise the value of Goose over
generic BLE logger alternatives.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Haptic buzz primitive (`buzz(loops:)` cmd 0x13) | Hardware-confirmed; unlocks 4 downstream features | LOW | ~2 hours; confirmed on real MG hardware via NOOP RE |
| Breathe screen with strap haptic cues | HRV biofeedback with live R-R; phone + strap in sync | MEDIUM | Port from NOOP BreathingView; replace StrandDesign with Goose components |
| Interval Timer with silent haptic cues | Gym-silent HIIT timer; WHOOP 5.0 differentiator | MEDIUM | Port from NOOP IntervalTimerView |
| Smart alarm + wake-window engine | Strap fires alarm autonomously; phone-side window manager | HIGH | Alarm infra exists (AlarmCommandKind); wake-window SetAlarmInfoCommandPacketRev4 needs RE |
| Coach VOW messages | Contextual coaching nudges from bridge data; local, no server | MEDIUM | Rule-based message selector in Rust; new CoachVOWView in Swift |
| GooseBLEHistoricalManager | Decoupled historical sync — bugs don't kill active connection | MEDIUM | Architectural; enables testing via service-layer DI |
| Swift BLE data validator | Corrupt frames gated before Rust/SQLite; silent discard + diagnostics | LOW | New GooseBLEDataValidator struct; ~1 day |
| Long-range Trends Dashboard | Unified multi-metric, multi-range view; YearHeatStrip heatmap | MEDIUM | Requires metricSeries table; NOOP TrendsView reference |
| WHOOP CSV import | Official WHOOP export ZIP → Goose SQLite; tolerance for 4.0/5.0/MG header variants | MEDIUM | Port from NOOP WhoopExportImporter; bridge methods for import |
| Protocol-based service layer + mocks | Unit tests for BLE, sync, health pipeline without real hardware | MEDIUM | GooseBLEManaging + GooseRustBridging protocols; mock implementations |
| HR sample decimation (LTTB) | Chart render performance for long sessions; window-adaptive | LOW | Only justified after Instruments confirms a real problem |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| AdvancedHaptic / HapticHeartbeat paced mode | WHOOP has it; sounds compelling | `HapticsPatternType` values unknown — needs RE session with live WHOOP 5.0 running `get_all_haptics_pattern`; blocks shipping Breathe | Ship Breathe with `buzz(loops:)` cues first; plan AdvancedHaptic as v11.0 after RE |
| Windowed wake-window SetAlarmInfoCommandPacketRev4 | True smart alarm (lightest-sleep firing) | Wire layout unknown; `STRAP_DRIVEN_ALARM_EXECUTED` event not yet observed; RE prerequisite before any implementation | Ship single-shot alarm UI first; windowed alarm after BTSnoop RE session |
| Apple Health XML export importer | Seems like a richer import | Goose already uses HealthKit API — XML importer would be a regression from live queries | Expand HealthKitFullImporter to write to appleDaily table instead |
| CoachEverywhere floating overlay | WHOOP shows coach messages across all screens | Intrusive; high implementation cost; no clear user request | Coach VOW card pinned to top of Coach tab only |
| Server-side VOW message delivery | More dynamic content | Requires APNs + server infrastructure; out of scope | Local rule-based message selector in Rust |
| Frequency-domain HRV / DFA alpha1 | Adds clinical depth | WHOOP itself does not expose LF/HF; no user-visible impact for WHOOP parity goal | Defer to post-v10.0 as a differentiator, not table stakes |
| Full Metric Explorer + Correlation Engine (NOOP Tier 3) | Power user analytics | 7–10 days effort; blocks shipping simpler features | Plan as dedicated v11.0 milestone after metricSeries table exists |

---

## Feature Dependencies

```
HAP-01: buzz(loops:) primitive
    ├──unlocks──> HAP-02: Breathe screen (inhale/exhale haptic cues)
    ├──unlocks──> FEAT-02a: Interval Timer (WORK/REST/done haptic cues)
    └──unlocks──> HAP-03: Smart alarm UI feedback (notification buzz on arm/cancel)

HAP-03: Smart alarm (single-shot, infra already exists)
    └──extends──> HAP-04: Wake-window engine
                      └──blocked by──> RE: SetAlarmInfoCommandPacketRev4 layout
                      └──blocked by──> RE: STRAP_DRIVEN_ALARM_EXECUTED event parse

BLE5-01: R22 packet parsing (Rust)
    └──enables──> Metrics for WHOOP 5.0 users streaming 0x10

BLE5-02: v18 historical decode (Rust)
    └──enables──> Full historical offload for WHOOP 5.0 users

BLE5-03: GooseBLEHistoricalManager
    └──depends on──> ARCH-01: GooseBLEManaging protocol (for testability)

ARCH-01: Service layer protocols
    └──enables──> BLE5-03: GooseBLEHistoricalManager (mockable)
    └──enables──> Unit tests for CaptureFrameWriteQueue, PassiveActivityDetector

DATA-01a: metricSeries table
    └──unblocks──> DATA-03b: Long-range Trends Dashboard (range queries)

DATA-01b: workout table
    └──unblocks──> DATA-03c: Manual Workout Entry sheet
    └──unblocks──> FEAT-02d: WHOOP CSV import (workout rows)

DATA-01c: journal table
    └──extends──> FEAT-01: Coach VOW messages (behaviour tag context)
    └──unblocks──> Correlation Engine (v11.0+)

DATA-01d: appleDaily table
    └──unblocks──> HealthKitFullImporter provenance separation

DATA-02: Realtime strain accumulation
    └──depends on──> WhoopDataSignalPipeline (already exists; must publish per-sample HR)

FEAT-03: iOS local notifications
    └──depends on──> syncBandSleepHistory() (sleep summary trigger — already exists)
    └──depends on──> PassiveActivityDetector .finished (workout trigger — already exists)
    └──soft depends──> BLE battery GATT (battery table already populated)

DATA-04: HR decimation
    └──conditional──> Only after Instruments confirms render cost is real
```

### Dependency Notes

- **HAP-01 is the single highest-leverage primitive**: 4 features unblock from one ~15-line function.
  It must be the first task in any haptic phase.

- **HAP-03 and HAP-04 are split by RE risk**: HAP-03 (single-shot alarm UI) builds on the
  existing `AlarmCommandKind` + `writeAlarmCommand()` infrastructure that is already fully
  implemented. HAP-04 (wake-window) is blocked by a genuine RE gap
  (`SetAlarmInfoCommandPacketRev4` layout unknown) and observation of `STRAP_DRIVEN_ALARM_EXECUTED`.
  Do not bundle HAP-03 and HAP-04 in the same phase.

- **ARCH-01 (service layer) has an important constraint** from the seed: protocols are only
  justified when test targets exist to use them. Build Phase 1 (protocols) + Phase 2 (mocks) +
  Phase 3 (at least 2 test cases) atomically — do not ship protocols alone.

- **DATA-01 (4 tables) should ship as a single Rust migration** to keep schema version consistent.
  Build order within DATA-01: metricSeries first (unblocks Trends), then journal, then workout,
  then appleDaily.

- **BLE5-01 and BLE5-02 are independent** of each other and of the haptic tree — they can be
  done in any order and have no shared prerequisites.

- **FEAT-03 (iOS notifications)** has the UNUserNotificationCenter permission already in onboarding.
  What is missing is the `NotificationScheduler` actor that wires the three trigger points. No
  new background modes needed.

---

## Build Order (Phase Sequencing Recommendations)

Based on dependencies and risk profile:

### Wave 1 — Protocol gaps (no RE risk, pure Rust, unblocks WHOOP 5.0 users)
- BLE5-01: R22 packet parsing
- BLE5-02: v18 historical decode + stale-clock dedup

These are the highest-impact fixes for existing users. Independent. Can be done in parallel.

### Wave 2 — HAP-01 buzz primitive + immediate haptic features
- HAP-01: `buzz(loops:)` via cmd 0x13 (~2 hours)
- HAP-02: Breathe screen (depends on HAP-01)
- FEAT-02a: Interval Timer (depends on HAP-01)

HAP-01 is a prerequisite for HAP-02, FEAT-02a, and the alarm feedback in HAP-03. Ship it first.

### Wave 3 — Data foundation + screens
- DATA-01: 4 SQLite tables (journal, workout, appleDaily, metricSeries) — pure Rust migration
- DATA-02: Realtime strain accumulation — Swift-side accumulator during workout
- DATA-03a: Stress view delta additions (Calm Time tile, Δ-baseline, range selector)
- DATA-03c: Manual Workout Entry sheet (depends on workout table from DATA-01b)
- DATA-03b: Long-range Trends Dashboard (depends on metricSeries from DATA-01a)

### Wave 4 — Coaching + notifications + structural features
- FEAT-01: Coach VOW messages (depends on bridge data; enhanced by journal table)
- FEAT-03: iOS local notifications (NotificationScheduler actor)
- BLE5-03: GooseBLEHistoricalManager (decoupling; enhanced by ARCH-01 protocols)
- BLE5-04: Swift BLE data validator (GooseBLEDataValidator)
- ARCH-01: Protocol-based service layer + mocks + 2 test cases

### Wave 5 — HAP-03/04 alarm (RE-gated)
- HAP-03: Smart alarm UI using existing infrastructure (alarm confirmation/cancel in Sleep Coach)
- HAP-04: Wake-window engine — only after BTSnoop RE session confirms SetAlarmInfoCommandPacketRev4

### Defer to v11.0+
- FEAT-02b: YearHeatStrip heatmap (0.5 days, but not blocking anything in v10.0)
- FEAT-02c: WHOOP CSV import (meaningful effort; not user-blocking)
- FEAT-02d: Metric Explorer + Correlation Engine (NOOP Tier 3; 7–10 days)
- DATA-04: HR decimation (conditional on Instruments evidence)
- AdvancedHaptic / HapticHeartbeat pattern system (RE prerequisite)

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| BLE5-01: R22 parsing | HIGH — fixes WHOOP 5.0 users entirely | LOW — Rust only | P1 |
| BLE5-02: v18 historical decode | HIGH — fixes WHOOP 5.0 historical offload | MEDIUM — 2 Rust files + test | P1 |
| HAP-01: buzz primitive | HIGH — unblocks 4 features | LOW — ~2 hours | P1 |
| HAP-02: Breathe screen | HIGH — flagship haptic feature | MEDIUM — NOOP port + adaptation | P1 |
| DATA-01: 4 SQLite tables | HIGH — foundation for 5+ features | MEDIUM — pure Rust migration | P1 |
| DATA-02: Realtime strain | HIGH — live workout UX gap | MEDIUM — new Swift actor | P1 |
| FEAT-03: iOS notifications | HIGH — passive alerts without app open | MEDIUM — NotificationScheduler actor | P1 |
| FEAT-01: Coach VOW messages | MEDIUM — coaching UX upgrade | MEDIUM — Rust decision tree + Swift view | P2 |
| DATA-03: Stress/Trends/Manual Workout | MEDIUM — visible screens | MEDIUM — 5 days total | P2 |
| FEAT-02a: Interval Timer | MEDIUM — gym use case | MEDIUM — NOOP port | P2 |
| HAP-03: Smart alarm UI | MEDIUM — existing infra just needs UI | LOW — UI only on top of existing infra | P2 |
| BLE5-03: BLEHistoricalManager | MEDIUM — maintainability + testability | MEDIUM — refactor | P2 |
| BLE5-04: BLE data validator | MEDIUM — data integrity | LOW — new struct, ~1 day | P2 |
| ARCH-01: Service layer + mocks | MEDIUM — enables unit tests | MEDIUM — protocols + mocks + 2 tests | P2 |
| HAP-04: Wake-window engine | HIGH value, HIGH risk | HIGH — RE gate | P3 (RE blocked) |
| DATA-04: HR decimation | LOW — mitigated by existing prune() | LOW | P3 (conditional) |
| FEAT-02c: WHOOP CSV import | MEDIUM — power user import | MEDIUM — NOOP port | P3 |

**Priority key:**
- P1: Must have for v10.0 — unblocks users or unlocks a cluster of other features
- P2: Should have in v10.0 — meaningful value addition
- P3: Defer — either RE-blocked, conditional, or better as v11.0

---

## RE Prerequisites (Must Be Planned as Explicit Tasks)

Two features require targeted reverse-engineering sessions before implementation can begin.
These are not "research" in the GSD sense — they are concrete 30–60 min hardware sessions:

### RE-01: STRAP_DRIVEN_ALARM_EXECUTED event parse (HAP-04 gate)
- Arm alarm for T+2 min via existing `writeAlarmCommand()`
- BTSnoop HCI capture with `/opt/homebrew/bin/tshark`
- Identify inbound payload on handle `0x0022`/`0x0027` at alarm fire time
- Map to `StrapDrivenAlarmSetEventPacketRev1/Rev3` field layout in `strap_events.rs`

### RE-02: SetAlarmInfoCommandPacketRev4 layout (HAP-04 gate)
- Decompile `SetAlarmInfoCommandPacketRev4` in Ghidra
- BTSnoop capture of WHOOP app setting a smart alarm (ground-truth bytes)
- Find field offsets for `alarmMode` (Exact vs Range), `lowerTimeBound`, `upperTimeBound`, `enabled`

Both RE sessions should be planned as standalone phase tasks, not bundled into the
implementation phases that depend on them.

---

## Sources

- Live codebase grep verification: `GooseSwift/`, `Rust/core/src/` — 2026-06-12
- Seed files: `.planning/seeds/*.md` — 16 seeds reviewed
- NOOP reverse-engineering findings in seeds (hardware-confirmed on MG): `HapticPayloads.swift`, `BreathingView.swift`, `IntervalTimerView.swift`
- Ghidra analysis of WHOOP 5.37.0 IPA (2026-06-11): `WhoopSleepCoach`, `WhoopVow`, `WhoopLocalNotifications`, `WHPBLEProcessDataValidator` classes
- Issue #92 (darylbleach): BTSnoop capture confirming R22 type 0x10 on WHOOP 5.0
- `.planning/PROJECT.md` — v10.0 active requirements list

---
*Feature research for: WHOOP iOS companion app — v10.0 protocol parity, haptics, feature completeness*
*Researched: 2026-06-12*
