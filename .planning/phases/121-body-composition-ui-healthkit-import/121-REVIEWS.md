# Phase 121 — Multi-AI Plan Review

**Phase:** 121 — Body Composition UI + HealthKit Import
**Plan:** 121-01-PLAN.md
**Reviewers:** Codex · Gemini · Claude-Reviewer (parallel, independent)
**Date:** 2026-06-27

---

## Cycle Summary

| Metric | Value |
|--------|-------|
| HIGH findings | 5 |
| MEDIUM findings | 3 |
| LOW findings | 4 |
| Total findings | 12 |
| Reviewer verdicts | Codex: NEEDS_REPLAN · Gemini: CONVERGED · Claude-Reviewer: NEEDS_REPLAN |
| **Synthesized verdict** | **NEEDS_REPLAN** |

Three HIGH findings are guaranteed compile failures (F-01, F-02, F-03, F-04, F-05). Execution must not proceed until the plan amendments below are applied.

---

## HIGH Findings

### F-01 — CONTEXT.md D-05 contradicts PLAN.md on sparkline implementation

**Convergence:** FULL (Codex + Gemini + Claude-Reviewer)
**Risk:** Risk 1 — Charts import gate

CONTEXT.md line 32 (`D-05`) says: *"Uses Swift Charts (Chart + .lineMark). Follows Swift Charts pattern from SleepV2BevelTrendViews.swift."*

PLAN.md must_haves truth says: *"Sparkline uses GeometryReader + Path (no import Charts)"*

`grep 'import Charts'` across GooseSwift/ returns zero results. Charts is not linked in the project. If the executor follows CONTEXT.md, the build fails with a missing framework linker error.

**Fix:** Update CONTEXT.md D-05 to:
> D-05: Inline weight sparkline using GeometryReader + Path (CoreGraphics only — no import Charts). View hidden when bodyCompositionHistory is empty. Renders last 7 days of weight_kg values from body_composition.history_between.

PLAN.md must_haves is authoritative and correct — preserve it unchanged.

---

### F-02 — `Locale.MeasurementSystem == .us` is the wrong Swift case

**Convergence:** PARTIAL (Codex + Claude-Reviewer; Gemini cleared using wrong API surface)
**Risk:** Risk 5 — Locale conversion

PLAN.md must_haves truth uses `Locale.current.measurementSystem == .us`. Swift `Locale.MeasurementSystem` (iOS 16+) has three cases: `.metric`, `.uk`, `.usSystem`. The `.us` case belongs to the deprecated `NSLocale` ObjC enum. The codebase has zero uses of `measurementSystem` — this is untested new API territory. At iOS 26 target this will either fail to compile (ambiguous member) or silently never match.

Additionally, the codebase already has a user-persisted `UnitSystem` enum (`.metric` / `.imperial`) used throughout `MoreProfileViews.swift`. A user in the US who set the app to metric would see lbs despite their preference if locale auto-detection is used.

**Fix (preferred):** Reuse the existing `UnitSystem` stored preference from `MoreProfileViews.swift` instead of `Locale.current.measurementSystem`. Update all plan references accordingly.

**Fix (minimal):** Replace all occurrences of `== .us` with `== .usSystem` in the plan if Locale auto-detection is retained. Confirm at build time.

---

### F-03 — `hkDateFormatter` is `private` — invisible from sibling extension file

**Convergence:** UNIQUE (Claude-Reviewer only)
**Risk:** Risk 2 — Compile error in new extension

PLAN.md Task 1 instructs: *"Use Self.hkDateFormatter (nonisolated static let already present in HealthDataStore+Sleep.swift)"*

`HealthDataStore+Sleep.swift:340`:
```swift
private nonisolated static let hkDateFormatter: DateFormatter = {
```

Swift `private` is file-scoped. A `private` symbol in `HealthDataStore+Sleep.swift` is completely invisible to `HealthDataStore+BodyComposition.swift`, even though both extend the same type. This is a guaranteed compile error: *"use of unresolved identifier 'hkDateFormatter'"*.

**Fix:** Add a prerequisite step to PLAN.md Task 1:
> **Prerequisite:** In `HealthDataStore+Sleep.swift:340`, change `private nonisolated static let hkDateFormatter` to `internal nonisolated static let hkDateFormatter`. This makes the formatter accessible to all HealthDataStore extensions.

---

### F-04 — `bridge.requestAsync` silently drops bare array result from `history_between`

**Convergence:** PARTIAL (Codex; confirmed by reading GooseRustBridge.swift)
**Risk:** Risk 2 — history_between return format

`GooseRustBridge.requestAsync()` is implemented as:
```swift
func requestAsync(method: String, args: [String: Any] = [:]) async throws -> [String: Any] {
    try await requestValueAsync(...) as? [String: Any] ?? [:]
}
```

When Rust returns a bare JSON array (`[[...]]`), the `as? [String: Any]` cast fails silently and returns `[:]`. PLAN.md Pitfall 1 correctly identifies that `history_between` returns a bare array (not wrapped in a `"rows"` key), but Task 1's action body calls `bridge.requestAsync` — which will always yield empty history with no error or crash.

**Fix:** In Task 1, replace:
```swift
try await bridge.requestAsync(method: "body_composition.history_between", ...)
```
with:
```swift
let rows = try await bridge.requestValueAsync(method: "body_composition.history_between",
                                              args: [...]) as? [[String: Any]] ?? []
```

Add a TDD behavior row: *"when bridge returns a bare 7-element array, bodyCompositionHistory has 7 elements"* to force this path into the test suite.

---

### F-05 — Sparkline y-coordinate inversion not specified — silent rendering bug

**Convergence:** UNIQUE (Gemini only)
**Risk:** Risk 1 — CoreGraphics sparkline correctness

PLAN.md Task 3 defers `chartPoint()` implementation to *"read SleepV2BevelTrendViews.swift for the full implementation"* with the body elided as `{ ... }`. In SwiftUI `Path`, y=0 is at the top of the coordinate space. Without the explicit formula, an executor may write:
```swift
let y = plot.minY + (normalized * plot.height)  // WRONG — inverts chart
```
producing a sparkline where heavier weights appear lower than lighter ones.

**Fix:** Add the `chartPoint` formula explicitly in PLAN.md Task 3 — do not delegate this to a reference file:
```swift
private func chartPoint(index: Int, value: Double, plot: CGRect,
                        domain: (min: Double, max: Double)) -> CGPoint {
  let normalized = (value - domain.min) / max(domain.max - domain.min, 0.001)
  let x = plot.minX + CGFloat(index) / CGFloat(max(points.count - 1, 1)) * plot.width
  let y = plot.maxY - CGFloat(normalized) * plot.height  // y=0 is TOP in CoreGraphics
  return CGPoint(x: x, y: y)
}
```

---

## MEDIUM Findings

### F-06 — Unit system should use existing stored preference, not Locale auto-detection

**Convergence:** PARTIAL (Codex + Gemini)

Partially overlaps F-02. The codebase-level argument: `MoreProfileViews.swift` uses a persisted `unitSystem` enum for all unit display decisions. Using `Locale.current.measurementSystem` for body composition display creates an inconsistency where the body composition card might show lbs while every other unit in the app shows kg.

**Fix:** Read the `unitSystem` UserDefaults key used by `MoreProfileViews.swift` and pass it into `displayWeight()`. This is the correct fix that also resolves F-02.

---

### F-07 — Thread safety: upsert calls inside HKSampleQuery continuation body risk Swift 6 actor violation

**Convergence:** UNIQUE (Gemini)

PLAN.md describes calling `await upsertBodyComposition(...)` inside the `HKSampleQuery` `withCheckedContinuation` completion handler. `HealthDataStore` is `@MainActor @Observable`. The HKSampleQuery callback runs on an arbitrary background queue. Calling `await upsertBodyComposition` inside the off-actor continuation body (before the continuation resumes) risks a Swift 6 strict concurrency actor isolation violation.

**Fix:** Restructure Task 1 to explicitly:
1. Collect all `(date, value)` tuples into a local array *inside* the continuation body (off-actor — data collection only)
2. Resume the continuation with that array
3. Call `await upsertBodyComposition(...)` in a loop *after* the continuation resumes on the `@MainActor` calling context

Add a comment to this effect in the plan's code stubs.

---

### F-08 — CONTEXT.md D-01 names wrong file for HealthView insertion point

**Convergence:** UNIQUE (Codex)

CONTEXT.md D-01 says the new section goes in `HealthDashboardViews.swift`. PLAN.md `files_modified` correctly lists `HealthView.swift`. Both anchor structs (`HealthVitalsPreviewSection` at line 34, `HealthRouteShortcutSection` at line 36) are confirmed in `HealthView.swift`.

**Fix:** Update CONTEXT.md D-01 to say `HealthView.swift` instead of `HealthDashboardViews.swift`.

---

## LOW Findings

### F-09 — Info.plist NSHealth keys already present; no edits needed

**Convergence:** FULL (Codex + Gemini + Claude-Reviewer)

Both `NSHealthShareUsageDescription` (line 40) and `NSHealthUpdateUsageDescription` (line 42) already exist in `GooseSwift/Info.plist` from Phase 97. No new entries are needed. The plan correctly omits `Info.plist` from `files_modified`.

**Fix:** Add an explicit note in PLAN.md Task 1: *"Info.plist: both NSHealth* keys already present from Phase 97 — do NOT add or modify."* Add to verify gate: `grep 'toShare: \[\]' GooseSwift/HealthDataStore+BodyComposition.swift` to assert read-only import stays read-only.

---

### F-10 — pbxproj UUID slots 019/01A/01B are confirmed free

**Convergence:** FULL (Codex + Claude-Reviewer)

Last used E-series slot is `E1/E2000000000000000000018` (RealtimePIPQueue.swift). Slots 019, 01A, 01B are free. The plan's pre-check grep instruction is correct.

**Fix:** None required. UUID assignments are safe.

---

### F-11 — bodyFatPercentage HK authorization and fraction conversion are correct

**Convergence:** FULL (Codex + Gemini + Claude-Reviewer)

`bodyFatPercentage` is not in any existing HK auth scope. The new `requestAuthorization` call for both `bodyMass` + `bodyFatPercentage` is required and correctly included. BF% ÷ fraction × 100 conversion is correct (`HKUnit.percent()` returns 0–1 range).

**Fix (enhancement):** Add a runtime guard before the multiply: `guard value >= 0.0 && value <= 1.0 else { continue }` to reject malformed HealthKit samples.

---

### F-12 — `loadBodyCompositionHistory()` belongs in existing `.onAppear` Task block

**Convergence:** UNIQUE (Codex)

`HealthView.swift` uses `.onAppear { Task { ... } }` at lines 72–78 — there is no `.task` modifier anywhere in the file. PLAN.md Task 4 instructs adding a `.task` modifier which would create a second lifecycle hook.

**Fix:** Update PLAN.md Task 4: add `await healthStore.loadBodyCompositionHistory()` inside the existing `.onAppear` Task block at line 74, not as a new `.task` modifier.

---

## Required Plan Amendments Before Execution

The following changes must be applied before `gsd-execute-phase` is invoked:

| Amendment | File | Finding |
|-----------|------|---------|
| Fix D-05: replace Swift Charts with GeometryReader+Path | 121-CONTEXT.md | F-01 |
| Fix D-01: HealthDashboardViews.swift → HealthView.swift | 121-CONTEXT.md | F-08 |
| Change `.us` → `.usSystem` OR adopt existing UnitSystem preference | 121-01-PLAN.md | F-02, F-06 |
| Add prerequisite: change `hkDateFormatter` from `private` to `internal` in HealthDataStore+Sleep.swift | 121-01-PLAN.md Task 1 | F-03 |
| Replace `bridge.requestAsync` with `bridge.requestValueAsync` + `[[String:Any]]` cast for history_between | 121-01-PLAN.md Task 1 | F-04 |
| Add explicit `chartPoint` y-inversion formula | 121-01-PLAN.md Task 3 | F-05 |
| Restructure HKSampleQuery continuation: collect off-actor, upsert on-actor | 121-01-PLAN.md Task 1 | F-07 |
| Add `.onAppear` Task block note (not new `.task`) | 121-01-PLAN.md Task 4 | F-12 |
| Add Info.plist no-touch note + toShare:[] verify gate | 121-01-PLAN.md | F-09 |
| Add BF% range guard before ×100 multiply | 121-01-PLAN.md Task 1 | F-11 |

---

## Reviewer Raw Verdicts

| Reviewer | Verdict | Key reasoning |
|----------|---------|---------------|
| Codex | NEEDS_REPLAN | CONTEXT/PLAN sparkline contradiction; requestAsync silent drop; Locale.us wrong case; UnitSystem consistency |
| Gemini | CONVERGED | Architecture sound; sparkline y-inversion not specified; thread-safety pattern ambiguous |
| Claude-Reviewer | NEEDS_REPLAN | hkDateFormatter private access = compile error; Locale.usSystem wrong case = compile error; CONTEXT D-05 contradicts PLAN |

**Synthesized:** NEEDS_REPLAN — 5 HIGH findings including 3 guaranteed compile errors (F-02, F-03, F-04) and 1 guaranteed linker error if CONTEXT.md is followed (F-01). Apply all Required Plan Amendments before re-running execute-phase.
