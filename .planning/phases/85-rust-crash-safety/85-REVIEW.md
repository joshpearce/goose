---
phase: 85-rust-crash-safety
reviewed: 2026-06-14T20:30:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - Rust/core/src/bridge.rs
  - Rust/core/src/capabilities.rs
  - Rust/core/src/energy_rollup.rs
  - Rust/core/src/exercise_detection.rs
  - Rust/core/src/lib.rs
  - Rust/core/src/metrics.rs
  - Rust/core/src/openwhoop_reference.rs
  - Rust/core/src/step_discovery.rs
  - Rust/core/src/store.rs
findings:
  critical: 0
  warning: 2
  info: 2
  total: 4
status: issues_found
---

# Phase 85: Code Review Report

**Reviewed:** 2026-06-14T20:30:00Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Phase 85 converted production `.unwrap()` calls to safe alternatives across the Rust core and enforced `#![cfg_attr(not(test), deny(clippy::unwrap_used))]` at the crate root. The primary objective — eliminating production panics from bare unwraps — is achieved. No bare `.unwrap()` remains in any production code path across all nine reviewed files. All test-code `unwrap()` conversions to `.expect("reason")` are syntactically correct and appropriately scoped.

Two warnings were found: a correctness gap in the Lipponen-Tarvainen ectopic-beat filter (median index uses upper-median for even-length windows rather than lower-median, per the 2019 paper), and a silent null-pointer return from the FFI string allocator that discards error context. Two informational items note the `#[allow(clippy::unnecessary_unwrap)]` in the global allow list and a documentation version lag.

## Warnings

### WR-01: Lipponen-Tarvainen Filter Uses Upper-Median for Even-Length Windows

**File:** `Rust/core/src/metrics.rs:2676`
**Issue:** `lipponen_tarvainen_filter` sorts the local window and picks `window[window.len() / 2]` as the "median". For even-length windows, Rust integer division rounds down, so `len/2` selects the **upper** of the two middle elements rather than the lower. The Lipponen-Tarvainen (2019) paper convention is the lower-median (index `(len-1)/2`). For a 4-element window `[a, b, c, d]`, this code picks `c` (index 2) instead of `b` (index 1). The net effect is that the ectopic exclusion threshold is slightly higher than specified — the filter is more conservative and will remove fewer ectopic beats than the reference algorithm intends. At typical window sizes (2–5 elements), the deviation is one element out of position; RMSSD values will be marginally less cleaned than the reference.

**Fix:** Change the median index from `window.len() / 2` to `(window.len() - 1) / 2` to match the lower-median convention used in the LT 2019 specification:
```rust
// Before (upper-median for even lengths):
let median = window[window.len() / 2];

// After (lower-median, matching LT 2019):
let median = window[(window.len() - 1) / 2];
```
If exact parity with the my-whoop Python reference implementation is required, verify which index convention the Python version uses before changing.

### WR-02: `string_to_c_string` Returns Null and Discards Error Context on Null-Byte in Response

**File:** `Rust/core/src/bridge.rs:9803-9807`
**Issue:** `string_to_c_string` constructs a `CString`, which fails if the string contains an interior null byte (`\0`). On failure it silently returns `ptr::null_mut()`. The Swift caller correctly handles null via `guard let responsePointer else { throw .nullResponse }`, so there is no crash, but the original error that triggered the response is completely lost — the caller receives only a generic `.nullResponse` error with no diagnostic context.

The failure path is narrow: `serde_json::to_string` already escapes interior nulls in JSON string values, and the error fallback in `serialize_response` uses `escape_json_string` which escapes `\`, `"`, `\n`, `\r`, and `\t` but **not** null bytes (`\0`). If a Rust error message ever contains a literal null byte (e.g., from an OS error string on some platforms), the serialized response would carry a null byte in the error code field, causing `CString::new` to fail and the response to be replaced by Swift's generic `.nullResponse`.

**Fix:** Add null-byte escaping in `escape_json_string` or sanitize the response string before passing to `CString::new`:
```rust
fn escape_json_string(value: &str) -> String {
    value
        .replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('\0', "\\u0000")  // add this line
        .replace('\n', "\\n")
        .replace('\r', "\\r")
        .replace('\t', "\\t")
}
```
Alternatively, in `string_to_c_string`, replace null bytes before constructing `CString`:
```rust
fn string_to_c_string(value: String) -> *mut c_char {
    let sanitized = value.replace('\0', "\u{FFFD}");
    match CString::new(sanitized) {
        Ok(value) => value.into_raw(),
        Err(_) => ptr::null_mut(), // now truly unreachable
    }
}
```

## Info

### IN-01: `clippy::unnecessary_unwrap` Allow Coexists with `deny(clippy::unwrap_used)` — No Safety Gap, but Confusing

**File:** `Rust/core/src/lib.rs:13`
**Issue:** The global `#![allow(...)]` block includes `clippy::unnecessary_unwrap`. This lint fires when code does `if x.is_some() { x.unwrap() }` — exactly the pattern that the new `deny(clippy::unwrap_used)` already forbids via the unwrap itself. Allowing `unnecessary_unwrap` has no practical effect on safety because `deny(unwrap_used)` fires first on any `.unwrap()` call regardless. However, the combination is confusing to a reader: it creates the impression that `unnecessary_unwrap` was intentionally exempted for a reason, when in fact its allow is dead weight since `unwrap_used` covers its entire surface area in production code.

**Fix:** Remove `clippy::unnecessary_unwrap` from the global allow list, or add a comment explaining that it's retained only for historical compatibility and has no practical effect in production builds:
```rust
// Note: unnecessary_unwrap is redundant here because deny(unwrap_used) already
// forbids .unwrap() in production, making the "you could use if-let" suggestion moot.
// Kept for pre-existing historical compatibility; harmless.
clippy::unnecessary_unwrap,
```

### IN-02: Documentation Version Lag in CLAUDE.md Stack Section

**File:** `CLAUDE.md` (project instructions)
**Issue:** The stack documentation lists `rusqlite 0.37` and `sha2 0.10`, but `Cargo.toml` declares `rusqlite = "0.40"` and `sha2 = "0.11"`. These are minor version bumps but the mismatch could mislead contributors searching for dependency context.

**Fix:** Update the stack documentation to reflect the current `Cargo.toml` dependency versions: `rusqlite 0.40` and `sha2 0.11`.

---

_Reviewed: 2026-06-14T20:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
