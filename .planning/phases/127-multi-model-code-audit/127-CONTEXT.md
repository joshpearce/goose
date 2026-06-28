# Phase 127: Multi-Model Code Audit - Context

**Gathered:** 2026-06-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Produce a structured, prioritised findings report covering Rust core, Android Kotlin, and iOS Swift — analysed independently by Opus, Gemini (self-contained prompt), and Codex CLI. Analysis only; no source changes in this phase. Output feeds Phase 128 (Android fixes) and future iOS phases.

</domain>

<decisions>
## Implementation Decisions

### Gemini Execution Strategy
- **D-01:** Gemini uses self-contained inline prompts (no file path mentions in prompt text). Add explicit instruction "Do NOT read any files — all context is below." Timeout 90 seconds. If Gemini exits with only the banner or hangs, mark `gemini_status: timeout_during_agentic_file_read` in findings report and continue with Opus+Codex results.
- **D-02:** Gemini prompt must keep inline code under ~400 lines to avoid large-inline-diff timeout. For Rust, pass bridge/mod.rs + store/mod.rs + android_jni.rs inline; for Android, pass GooseBridge.kt + WhoopBleClient.kt + AppViewModel.kt; for Swift, pass GooseAppModel.swift header + GooseRustBridge.swift.

### Analysis Scope (per model)
- **D-03:** Full codebase scope:
  - **Rust**: all non-bin `.rs` files under `Rust/core/src/` (57 files) — priority focus: `bridge/`, `store/`, `android_jni.rs`, `metric_features.rs`, `historical_sync.rs`, `protocol.rs`
  - **Android Kotlin**: all 17 `.kt` source files under `android/app/src/main/`
  - **iOS Swift**: key architecture files — `GooseAppModel.swift`, `GooseRustBridge.swift`, `GooseBLEClient.swift`, `HealthDataStore.swift` and their `+*.swift` extensions; `NotificationFrameParsing.swift`, `CaptureFrameWriteQueue.swift`, `OvernightSQLiteMirrorQueue.swift`
- **D-04:** Opus (via Agent tool subagent) reads files directly with Read/Bash tools — full file access, no content limits. Codex CLI likewise reads files via its native filesystem access.

### Findings Report Structure
- **D-05:** Three raw model outputs saved as individual artifacts:
  - `.planning/phases/127-multi-model-code-audit/127-OPUS-FINDINGS.md`
  - `.planning/phases/127-multi-model-code-audit/127-GEMINI-FINDINGS.md` (or `127-GEMINI-STATUS.md` if timeout)
  - `.planning/phases/127-multi-model-code-audit/127-CODEX-FINDINGS.md`
- **D-06:** Consolidated report at `.planning/phases/127-multi-model-code-audit/127-AUDIT-REPORT.md` — de-duplicated, ranked HIGH/MEDIUM/LOW across axes: module organisation, god-files, JNI/FFI patterns, threading/coroutine scope, null-safety/error handling gaps.
- **D-07:** Each HIGH/MEDIUM finding in consolidated report names: platform (Rust/Android/iOS), file path, symbol/function where possible, severity, and tag: `android-v16` (fix in Phase 128) vs `ios-future` vs `rust-future`.

### Axes to Analyse (per model)
- **D-08:** Required analysis axes:
  1. Module organisation — god files, single-responsibility violations, module boundary clarity
  2. JNI/FFI patterns — error propagation, SAFETY contracts, lifecycle assumptions
  3. Threading/concurrency — coroutine scope (Android), DispatchQueue safety (Swift), Rust Send/Sync
  4. Null-safety/error handling — silent discards, `unwrap()` equivalents, `try?` silent failures, Kotlin `!!` operators
  5. Android-specific — Compose state management, ViewModel ownership, lifecycle binding

### Claude's Discretion
- Order of model spawning (all parallel where possible)
- Exact prompting wording for Opus and Codex (no user constraint)
- Consolidation approach (de-duplication algorithm, majority-vote for severity)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Codebase — Rust core
- `Rust/core/src/android_jni.rs` — JNI shim; delegates to bridge/mod.rs
- `Rust/core/src/bridge/mod.rs` — BridgeRouter; domain handler dispatch
- `Rust/core/src/store/mod.rs` — domain store root; SleepStore/CaptureStore/MetricsStore
- `Rust/core/src/metric_features.rs` — large feature computation module
- `Rust/core/src/historical_sync.rs` — sync protocol implementation
- `Rust/core/src/protocol.rs` — WHOOP wire protocol parsing

### Codebase — Android
- `android/app/src/main/kotlin/com/goose/app/bridge/GooseBridge.kt` — JNI call site
- `android/app/src/main/kotlin/com/goose/app/ble/WhoopBleClient.kt` — BLE central
- `android/app/src/main/kotlin/com/goose/app/viewmodel/AppViewModel.kt` — central ViewModel
- `android/app/src/main/kotlin/com/goose/app/viewmodel/MetricsViewModel.kt` — metrics bridge calls

### Codebase — iOS Swift
- `GooseSwift/GooseAppModel.swift` + `GooseAppModel+*.swift` — central @MainActor coordinator
- `GooseSwift/GooseRustBridge.swift` — C FFI bridge wrapper
- `GooseSwift/GooseBLEClient.swift` + `GooseBLEClient+*.swift` — CoreBluetooth central
- `GooseSwift/HealthDataStore.swift` + `HealthDataStore+*.swift` — metrics query layer

### Seeds (provide WHY for known gaps)
- `.planning/seeds/SEED-007-best-practices-gaps.md` — 9 silent try? failures (BP-01), nonisolated(unsafe) gaps
- `.planning/seeds/SEED-004-architectural-overhaul.md` — god-file analysis consensus from 3 prior models

### Requirements
- `.planning/REQUIREMENTS.md` — RUST-AUD-01 requirements and acceptance criteria

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- SEED-004 already documents prior 3-model consensus on Rust god files (bridge.rs dispatcher, store.rs 9790L) — read it to seed the analysis prompt, not to replace running the audit fresh
- SEED-007 documents known gaps: 9 silent `try?` failures in Swift, nonisolated(unsafe) without locks

### Established Patterns
- Gemini CLI known to hang with file paths in prompt → self-contained prompt required (D-01/D-02)
- Gemini CLI installed at `/opt/homebrew/bin/gemini` — use absolute path in subagent contexts
- Codex uses `gpt-5.5` model via Siemens gateway; invoked as `codex` CLI
- Opus runs as Claude subagent (Agent tool) with full file-read capability

### Integration Points
- Findings report feeds Phase 128 (RUST-AUD-02, BP-AND-01/02) — must be specific enough to act on without re-investigation
- Deferred findings (Rust-core, iOS) feed future milestones and may seed new SEED-* files

</code_context>

<specifics>
## Specific Ideas

- User explicitly wants all three models (Opus, Gemini, Codex) — senior engineer perspective
- Rust analysis should cover module organisation specifically (god files are a known concern per SEED-004)
- Swift analysis added by user: focus on threading patterns, DispatchQueue safety, @MainActor correctness, bridge call sites
- Full codebase scope per user choice (not sampled subset)

</specifics>

<deferred>
## Deferred Ideas

- Fixing Rust god files (bridge.rs, store.rs) — deferred to v17.0+ (Rust-scope)
- iOS architectural fixes — deferred to v17.0 (Phase 128 covers Android only)
- Play Store release — out of scope for v16.0

</deferred>

---

*Phase: 127-Multi-Model Code Audit*
*Context gathered: 2026-06-28*
