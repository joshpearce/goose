# Phase 100 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| Test runner | xcodebuild (iOS Simulator) |
| Swift tests | GooseSwiftTests/ (XCTest) |
| Rust tests | N/A — no Rust changes in this phase |

## Sampling Rate

Build verification after each plan's final task. No manual hardware test required — physical device testing deferred per hardware gate.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| Task 1 | 100-01 | 1 | BLE-01 | Build + grep | `xcodebuild build -sdk iphonesimulator ... CODE_SIGNING_ALLOWED=NO` | Pending |
| Task 2 | 100-01 | 1 | BLE-01 | grep | `grep -c 'didUpdatePreferredPHY' GooseSwift/CoreBluetoothBLETransport+PeripheralDelegate.swift` | Pending |
| Task 1 | 100-02 | 1 | BLE-02 | grep | `grep -c 'isOnWrist' GooseSwift/CoreBluetoothBLETransport.swift` | Pending |
| Task 2 | 100-02 | 1 | BLE-02 | Build + grep | `grep -c 'handleBodyLocationValue' GooseSwift/CoreBluetoothBLETransport+HistoricalHandlers.swift` | Pending |

## Wave 0 Gaps (accepted)

The following unit tests were identified in RESEARCH.md as Wave 0 gaps:

- `GooseSwiftTests/BLEBodyLocationParseTests.swift` — location byte → `Bool?` mapping (location 1 = true, 2-7/160 = false, other = nil)
- `GooseSwiftTests/BLEBodyLocationParseTests.swift` — `isOnWrist` reset to nil on disconnect

**Acceptance rationale:** The `handleBodyLocationValue` function is a simple byte-index lookup with no external dependencies. Coverage is provided by:
1. The automated grep verify steps confirming the function exists and is wired
2. The iOS simulator build gate confirming compilation
3. Full device-level validation requires physical WHOOP hardware (hardware gate — deferred)

Unit tests for this parser are tracked as a backlog item for Phase 110 (Code Health).
