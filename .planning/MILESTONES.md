# Milestones

## v5.0 Metrics Accuracy, IMU & Upstream Fixes (Phases 20-26) — PLANNED

**Phases:** 7 (Phases 20–26)
**Requirements:** 26 (SYNC-01–05, PERF-05, IMU-01–04, ALG-HRV-01–04, ALG-STR-01–03, ALG-CAL-01–02, ALG-SLP-01–02, ALG-REC-01–03, ALG-SLP-03–04)

**Goal:** Port validated algorithms from `my-whoop` into the Rust core — confirmed against WHOOP 5.37.0 IPA via Ghidra and peer-reviewed literature — so each metric (HRV, Recovery, Strain, Calories, Sleep) produces values aligned with WHOOP from the same raw data.

---

## v4.0 Security, Performance & Coach Expansion (Shipped: 2026-06-06)

**Phases completed:** 4 phases (16-19), 12 plans
**Known deferred items at close:** 6 (see STATE.md Deferred Items)

**Key accomplishments:**

- Deep link security: `allowsRemoteInvocation` guard blocks state-changing BLE commands from external `gooseswift://` invocations (SEC-01, upstream PR #15)
- Full `@Observable` migration: GooseAppModel + HealthDataStore + GooseBLEClient — 68 `@Published` removed; NavigationRequestObserver warning eliminated (PERF-01, PERF-02, PERF-03)
- Coach multi-provider: four AI backends (ChatGPT, Claude, Custom endpoint, Gemini OAuth PKCE); `CoachProvider` protocol; `CoachProviderRegistry`; provider picker UI in settings (COACH-01–06)
- pt-PT localisation complete: 128 strings covering all v4.0 UI additions including Coach settings, provider config, model preset names; onboarding skip button; startup non-blocking (L10N-03, PERF-04, UX-01)

---

## v3.0 Wearable UX, CI Hardening & RTC Sync (Shipped: 2026-06-05)

**Phases completed:** 8 phases (9–15 + 10.1), 17 plans

**Key accomplishments:**

- BLE stability: FFI catch_unwind + panic=unwind; 24 MB storage cap; exponential reconnect backoff (1s/60s) for WHOOP and HR monitor; per-row device_id in capture sessions
- HR monitor scan/connect UI: live scan list with RSSI, connect sheet, connected panel, wired into More tab Device section
- BLE main-thread publishing fix: all @Published mutations dispatched to main thread; eliminates background-thread CoreBluetooth warnings
- HR monitor independent capture: .hrMonitor mode; startHRMonitorCapture/stopHRMonitorCapture not gated on WHOOP session
- WHOOP 4.0 RTC clock sync: silent drift correction via BLE after connection
- Recovery V2 dashboard: hero score, HRV, RHR from bridge; 7-day trend
- pt-PT localisation infrastructure: Localizable.xcstrings, 650+ strings, dynamic status strings via LocalizedStatusStrings.swift
- Recovery formula SDNN accuracy: rmssd_segment_aware, hkHRVSDNNMs rename, baseline normalization

---

## v2.0 Multi-Device & Platform Foundations (Shipped: 2026-06-04)

**Phases completed:** 8 phases, 13 plans, 19 tasks

**Key accomplishments:**

- Duration:
- Duration:
- Duration:
- One-liner:
- WearableDescriptor.genericHRMonitor descriptor, empty-prefix guard, normalized HR_MONITOR rustDeviceType, and dedicated 0x180D BLE scan/connect/notify flow with background-queue dispatch — completing the WEAR-02 iOS acquisition path
- One-liner:
- Pure buildUploadPayload function extracted from performUpload plus 6-test GooseUploadServiceTests suite locking the WEAR-03 device taxonomy (GEN4/GOOSE/HR_MONITOR) behind regression tests — resolves cross-AI review HIGH-3.
- Root cause fix (capture_import.rs):
- `bridge_hr_monitor_upload_stream_contains_bpm_and_rr`

---

## v1.0 Servidor Remoto + PRs Upstream (Shipped: 2026-06-03)

**Phases completed:** 5 phases, 12 plans, 6 tasks

**Key accomplishments:**

- (none recorded)

---
