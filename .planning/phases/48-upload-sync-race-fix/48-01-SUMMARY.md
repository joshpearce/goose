---
phase: 48-upload-sync-race-fix
plan: "01"
subsystem: rust-store
tags: [tdd, rust, sync, contract-test]
dependency_graph:
  requires: []
  provides: [sync_methods_tests::test_pre_capture_does_not_mark_rows_inserted_during_race_window]
  affects: [Rust/core/src/store.rs]
tech_stack:
  added: []
  patterns: [inline-cfg-test, rusqlite-direct-insert]
key_files:
  created: []
  modified:
    - Rust/core/src/store.rs
decisions:
  - "D-06 contract test placed inside existing sync_methods_tests module (not a new file) — avoids Cargo.toml changes and is consistent with the existing test shapes"
  - "Test uses store.conn.execute() for raw inserts, matching the pattern in test_mark_synced_sets_flag — consistent with existing infrastructure"
  - "Test asserts both the race-window row remains synced=0 (Assertion A) and the pre-captured row becomes synced=1 (Assertion B)"
metrics:
  duration: "4 minutes"
  completed: "2026-06-10"
  tasks_completed: 1
  files_modified: 1
---

# Phase 48 Plan 01: Race-Window Contract Test Summary

Rust-level contract test proving the pre-capture-then-mark pattern is race-safe: rows inserted after `rows_pending_upload` captures IDs remain `synced=0` after `mark_synced_rows` is called with only the pre-captured IDs (D-06).

## What Was Built

Added one `#[test]` function — `test_pre_capture_does_not_mark_rows_inserted_during_race_window` — inside the existing `sync_methods_tests` module in `Rust/core/src/store.rs`. No production code was changed; no new files were created.

The test follows this sequence:
1. Inserts a "pre-upload" row (ts=1.0, bpm=70) into `hr_samples`.
2. Calls `store.rows_pending_upload("hr_samples", 500)` to capture the rowID — simulating the pre-capture step in `GooseUploadService`.
3. Inserts a "race-window" row (ts=2.0, bpm=72) — simulating a BLE frame arriving while the HTTP request is in-flight.
4. Calls `store.mark_synced_rows("hr_samples", &captured_ids)` with only the pre-captured IDs.
5. **Assertion A:** `rows_pending_upload` returns exactly 1 row with ts=2.0 (the race-window row remains pending).
6. **Assertion B:** `SELECT synced FROM hr_samples WHERE ts=1.0` returns 1 (pre-captured row is now synced=1).

## Verification

```
test store::sync_methods_tests::test_pre_capture_does_not_mark_rows_inserted_during_race_window ... ok
test store::sync_methods_tests::test_mark_synced_sets_flag ... ok
test store::sync_methods_tests::test_mark_synced_unknown_table_rejected ... ok
test store::sync_methods_tests::test_rows_pending_upload_returns_unsynced ... ok
test store::sync_methods_tests::test_rows_pending_upload_respects_limit ... ok
test store::sync_methods_tests::test_sync_backfill_creates_hr_rows ... ok
test store::sync_methods_tests::test_sync_backfill_is_idempotent ... ok
test store::sync_methods_tests::test_sync_prune_respects_synced_flag ... ok
test store::sync_methods_tests::test_sync_invalid_stream_rejected ... ok
test store::sync_methods_tests::test_sync_cursor_namespace_isolation ... ok
test result: ok. 10 passed; 0 failed; 0 ignored
```

All 10 sync_methods_tests pass. Zero regressions.

## Deviations from Plan

None — plan executed exactly as written.

The `algo_benchmark_reference_comparison_reports_runtime_and_coverage` test fails in the full suite but is pre-existing (requires Python reference tools with neurokit2, pyhrv — not installed in this environment). This is out of scope per CLAUDE.md and pre-dates this plan's changes.

## Known Stubs

None.

## Threat Flags

None. The new test code adds no network endpoints, auth paths, file access patterns, or schema changes. It is test-only code inside `#[cfg(test)]`.

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add race-window contract test to sync_methods_tests | 45233c5 | Rust/core/src/store.rs |

## Self-Check: PASSED

- [x] `Rust/core/src/store.rs` — modified (54 lines added)
- [x] Commit `45233c5` exists in git log
- [x] `test_pre_capture_does_not_mark_rows_inserted_during_race_window` present in `sync_methods_tests` module
- [x] All sync_methods_tests pass (10/10)
