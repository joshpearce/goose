---
phase: 49-healthdatastore-async-migration
plan: "05"
subsystem: HealthDataStore
tags: [async-migration, swift-concurrency, exercise, imu, v24-biometrics]
dependency_graph:
  requires: [49-01]
  provides: [async-runExerciseSessions, async-runIMUStepCount, async-runV24Biometrics]
  affects: [HealthMetricFamilyStrainViews, HealthRecoveryStressViews]
tech_stack:
  added: []
  patterns: [async-func, await-bridge-requestAsync, task-wrapper-shim]
key_files:
  created: []
  modified:
    - GooseSwift/HealthDataStore+Exercise.swift
    - GooseSwift/HealthDataStore+IMUSteps.swift
    - GooseSwift/HealthDataStore+V24Biometrics.swift
    - GooseSwift/HealthRecoveryStressViews.swift
    - GooseSwift/HealthMetricFamilyStrainViews.swift
decisions:
  - "runV24Biometrics merged into existing Task{} in HealthRecoveryStressViews alongside runPacketScores+runRecoveryV1+runReadinessV1"
  - "HealthMetricFamilyStrainViews bare calls wrapped in Task{} as minimal shim (full refactor deferred to 49-07)"
metrics:
  duration_minutes: 2
  completed_date: "2026-06-10"
  tasks_completed: 3
  files_modified: 5
---

# Phase 49 Plan 05: Exercise+IMU+V24 Async Migration Summary

**One-liner:** Migrated runExerciseSessions, runIMUStepCount, and runV24Biometrics from packetInputQueue.async GCD wrappers to async func using await bridge.requestAsync; 5 bridge calls total now awaited.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Migrate runExerciseSessions to async | 4b18ea6 | HealthDataStore+Exercise.swift |
| 2 | Migrate runIMUStepCount to async with 2 sequential awaits | 7180e46 | HealthDataStore+IMUSteps.swift |
| 3 | Migrate runV24Biometrics to async incl. optional try? spo2 | 2dd022a | HealthDataStore+V24Biometrics.swift |

## What Was Built

Three HealthDataStore extension functions migrated from synchronous GCD dispatch to Swift Concurrency:

- **runExerciseSessions** (Exercise.swift): 1 awaited bridge call (`exercise.sessions_between`). @MainActor state captured before await; exerciseSessions mutated directly after.
- **runIMUStepCount** (IMUSteps.swift): 2 sequential awaited bridge calls (`store.gravity_rows_between` then `metrics.imu_step_count_v1`). packetInputReports stepReport captured on @MainActor before first await; imuStepCountResult mutated directly after second await.
- **runV24Biometrics** (V24Biometrics.swift): 2 awaited bridge calls — primary `biometrics.v24_between` (try await), secondary `biometrics.spo2_from_raw` (try? await). The optional try? semantics preserved exactly as required by Pitfall 4 in the research notes.

## Verification Results

All acceptance criteria met:

- Exercise: 1 `await bridge.requestAsync`, 0 non-awaited `bridge.request`, `func runExerciseSessions() async` present, 0 `packetInputQueue`
- IMU: 2 `await bridge.requestAsync`, 0 non-awaited `bridge.request`, `func runIMUStepCount() async` present, 0 `packetInputQueue`
- V24: 2 `await bridge.requestAsync`, 1 `try? await bridge.requestAsync`, 0 non-awaited `bridge.request`, `func runV24Biometrics() async` present, 0 `packetInputQueue`
- Total: 5 bridge calls across 3 files awaited via requestAsync

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Wrapped bare async calls in view callers**
- **Found during:** Post-Task 3 caller scan
- **Issue:** HealthRecoveryStressViews.swift (lines 208, 216) and HealthMetricFamilyStrainViews.swift (lines 568-573) had bare `store.runV24Biometrics()`, `store.runExerciseSessions()`, `store.runIMUStepCount()` calls. Calling async functions without `await` in a non-async context is a Swift compiler error.
- **Fix:** In HealthRecoveryStressViews.swift, added `runV24Biometrics` into the existing Task{} block alongside runPacketScores+runRecoveryV1+runReadinessV1. In HealthMetricFamilyStrainViews.swift, wrapped both exercise+IMU calls in `Task { await ... }` shims.
- **Files modified:** GooseSwift/HealthRecoveryStressViews.swift, GooseSwift/HealthMetricFamilyStrainViews.swift
- **Commit:** fc0b568
- **Note:** Plan 49-07 will do the full caller refactor; these are minimal shims to keep the build clean.

## Known Stubs

None — all migrated functions wire live data from the bridge.

## Threat Flags

None — no new network endpoints, auth paths, or trust boundary changes introduced.

## Self-Check: PASSED

- GooseSwift/HealthDataStore+Exercise.swift — exists, contains `func runExerciseSessions() async`
- GooseSwift/HealthDataStore+IMUSteps.swift — exists, contains `func runIMUStepCount() async`
- GooseSwift/HealthDataStore+V24Biometrics.swift — exists, contains `func runV24Biometrics() async`
- Commits 4b18ea6, 7180e46, 2dd022a, fc0b568 — verified in git log
