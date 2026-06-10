---
phase: 47-device-id-namespace-resolution
verified: 2026-06-10T15:00:00Z
status: passed
score: 5/5 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 4/5
  gaps_closed:
    - "cargo test -p goose-core verde — decoded_frames_between() SELECT now includes device_uuid at column index 18; test_sync_backfill_creates_hr_rows and test_sync_backfill_is_idempotent both pass"
  gaps_remaining: []
  regressions: []
---

# Phase 47: Device ID Namespace Resolution — Verification Report

**Phase Goal:** O mismatch UUID (CoreBluetooth) vs device_model (BLE name) nos identificadores de dispositivo é resolvido — a coluna `device_uuid` existe na DB e o mapeamento é feito na ligação BLE.
**Verified:** 2026-06-10T15:00:00Z
**Status:** passed
**Re-verification:** Yes — after gap closure (SC5 fix: decoded_frames_between SELECT missing device_uuid)

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Schema migration adds `device_uuid TEXT` (nullable) to `raw_evidence` and `decoded_frames`; index on `(device_uuid, captured_at)` | ✓ VERIFIED | `store.rs:6883` adds column to raw_evidence via ensure_raw_evidence_columns; `store.rs:6906` adds to decoded_frames; composite index created on `captured_at` |
| 2 | GooseBLEClient captures UUID at connect; GooseAppModel persists UUID↔device_model in UserDefaults (`goose.swift.device_uuid_map`); cleared on disconnect | ✓ VERIFIED | `GooseBLEClient.swift:33` property; `GooseBLEClient+CentralDelegate.swift:218` sets UUID on didConnect; clears on all disconnect paths; `GooseAppModel+Lifecycle.swift:120-128` persists map and wires queue |
| 3 | CaptureFrameWriteQueue carries device_uuid (NSLock-guarded); GooseUploadService passes device_uuid in upload payloads | ✓ VERIFIED | `CaptureFrameWriteQueue.swift:204-207` NSLock-guarded property; deviceUUID on CapturedFrameWriteRow; bridgeObject emits it; GooseUploadService forwards frames verbatim |
| 4 | `GET /v1/export/frames/{device_id}` accepts UUID or device_model (bidirectional lookup); device_id never interpolated into SQL | ✓ VERIFIED | `read.py:23-29` _is_uuid() helper; `read.py:370-385` bidirectional WHERE clause; device_id always bound as %s parameter |
| 5 | `cargo test -p goose-core` verde; testes cobrem: migration roundtrip, insert com uuid, query por uuid, query por device_model | ✓ VERIFIED | `test_sync_backfill_creates_hr_rows` ok; `test_sync_backfill_is_idempotent` ok; 5 capture_import_tests all pass; only pre-existing failure is `algo_benchmark_reference_comparison_reports_runtime_and_coverage` (excluded by SC5 wording) |

**Score:** 5/5 truths verified

### Gap Closure Verification

**Gap that was open:** `decoded_frames_between()` SELECT in `Rust/core/src/store.rs` was missing `decoded_frames.device_uuid` — the shared `decoded_frame_from_row` mapper reads column index 18 but the plural query returned only 18 columns (indices 0–17), causing `Sqlite(InvalidColumnIndex(18))` in both sync_backfill tests.

**Fix confirmed at `store.rs:5262`:** `decoded_frames.device_uuid` is now the 19th column (index 18) in the `decoded_frames_between()` SELECT, matching the singular `decoded_frame()` SELECT at line 5300 and the mapper expectation.

**Test run result (re-verification):**

| Test | Before fix | After fix |
|------|-----------|-----------|
| `test_sync_backfill_creates_hr_rows` | FAILED (InvalidColumnIndex(18)) | ok |
| `test_sync_backfill_is_idempotent` | FAILED (InvalidColumnIndex(18)) | ok |
| `algo_benchmark_reference_comparison_reports_runtime_and_coverage` | FAILED (pre-existing) | FAILED (pre-existing — unchanged) |
| All other tests | 135 passed | 137 passed (2 previously failing now pass) |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Rust/core/src/store.rs` | device_uuid on structs, migration, insert+read paths including decoded_frames_between | ✓ VERIFIED | All paths now include device_uuid; decoded_frames_between SELECT has 19 columns at line 5262 |
| `Rust/core/src/capture_import.rs` | device_uuid field on CapturedFrameInput + pass-through | ✓ VERIFIED | field at line 79; pass-through at lines 616, 630, 691, 752 |
| `Rust/core/src/bridge.rs` | "device_uuid" in upload bridge response | ✓ VERIFIED | `json!({..., "device_uuid": r.device_uuid, ...})` at line 3616 |
| `Rust/core/tests/capture_import_tests.rs` | 5 new tests | ✓ VERIFIED | All 5 tests present and passing |
| `GooseSwift/GooseBLEClient.swift` | connectedPeripheralUUID property | ✓ VERIFIED | line 33 |
| `GooseSwift/CaptureFrameWriteQueue.swift` | currentDeviceUUID NSLock + deviceUUID on row + device_uuid in bridgeObject | ✓ VERIFIED | lines 204-207 (NSLock), 61 (stored prop), 74 (bridgeObject) |
| `GooseSwift/GooseAppModel+Lifecycle.swift` | UUID↔model UserDefaults persistence + queue wiring | ✓ VERIFIED | lines 120-135 |
| `server/db/init.sql` | device_uuid column + index on raw_frames | ✓ VERIFIED | lines 130-131 |
| `server/ingest/app/read.py` | bidirectional read_device_frames + _is_uuid helper | ✓ VERIFIED | lines 23-29, 370-385 |
| `server/ingest/app/main.py` | device_uuid field on IngestFrame | ✓ VERIFIED | line 445: `device_uuid: str | None = None` |
| `server/ingest/app/store.py` | device_uuid persisted in insert_raw_frames_batch | ✓ VERIFIED | lines 52, 63 |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `CapturedFrameInput.device_uuid` | `RawEvidenceInput.device_uuid` | `frame.device_uuid.as_deref()` | ✓ WIRED | capture_import.rs lines 616, 630, 691, 752 |
| `insert_raw_evidence` | `raw_evidence.device_uuid` | params![] ?9 binding | ✓ WIRED | store.rs lines 2207, 2220 |
| `upload_get_raw_frames_for_upload_bridge` | `RawEvidenceRow.device_uuid` | json!({}) serialisation | ✓ WIRED | bridge.rs line 3616 |
| `GooseBLEClient+CentralDelegate.didConnect` | `GooseBLEClient.connectedPeripheralUUID` | peripheral.identifier.uuidString | ✓ WIRED | CentralDelegate.swift line 218 |
| `GooseAppModel.handleBLEConnectionStateChange` | `CaptureFrameWriteQueue.currentDeviceUUID + UserDefaults device_uuid_map` | ble.connectedPeripheralUUID read on 'ready' | ✓ WIRED | GooseAppModel+Lifecycle.swift lines 120-128 |
| `CapturedFrameWriteRow.deviceUUID` | `bridgeObject["device_uuid"]` | captured at enqueue time, NSNull fallback | ✓ WIRED | CaptureFrameWriteQueue.swift lines 61, 74; NotificationPipeline.swift line 187 |
| `IngestFrame.device_uuid` | `insert_raw_frames_batch INSERT raw_frames` | f.get("device_uuid") parameterised bind | ✓ WIRED | store.py lines 52, 63 |
| `export_device_frames route` | `read_device_frames bidirectional WHERE clause` | _is_uuid(device_id) branch | ✓ WIRED | read.py lines 370-385 |
| `decoded_frames_between()` | `decoded_frame_from_row` mapper index 18 | SELECT column list | ✓ WIRED | store.rs:5262 — `decoded_frames.device_uuid` is 19th SELECT column (index 18); mapper reads it correctly |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `raw_evidence.device_uuid` | device_uuid column | Parameterised INSERT via ensure_raw_evidence_columns migration | Yes | ✓ FLOWING |
| `decoded_frames.device_uuid` via `decoded_frame()` | device_uuid at index 18 | INSERT with ?18 binding | Yes | ✓ FLOWING |
| `decoded_frames.device_uuid` via `decoded_frames_between()` | device_uuid at index 18 | SELECT now includes column at line 5262 | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Migration adds device_uuid column + index | `cargo test --test capture_import_tests test_migration_adds_device_uuid` | 1 passed; 0 failed | ✓ PASS |
| Insert with uuid persists | `cargo test --test capture_import_tests test_insert_raw_evidence_with_uuid` | 1 passed; 0 failed | ✓ PASS |
| Query by uuid | `cargo test --test capture_import_tests test_query_raw_evidence_by_uuid` | 1 passed; 0 failed | ✓ PASS |
| device_model unaffected | `cargo test --test capture_import_tests test_query_raw_evidence_by_device_model` | 1 passed; 0 failed | ✓ PASS |
| Import propagation | `cargo test --test capture_import_tests test_capture_import_propagates_device_uuid` | 1 passed; 0 failed | ✓ PASS |
| Sync backfill (gap closure target) | `cargo test` — `test_sync_backfill_creates_hr_rows` | ok | ✓ PASS |
| Sync backfill idempotent (gap closure target) | `cargo test` — `test_sync_backfill_is_idempotent` | ok | ✓ PASS |
| Full lib test suite | `cargo test` (from Rust/core) | 137 passed; 1 FAILED (pre-existing algo_benchmark) | ✓ PASS (SC5 excepts algo_benchmark) |

### Probe Execution

No probes defined for this phase. SKIPPED.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|------------|------------|-------------|--------|----------|
| DEVID-01 | 47-01 | device_uuid column exists on raw_evidence and decoded_frames, nullable, filled on capture | ✓ SATISFIED | Schema migration verified; insert wired; 5 capture_import tests pass; decoded_frames_between now fully wired |
| DEVID-02 | 47-01, 47-02, 47-03 | Consistent CoreBluetooth UUID flows from iOS capture through Rust storage and upload to server | ✓ SATISFIED | iOS wiring, upload, server ingest all verified; all Rust read paths (singular + plural) now include device_uuid |

### Anti-Patterns Found

None in re-verification. The previously identified BLOCKER (missing `device_uuid` in `decoded_frames_between` SELECT) has been resolved.

### Human Verification Required

None. All gaps were programmatically verifiable and have been resolved.

### Gaps Summary

No gaps remain. SC5 gap (InvalidColumnIndex(18) in sync_backfill tests) was closed by adding `decoded_frames.device_uuid` to the `decoded_frames_between()` SELECT at `Rust/core/src/store.rs:5262`. Both previously failing tests now pass. The only remaining test failure is `algo_benchmark_reference_comparison_reports_runtime_and_coverage`, which was pre-existing and explicitly excluded by SC5's wording.

---

_Verified: 2026-06-10T15:00:00Z_
_Verifier: Claude (gsd-verifier)_
