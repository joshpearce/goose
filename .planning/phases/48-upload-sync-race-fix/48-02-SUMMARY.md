---
phase: 48-upload-sync-race-fix
plan: "02"
subsystem: upload-sync
tags: [swift, race-fix, upload-service, sync, urlsession]
requires: []
provides: [captureAllPendingRowIDs, markStreamsSynced, init-databasePath-session]
affects: [GooseUploadService, GooseUploadServiceTests]
tech-stack:
  added: []
  patterns: [pre-capture-before-http, urlsession-injection]
key-files:
  modified:
    - GooseSwift/GooseUploadService.swift
decisions:
  - "Pre-capture rowIDs for all 8 upload streams before any HTTP call (D-03)"
  - "markHrSamplesSynced removed; replaced by captureAllPendingRowIDs + markStreamsSynced pair"
  - "limit=500 per stream matches existing batch cap — intentional, not increased"
  - "device_id filter preserved for hr_samples, rr_intervals, events, battery; ts filter only for gravity, spo2_samples, skin_temp_samples, resp_samples"
metrics:
  duration: 299s
  completed: "2026-06-10"
  tasks: 2
  files_changed: 1
---

# Phase 48 Plan 02: Upload Sync Race Fix (Swift Orchestration) Summary

**One-liner:** Pre-capture rowIDs for all 8 upload streams before HTTP POST using captureAllPendingRowIDs; mark synced only on 2xx via markStreamsSynced — eliminates blind-marking race in GooseUploadService.

## What Was Built

### Task 1: URLSession-injectable init (commit 9d865f3)

Added `init(databasePath: String, session: URLSession)` to `GooseUploadService`. The new initialiser stores the caller-provided session directly without creating a new `URLSessionConfiguration`. The existing `init(databasePath: String)` is unchanged — it creates its own ephemeral session with a 15s timeout.

This enables `GooseSwiftTests/GooseUploadServiceTests.swift` (Plan 03) to inject a mock `URLSession` for deterministic 200/503 scenario testing without needing `URLProtocol` global state.

### Task 2: Race condition fix — pre-capture rowIDs before HTTP (commit 6f73453)

**Root cause:** `markHrSamplesSynced` called `sync.rows_pending_upload` *after* a successful upload. Any rows arriving between the upload response and the mark call were captured and marked `synced=1` without having been sent to the server.

**Fix:** Three coordinated changes to `performUpload`:

1. **`captureAllPendingRowIDs(deviceID:sinceTimestamp:) -> [String: [Int]]`** — new private method. Calls `sync.rows_pending_upload` for each of the 8 upload streams before `upload.get_recent_decoded_streams` is called. Client-side filters preserve the existing device_id and ts boundary (required because `rows_pending_upload` returns all devices). Streams without a `device_id` column (gravity, spo2_samples, skin_temp_samples, resp_samples) apply only the ts filter. On bridge error, the stream gets an empty array — upload continues.

2. **`markStreamsSynced(rowIDsByStream: [String: [Int]])`** — new private method. Iterates the pre-captured dictionary; skips empty arrays; calls `sync.mark_synced` per stream at debug log level. Called **only inside `if uploadSucceeded { }`** — never on failure or timeout.

3. **`markHrSamplesSynced` removed entirely.** The old function only handled `hr_samples`; the new pair covers all 8 streams.

4. **Failure log message updated** from `"upload failed after 3 attempts — discarding batch"` to `"upload failed — rows not marked synced, will retry"` — accurately reflects that rows are NOT discarded.

## Verification Results

All plan verification criteria met:

| Check | Result |
|-------|--------|
| Build clean (0 error lines) | PASS |
| `markHrSamplesSynced` count in file | 0 |
| `captureAllPendingRowIDs` line < `get_recent_decoded_streams` line | line 63 < line 69 — PASS |
| `markStreamsSynced` inside `if uploadSucceeded {` block | line 132, inside block at line 130 — PASS |
| Two `init(databasePath:` initialisers | 2 — PASS |

## Commits

| Task | Commit | Type | Description |
|------|--------|------|-------------|
| Task 1 | 9d865f3 | feat | Add init(databasePath:session:) for URLSession injection |
| Task 2 | 6f73453 | fix | Pre-capture rowIDs for all 8 streams before HTTP (SYNCR-01) |

## Deviations from Plan

None — plan executed exactly as written.

The 8 stream list in the plan (`hr_samples`, `rr_intervals`, `events`, `battery`, `spo2_samples`, `skin_temp_samples`, `resp_samples`, `gravity`) matches the Rust STREAM_ALLOWLIST intersection with the upload payload confirmed in RESEARCH.md. `gravity2_samples` and `exercise_sessions` are correctly excluded.

## Known Stubs

None. All new functions are fully wired: `captureAllPendingRowIDs` is called in `performUpload` at the correct insertion point; `markStreamsSynced` is called in the success branch.

## Threat Flags

No new network endpoints, auth paths, or file access patterns introduced. Stream names are hardcoded constants (T-48-02 disposition: accept — STREAM_ALLOWLIST in Rust is the second line of defence). RowIDs are integers from the local SQLite database, never from user input (T-48-03 disposition: accept).

## Self-Check: PASSED

- [x] GooseSwift/GooseUploadService.swift exists and contains the new functions
- [x] Commit 9d865f3 exists: `git log --oneline | grep 9d865f3`
- [x] Commit 6f73453 exists: `git log --oneline | grep 6f73453`
- [x] markHrSamplesSynced count = 0
- [x] Two init(databasePath: present
- [x] captureAllPendingRowIDs precedes get_recent_decoded_streams (line 63 < line 69)
