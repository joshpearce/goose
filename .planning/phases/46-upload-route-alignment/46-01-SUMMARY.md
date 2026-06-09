---
phase: 46-upload-route-alignment
plan: "01"
subsystem: server
tags: [fastapi, timescaledb, upload, raw-frames, ios-upload, idempotency, auth]
dependency_graph:
  requires: []
  provides: [raw_frames_hypertable, insert_raw_frames_batch, POST_v1_ingest-frames, read_device_frames_union]
  affects: [server/db/init.sql, server/ingest/app/store.py, server/ingest/app/read.py, server/ingest/app/main.py]
tech_stack:
  added: []
  patterns: [ON CONFLICT DO NOTHING idempotency, psycopg parametrised SQL, UNION read path, Pydantic hex validation]
key_files:
  created:
    - server/ingest/tests/test_ingest_frames_api.py
  modified:
    - server/db/init.sql
    - server/ingest/app/store.py
    - server/ingest/app/read.py
    - server/ingest/app/main.py
    - server/ingest/tests/conftest.py
decisions:
  - "raw_frames PRIMARY KEY (device_id, ts, frame_hex): multiple distinct frames can share a captured_at_unix, so frame_hex is part of the dedup key"
  - "read_device_frames fetches raw_frames rows separately then merges + sorts in Python rather than SQL UNION ALL to preserve the existing archive decompression loop unchanged"
  - "ingest_frames route does not trigger compute_day recompute (raw frames have no decoded stream data to recompute daily metrics from)"
metrics:
  duration_minutes: 30
  completed_date: "2026-06-09"
  tasks_completed: 3
  files_modified: 5
---

# Phase 46 Plan 01: Upload Route Alignment Summary

**One-liner:** POST /v1/ingest-frames persists raw BLE frames to a new raw_frames TimescaleDB hypertable, with idempotent ON CONFLICT DO NOTHING upserts and UNION read path so GET /v1/export/frames/{device_id} returns both archive and uploaded frames.

## Objective

Implement the missing `POST /v1/ingest-frames` endpoint on the FastAPI server and make the raw-frame round-trip work end to end: frames uploaded via iOS are retrievable via the existing `GET /v1/export/frames/{device_id}`.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add raw_frames table + insert_raw_frames_batch store function | 9e20b4a | server/db/init.sql, server/ingest/app/store.py |
| 2 | UNION raw_frames into read_device_frames + add POST /v1/ingest-frames route | e135f83 | server/ingest/app/read.py, server/ingest/app/main.py |
| 3 | Round-trip + auth + idempotency pytest module + conftest TRUNCATE update | 63d846d | server/ingest/tests/test_ingest_frames_api.py, server/ingest/tests/conftest.py |

## What Was Built

### Task 1: raw_frames schema + store function

`server/db/init.sql` — new `raw_frames` TimescaleDB hypertable with:
- PRIMARY KEY `(device_id, ts, frame_hex)` for row-level idempotency
- Columns: `device_id`, `ts` (TIMESTAMPTZ), `frame_hex`, `source`, `device_type`, `device_model`, `sensitivity`, `received_at`
- `SELECT create_hypertable('raw_frames', 'ts', if_not_exists => TRUE)`
- `CREATE INDEX IF NOT EXISTS raw_frames_device_time ON raw_frames (device_id, ts)`
- `ALTER TABLE raw_frames ADD COLUMN IF NOT EXISTS device_generation TEXT DEFAULT '5.0'` (idempotent migration)

`server/ingest/app/store.py` — `insert_raw_frames_batch(conn, device_id, frames) -> dict`:
- Iterates frames, inserts with `to_timestamp(%s)` conversion
- `ON CONFLICT (device_id, ts, frame_hex) DO NOTHING`
- Uses `cur.rowcount` to tally `inserted` vs `skipped`
- Returns `{"inserted": N, "skipped": M}`
- Caller commits (consistent with all other store functions)

### Task 2: Route + read path

`server/ingest/app/main.py`:
- `IngestFramesDevice` (id, mac, name)
- `IngestFrame` (captured_at_unix: float, frame_hex validated with `^[0-9a-fA-F]*$`, optional source/device_type/device_model/sensitivity)
- `IngestFramesBatch` (device: IngestFramesDevice, frames: list[IngestFrame])
- `POST /v1/ingest-frames` with `dependencies=[Depends(require_auth)]`
  - Calls `store.ensure_device` then `store.insert_raw_frames_batch`; commits; returns result

`server/ingest/app/read.py`:
- `read_device_frames` extended to also `SELECT` from `raw_frames` (extract epoch → captured_at_unix)
- NULL columns fall back to archive-path defaults (source, device_model, device_type, sensitivity)
- Combined list sorted ascending by `captured_at_unix`, truncated to `limit`
- Archive path (raw_batches + .zst decompression) unchanged

### Task 3: pytest module

`server/ingest/tests/test_ingest_frames_api.py`:
- `test_round_trip`: POST 3 frames → `{inserted:3, skipped:0}`; GET returns 3 frames sorted ASC with matching hex
- `test_idempotency`: second POST of same batch → `{inserted:0, skipped:3}`; GET count stays 3
- `test_auth_required`: empty Authorization header → 401
- All tests marked `@requires_docker` (skipped without Docker, never fail)

`server/ingest/tests/conftest.py`:
- `raw_frames` added to `clean_db` TRUNCATE statement for test isolation

## Deviations from Plan

None — plan executed exactly as written.

## Threat Model Coverage

| Threat ID | Mitigation Applied |
|-----------|-------------------|
| T-46-01 (frame_hex tampering) | `IngestFrame.frame_hex` uses `pattern=r"^[0-9a-fA-F]*$"`; persisted via `%s` parametrised SQL only |
| T-46-02 (auth on both endpoints) | `POST /v1/ingest-frames` has `dependencies=[Depends(require_auth)]`; auth test asserts 401 |
| T-46-03 (DoS — large array) | Accepted: single-user server behind Bearer auth; iOS client caps at 2000 frames |
| T-46-04 (SQL injection) | All writes/reads use `%s` placeholders; table/column names are hardcoded literals |

## Known Stubs

None.

## Self-Check: PASSED

- `server/db/init.sql`: contains `CREATE TABLE IF NOT EXISTS raw_frames` — FOUND
- `server/ingest/app/store.py`: contains `def insert_raw_frames_batch` — FOUND
- `server/ingest/app/read.py`: contains `FROM raw_frames` — FOUND
- `server/ingest/app/main.py`: contains `"/v1/ingest-frames"` — FOUND
- `server/ingest/tests/test_ingest_frames_api.py`: 3 test functions — FOUND
- `server/ingest/tests/conftest.py`: contains `raw_frames` in TRUNCATE — FOUND
- Commits 9e20b4a, e135f83, 63d846d all present in git log — FOUND
