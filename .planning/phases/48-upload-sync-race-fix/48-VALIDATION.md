---
phase: 48
slug: upload-sync-race-fix
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-10
---

# Phase 48 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Xcode built-in) + cargo test |
| **Config file** | GooseSwift.xcodeproj (XCTest), Rust/core/Cargo.toml (cargo) |
| **Quick run command (Swift)** | Run GooseSwiftTests target in Xcode simulator |
| **Quick run command (Rust)** | `cargo test -p goose-core sync_methods_tests --manifest-path Rust/core/Cargo.toml` |
| **Full suite command** | `cargo test -p goose-core --manifest-path Rust/core/Cargo.toml` |
| **Estimated runtime** | ~30s (Rust) + ~60s (Swift build) |

---

## Sampling Rate

- **After every task commit:** `cargo test -p goose-core sync_methods_tests --manifest-path Rust/core/Cargo.toml`
- **Per wave merge:** `cargo test -p goose-core --manifest-path Rust/core/Cargo.toml` (full Rust suite)
- **Phase gate:** Full Rust suite green + GooseSwiftTests build clean

---

## Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SYNCR-01a | 503 server response leaves rows with synced=0 | unit (Swift) | Xcode GooseUploadServiceTests | ✅ needs new test methods |
| SYNCR-01b | 200 server response marks rows synced=1 | unit (Swift) | Xcode GooseUploadServiceTests | ✅ needs new test methods |
| SYNCR-01c | Pre-captured rowIDs exclude rows inserted during race window | unit (Rust) | `cargo test … test_pre_capture_does_not_mark_rows_inserted_during_race_window` | ❌ Wave 0 add |
| SYNCR-01d | rows_pending_upload/mark_synced existing behaviour preserved | unit (Rust) | `cargo test … sync_methods_tests` | ✅ existing tests |

---

## Wave 0 Gaps (must be created before execution)

- [ ] Add `test_pre_capture_does_not_mark_rows_inserted_during_race_window` to `Rust/core/src/store.rs` `sync_methods_tests` module
- [ ] Add `init(databasePath:session:)` URLSession-injectable initialiser to `GooseUploadService`
- [ ] Add Swift test methods `test_upload503_leavesSynced0` and `test_upload200_marksSynced1` to `GooseSwiftTests/GooseUploadServiceTests.swift`
