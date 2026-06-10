---
phase: 49-healthdatastore-async-migration
plan: "06"
subsystem: HealthDataStore
tags: [async, bridge, cardio, utilities, main-thread-safety]
dependency_graph:
  requires: [49-01]
  provides: [async-cardio-bridge-calls, async-sleep-score-helper]
  affects: [HealthDataStore+Cardio.swift, HealthDataStore+Utilities.swift]
tech_stack:
  added: []
  patterns: [await-before-capture, requestAsync-offload]
key_files:
  created: []
  modified:
    - GooseSwift/HealthDataStore+Cardio.swift
    - GooseSwift/HealthDataStore+Utilities.swift
decisions:
  - "Dead-code finding confirmed: cardioLoadActivitySessions, cardioLoadActivityMetricsByName, and sleepScoreReport have zero live callers — converting to async required no caller updates"
  - "databasePath captured into local constant before each await to preserve @MainActor state snapshot"
metrics:
  duration: "3min"
  completed: "2026-06-10"
  tasks: 2
  files: 2
---

# Phase 49 Plan 06: Cardio + Utilities Async Migration Summary

Eliminated the only remaining direct @MainActor FFI blocks: converted `cardioLoadActivitySessions`, `cardioLoadActivityMetricsByName` (HealthDataStore+Cardio.swift), and `sleepScoreReport` (HealthDataStore+Utilities.swift) to `async` using `await bridge.requestAsync`. All three methods had zero live callers (confirmed by grep), so no caller updates were required.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Convert Cardio bridge calls to async | 9c85084 | GooseSwift/HealthDataStore+Cardio.swift |
| 2 | Convert sleepScoreReport helper to async | 0d52bc9 | GooseSwift/HealthDataStore+Utilities.swift |

## What Was Built

### Task 1 — HealthDataStore+Cardio.swift

- `cardioLoadActivitySessions(from:to:)` → `async -> [[String: Any]]`: captures `databasePath`, `startMs`, `endMs` before `await bridge.requestAsync(method: "activity.list_sessions", ...)`.
- `cardioLoadActivityMetricsByName(sessionID:)` → `async -> [String: [String: Any]]`: captures `databasePath` before `await bridge.requestAsync(method: "activity.list_metrics", ...)`.
- `cardioLoadAlgorithmSummary`, `cardioStatusRows`, `cardioLoadSnapshot`, `cardioLoadContribution`, `cardioLoadDailyComputations` — untouched (none call the bridge).

### Task 2 — HealthDataStore+Utilities.swift

- `sleepScoreReport(baseArgs:)` → `async throws -> [String: Any]`: replaced `try bridge.request(...)` with `try await bridge.requestAsync(...)`. Args and return shape unchanged.

## Verification Results

- `await bridge.requestAsync` in Cardio: **2** (expected 2)
- Non-awaited `bridge.request(` in Cardio: **0** (expected 0)
- `await bridge.requestAsync` in Utilities: **1** (expected 1)
- Non-awaited `bridge.request(` in Utilities: **0** (expected 0)
- Both async function signatures present: **confirmed**

## Deviations from Plan

None — plan executed exactly as written. Dead-code finding (zero callers for all three functions) held during implementation, confirming no cascade into SwiftUI bodies or caller updates were needed.

## Known Stubs

None introduced in this plan.

## Threat Flags

None — no new network endpoints, auth paths, or schema changes introduced.

## Self-Check: PASSED

- GooseSwift/HealthDataStore+Cardio.swift: FOUND
- GooseSwift/HealthDataStore+Utilities.swift: FOUND
- Commit 9c85084: FOUND
- Commit 0d52bc9: FOUND
