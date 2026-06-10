---
phase: 47
slug: device-id-namespace-resolution
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-10
validated: 2026-06-10
---

# Phase 47 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Rust built-in test runner |
| **Config file** | `Rust/core/Cargo.toml` |
| **Quick run command** | `cargo test -p goose-core capture_import` |
| **Full suite command** | `cargo test -p goose-core` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cargo test -p goose-core capture_import`
- **After every plan wave:** Run `cargo test -p goose-core`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 47-01-01 | 01 | 1 | DEVID-01 | — | N/A | unit | `cargo test --test capture_import_tests test_migration_adds_device_uuid` | ✅ | ✅ green |
| 47-01-02 | 01 | 1 | DEVID-01 | — | N/A | unit | `cargo test --test capture_import_tests test_insert_raw_evidence_with_uuid` | ✅ | ✅ green |
| 47-01-03 | 01 | 1 | DEVID-01 | — | N/A | unit | `cargo test --test capture_import_tests test_query_raw_evidence_by_uuid` | ✅ | ✅ green |
| 47-01-04 | 01 | 1 | DEVID-02 | — | N/A | unit | `cargo test --test capture_import_tests test_query_raw_evidence_by_device_model` | ✅ | ✅ green |
| 47-01-05 | 01 | 1 | DEVID-02 | — | N/A | unit | `cargo test --test capture_import_tests test_capture_import_propagates_device_uuid` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `Rust/core/tests/capture_import_tests.rs` — 5 new test functions for DEVID-01/02 (add to existing file)

*Framework install: none — Rust test infrastructure already present.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `GooseBLEClient` extrai UUID em connect e GooseAppModel guarda em UserDefaults | DEVID-02 | Requer dispositivo físico ou simulador com BLE | Conectar WHOOP → verificar `goose.swift.device_uuid_map` em UserDefaults via Xcode debug |
| `GooseUploadService` inclui `device_uuid` no payload de upload | DEVID-02 | Network layer — requer servidor a correr | Activar upload → verificar request body em proxy HTTP |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** 2026-06-10 — all 5 cargo tests pass (17/17 in capture_import_tests suite)
