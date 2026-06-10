# Phase 49: HealthDataStore Async Migration - Context

**Gathered:** 2026-06-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Migrate all 60+ `GooseRustBridge.request` / `requestValue` call sites in `HealthDataStore` and its 17 extension files from synchronous GCD dispatch (`packetInputQueue.async { }`) to Swift Concurrency (`async/await`). After migration, no bridge FFI call runs on the @MainActor thread; the existing `packetInputQueue` and `heartRateTimelineQueue` DispatchQueues are removed.

**Important context:** The current code already dispatches bridge calls to background queues — there is no active main-thread freeze. This migration is architectural: replace manual GCD boilerplate with Swift Concurrency for cleaner, auditable concurrency.

</domain>

<decisions>
## Implementation Decisions

### Migration approach
- **D-01:** Make `GooseRustBridge.requestValue` (and by extension `request`) an `async throws` function. Internally, the sync FFI call (`goose_bridge_handle_json`) runs inside `Task.detached(priority: .userInitiated) { ... }.value`. This ensures the FFI never executes on @MainActor even when called from @MainActor context.
- **D-02:** `HealthDataStore` remains `@MainActor @Observable`. No annotation change. The suspension points in `await bridge.request(...)` cause the runtime to hop to a worker thread for the FFI, then return to @MainActor for @Observable property mutations.
- **D-03:** All `refresh*` / `run*` methods in HealthDataStore that call the bridge become `async func`. Their callers (e.g., `refreshBridgeCatalogs()` called from `AppShellView`) wrap them in `Task { await store.refreshBridgeCatalogs() }`.

### Scope
- **D-04:** All 60+ call sites in `HealthDataStore.swift` and all `HealthDataStore+*.swift` files are migrated. Zero occurrences of `bridge.request` or `bridge.requestValue` without `await` in the final state.
- **D-05:** `packetInputQueue` and `heartRateTimelineQueue` are removed from `HealthDataStore.swift` after migration. No retained dead code.

### Migration strategy
- **D-06:** Wave-per-file approach: Plan 1 modifies `GooseRustBridge.swift` (adds async variant); subsequent plans group `HealthDataStore+*.swift` files with zero inter-plan file overlap. Each plan builds and compiles cleanly before the next begins.
- **D-07:** For each extension file: replace `packetInputQueue.async { ... bridge.request(...) ... DispatchQueue.main.async { self.x = result } }` with `async func refreshX() { ... let report = try await bridge.request(...) ... self.x = result }` (direct @MainActor mutation after `await` is safe).

### Verification
- **D-08:** Verification is: (a) `xcodebuild build` with zero errors and zero Swift Concurrency warnings; (b) launch in iOS Simulator and confirm Recovery V2, Sleep V2, and Esforço dashboards populate with data after a bridge call is triggered.

### Claude's Discretion
- Exact batching of HealthDataStore+*.swift files into plans (group by logical area, e.g., Cardio+Recovery together, Sleep+StagingSleep together).
- Whether to introduce a `nonisolated` wrapper on GooseRustBridge or use the existing instance — implementer chooses what compiles cleanly.
- Whether to add a `requestAsync` method alongside the existing sync `request`, or replace it — implementer decides based on migration strategy (additive is safer for wave migration).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Bridge layer
- `GooseSwift/GooseRustBridge.swift` — `requestValue` (line 30) is the sync FFI wrapper to make async; `request` (line 26) is the typed wrapper around `requestValue`
- `GooseSwift/GooseSwift-Bridging-Header.h` — C symbols `goose_bridge_handle_json` / `goose_bridge_free_string`

### HealthDataStore base class
- `GooseSwift/HealthDataStore.swift` — `@MainActor @Observable final class`; `packetInputQueue` (line 53) and `heartRateTimelineQueue` (line 54) to remove; `refreshBridgeCatalogs` (line 213) and `runPacketInputs` (line 263) are primary entry points to migrate

### Extension files to migrate (18 files)
- `GooseSwift/HealthDataStore+Recovery.swift` — `runRecoveryV1` uses `packetInputQueue.async`; bridge.request at line 115
- `GooseSwift/HealthDataStore+Cardio.swift` — bridge.request at lines 97, 116
- `GooseSwift/HealthDataStore+Sleep.swift`
- `GooseSwift/HealthDataStore+StagingSleep.swift`
- `GooseSwift/HealthDataStore+Snapshots.swift`
- `GooseSwift/HealthDataStore+ActivitySnapshots.swift`
- `GooseSwift/HealthDataStore+PacketInputs.swift` — `nonisolated static` helpers already correct; instance call sites to migrate
- `GooseSwift/HealthDataStore+Readiness.swift`
- `GooseSwift/HealthDataStore+Exercise.swift`
- `GooseSwift/HealthDataStore+IMUSteps.swift`
- `GooseSwift/HealthDataStore+CoachSummaries.swift`
- `GooseSwift/HealthDataStore+StaticSnapshots.swift`
- `GooseSwift/HealthDataStore+StressEnergy.swift`
- `GooseSwift/HealthDataStore+Trends.swift`
- `GooseSwift/HealthDataStore+Utilities.swift`
- `GooseSwift/HealthDataStore+V24Biometrics.swift`
- `GooseSwift/HealthDataStore+Vitals.swift`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `packetInputQueue` / `heartRateTimelineQueue`: existing GCD queues that will be REMOVED after migration — do not add new calls to these
- `Task { @MainActor [weak self] in ... }`: already used in some call sites (e.g., Recovery.swift line 132) as a precedent for the async result-publication pattern

### Established Patterns
- Current pattern to replace: `queue.async { [weak self] in ... let r = try bridge.request(...) ... DispatchQueue.main.async { self.prop = r } }`
- Target pattern: `async func refreshX() async { ... let r = try await bridge.request(...) ... self.prop = r }` — @MainActor mutation after `await` is safe because the function returns to @MainActor after suspension
- `GooseRustBridge` is instantiated per-owner (not singleton); each HealthDataStore instance owns `let bridge = GooseRustBridge()` — this doesn't change

### Integration Points
- Callers of HealthDataStore refresh methods (SwiftUI views, GooseAppModel) currently call sync `refreshBridgeCatalogs()` etc. directly — after migration, call sites need `Task { await store.refreshBridgeCatalogs() }` wrappers
- `HeartRateSeriesStore.shared` and HealthKit calls (HK query handlers) are NOT bridge calls — exclude from migration scope

</code_context>

<specifics>
## Specific Ideas

- D-06 wave strategy: additive approach is preferred — add `requestAsync` alongside sync `request` so extension files can be migrated one-by-one without breaking the rest of the build mid-wave
- Final cleanup plan removes sync `request`/`requestValue` and renames `requestAsync` → `request` (or keeps as async, since sync version is gone)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 49-HealthDataStore Async Migration*
*Context gathered: 2026-06-10*
