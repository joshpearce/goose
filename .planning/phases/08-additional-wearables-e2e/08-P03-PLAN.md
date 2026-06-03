---
phase: "08"
plan: "08-P03"
title: "Upload Fix: Remove Silent Gen5 Fallback + Handle HR_MONITOR Device Type"
wave: 2
depends_on: ["08-P02"]
files_modified:
  - GooseSwift/GooseUploadService.swift
  - GooseSwift/GooseAppModel+Upload.swift
autonomous: true
requirements:
  - WEAR-03
---

<objective>
Addresses D-04 (reuse existing WHOOP frames table, no migration) and WEAR-03.
Fix `GooseUploadService` to remove the silent WHOOP Gen5 fallback (`"5.0"`) that incorrectly
labels HR monitor upload data as Gen5. After this plan, the upload payload correctly identifies
HR monitor data using the sanitized BLE-advertised device name (e.g., `"Polar H10"`) as the
`device_type` field, and all non-WHOOP device types are handled without silently defaulting to
`"5.0"`. `triggerManualUpload()` in `GooseAppModel+Upload.swift` is also updated to pass the
correct device type for the currently connected device.
</objective>

<must_haves>
  <truths>
    - D-04: HR monitor frames reuse the existing WHOOP frames/raw_evidence table — no new table migration is created in this phase; `parse_device_type("HR_MONITOR")` maps to `DeviceType::Goose` for storage compatibility
    - WEAR-03: `GooseUploadService.performUpload` does NOT contain the expression `deviceType == "GEN4" ? "4.0" : "5.0"` — the silent Gen5 fallback is removed
    - The upload payload for HR monitor data contains a `device_type` key (or `device_generation` key) with the sanitized BLE device name (e.g., `"Polar H10"`, `"Garmin HRM"`, `"unknown_hr_monitor"`)
    - WHOOP Gen5 upload still works: `deviceType == "GOOSE"` produces `device_generation: "5.0"` in the payload
    - WHOOP Gen4 upload still works: `deviceType == "GEN4"` produces `device_generation: "4.0"` in the payload
    - `triggerManualUpload()` no longer hardcodes `deviceType: "GOOSE"` — it derives the correct device type from the active connection
  </truths>
</must_haves>

<threat_model>
  <threats>
    <threat id="T-08-04" severity="low">
      BLE-advertised device names could be unexpectedly long or contain special characters that cause JSON serialization issues. Mitigation: device name sanitization (trim + max 64 chars + empty fallback) is applied in `GooseBLEHRMonitorManager` (Plan 2) before the name is used as `deviceType`; the upload service does not re-sanitize but relies on the pre-sanitized value from the BLE layer.
    </threat>
    <threat id="T-08-05" severity="low">
      Changing the upload payload structure for WHOOP devices could break the server ingest endpoint. Mitigation: WHOOP payload structure is unchanged — `device_generation: "4.0"` and `device_generation: "5.0"` continue to be sent as before. Only HR monitor payloads use a different field (`device_type` with the device name string).
    </threat>
  </threats>
</threat_model>

<tasks>

  <task id="P03-T01" type="execute">
    <title>Fix GooseUploadService.performUpload to remove silent Gen5 fallback</title>
    <read_first>
      - GooseSwift/GooseUploadService.swift (full file — focus on lines 86–94: the `deviceGeneration` mapping and payload construction)
      - .planning/phases/08-additional-wearables-e2e/08-CONTEXT.md (D-06: device_type = BLE-advertised device name, sanitized; D-05: server receives as-is)
      - .planning/phases/08-additional-wearables-e2e/08-RESEARCH.md (F-04: the exact silent fallback code that must be replaced; F-10: upload trigger context)
      - .planning/requirements.md — WEAR-03: upload must identify HR monitor data with a distinct device_type
    </read_first>
    <action>
      In `GooseSwift/GooseUploadService.swift`, in the `performUpload` function, replace lines:

      ```swift
      let deviceGeneration = deviceType == "GEN4" ? "4.0" : "5.0"
      let payload: [String: Any] = [
          "device": ["id": deviceID.uuidString, "mac": NSNull(), "name": NSNull()],
          "streams": [...],
          "device_generation": deviceGeneration,
      ]
      ```

      with:

      ```swift
      // WHOOP devices: use device_generation field for compatibility with server schema
      // HR monitors and future devices: use device_type field with the device's actual identifier
      let payload: [String: Any]
      switch deviceType {
      case "GEN4":
          payload = [
              "device": ["id": deviceID.uuidString, "mac": NSNull(), "name": NSNull()],
              "streams": [
                  "hr": hr, "rr": rr, "events": events, "battery": battery,
                  "spo2": spo2, "skin_temp": skinTemp, "resp": resp, "gravity": gravity,
              ],
              "device_generation": "4.0",
          ]
      case "GOOSE":
          payload = [
              "device": ["id": deviceID.uuidString, "mac": NSNull(), "name": NSNull()],
              "streams": [
                  "hr": hr, "rr": rr, "events": events, "battery": battery,
                  "spo2": spo2, "skin_temp": skinTemp, "resp": resp, "gravity": gravity,
              ],
              "device_generation": "5.0",
          ]
      default:
          // HR monitor or future device: use device_type with the actual device identifier
          // deviceType for HR monitors = sanitized BLE-advertised device name (e.g., "Polar H10")
          payload = [
              "device": ["id": deviceID.uuidString, "mac": NSNull(), "name": NSNull()],
              "streams": [
                  "hr": hr, "rr": rr, "events": events, "battery": battery,
                  "spo2": spo2, "skin_temp": skinTemp, "resp": resp, "gravity": gravity,
              ],
              "device_type": deviceType,
          ]
      }
      ```

      Note: The `streams` dictionary content is identical — copy it exactly from the original
      to avoid introducing any structural changes to the WHOOP payload paths.
    </action>
    <acceptance_criteria>
      - `GooseUploadService.swift` does NOT contain the string `"GEN4" ? "4.0" : "5.0"` (the ternary fallback is removed)
      - `GooseUploadService.swift` contains a `switch deviceType` (or equivalent) with explicit cases for `"GEN4"` and `"GOOSE"`
      - `GooseUploadService.swift` contains a `default` case that uses `"device_type": deviceType` for non-WHOOP devices
      - The `streams` dictionary structure is identical to the original for WHOOP cases
      - Swift build succeeds with no compile errors
    </acceptance_criteria>
  </task>

  <task id="P03-T02" type="execute">
    <title>Fix triggerManualUpload in GooseAppModel+Upload.swift to use correct device type</title>
    <read_first>
      - GooseSwift/GooseAppModel+Upload.swift (full file — triggerManualUpload hardcodes "GOOSE")
      - GooseSwift/GooseAppModel.swift (lines 1–100 — check for hrMonitorManager property or connected HR state)
      - GooseSwift/GooseBLEClient+HRMonitor.swift (GooseBLEHRMonitorManager hrConnectionState property — verify it's accessible)
      - .planning/phases/08-additional-wearables-e2e/08-RESEARCH.md (F-10: manual upload trigger context)
    </read_first>
    <action>
      In `GooseSwift/GooseAppModel+Upload.swift`, update `triggerManualUpload()`:

      Current:
      ```swift
      func triggerManualUpload() {
          let deviceID = ble.activeDeviceIdentifier ?? UUID()
          let sinceTimestamp = lastUploadAt ?? Date().addingTimeInterval(-24 * 3600)
          uploadService.upload(
              deviceID: deviceID,
              deviceType: "GOOSE",
              sinceTimestamp: sinceTimestamp
          )
      }
      ```

      Updated:
      ```swift
      func triggerManualUpload() {
          let sinceTimestamp = lastUploadAt ?? Date().addingTimeInterval(-24 * 3600)
          // Upload WHOOP data if a WHOOP device is active
          if let deviceID = ble.activeDeviceIdentifier {
              let whoopDeviceType = ble.activeDescriptor?.commandCharacteristicPrefix.hasPrefix("610800") == true ? "GEN4" : "GOOSE"
              uploadService.upload(deviceID: deviceID, deviceType: whoopDeviceType, sinceTimestamp: sinceTimestamp)
          }
          // Upload HR monitor data if an HR monitor is connected
          let hrManager = ble.hrMonitorManager
          if let hrPeripheral = hrManager.hrPeripheral, hrManager.hrConnectionState != "disconnected" {
              let deviceName = hrManager.connectedDeviceName ?? "unknown_hr_monitor"
              uploadService.upload(deviceID: hrPeripheral.identifier, deviceType: deviceName, sinceTimestamp: sinceTimestamp)
          }
      }
      ```

      This requires `GooseBLEHRMonitorManager` to expose `var hrPeripheral: CBPeripheral?`,
      `var hrConnectionState: String`, and `var connectedDeviceName: String?` as accessible
      (non-private) properties. Verify these exist in `GooseBLEClient+HRMonitor.swift` from Plan 2,
      or update their access level from `private` to `internal` as needed.

      Also add `var activeDescriptor: WearableDescriptor?` to `GooseBLEClient` if it doesn't exist.
      Check `GooseBLEClient.swift` and `GooseBLEClient+Commands.swift` for an existing
      `activeDescriptor` property — if it already exists from Phase 6 (GEN4-01 fix), use it
      directly. If it doesn't, derive the device type from `ble.activeDeviceIdentifier` and
      the `ble.firmwareVersion` or `generation` field on `ble.discoveredDevices`.

      Simpler alternative if `activeDescriptor` is not available: use the `generation` field
      from the remembered device. In `GooseBLEClient`, `rememberedGeneration` or the discovered
      device `generation` field ("4.0" → GEN4, "5.0" → GOOSE) set during Phase 6. Use:
      ```swift
      let whoopDeviceType = (ble.discoveredDevices.first?.generation == "4.0") ? "GEN4" : "GOOSE"
      ```
    </action>
    <acceptance_criteria>
      - `GooseAppModel+Upload.swift` `triggerManualUpload()` does NOT hardcode `deviceType: "GOOSE"` as a string literal
      - `triggerManualUpload()` derives device type dynamically (from `generation`, `activeDescriptor`, or equivalent)
      - HR monitor upload is triggered if `hrMonitorManager.hrConnectionState != "disconnected"`
      - Swift build succeeds with no compile errors
    </acceptance_criteria>
  </task>

  <task id="P03-T03" type="execute">
    <title>Add Rust bridge tests verifying HR_MONITOR upload path does not silently use GOOSE device_type</title>
    <read_first>
      - Rust/core/tests/bridge_tests.rs (existing bridge test file from Phase 6 — test structure)
      - Rust/core/src/bridge.rs (lines 7956–7966: parse_device_type — currently rejects "HR_MONITOR")
      - .planning/phases/08-additional-wearables-e2e/08-RESEARCH.md (F-03 and F-08: bridge must accept or gracefully handle HR_MONITOR)
    </read_first>
    <action>
      In `Rust/core/src/bridge.rs`, extend `parse_device_type` to accept `"HR_MONITOR"` as a valid
      alias. Since `DeviceType` enum in `protocol.rs` does not have an `HrMonitor` variant, map
      `"HR_MONITOR"` to `DeviceType::Goose` for now (HR monitor frames stored as raw bytes pass
      through the existing pipeline without WHOOP-specific CRC parsing — the content is ignored,
      only stored as raw evidence). Add a TODO comment explaining the mapping.

      ```rust
      fn parse_device_type(value: &str) -> GooseResult<DeviceType> {
          match value {
              "GEN4" | "GEN_4" | "Gen4" | "gen4" => Ok(DeviceType::Gen4),
              "MAVERICK" | "Maverick" | "maverick" => Ok(DeviceType::Maverick),
              "PUFFIN" | "Puffin" | "puffin" => Ok(DeviceType::Puffin),
              "GOOSE" | "Goose" | "goose" => Ok(DeviceType::Goose),
              // HR_MONITOR: standard GATT measurement bytes, not WHOOP proprietary frames.
              // Stored as raw evidence under Goose device type; CRC validation is skipped at import.
              "HR_MONITOR" | "hr_monitor" => Ok(DeviceType::Goose),
              other => Err(GooseError::message(format!(
                  "unsupported device_type: {other}"
              ))),
          }
      }
      ```

      In `Rust/core/tests/bridge_tests.rs`, add a test:
      ```rust
      #[test]
      fn bridge_accepts_hr_monitor_device_type_string() {
          // Verify that passing device_type: "HR_MONITOR" in a frame import request
          // does not return an error about unsupported device_type.
          // (HR_MONITOR maps to Goose DeviceType for storage purposes)
          let result = /* call bridge with method: "capture.import_frame", args: { device_type: "HR_MONITOR", frame_hex: "...", database_path: tempdir } */;
          // assert no "unsupported device_type" error
      }
      ```

      If writing a full bridge round-trip test is complex, at minimum add a unit test for
      `parse_device_type` directly (as a module-level test in `bridge.rs`):
      ```rust
      #[cfg(test)]
      mod tests {
          use super::*;
          #[test]
          fn parse_device_type_accepts_hr_monitor() {
              assert!(parse_device_type("HR_MONITOR").is_ok());
              assert!(parse_device_type("hr_monitor").is_ok());
          }
      }
      ```
    </action>
    <acceptance_criteria>
      - `Rust/core/src/bridge.rs` `parse_device_type` function accepts `"HR_MONITOR"` and `"hr_monitor"` without returning an error
      - Either `bridge_tests.rs` or a `#[cfg(test)]` block in `bridge.rs` contains a test asserting `parse_device_type("HR_MONITOR").is_ok()`
      - `cargo test` passes with no regressions
    </acceptance_criteria>
  </task>

  <task id="P03-T04" type="execute">
    <title>Verify full test suite passes and source assertion checks are satisfied</title>
    <read_first>
      - GooseSwift/GooseUploadService.swift (current state after T01 — verify fallback is gone)
      - GooseSwift/GooseAppModel+Upload.swift (current state after T02)
      - Rust/core/src/bridge.rs (current state after T03)
    </read_first>
    <action>
      Run the full Rust test suite and perform source assertions:

      1. `grep -n "\"GEN4\" ? \"4.0\" : \"5.0\"" GooseSwift/GooseUploadService.swift` — must return no matches (fallback removed)
      2. `grep -n "device_type.*deviceType" GooseSwift/GooseUploadService.swift` — must show the `default:` case using `device_type`
      3. `grep -n "HR_MONITOR" Rust/core/src/bridge.rs` — must show the new match arm
      4. `cd Rust/core && cargo test 2>&1 | tail -10` — must exit 0

      Fix any compile errors found. Do not break existing passing tests.
    </action>
    <acceptance_criteria>
      - `GooseUploadService.swift` source does not contain the ternary `"GEN4" ? "4.0" : "5.0"` fallback
      - `bridge.rs` `parse_device_type` returns `Ok(...)` for `"HR_MONITOR"`
      - `cargo test` passes
      - Swift build succeeds (no compile errors)
    </acceptance_criteria>
  </task>

</tasks>

<verification>
  1. `grep "\"GEN4\" ? \"4.0\" : \"5.0\"" GooseSwift/GooseUploadService.swift` — zero matches (fallback gone)
  2. `grep "device_type.*deviceType\|device_type.*Polar\|default:" GooseSwift/GooseUploadService.swift` — shows HR monitor branch
  3. `grep "HR_MONITOR" Rust/core/src/bridge.rs` — present in parse_device_type
  4. `cd Rust/core && cargo test 2>&1 | grep -E "FAILED|test result"` — test result: ok
  5. `grep "GOOSE" GooseSwift/GooseAppModel+Upload.swift | grep triggerManualUpload` — hardcoded "GOOSE" string gone
</verification>

<success_criteria>
  - [ ] Silent WHOOP Gen5 fallback removed from `GooseUploadService.performUpload`
  - [ ] HR monitor upload uses sanitized device name as `device_type` in payload
  - [ ] WHOOP Gen4 and Gen5 upload payloads are structurally unchanged
  - [ ] `triggerManualUpload()` no longer hardcodes `deviceType: "GOOSE"`
  - [ ] `parse_device_type` in bridge.rs accepts `"HR_MONITOR"` without error
  - [ ] `cargo test` passes
  - [ ] WEAR-03 requirement is fully satisfied
</success_criteria>
