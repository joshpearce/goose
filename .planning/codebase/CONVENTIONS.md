# Coding Conventions

**Analysis Date:** 2026-06-04

## Naming Patterns

**Files:**
- Swift: PascalCase matching the primary type — `GooseBLEClient.swift`, `ActivityModels.swift`
- Extensions that add a concern use `+` notation — `GooseBLEClient+Commands.swift`, `GooseAppModel+OvernightRun.swift`
- Multiple related views in one file use `Views` suffix — `HealthDashboardViews.swift`
- Type bundles use `Types` suffix — `GooseBLETypes.swift`, `CoachChatTypes.swift`
- Model bundles use `Models` suffix — `ActivityModels.swift`, `HealthModels.swift`
- Rust: `snake_case` modules in flat `Rust/core/src/` — `bridge.rs`, `protocol.rs`, `step_motion_estimator.rs`
- Rust test files mirror the module under test with `_tests` suffix — `protocol_tests.rs`, `metrics_tests.rs`

**Types:**
- Swift: PascalCase throughout — `GooseAppModel`, `GooseBLEClient`, `OvernightSQLiteMirrorQueue`
- Prefix with subsystem/domain for disambiguation — `GooseMessage`, `GooseSyncToast`, `GooseHistoricalSyncProgress`
- Error types use PascalCase with `Error` suffix — `GooseRustBridgeError`, `OpenAIResponsesError`
- Enum cases use camelCase — `case debug`, `case poweredOn`, `case healthMonitor`
- Rust: PascalCase structs and enums — `GooseStore`, `BridgeResponse`, `GooseError`
- Rust type alias: `pub type GooseResult<T> = Result<T, GooseError>` (defined in `Rust/core/src/error.rs`)

**Functions/Methods:**
- Swift: camelCase verbs — `handleNotification`, `startOvernightGuard`, `refreshActivityTimeline`
- Action prefix verbs: `begin`, `start`, `stop`, `handle`, `refresh`, `resume`, `persist`, `publish`
- Factory statics prefixed with `make` or descriptive verb — `makeRequest`, `buildUploadPayload`
- Rust: `snake_case` — `run_perf_budget`, `parse_frame_hex`, `evaluate_linear_calibration`
- Rust bridge handler functions use `_bridge` suffix — `parse_frame_hex_bridge`, `storage_check_bridge`

**Properties:**
- Swift: camelCase — `bluetoothState`, `connectionState`, `liveHeartRateBPM`
- Booleans prefixed with `is`, `can`, `has`, `should` — `isScanning`, `canSend`, `isStreaming`
- `UserDefaults` keys: dot-namespaced reverse-DNS strings as `static let` — `"goose.swift.liveHRVRMSSD"`, `"goose.coach.modelPreset"`

**Constants:**
- Swift: `static let` on the enclosing type, camelCase — `static let bleUIStatePublishInterval: TimeInterval = 0.2`, `static let maximumDisplayedMessages = 300`
- `DispatchQueue` labels use reverse-DNS — `"com.goose.swift.corebluetooth"`, `"com.goose.swift.notification-ingest"`
- Enum cases as namespaced constants: `OnboardingStorage.onboardingComplete`, `FitnessColor.workoutYellow`
- Rust: `SCREAMING_SNAKE_CASE` for public constants — `GOOSE_HRV_V0_ID`, `BRIDGE_RESPONSE_SCHEMA`, `CURRENT_SCHEMA_VERSION`, `PACKET_TYPE_EVENT`

## Code Style

**Indentation:**
- Swift: 2-space indentation consistently throughout all Swift files
- Rust: 4-space (enforced by `rustfmt` in CI)

**Brace style:**
- Swift: opening brace on same line (K&R style); no Allman braces

**Multi-line signatures:**
- Long method signatures split with each parameter on its own indented line; closing `)` on its own line

**Spacing:**
- One blank line between methods within a Swift type
- Two blank lines between top-level declarations in extension files (import block + two blank lines + extension body)
- No blank lines between `import` statements

**Literals:**
- Trailing commas in multi-line Swift array/dict literals

**Formatters:**
- Swift: no `.swiftformat` or `.swiftlint.yml` detected — style is enforced by convention only
- Rust: `rustfmt` enforced in CI — `cargo fmt --all -- --check` (`.github/workflows/rust-core.yml`)
- Rust `clippy`: runs advisory-only in CI (`continue-on-error: true`); does not gate merges

## Swift-Specific Patterns

**Actor model:**
- `@MainActor` applied to `GooseAppModel` and `HealthDataStore` — all `@Published` state mutations happen on main
- Dedicated `DispatchQueue` instances for BLE events, notification parsing, frame writes, packet input computation, and overnight mirror writes
- Background work dispatches back to main with `Task { @MainActor in ... }`
- `nonisolated` on static utility methods that can safely run off main — e.g., `nonisolated static func shouldPublishOvernightRawSpoolSnapshot(...)` in `GooseAppModel+OvernightRun.swift`
- `NSLock` guards for counters shared between queues

**Published and state:**
- `@Published private(set) var` for read-only public state on `ObservableObject` — prevents external mutation while keeping reactivity
- `@Published var` for fully mutable state
- `@EnvironmentObject` for app-wide injection of `GooseAppModel` and `AppRouter`
- `@StateObject` at the root (`GooseSwiftApp`) for owned instances
- `@State` for view-local ephemeral state only

**Access control:**
- `private` used heavily for internal state in `final class` types (~1281 occurrences in `GooseSwift/`)
- `private(set)` for `@Published` properties that views may read but not write
- `@unchecked Sendable` on queue-protected types — `final class CaptureFrameWriteQueue: @unchecked Sendable`, `final class GooseUploadService: @unchecked Sendable`
- All major behavioral types are `final class` (not `struct`) when they hold identity or manage lifecycle

**Extension files:**
- Large classes split into focused extension files per concern area
  - `GooseBLEClient+Commands.swift`, `GooseBLEClient+HistoricalCommands.swift`, `GooseBLEClient+Parsing.swift`, `GooseBLEClient+PeripheralDelegate.swift`
  - `GooseAppModel+NotificationPipeline.swift`, `GooseAppModel+ActivityRecording.swift`, `GooseAppModel+OvernightRun.swift`
  - `HealthDataStore+PacketInputs.swift`, `HealthDataStore+Snapshots.swift`, `HealthDataStore+Sleep.swift`, `HealthDataStore+Cardio.swift`
- Each extension owns a coherent slice of behavior; all share mutable state on the parent class
- `// MARK: -` section dividers used within longer files to separate logical groups

## Rust-Specific Patterns

**Error handling:**
- Central `GooseError` enum in `Rust/core/src/error.rs` using `thiserror`
- Variants: `Message(String)`, `Io { path: PathBuf, source: io::Error }`, `Json { path, source }`, `Hex(#[from] hex::FromHexError)`, `Sqlite(#[from] rusqlite::Error)`
- Constructor helpers: `GooseError::message(...)`, `GooseError::io(path, source)`, `GooseError::json(path, source)`
- `GooseResult<T>` type alias used as the return type for all fallible public functions
- `?` operator propagated throughout; `.map_err(|e| GooseError::message(format!("...")))` for context wrapping
- Bridge layer converts `Err(GooseError)` into `{ ok: false, error: { code, message } }` JSON before returning to Swift

**Module organization:**
- Flat `Rust/core/src/` directory — 42 modules, no subdirectories
- `mod error` is private (`mod error;`); re-exports `GooseError` and `GooseResult` at crate root
- All domain modules are `pub mod` (see `Rust/core/src/lib.rs`)
- CLI binaries in `Rust/core/src/bin/` — one binary per tool; each calls a domain function and exits, printing errors with `eprintln!("{error}")`
- Integration tests in `Rust/core/tests/` (one file per domain area tested)
- Inline `#[cfg(test)]` modules are minimal — 19 inline unit tests vs 697 functions in integration test files

**FFI patterns:**
- Two C symbols exported: `goose_bridge_handle_json(request: *const c_char) -> *mut c_char` and `goose_bridge_free_string(ptr: *mut c_char)`
- Bridge input: JSON string with schema `goose.bridge.request.v1`, fields `schema`, `request_id`, `method`, `args`
- Bridge output: heap-allocated JSON string; caller must free with `goose_bridge_free_string`
- All bridge response: `{ ok: bool, request_id: String, result?: Value, error?: { code, message }, timing_ms: f64 }`
- All storage-backed bridge methods require `database_path` in `args` — Rust side is stateless
- Platform conditional: `tungstenite` excluded on Android — `#[cfg(not(target_os = "android"))]`

**Serialization:**
- `serde::Serialize` and `serde::Deserialize` derived on all data structs
- JSON is the single wire format through the FFI boundary
- `include_str!()` used in integration tests to embed fixture JSON at compile time

## Comments & Documentation

- No `///` doc comments on any public API — neither Swift nor Rust use documentation comments
- Inline `//` comments explain non-obvious logic and configuration constants
- No TODO, FIXME, HACK, or XXX markers anywhere in the codebase
- Swift: `// MARK: -` section dividers used within longer files
- Rust test function names serve as documentation — named after the precise invariant being checked, e.g., `goose_hrv_v0_pnn50_uses_strictly_greater_than_50_ms`
- Comments use natural sentence case; parameter names and types are considered self-documenting from the code

## Error Handling

**Swift:**
- `do { try ... } catch { }` for throwing FileManager, JSON serialization, and export operations
- Bridge failures set human-readable `@Published` status strings — e.g., `catalogStatus = "Metric catalog unavailable: \(error)"` — rather than propagating thrown errors to the UI
- BLE errors logged via `ble.record(level: .error, source:, title:, body:)` and surfaced in `connectionState`
- Overnight guard errors accumulate as `@Published` warning strings in `overnightGuardWarning` / `overnightGuardStatus`
- `throw` propagated in static I/O utilities (`GooseSwift/GooseLocalDataExporter+FileSystem.swift`), caught at the call site in the exporter

**Rust:**
- `GooseResult<T>` as the universal return type for all fallible functions
- `?` propagation within domain functions; the bridge layer converts errors to JSON before returning
- No `unwrap()` or `expect()` in production source files — integration tests use `.unwrap()` freely for brevity

## Logging

**Swift:**
- Framework: `OSLog` — 11 files import `OSLog`
- Logger instances declared as `let logger = Logger(subsystem: "com.goose.swift", category: "<area>")`
  - `"ble"` category — `GooseBLEClient.swift` line 83, `GooseBLEClient+VitalsAndLogging.swift` line 337
  - `"upload"` category — `GooseUploadService.swift` line 4 (module-level `private let`)
- Log levels in use: `.debug`, `.info`, `.warning`, `.error`
- Privacy annotation: `"\(value, privacy: .public)"` used consistently when logging dynamic string values
- BLE subsystem uses a custom `ble.record(level:source:title:body:)` abstraction (`GooseBLEClient+VitalsAndLogging.swift`) that gates OSLog writes via `shouldWriteOSLog(_:)` and also captures events to SQLite

**Rust:**
- No logging framework — CLIs print structured JSON reports to stdout via `println!`
- Errors reported to stderr via `eprintln!("{error}")`
- No runtime logging in the library itself; all observability surfaces through the JSON bridge protocol
