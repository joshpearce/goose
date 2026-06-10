---
phase: 49-healthdatastore-async-migration
plan: "04"
subsystem: healthdatastore
tags: [async, swift-concurrency, sleep-staging, readiness, GooseRustBridge]
dependency_graph:
  requires:
    - phase: 49-01
      provides: "requestAsync / requestValueAsync on GooseRustBridge"
    - phase: 49-03
      provides: "async runPacketScores / runSleepScore / runRecoveryV1"
  provides:
    - async runSleepStaging (1 awaited bridge call, HealthDataStore+StagingSleep.swift)
    - async runReadinessV1 (2 awaited sequential bridge calls, HealthDataStore+Readiness.swift)
  affects:
    - 49-05 (Exercise+IMU+V24 migration — same async pattern)
    - 49-07 (final caller cleanup — partial callers addressed here)
tech_stack:
  added: []
  patterns:
    - "async func with @MainActor state captured as local let before first await"
    - "Task{ await store.runXxx() } wrapper for sync caller sites in Views"
    - "Direct self.prop = result after await (safe: HealthDataStore is @MainActor)"
key_files:
  created: []
  modified:
    - GooseSwift/HealthDataStore+StagingSleep.swift
    - GooseSwift/HealthDataStore+Readiness.swift
    - GooseSwift/HealthDataStore.swift
    - GooseSwift/HealthSleepOverviewViews.swift
    - GooseSwift/HealthRecoveryStressViews.swift
decisions:
  - "liveStrainReport captured before first await in runReadinessV1 to preserve @MainActor state snapshot"
  - "runReadinessV1 merged into existing Task{} in HealthRecoveryStressViews alongside runPacketScores+runRecoveryV1 — single Task per trigger"
  - "runSleepStaging caller in HealthSleepOverviewViews wrapped in standalone Task{ await } per existing pattern"
metrics:
  duration_minutes: 8
  completed_date: "2026-06-10"
  tasks_completed: 2
  files_modified: 5
requirements: [ASYNC-01, ASYNC-02]
---

# Phase 49 Plan 04: StagingSleep + Readiness Async Migration Summary

**Migrated `runSleepStaging` (1 bridge call) and `runReadinessV1` (2 sequential bridge calls) from `packetInputQueue.async` GCD dispatch to Swift Concurrency `async func` + `await bridge.requestAsync` — 3 total bridge calls now off the @MainActor.**

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Migrate runSleepStaging to async (StagingSleep) | ea0a611 | GooseSwift/HealthDataStore+StagingSleep.swift, GooseSwift/HealthDataStore.swift, GooseSwift/HealthSleepOverviewViews.swift |
| 2 | Migrate runReadinessV1 to async with 2 sequential awaits (Readiness) | c60b3f3 | GooseSwift/HealthDataStore+Readiness.swift, GooseSwift/HealthRecoveryStressViews.swift |

## What Was Built

- `runSleepStaging()` is now `async`: 1 awaited `bridge.requestAsync("metrics.sleep_staging")` call. All @MainActor inputs (`databasePath`, `packetScoreReports["sleep"]`) captured as local `let` before the await. `packetInputQueue.async` wrapper removed. Inner `Task { @MainActor }` closures removed. `self.sleepStagingResult` mutated directly after the await (Swift guarantees @MainActor re-entry — D-02).

- `runReadinessV1()` is now `async`: 2 sequential awaited `bridge.requestAsync(...)` calls preserving original order — first `"exercise.sessions_between"` fetches sessions, then `"metrics.goose_readiness_v1"` computes the readiness score from aggregated daily strain. All @MainActor inputs (`databasePath`, `packetScoreReports["strain"]`) captured before the first await. `packetInputQueue.async` wrapper removed. `Task { @MainActor }` closure removed. `self.readinessResult` mutated directly after both awaits.

## Build Verification

- Scheme: GooseSwift
- Destination: iPhone 17 Simulator (iOS latest)
- Result: `** BUILD SUCCEEDED **`
- Swift Concurrency warnings: none
- Errors: none

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Wrapped sync callers of now-async runSleepStaging in Task{} to unblock build**
- **Found during:** Task 1 post-edit build check
- **Issue:** `HealthDataStore.swift` (line 309) called `self.runSleepStaging()` bare inside an existing `Task { }` — needed `await`. `HealthSleepOverviewViews.swift` (line 147) called `store.runSleepStaging()` in `.onAppear {}` sync context — Swift rejects async calls from sync contexts.
- **Fix:** `HealthDataStore.swift`: added `await` before the call (already inside a Task). `HealthSleepOverviewViews.swift`: wrapped in `Task { await store.runSleepStaging() }`.
- **Files modified:** `GooseSwift/HealthDataStore.swift`, `GooseSwift/HealthSleepOverviewViews.swift`
- **Committed in:** ea0a611

**2. [Rule 1 - Bug] Wrapped sync callers of now-async runReadinessV1 in Task{} to unblock build**
- **Found during:** Task 2 post-edit build check
- **Issue:** `HealthRecoveryStressViews.swift` called `store.runReadinessV1()` as bare sync call in `.onAppear {}` and `.onChange {}` closures. Per the 49-03 decision, this was intentionally deferred until this plan migrated `runReadinessV1`.
- **Fix:** Merged `await store.runReadinessV1()` into the existing `Task { }` that already contains `runPacketScores` + `runRecoveryV1`. `runV24Biometrics()` remains as bare sync call (pending 49-05 migration).
- **Files modified:** `GooseSwift/HealthRecoveryStressViews.swift`
- **Committed in:** c60b3f3

## Known Stubs

None. Both bridge calls are wired and awaited.

## Threat Flags

None. This change is architectural refactoring only — no new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

- GooseSwift/HealthDataStore+StagingSleep.swift: 1 `await bridge.requestAsync` — VERIFIED (grep count = 1)
- GooseSwift/HealthDataStore+StagingSleep.swift: 0 `packetInputQueue` — VERIFIED (grep count = 0)
- GooseSwift/HealthDataStore+StagingSleep.swift: `func runSleepStaging() async` — VERIFIED (grep count = 1)
- GooseSwift/HealthDataStore+Readiness.swift: 2 `await bridge.requestAsync` — VERIFIED (grep count = 2)
- GooseSwift/HealthDataStore+Readiness.swift: 0 `packetInputQueue` — VERIFIED (grep count = 0)
- GooseSwift/HealthDataStore+Readiness.swift: `func runReadinessV1() async` — VERIFIED (grep count = 1)
- Total bridge calls awaited across both files: 3 — VERIFIED
- Commit ea0a611 (Task 1): FOUND
- Commit c60b3f3 (Task 2): FOUND
- Build: `** BUILD SUCCEEDED **` with zero errors and zero concurrency warnings — VERIFIED

## Next Phase Readiness

- 49-05 can proceed: `runExerciseSessions`, `runIMUStepCount`, `runV24Biometrics` are still sync — ready for migration
- `HealthRecoveryStressViews.swift` has partial Task{} wrapping — `runV24Biometrics` remains bare sync call until 49-05 migrates it; no build issue since `runV24Biometrics` is still sync

---
*Phase: 49-healthdatastore-async-migration*
*Completed: 2026-06-10*
