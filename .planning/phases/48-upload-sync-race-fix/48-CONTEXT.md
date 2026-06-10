# Phase 48: Upload Sync Race Fix - Context

**Gathered:** 2026-06-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Eliminate the race condition in `GooseUploadService.performUpload` where `hr_samples` (and all other streams with a `synced` flag) are marked as synced before the server confirms receipt. RowIDs for all synced streams are captured before the HTTP request; `mark_synced` is called only after a 2xx response.

</domain>

<decisions>
## Implementation Decisions

### Scope of the fix
- **D-01:** Fix applies to **all streams that have a `synced` flag** in the Rust schema — not just `hr_samples`. Verify which streams have `synced=0/1` columns (expected: hr_samples; rr_intervals if applicable) and apply the pre-capture pattern to each.
- **D-02:** `markHrSamplesSynced` is refactored to accept pre-captured `[Int]` rowIDs as parameter instead of fetching internally. Pattern is generalised for any stream with a synced flag.

### Row capture timing
- **D-03:** Call `sync.rows_pending_upload` for each affected stream **before** constructing the upload payload (before `upload.get_recent_decoded_streams`). Store as `let rowIDs: [Int]`. Pass rowIDs to the marking function after 2xx.
- **D-04:** On failure (5xx or timeout after all retries), do NOT call `mark_synced` — rows stay with `synced=0` and are included in the next upload attempt.

### Test strategy
- **D-05:** Add a **Swift XCTest target** (`GooseSwiftTests`) to the Xcode project (`GooseSwift.xcodeproj`). Use a `URLProtocol` mock (or inject `URLSession` via initialiser) to simulate 503 → rows remain `synced=0`, and 200 → rows transition to `synced=1`. This tests the Swift orchestration layer, not just Rust persistence.
- **D-06:** Also add Rust-level tests for `sync.rows_pending_upload` and `sync.mark_synced` correctness (can be in existing `Rust/core/tests/`).

### Claude's Discretion
- Exact XCTest target name, target membership, and whether to use `URLProtocol` or constructor injection for `URLSession` — implementer decides based on minimal setup overhead.
- How to discover all streams with `synced` columns — grep Rust schema migrations and `sync.rs` module, then fix only those found.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source file — upload service
- `GooseSwift/GooseUploadService.swift` — the file being fixed; `performUpload` (line 41), `markHrSamplesSynced` (line 243), `uploadRawFrames` (line 142)

### Rust sync module
- `Rust/core/src/sync.rs` (or equivalent) — `rows_pending_upload`, `mark_synced` bridge handlers; discover synced-flag columns here
- `Rust/core/src/bridge.rs` — bridge dispatch table; `sync.*` method registrations

### Requirements
- `.planning/REQUIREMENTS.md` §SYNCR-01 — "performUpload captura os rowIDs de hr_samples antes do HTTP request e só chama markHrSamplesSynced após confirmação 2xx"
- `.planning/ROADMAP.md` §Phase 48 — Success Criteria 1-5

### Schema
- `Rust/core/src/` (migrations or schema init) — confirm which tables have `synced` column

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `GooseRustBridge` in `GooseUploadService` — already used for `sync.rows_pending_upload` and `sync.mark_synced`; no new bridge infrastructure needed
- `performRequest(_ request: URLRequest) async -> Int?` — already returns nil on failure; use this to determine whether to call mark_synced

### Established Patterns
- `Task.detached(priority: .utility)` — background execution pattern already used in `upload()` and `triggerBackfill()`
- `@unchecked Sendable` + cooperative thread pool — GooseUploadService is already structured for concurrent access; no new locking needed if rowIDs are captured in the same detached task
- Retry loop with `delays: [UInt64]` — existing 3-attempt pattern; rowIDs captured once before the loop, marking happens after the loop if successful

### Integration Points
- `GooseAppModel+Upload.swift` — calls `upload(deviceID:deviceType:sinceTimestamp:)`; no changes needed there
- `Rust/core/tests/` — add new test file for sync pre-capture correctness
- `GooseSwift.xcodeproj` — add `GooseSwiftTests` test target (new)

</code_context>

<specifics>
## Specific Ideas

- The refactored `markHrSamplesSynced` should accept `rowIDs: [Int]` directly (removing internal `rows_pending_upload` call)
- The pre-capture call should use `sinceTimestamp` for filtering, same as the current implementation, to bound the window
- 503 / network error path should `logger.warning("upload failed — rows not marked synced, will retry")` for observability

</specifics>

<deferred>
## Deferred Ideas

- Fixing `uploadRawFrames` (raw BLE frames) to also pre-capture frame IDs before marking — raw frames don't have a `synced` flag currently, so this is out of scope for Phase 48.
- Full sync idempotency / deduplication audit across all streams — broader than SYNCR-01.

</deferred>

---

*Phase: 48-Upload Sync Race Fix*
*Context gathered: 2026-06-10*
