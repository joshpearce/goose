---
phase: 46-upload-route-alignment
reviewed: 2026-06-10T00:00:00Z
depth: deep
files_reviewed: 6
files_reviewed_list:
  - server/db/init.sql
  - server/ingest/app/store.py
  - server/ingest/app/read.py
  - server/ingest/app/main.py
  - server/ingest/tests/conftest.py
  - server/ingest/tests/test_ingest_frames_api.py
findings:
  critical: 3
  warning: 4
  info: 3
  total: 10
  fixed_critical: 3
  fixed_warning: 1
status: fixed
---

# Phase 46: Code Review Report

**Reviewed:** 2026-06-10T00:00:00Z
**Depth:** deep
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Phase 46 adds `POST /v1/ingest-frames` (iOS raw BLE frame upload) and adapts `GET /v1/export/frames/{device_id}` to serve back frames from both the archive path and the new `raw_frames` table. The implementation is broadly correct: auth is consistently applied via `require_auth`, all SQL uses parameterised queries, and the idempotency contract is enforced by a `ON CONFLICT DO NOTHING` unique index.

Three blockers found: the `raw_frames` table is never created by `init.sql` (it is referenced but its `CREATE TABLE` statement is absent, so every deployment that does not have a pre-existing table will fail at startup index creation); `frame_hex` validation accepts the empty string, which silently stores zero-byte frames; and the UNION merge in `read_device_frames` applies `limit` only after fetching ALL rows from both sources, meaning an adversary with a Bearer token can force the server to materialise arbitrarily large result sets in memory. Four warnings and three info items follow.

---

## Critical Issues

### CR-01: `raw_frames` table never created — index references a non-existent table

**File:** `server/db/init.sql:111-112`

**Issue:** `init.sql` only creates `CREATE UNIQUE INDEX IF NOT EXISTS raw_frames_dedup ON raw_frames (...)`. There is no `CREATE TABLE IF NOT EXISTS raw_frames (...)` anywhere in the file or any other `.sql` file in the repository. On a fresh database (the only supported deployment path — `bootstrap_schema` re-applies this single file on every startup) the `CREATE UNIQUE INDEX` statement will raise `ERROR: relation "raw_frames" does not exist` and abort schema bootstrap, making the entire service fail to start. `conftest.py` truncates `raw_frames` in `clean_db`, which means the integration tests also fail on a truly fresh DB unless the table was created by a prior migration step not tracked in source control.

**Fix:** Add the table DDL immediately before the index, following the same `CREATE TABLE IF NOT EXISTS` pattern used for every other table:

```sql
-- ── Raw frames uploaded directly from iOS (POST /v1/ingest-frames) ──────────
CREATE TABLE IF NOT EXISTS raw_frames (
    id            BIGSERIAL,
    device_id     TEXT        NOT NULL REFERENCES devices(device_id),
    captured_at   TIMESTAMPTZ NOT NULL,
    frame_hex     TEXT        NOT NULL,
    source        TEXT,
    device_type   TEXT,
    device_model  TEXT,
    sensitivity   TEXT,
    received_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS raw_frames_dedup
    ON raw_frames (device_id, captured_at, frame_hex);
```

---

### CR-02: `frame_hex` Pydantic pattern accepts the empty string — empty frames stored silently

**File:** `server/ingest/app/main.py:440`

**Issue:** `IngestFrame.frame_hex` is validated with `pattern=r"^[0-9a-fA-F]*$"`. The `*` quantifier makes the entire hex body optional — a zero-length string `""` satisfies the regex and passes `hex_even_length` (0 % 2 == 0). An empty `frame_hex` is then inserted into `raw_frames`, producing a row that is meaningless as a BLE frame. The existing `Frame` model on line 65 has the same defect.

**Fix:** Change both patterns to `+` (one or more):

```python
# main.py line 65
hex: str = Field(..., pattern=r"^[0-9a-fA-F]+$")

# main.py line 440
frame_hex: str = Field(..., pattern=r"^[0-9a-fA-F]+$")
```

---

### CR-03: `read_device_frames` fetches all DB rows without a LIMIT — unbounded memory materialisation

**File:** `server/ingest/app/read.py:357-383`

**Issue:** The second query (against `raw_frames`) uses no `LIMIT` clause:

```python
db_rows = conn.execute(
    """SELECT ... FROM raw_frames WHERE device_id = %s
         AND extract(epoch FROM captured_at) >= %s
         AND extract(epoch FROM captured_at) <= %s
       ORDER BY captured_at""",
    (device_id, from_ts, to_ts),
).fetchall()
```

`fetchall()` materialises the entire result set in the Python process before the final `out[:limit]` truncation. Any authenticated caller (including the iOS client using its device key) can trigger retrieval of millions of rows by passing a wide time window. The archive path (`raw_batches`) correctly breaks early once `len(out) >= limit`, making the asymmetry more visible. At scale this is a memory-exhaustion / denial-of-service condition.

**Fix:** Push the limit into the query and add early-exit logic to match the archive path:

```python
remaining = limit - len(out)
if remaining <= 0:
    out.sort(key=lambda r: r["captured_at_unix"])
    return out[:limit]

db_rows = conn.execute(
    """SELECT extract(epoch FROM captured_at)::float AS captured_at_unix,
              frame_hex, source, device_model, device_type, sensitivity
       FROM raw_frames
       WHERE device_id = %s
         AND extract(epoch FROM captured_at) >= %s
         AND extract(epoch FROM captured_at) <= %s
       ORDER BY captured_at
       LIMIT %s""",
    (device_id, from_ts, to_ts, remaining),
).fetchall()
```

Note: because the final sort merges both sources, using `remaining` as the DB limit may still emit fewer than `limit` total rows when archive frames interleave with DB frames. The correct fix is to fetch `limit` rows from each source independently and merge-sort them — but limiting the DB fetch to `limit` is a strict safety improvement over the current unlimited `fetchall()`.

---

## Warnings

### WR-01: `to` query parameter on `/v1/export/frames/{device_id}` has no upper bound — sentinel epoch accepted

**File:** `server/ingest/app/main.py:472-473`

**Issue:** `to: float = Query(9_999_999_999.0, alias="to")` has no `le=` constraint. A caller can pass `to=1e18`, causing the DB query to scan the entire `raw_frames` table for the device without a meaningful time bound. The `from_` parameter has `ge=0.0` but `to` lacks a matching `le=`. Combined with CR-03 this makes the attack surface larger.

**Fix:**

```python
to: float = Query(9_999_999_999.0, alias="to", le=9_999_999_999.0),
```

Or use a more principled upper bound (e.g. year 2100 epoch ≈ 4102444800).

---

### WR-02: `require_auth` accepts an empty `Authorization` header as the default — timing-safe compare runs against a likely-short token

**File:** `server/ingest/app/main.py:57-60`

**Issue:**

```python
def require_auth(authorization: str = Header(default="")) -> None:
    expected = f"Bearer {cfg.api_key}"
    if not secrets.compare_digest(authorization, expected):
        raise HTTPException(status_code=401, detail="unauthorized")
```

`secrets.compare_digest` is used correctly for timing safety. However, `Header(default="")` means that if the client omits the `Authorization` header entirely, `authorization` is `""`. `compare_digest("", "Bearer secret")` returns `False` and correctly raises 401. This is not an auth bypass. The actual warning is that `default=""` causes FastAPI not to mark the parameter as required in the schema (when schema is exposed) and, more importantly, if `cfg.api_key` is ever an empty string (which `load_config` does reject, but defence-in-depth is absent here), `compare_digest("Bearer ", "Bearer ")` would return `True` for any request that sends `"Bearer "`. Consider adding an assertion:

```python
def require_auth(authorization: str = Header(default="")) -> None:
    assert cfg.api_key, "api_key must be non-empty"
    expected = f"Bearer {cfg.api_key}"
    if not secrets.compare_digest(authorization, expected):
        raise HTTPException(status_code=401, detail="unauthorized")
```

Or validate at config load time (which `load_config` already does via `if not api_key: raise`), but the runtime guard prevents a future config refactor from silently creating a zero-length key bypass.

---

### WR-03: `insert_raw_frames_batch` uses a Python `for` loop — missing `executemany` and no batch-size limit

**File:** `server/ingest/app/store.py:44-64`

**Issue:** Each frame in the batch is inserted via a separate `cur.execute()` call inside a Python loop. For large uploads this is an unnecessary round-trip amplifier. More critically, there is **no upper bound on the number of frames** accepted in a single request. `IngestFramesBatch.frames` is `list[IngestFrame]` with no `max_items` constraint in Pydantic. A client can post a payload with tens of thousands of frames, holding the database connection open for the duration of the loop and blocking the single-threaded FastAPI event loop (since psycopg is synchronous here).

**Fix:** Add a maximum frame count in the Pydantic model:

```python
class IngestFramesBatch(BaseModel):
    device: IngestFramesDevice
    frames: list[IngestFrame] = Field(..., max_length=5000)
```

And consider using `executemany` or a `COPY` approach for the inner loop.

---

### WR-04: `read_device_frames` reads arbitrary file paths from the database without path-existence or path-traversal hardening

**File:** `server/ingest/app/read.py:322-332`

**Issue:** The `file_path` column from `raw_batches` is passed directly to `open()`. The column is populated by the ingest pipeline (not user input to this endpoint), so this is not a classic injection vector. However, if the database is compromised or a previous ingest wrote a crafted path, the server will attempt to open that path. The broad `except (OSError, Exception): continue` silently swallows all errors including permission errors on sensitive paths, which could be used to probe the filesystem via timing (if file open is fast for absent files but slow for large readable ones).

More concretely: `except (OSError, Exception)` is redundant — `Exception` already encompasses `OSError`; the `OSError` mention is dead code that creates a misleading false-specificity impression.

**Fix:** Narrow the exception and validate that the path is within the expected raw-data root:

```python
import pathlib

_RAW_ROOT = pathlib.Path(cfg.raw_root).resolve()

for file_path, ...:
    ...
    try:
        p = pathlib.Path(file_path).resolve()
        if not str(p).startswith(str(_RAW_ROOT)):
            continue  # outside expected root; skip silently
        with open(p, "rb") as fh:
            raw = zstandard.ZstdDecompressor().decompress(fh.read())
    except (OSError, zstandard.ZstdError):
        continue
```

---

## Info

### IN-01: SQL schema comment says `raw_frames` was "created in an earlier deployment" but is not in source control

**File:** `server/db/init.sql:108-110`

**Issue:** The comment reads "Table created in an earlier deployment with column `captured_at` (not `ts`)." This implies the table DDL lives outside the tracked schema file, breaking the property that `init.sql` is the single source of truth for the database schema. Any fresh deployment, CI environment, or disaster-recovery restore will silently lack the table (exacerbating CR-01). The comment should be replaced with the actual DDL.

---

### IN-02: `test_auth_required` only tests a missing token, not a wrong token

**File:** `server/ingest/tests/test_ingest_frames_api.py:118-127`

**Issue:** The test sends `Authorization: ""`. It does not verify that a plausible-but-wrong token (e.g. `"Bearer wrongkey"`) is also rejected. A future regression that accidentally accepts non-empty tokens would not be caught. Add a second assertion:

```python
r2 = client.post(
    "/v1/ingest-frames",
    json=payload,
    headers={"Authorization": "Bearer wrongkey"},
)
assert r2.status_code == 401
```

---

### IN-03: `conftest.py` `_docker_available()` is evaluated at module import time — `requires_docker` marker is a module-level constant

**File:** `server/ingest/tests/conftest.py:23`

**Issue:**

```python
requires_docker = pytest.mark.skipif(not _docker_available(), reason="docker not available")
```

`_docker_available()` is called once when `conftest.py` is imported (i.e. at collection time). If Docker starts or stops between collection and test execution (rare, but possible in CI), the marker's decision is stale. More practically, `subprocess.run(["docker", "info"], ...)` is a side-effecting network call at collection time, which slows `pytest --collect-only` and may time out in restricted environments. The recommended pattern is to use a `pytest.fixture` with `autouse` + `pytest.skip()` inside the test body, or use `pytest.mark.skipif` with a lambda-based condition. This is a minor quality issue with no correctness impact in normal usage.

---

_Reviewed: 2026-06-10T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
