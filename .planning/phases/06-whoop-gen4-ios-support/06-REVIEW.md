---
phase: "06"
status: warning
depth: standard
files_reviewed: 17
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
reviewed_at: "2026-06-03"
---

# Phase 06 Code Review: WHOOP Gen4 iOS Support

**Depth:** standard | **Files:** 17 | **Status:** warning

## Summary

Phase 06 changes are well-structured and correctly implement Gen4 BLE support. The critical Rust alias fix (`"GEN4"`) and `supportsV5*` rename are clean. Three warnings require attention before shipping.

---

## Findings

### WR-01 — `supportsHistoricalSync` (and siblings) silently return `false` when `activeDescriptor` is `nil`

**File:** `GooseSwift/GooseBLEClient+Commands.swift` — lines 147–161  
**Severity:** Warning  
**Category:** Logic bug

All four capability guards use:
```swift
commandCharacteristic.map { activeDescriptor?.isCommandCharacteristic($0) == true } == true
```

When `commandCharacteristic` is set but `activeDescriptor` is `nil` (e.g., device connected and characteristic discovered before `processDiscoveredCharacteristics` sets `activeDescriptor`), every guard returns `false`. This is a race condition during the connection setup sequence: if `commandCharacteristic` is set before `processDiscoveredCharacteristics` runs (which it cannot be, given the logic), or if `activeDescriptor` is reset by a disconnect callback while a command is in flight, all commands will be silently blocked.

**More practically:** `activeDescriptor` is set *inside* `shouldUseCommandCharacteristic` → only after `processDiscoveredCharacteristics` sets `commandCharacteristic`. So the nil window is short. But if the assumption breaks (e.g., restoration path with cached characteristics sets `commandCharacteristic` without calling `processDiscoveredCharacteristics`), all commands silently fail with no log output.

**Recommendation:** Add a log record when `activeDescriptor` is nil but `commandCharacteristic` is set. Or change the guard to fall back to prefix matching when descriptor is nil:
```swift
commandCharacteristic.map { c in
  if let desc = activeDescriptor { return desc.isCommandCharacteristic(c) }
  // Fallback: accept any known command characteristic UUID
  return commandCharacteristicIDs.contains(c.uuid)
} == true
```

---

### WR-02 — `connectedDeviceGeneration` not cleared on state transitions other than `"disconnected"` / `"connect failed"`

**File:** `GooseSwift/GooseAppModel+Lifecycle.swift` — lines 98–104  
**Severity:** Warning  
**Category:** State management bug

```swift
if state == "ready" {
  connectedDeviceGeneration = ...
} else if state == "disconnected" || state == "connect failed" {
  connectedDeviceGeneration = nil
}
```

Connection states such as `"connecting"`, `"discovering"`, and `"connect timeout"` (or any transient error state not matching those two strings) leave `connectedDeviceGeneration` stale from the previous connection. If a user connects device A (Gen 4), then it drops and reconnects as device B (Gen 5), the UI would briefly show the stale "Gen 4" label during the reconnection window.

**Recommendation:** Clear on any non-ready state, or keep track of the previous generation and only update when it changes:
```swift
if state == "ready" {
  connectedDeviceGeneration = ble.discoveredDevices
    .first(where: { $0.id == ble.activeDeviceIdentifier })?.generation
} else if state != "ready" {
  // Clear on all non-ready states to avoid stale label
  connectedDeviceGeneration = nil
}
```

---

### WR-03 — `generation(from:)` trusts CBUUID uppercased output without normalization note

**File:** `GooseSwift/GooseBLEClient+Parsing.swift` — lines 337–344  
**Severity:** Warning  
**Category:** Correctness / defensive programming

```swift
let lower = uuid.uuidString.lowercased()
if lower.hasPrefix("61080001") { return "4.0" }
if lower.hasPrefix("fd4b0001") { return "5.0" }
```

`CBUUID.uuidString` always returns uppercase on iOS (by CoreBluetooth contract), so `lowercased()` is functionally redundant here. This is not a bug — the code is correct — but the `WearableDescriptor` static instances store lowercase prefixes (`"61080001"`, `"fd4b0001"`), and `isCommandCharacteristic` also uses `.lowercased()`. The convention is consistent but the `lowercased()` in `generation(from:)` could be removed for clarity since the source is always uppercase, or a comment should explain the defensive intent. Minor inconsistency: `WearableDescriptor.commandCharacteristicPrefix` stores lowercase and is compared against `lowercased()` output; `generation(from:)` follows the same pattern — so this is consistent but could be documented.

**Recommendation:** Add a comment: `// CBUUID.uuidString is always uppercase; lowercased() is defensive` or remove the call if consistency with WearableDescriptor prefix storage isn't intended.

---

### INFO-01 — `GooseDiscoveredDevice.generation` has no explicit "unknown" sentinel type

**File:** `GooseSwift/GooseBLETypes.swift` — line 47  
**Severity:** Info  
**Category:** Type safety / API design

`generation: String` uses `"unknown"` as a sentinel. Multiple call sites check `generation == "unknown"` as a condition. Consider a typed enum:
```swift
enum WearableGeneration: String {
  case gen4 = "4.0"
  case gen5 = "5.0"
  case unknown
}
```
This would make exhaustive switching possible in future UI changes and eliminate string comparison errors. Not a blocking issue for this phase.

---

### INFO-02 — Rust `bridge_tests.rs` Gen4 tests use `GET_HELLO_FRAME` which is a Gen5/GOOSE frame

**File:** `Rust/core/tests/bridge_tests.rs` — lines 408–487  
**Severity:** Info  
**Category:** Test quality

The Gen4 bridge tests use `GET_HELLO_FRAME = "aa0108000001e67123019101363e5c8d"` which is a GOOSE (Gen5) format frame. When passed to `protocol.parse_frame_hex` with `device_type: "GEN4"`, the frame may parse differently or fail with a protocol error. The tests correctly assert that the error is NOT `"unsupported device_type"`, which is the bug being tested. However, a dedicated Gen4 frame hex constant would make the test intent clearer and avoid potential false confidence. The `capture.import_frame_batch` test (`bridge_gen4_upload_device_generation_field_is_set_correctly`) correctly inserts the raw frame regardless of parse success, so that test is valid for its purpose.

---

## Files with No Issues

- `GooseSwift/GooseBLEClient.swift` — `activeDescriptor` property addition, canSync* property updates: clean
- `GooseSwift/GooseBLEClient+CentralDelegate.swift` — `generation:` parameter addition, `activeDescriptor = nil` on disconnect: clean
- `GooseSwift/GooseBLEClient+HistoricalCommands.swift` — rename only: clean
- `GooseSwift/GooseBLEClient+UserActions.swift` — rename only: clean
- `GooseSwift/DeviceView.swift` — generation label, `generationMajorVersion` helper: clean
- `GooseSwift/ConnectionView.swift` — generation label: clean
- `GooseSwift/OnboardingStepViews.swift` — generation in scan row, 4.0 body copy: clean
- `GooseSwift/OnboardingModels.swift` — connect title update: clean
- `GooseSwiftTests/WearableDescriptorTests.swift` — 8 tests, correct assertions: clean
- `GooseSwiftTests/GooseBLETypesTests.swift` — 7 tests, correct assertions: clean
- `Rust/core/src/bridge.rs` — `"GEN4"` alias addition: clean

## Verdict

**3 warnings, 0 critical.** WR-01 and WR-02 are state management concerns worth fixing before a production release or upstream PR submission. WR-03 and both info items are minor quality notes. The core Gen4 unblocking logic (WearableDescriptor, GEN4 alias fix, generation field) is correct.
