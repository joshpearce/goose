---
phase: 47-device-id-namespace-resolution
plan: "03"
subsystem: server
tags: [server, timescaledb, fastapi, device-uuid, bidirectional-lookup, schema-migration]
dependency_graph:
  requires: [47-01, 47-02]
  provides: [DEVID-02-server-half]
  affects: [server/db/init.sql, server/ingest/app/main.py, server/ingest/app/store.py, server/ingest/app/read.py]
tech_stack:
  added: []
  patterns:
    - FastAPI Pydantic optional field with None default
    - Python uuid stdlib try/except for format detection
    - psycopg parameterised %s in f-string (column name only, never value)
    - idempotent ALTER TABLE ADD COLUMN IF NOT EXISTS
key_files:
  created: []
  modified:
    - server/db/init.sql
    - server/ingest/app/main.py
    - server/ingest/app/store.py
    - server/ingest/app/read.py
    - server/ingest/tests/test_ingest_frames_api.py
    - server/ingest/tests/test_read_api.py
decisions:
  - "device_uuid column: nullable TEXT, no DEFAULT — NULL is correct for pre-migration rows (D-07)"
  - "_is_uuid() uses uuid.UUID() try/except (stdlib, handles all UUID variants) over regex"
  - "bidirectional f-string: only column-name literal interpolated, value always bound as %s (T-47-05)"
  - "archive raw_batches path unchanged — device_id IS already the UUID in the devices table (RESEARCH A3)"
metrics:
  duration: 3m
  completed: "2026-06-10"
  tasks: 2
  files: 6
---

# Phase 47 Plan 03: Server Device UUID Migration Summary

Server half of DEVID-02 — adds `device_uuid TEXT` (nullable, no default) to `raw_frames` via idempotent `ALTER TABLE ADD COLUMN IF NOT EXISTS`, wires it through the `IngestFrame` Pydantic model and `insert_raw_frames_batch` persistence, and upgrades `GET /v1/export/frames/{device_id}` to bidirectional lookup (UUID → `device_uuid` column, non-UUID → `device_model` column), fully parameterised.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Schema migration + ingest model + persistence | cc46a56 | server/db/init.sql, server/ingest/app/main.py, server/ingest/app/store.py |
| 2 | Bidirectional export lookup + tests | e808551 | server/ingest/app/read.py, server/ingest/tests/test_ingest_frames_api.py, server/ingest/tests/test_read_api.py |

## What Was Built

### Task 1 — Schema Migration + Ingest Model + Persistence

**`server/db/init.sql`:** Added idempotent migration block before the existing `device_generation` migrations:
```sql
-- Phase 47: CoreBluetooth peripheral UUID on raw_frames. Idempotent.
ALTER TABLE raw_frames ADD COLUMN IF NOT EXISTS device_uuid TEXT;
CREATE INDEX IF NOT EXISTS raw_frames_device_uuid ON raw_frames (device_uuid, captured_at);
```
No `DEFAULT` — `NULL` is semantically correct for pre-migration rows (D-07).

**`server/ingest/app/main.py`:** Added `device_uuid: str | None = None` to `IngestFrame` Pydantic model after `sensitivity`. Uploads omitting this field continue to validate (backward-compatible).

**`server/ingest/app/store.py`:** Extended `insert_raw_frames_batch` INSERT to include `device_uuid` in column list and `f.get("device_uuid")` as the matching `%s` bind. `ON CONFLICT (device_id, captured_at, frame_hex)` dedup key is unchanged — `device_uuid` is NOT part of the conflict key.

### Task 2 — Bidirectional Export Lookup + Tests

**`server/ingest/app/read.py`:** Added `import uuid as _uuid` and module-level helper:
```python
def _is_uuid(s: str) -> bool:
    try:
        _uuid.UUID(s)
        return True
    except ValueError:
        return False
```

Modified the `raw_frames` query in `read_device_frames` to use bidirectional lookup:
```python
is_uuid = _is_uuid(device_id)
device_clause = "device_uuid = %s" if is_uuid else "device_model = %s"
```
The f-string only interpolates the column-name literal (`device_clause`); the value `device_id` is always a `%s` bound parameter — no SQL injection risk (T-47-05, T-47-06).

The `raw_batches` archive path is untouched — it queries `WHERE device_id = %s` and the `devices.device_id` PK is already the CoreBluetooth UUID (RESEARCH A3, D-06).

**New tests (3):**
- `test_ingest_frames_api.py::test_device_uuid_persisted` — POST /v1/ingest-frames with `device_uuid` in frame; asserts DB row stores that value
- `test_read_api.py::test_export_frames_by_device_uuid` — insert row with known `device_uuid`, GET /v1/export/frames/{uuid}, assert frame returned
- `test_read_api.py::test_export_frames_by_device_model` — insert row with `NULL` `device_uuid` and known `device_model`, GET /v1/export/frames/{model_string} (non-UUID), assert frame returned via device_model branch

All tests use `@requires_docker` and skip cleanly when Docker daemon is not running. The pure model test (`test_backfill_workouts_from_to_aliases_accepted`) passes. All Docker-gated tests skip consistently with the existing test suite.

## Verification

| Check | Result |
|-------|--------|
| `grep -c "ADD COLUMN IF NOT EXISTS device_uuid TEXT" server/db/init.sql` | 1 (no DEFAULT) |
| `grep "raw_frames_device_uuid" server/db/init.sql` | references `(device_uuid, captured_at)` |
| `grep "device_uuid: str | None = None" server/ingest/app/main.py` | matches inside IngestFrame |
| `grep -A25 "def insert_raw_frames_batch" store.py | grep device_uuid` | 2 occurrences (column list + f.get) |
| ON CONFLICT clause still `(device_id, captured_at, frame_hex)` | confirmed |
| `grep "def _is_uuid" read.py` | matches with `_uuid.UUID(` in try/except ValueError |
| f-string only interpolates column-name literal | confirmed — value always `%s` bound |
| `raw_batches` archive query unchanged | `WHERE device_id = %s` |
| pytest run | 1 passed, 13 skipped (Docker unavailable — expected) |

## Deviations from Plan

None — plan executed exactly as written.

## Threat Surface Scan

No new network endpoints beyond what the plan describes. The bidirectional `GET /v1/export/frames/{device_id}` was already gated by `require_auth`; only the SQL predicate routing logic was changed. T-47-05 and T-47-06 mitigations applied as planned:
- Both UUID and device_model branches use `%s` bound parameters
- UUID branch normalises via `uuid.UUID()` stdlib parse gate before query

## Known Stubs

None — no placeholder data, no hardcoded empty values flowing to UI. Server-only changes.

## Self-Check

- [x] `server/db/init.sql` modified — confirmed at cc46a56
- [x] `server/ingest/app/main.py` modified — confirmed at cc46a56
- [x] `server/ingest/app/store.py` modified — confirmed at cc46a56
- [x] `server/ingest/app/read.py` modified — confirmed at e808551
- [x] `server/ingest/tests/test_ingest_frames_api.py` modified — confirmed at e808551
- [x] `server/ingest/tests/test_read_api.py` modified — confirmed at e808551
- [x] Task 1 commit cc46a56 exists
- [x] Task 2 commit e808551 exists

## Self-Check: PASSED
