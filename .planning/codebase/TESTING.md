# Testing

**Analysis Date:** 2026-06-04

## Test Coverage Summary

| Area | Coverage |
|------|----------|
| Rust protocol parsing | Comprehensive — `Rust/core/tests/protocol_tests.rs` |
| Rust bridge (all 58+ methods) | Comprehensive — `Rust/core/tests/bridge_tests.rs` (105 test functions) |
| Rust metrics algorithms (HRV, Recovery, Sleep, Strain, Stress) | Comprehensive — `Rust/core/tests/metrics_tests.rs` (63 functions) |
| Rust SQLite store (schema migrations, CRUD) | Comprehensive — `Rust/core/tests/store_tests.rs` (31 functions) |
| Rust sleep validation | Comprehensive — `Rust/core/tests/sleep_validation_tests.rs` (96 functions) |
| Rust performance budgets | Present — `Rust/core/tests/perf_budget_tests.rs` |
| Rust property-based invariants | Present — `Rust/core/tests/property_tests.rs` |
| Rust fixture index and parser fixtures | Present — `Rust/core/tests/fixture_tests.rs` |
| Swift BLE types and generation derivation | Present — `GooseSwiftTests/GooseBLETypesTests.swift` (14 methods) |
| Swift `WearableDescriptor` UUID matching | Present — `GooseSwiftTests/WearableDescriptorTests.swift` (8 methods) |
| Swift `GooseUploadService.buildUploadPayload` | Present — `GooseSwiftTests/GooseUploadServiceTests.swift` (5 methods + 1 source assertion) |
| Swift `GooseAppModel` (coordinator) | Not testable in XCTest — requires BLE hardware and `@MainActor`; noted in `GooseUploadServiceTests.swift` line 86 |
| Swift `HealthDataStore` (query layer) | Not tested — requires Rust bridge and SQLite |
| Swift `GooseRustBridge` (FFI) | Not tested via XCTest |
| Swift UI views | Not tested — no snapshot or UI test target |

## Swift Tests

**Test target:** `GooseSwiftTests` (XCTest)
- Defined in `GooseSwift.xcodeproj/project.pbxproj` as target `T50000000000000000000001`
- Output product: `GooseSwiftTests.xctest`
- **Note:** The `GooseSwift.xcscheme` TestAction `<Testables>` section is empty — the test target exists in the project but is not wired to the shared scheme's Run Tests action. Tests must be run by selecting the `GooseSwiftTests` target manually in Xcode.

**Test files:**
- `GooseSwiftTests/GooseBLETypesTests.swift` — 14 test methods, 30 Swift test functions
- `GooseSwiftTests/WearableDescriptorTests.swift` — 8 test methods
- `GooseSwiftTests/GooseUploadServiceTests.swift` — 5 behavioral tests + 1 source-level assertion (30 total XCT assertions)

**Run command:**
```bash
xcodebuild test -project GooseSwift.xcodeproj -scheme GooseSwift -destination 'platform=iOS Simulator,name=iPhone 16'
# or select GooseSwiftTests target in Xcode and press Cmd+U
```

**Import pattern:**
```swift
import XCTest
import CoreBluetooth          // only when testing BLE-related types
@testable import GooseSwift
```

**Test class pattern:**
```swift
final class GooseBLETypesTests: XCTestCase {

  // MARK: - <group description>

  func testGenerationDerivation_gen4ServiceUUID() {
    let generation = GooseBLEClient.generation(from: [gen4UUID])
    XCTAssertEqual(generation, "4.0", "<failure message>")
  }
}
```

**Key characteristics:**
- All test classes are `final class` conforming to `XCTestCase`
- No `setUp`/`tearDown`/`setUpWithError` lifecycle methods — each test is self-contained
- Instances of pure types created inline — `private let service = GooseUploadService(databasePath: "/dev/null")`
- `XCTSkip` used in one case when a source file cannot be resolved from the test bundle sandbox
- No mocking framework — only pure/static functions testable without BLE hardware

**What cannot be tested via XCTest:**
- `GooseAppModel` — requires `@MainActor` + CoreBluetooth hardware; explicitly documented in `GooseUploadServiceTests.swift`
- `GooseRustBridge` — FFI calls require the compiled `libgoose_core.a` linked to the test target
- Any `@MainActor` type that depends on a live `CBCentralManager`

**Source-level assertion pattern** (workaround for untestable behavior):
```swift
// Walk up from bundle URL to find source file; read contents; assert no forbidden literal
let sourceContent = try resolveUploadSourceContent()
XCTAssertFalse(sourceContent.contains("deviceType: \"GOOSE\""), "...")
// Falls back to XCTSkip when sandboxed
```
Used in `GooseUploadServiceTests.swift` to guard against a hardcoded device type regression.

## Rust Tests

**Runner:** `cargo test` (built-in)
- Config: `Rust/core/Cargo.toml` — no separate test framework dependency (uses built-in Rust test harness)
- Dev dependency: `tempfile = "3.13"` for temporary SQLite databases in tests
- Working directory for tests: `Rust/core/` — relative paths like `Path::new("fixtures")` resolve from there

**Run commands:**
```bash
cd Rust/core
cargo test --locked                    # run all tests
cargo test --locked --no-fail-fast     # as used in CI (continue past first failure)
cargo test --lib --verbose             # lib unit tests only (CI MSRV job)
cargo test <test_name>                 # single test by name
cargo test -p goose-core               # explicit crate
```

**Test organization:**
- **Integration tests** in `Rust/core/tests/` — 41 files, ~697 test functions total
- **Inline unit tests** — 19 `#[test]` functions inside `#[cfg(test)]` modules in `src/` files
- Each integration test file corresponds to one domain module

**Integration test files and scope:**

| File | Functions | Domain |
|------|-----------|--------|
| `bridge_tests.rs` | 105 | All bridge methods (JSON-RPC over FFI) |
| `sleep_validation_tests.rs` | 96 | Sleep staging, window detection, release gate |
| `metric_features_tests.rs` | 76 | Metric feature extraction |
| `metrics_tests.rs` | 63 | HRV, Recovery, Sleep, Strain, Stress algorithms |
| `command_tests.rs` | 59 | BLE command definitions and validation |
| `export_tests.rs` | 47 | Export bundle structure and checksums |
| `local_health_validation_suite_cli_tests.rs` | 46 | CLI tool contract |
| `health_sync_tests.rs` | 40 | HealthKit dry-run sync |
| `store_tests.rs` | 31 | SQLite schema, migrations, CRUD |
| `history_sync_tests.rs` | 31 | Historical sync state machine |
| `metric_feature_report_cli_tests.rs` | 26 | CLI report format |
| `fixture_tests.rs` | 22 | Fixture index integrity and parser fixtures |
| `activity_candidates_tests.rs` | 19 | Activity candidate classification |
| `protocol_tests.rs` | 18 | Frame parsing, CRC, deframing |
| `metric_readiness_tests.rs` | 17 | Metric readiness scoring |
| `debug_ws_tests.rs` | 17 | WebSocket debug server |
| `step_counter_tests.rs` | 15 | Step counting pipeline |
| `reference_runner_cli_tests.rs` | 15 | Reference algorithm CLI runner |
| `ui_coverage_tests.rs` | 13 | UI coverage audit |
| `reference_tests.rs` | 12 | OpenWHOOP reference algorithm output |
| `property_tests.rs` | ~8 | Property-based invariants (parser, deframer, algorithm bounds) |
| `perf_budget_tests.rs` | 3 | Performance budget pass/fail |
| `storage_check_tests.rs` | 3 | Storage self-test |
| Others (algo_benchmark, calibration, capture_*, privacy_lint, etc.) | varies | Domain-specific |

## Test Infrastructure

**CI — Rust core (`.github/workflows/rust-core.yml`):**
- `cargo fmt --all -- --check` — format gate (blocks merge on failure)
- `cargo build --lib` + `cargo test --lib` on Ubuntu + macOS-15 matrix, at MSRV `1.96`
- `cargo clippy --lib --no-deps -- -D warnings` — advisory only (`continue-on-error: true`)

**CI — Rust core full test (`.github/workflows/rust-core-ci.yml`):**
- `cargo build --all-targets --locked` + `cargo test --locked --no-fail-fast` on Ubuntu
- Android cross-compile: `cargo ndk -t arm64-v8a build --release --lib`
- Python3 available for reference algorithm adapters (NeuroKit2, pyHRV, pyActigraphy)

**CI — Swift/iOS:**
- No dedicated Swift CI workflow detected; iOS build requires macOS + Xcode and is not automated

**Fixtures:**
- Location: `Rust/core/fixtures/synthetic/` — `.hex` and `.json` pairs for parser testing
- `Rust/core/fixtures/index.json` — machine-readable fixture index with checksums
- Fixture JSON embedded in tests with `include_str!("../fixtures/synthetic/<file>.json")`
- `build_fixture_index(Path::new("fixtures"))` function validates checksums at test time

**Temporary databases:**
- `tempfile::tempdir()` creates isolated SQLite databases per test
- `GooseStore::open_in_memory()` used for pure algorithmic tests that need store but no persistence
- `GooseStore::open(&path)` used when migration or schema tests need a real file

**Bridge test helper:**
```rust
fn request(value: serde_json::Value) -> BridgeResponse {
    serde_json::from_str(&handle_bridge_request_json(&value.to_string())).unwrap()
}
```
Defined at the bottom of `Rust/core/tests/bridge_tests.rs` (line 8519). All bridge tests call through this helper.

**Seed helper pattern:**
```rust
fn seed_recovery_calibration(db: &std::path::Path) {
    let store = GooseStore::open(db).unwrap();
    // insert algorithm definitions, calibration records, etc.
}
```
Used to set up database state before testing bridge methods that require pre-existing data.

## Coverage Gaps

**Swift (high risk):**
- `GooseAppModel` — the central coordinator is completely untested; all BLE pipeline logic, overnight guard, and activity recording are uncovered
- `HealthDataStore` — all metric query extensions are untested
- `GooseRustBridge` — the FFI call/response cycle is not tested from Swift
- All SwiftUI views — no UI or snapshot tests exist
- `GooseUploadService.triggerManualUpload` — only guarded by a source-level assertion, not a behavioral test

**Swift (medium risk):**
- `CaptureFrameWriteQueue`, `OvernightSQLiteMirrorQueue` — queue-protected insert logic untested
- `NotificationFrameParser`, `WhoopDataSignalPipeline` — pipeline entry points untested

**Rust (low risk — well covered):**
- Rust core has broad coverage across all major modules
- `algo_benchmark_tests.rs` and `calibration_tests.rs` test less-frequently-exercised paths
- No explicit coverage measurement tooling configured (no `tarpaulin` or similar in `Cargo.toml`)

## Testing Conventions

**Rust test naming:**
- Descriptive `snake_case` function names that state the invariant — not `test_foo` prefix
- Examples: `parses_hand_derived_goose_v5_get_hello_frame`, `goose_hrv_v0_pnn50_uses_strictly_greater_than_50_ms`, `deframer_reassembles_split_v5_frame_and_drops_prefix_noise`
- `#[test]` attribute immediately before `fn`; no grouping struct or test runner macro

**Swift test naming:**
- Method names use `test` prefix (XCTest requirement) then a snake-like description
- Examples: `testGenerationDerivation_gen4ServiceUUID`, `test_buildUploadPayload_gen4_hasGeneration4_noDeviceClass`, `test_rustDeviceType_2A37_full128bit_returnsHRMonitor`
- `// MARK: - <group>` used to group related test methods within a class

**Rust assertion patterns:**
```rust
assert!(response.ok, "{:?}", response.error);  // pass error context on failure
assert_eq!(output.algorithm_id, GOOSE_HRV_V0_ID);
assert_close(output.mean_nn_ms, 800.0);  // local helper for f64 epsilon comparison

fn assert_close(actual: f64, expected: f64) {
    assert!((actual - expected).abs() < 1e-6, "expected {expected}, got {actual}");
}
```

**Swift assertion patterns:**
```swift
XCTAssertEqual(generation, "4.0", "61080001 service UUID should derive generation 4.0")
XCTAssertNil(payload["device_class"], "GEN4 payload must NOT carry device_class")
XCTAssertFalse(condition, "<explanation of required invariant>")
// All XCTAssert calls include a human-readable failure message as the last argument
```

**What gets mocked:**
- Nothing — both Swift and Rust tests use real types with real inputs
- Swift tests only cover pure static/instance methods that do not require hardware or background actors
- Rust tests use in-memory or temp-file databases; `GooseStore::open_in_memory()` substitutes for the real file
