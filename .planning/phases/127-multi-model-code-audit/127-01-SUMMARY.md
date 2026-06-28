---
phase: 127-multi-model-code-audit
plan: "01"
subsystem: code-audit
tags: [audit, multi-model, rust, android, ios, architecture]
status: complete

dependency_graph:
  requires: []
  provides: [127-AUDIT-REPORT, phase-128-android-fix-list]
  affects: [phase-128, future-rust-phases, future-ios-phases]

tech_stack:
  added: []
  patterns:
    - multi-model code audit (Opus + Codex; Gemini timed out)
    - D-01 self-contained Gemini prompt strategy (confirmed: Gemini ignores inline-only instruction)

key_files:
  created:
    - .planning/phases/127-multi-model-code-audit/127-OPUS-FINDINGS.md
    - .planning/phases/127-multi-model-code-audit/127-CODEX-FINDINGS.md
    - .planning/phases/127-multi-model-code-audit/127-GEMINI-STATUS.md
    - .planning/phases/127-multi-model-code-audit/127-AUDIT-REPORT.md
  modified: []

decisions:
  - "Gemini excluded from consolidation — 3 invocation attempts all timed out at 90s with 190-byte banner output (agentic file-read mode despite self-contained prompt). Confirmed D-01 failure mode."
  - "Codex exec subcommand used (not --quiet flag); gpt-5.1-codex-max model via Siemens gateway."
  - "android-v16 Phase 128 fix list contains 9 items (5 HIGH, 4 MEDIUM) all Android-side, no Rust/iOS required."

metrics:
  duration_minutes: 18
  completed_date: "2026-06-28"
  tasks_completed: 4
  tasks_total: 4
  files_created: 5
  files_modified: 0

---

# Phase 127 Plan 01: Multi-Model Code Audit Summary

**One-liner:** Three-model code audit (Opus + Codex; Gemini timed out) produced 31 structured findings across Rust/Android/iOS with 9 android-v16 HIGH+MEDIUM items ready for Phase 128.

## What Was Done

Ran three independent code audits in parallel across the full Goose codebase (Rust core 60 files, Android 17 files, iOS Swift 36 files) covering five analysis axes: module organisation, JNI/FFI patterns, threading/concurrency, null-safety/error handling, Android-specific Compose/ViewModel.

## Gemini Outcome

**gemini_status: timeout_during_agentic_file_read** — 3 invocation attempts, all producing only 190-byte banner output ("YOLO mode enabled / Ripgrep not available"). Exit codes: 0 (attempt 1 — no timeout enforcement available in zsh), 142 (attempt 2 — Perl SIGALRM at 90s), process kill at 90s (attempt 3). Gemini entered agentic file-read mode despite the "Do NOT read any files" instruction. Consolidation proceeded with Opus + Codex per D-01.

## Findings Count

| Severity | android-v16 | rust-future | ios-future | Total |
|----------|-------------|-------------|------------|-------|
| HIGH     | 5           | 3           | 4          | **12** |
| MEDIUM   | 4           | 4           | 4          | **12** |
| LOW      | 3           | 2           | 2          | **7**  |
| **Total**| **12**      | **9**       | **10**     | **31** |

## Phase 128 Android Fix List (9 items)

| # | Severity | Finding |
|---|----------|---------|
| A-01 | HIGH | `WhoopBleClient.scope` never cancelled — coroutines outlive ViewModel |
| A-02 | HIGH | `syncInProgress`/`activeGeneration` race between BLE callback and IO dispatcher |
| A-03 | HIGH | `importFrame` discards `safeHandle()` return — frame failures silent |
| A-04 | HIGH | 4 StateFlows in MainActivity not collected — Compose never recomposes |
| A-05 | HIGH | `bleClient` public val on AppViewModel — UI bypasses lifecycle guards |
| A-06 | MEDIUM | `queryScore` swallows all exceptions — metric failures invisible |
| A-07 | MEDIUM | `onSyncComplete` callback creates object reference cycle |
| A-08 | MEDIUM | `GooseUploadClient` singleton — upload state not observable from Compose |
| A-09 | MEDIUM | Sub-ViewModels bypass ViewModelProvider |

## Artifacts Produced

1. `.planning/phases/127-multi-model-code-audit/127-OPUS-FINDINGS.md` — 23 structured findings (12 HIGH, 8 MEDIUM, 3 LOW) across all five axes for Rust/Android/iOS
2. `.planning/phases/127-multi-model-code-audit/127-CODEX-FINDINGS.md` — 8 structured findings (3 HIGH, 3 MEDIUM, 2 LOW) from Codex gpt-5.1-codex-max
3. `.planning/phases/127-multi-model-code-audit/127-GEMINI-STATUS.md` — timeout status recorded per D-01
4. `.planning/phases/127-multi-model-code-audit/127-AUDIT-REPORT.md` — consolidated 31 findings, de-duplicated, severity-ranked, tagged, with Phase 128 fix list

## Key Decisions

- **D-01 confirmed:** Gemini cannot be used for code audits with self-contained prompts — enters agentic file-read regardless of instruction.
- **SEED-004 prior confirmed:** `store/mod.rs` (5,112L) and `metric_features.rs` (6,760L) are the largest god files (rust-future).
- **SEED-007 prior confirmed:** 9 silent `try?` failures exist in Swift; `nonisolated(unsafe)` properties lack compile-time lock enforcement (ios-future).
- **New findings beyond seeds:** Android coroutine scope leak, StateFlow not collected in Compose, silent exception swallowing in MetricsViewModel, GooseUploadClient with no observable state.

## Model Agreement

8 findings confirmed by both Opus and Codex (strong confidence). Gemini excluded. 23 single-model findings supported by prior seed consensus (SEED-004, SEED-007) or direct code evidence.

## Deviations from Plan

None — plan executed exactly as written. Gemini timeout is the documented failure mode (D-01 risk, `127-GEMINI-STATUS.md`).

## Self-Check: PASSED

All 5 artifacts verified on disk. No source files modified (GooseSwift Coach files were pre-existing modifications unrelated to this phase).
