---
phase: "08"
plan: "08-P02"
title: "iOS BLE HR Monitor Extension + WearableDescriptor.genericHRMonitor + Notification Routing"
wave: 1
depends_on: []
files_modified:
  - GooseSwift/GooseBLETypes.swift
  - GooseSwift/GooseBLEClient+HRMonitor.swift
  - GooseSwift/GooseAppModel+NotificationPipeline.swift
autonomous: true
requirements:
  - WEAR-02
---

<objective>
Implement the iOS BLE layer for standard HR monitors (0x180D Heart Rate Service):
(1) Add `WearableDescriptor.genericHRMonitor` static instance to `GooseBLETypes.swift`.
(2) Extend `GooseNotificationEvent.rustDeviceType` to return `"HR_MONITOR"` for 0x2A37 characteristics.
(3) Create `GooseBLEClient+HRMonitor.swift` — a new extension file with a dedicated second
`CBCentralManager` for scanning 0x180D devices (separate from WHOOP scan), manual connect, and
characteristic subscription on 0x2A37.
(4) Fix `GooseBLEClient+PeripheralDelegate.swift` (or `GooseAppModel+NotificationPipeline.swift`)
so 0x2A37 notifications are routed through `onNotification?` callback — enabling storage via the
existing capture pipeline.
</objective>

<must_haves>
  <truths>
    - WEAR-02: `GooseBLEClient+HRMonitor.swift` exists with `startHRMonitorScan()` and `stopHRMonitorScan()` methods that scan for `CBUUID("180D")`
    - `GooseNotificationEvent.rustDeviceType` returns `"HR_MONITOR"` when `characteristicUUID.uppercased() == "2A37"`
    - `WearableDescriptor.genericHRMonitor` static instance exists in `GooseBLETypes.swift` with `serviceUUIDPrefix: "180d"` and `commandCharacteristicPrefix: ""`
    - 0x2A37 notifications from connected HR monitor devices are delivered to `onNotification?` callback (enabling GooseAppModel.handleNotification and the capture pipeline)
    - WHOOP scan state, `activePeripheral`, and `connectionState` are NOT modified by HR monitor scanning or connection
    - HR monitor scan uses a separate `CBCentralManager` instance — the WHOOP central is not repurposed
    - HR monitor connection is manual only — no auto-connect logic
  </truths>
</must_haves>

<threat_model>
  <threats>
    <threat id="T-08-02" severity="medium">
      HR monitor scan could discover and accidentally connect to other non-HR BLE devices if the scan filter is too broad. Mitigation: HR monitor central scans exclusively for `[CBUUID("180D")]`; only peripherals advertising exactly this service UUID are shown in the HR monitor device list.
    </threat>
    <threat id="T-08-03" severity="low">
      Malformed BLE device names used as device_type in upload could contain PII or excessively long strings. Mitigation: device name sanitization (trim whitespace, cap to 64 chars, fallback to "unknown_hr_monitor") is applied before passing to the capture pipeline.
    </threat>
  </threats>
</threat_model>

<tasks>

  <task id="P02-T01" type="execute">
    <title>Add WearableDescriptor.genericHRMonitor and extend rustDeviceType in GooseBLETypes.swift</title>
    <read_first>
      - GooseSwift/GooseBLETypes.swift (full file — current WearableDescriptor struct and extension, GooseNotificationEvent.rustDeviceType computed property)
      - .planning/phases/08-additional-wearables-e2e/08-CONTEXT.md (D-07: WearableDescriptor.genericHRMonitor pattern; D-09: rustDeviceType = "HR_MONITOR")
      - .planning/phases/08-additional-wearables-e2e/08-PATTERNS.md (Pattern: WearableDescriptor Static Instance; Pattern: rustDeviceType computed property extension)
      - .planning/phases/06-whoop-gen4-ios-support/06-P03-SUMMARY.md (confirms isCommandUUID was added to WearableDescriptor — check if present)
    </read_first>
    <action>
      In `GooseSwift/GooseBLETypes.swift`, make two changes:

      1. In `extension WearableDescriptor`, add after the existing `.whoopGen4` static instance:
         ```swift
         // Standard Bluetooth Heart Rate Service (0x180D), HR Measurement characteristic (0x2A37)
         // HR monitors are read-only notify devices — no command characteristic
         static let genericHRMonitor = WearableDescriptor(
           serviceUUIDPrefix: "180d",
           commandCharacteristicPrefix: ""
         )
         ```

      2. In `GooseNotificationEvent`, update the `rustDeviceType` computed property from:
         ```swift
         var rustDeviceType: String {
           characteristicUUID.lowercased().hasPrefix("610800") ? "GEN4" : "GOOSE"
         }
         ```
         to:
         ```swift
         var rustDeviceType: String {
           if characteristicUUID.lowercased().hasPrefix("610800") { return "GEN4" }
           if characteristicUUID.uppercased() == "2A37" { return "HR_MONITOR" }
           return "GOOSE"
         }
         ```
    </action>
    <acceptance_criteria>
      - `GooseBLETypes.swift` contains `static let genericHRMonitor = WearableDescriptor(serviceUUIDPrefix: "180d", commandCharacteristicPrefix: "")`
      - `GooseNotificationEvent.rustDeviceType` computed property contains the `"HR_MONITOR"` branch for `"2A37"` UUID
      - `GooseNotificationEvent.rustDeviceType` still returns `"GEN4"` for `610800`-prefixed UUIDs
      - `GooseNotificationEvent.rustDeviceType` still returns `"GOOSE"` for all other characteristic UUIDs
      - Swift build succeeds (no compile errors introduced)
    </acceptance_criteria>
  </task>

  <task id="P02-T02" type="execute">
    <title>Create GooseBLEClient+HRMonitor.swift with dedicated scan/connect/notify for 0x180D</title>
    <read_first>
      - GooseSwift/GooseBLEClient+UserActions.swift (startScan/stopScan patterns — lines 13–145)
      - GooseSwift/GooseBLEClient.swift (lines 1–120 for class properties; lines 367–420 for UUID constants; standardHeartRateServiceID, standardHeartRateMeasurementID)
      - GooseSwift/GooseBLEClient+CentralDelegate.swift (CBCentralManagerDelegate pattern for scanning and connecting)
      - GooseSwift/GooseBLEClient+PeripheralDelegate.swift (CBPeripheralDelegate — how notifications are subscribed and received)
      - .planning/phases/08-additional-wearables-e2e/08-CONTEXT.md (D-07: separate scan mode; D-08: manual-only connection; D-09: notification routing)
      - .planning/phases/08-additional-wearables-e2e/08-RESEARCH.md (F-05: separate CBCentralManager; F-09: connection state separation)
      - .planning/phases/08-additional-wearables-e2e/08-PATTERNS.md (Pattern: BLE Extension File)
    </read_first>
    <action>
      Create `GooseSwift/GooseBLEClient+HRMonitor.swift` with the following structure:

      File header: `import CoreBluetooth`, `import Foundation`, `import OSLog`, blank line, `extension GooseBLEClient`.

      The extension manages a dedicated second `CBCentralManager` for HR monitor scanning, storing state in stored properties via an associated object pattern OR by declaring them in a companion struct. Since Swift extensions cannot add stored properties to a class, declare a private `HRMonitorState` nested class instance stored as an associated object OR use the approach of adding private computed vars backed by `objc_getAssociatedObject`. The simplest approach: add a private lazily-initialized `GooseBLEHRMonitorManager` helper class that conforms to `CBCentralManagerDelegate` and `CBPeripheralDelegate`, owned as a lazy property on the extension.

      **Recommended implementation approach:** Create a nested helper class `GooseBLEHRMonitorManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate` within the extension or as a separate file-level class in the same file. This class:
      - Holds `var central: CBCentralManager?`
      - Holds `var discoveredHRDevices: [GooseDiscoveredDevice] = []`
      - Holds `var hrPeripheral: CBPeripheral?`
      - Holds `var hrConnectionState: String = "disconnected"`
      - Has `weak var owner: GooseBLEClient?` back-reference for calling `onNotification` and `record`

      In the `GooseBLEClient+HRMonitor.swift` extension on `GooseBLEClient`:
      - `private(set) var hrMonitorManager: GooseBLEHRMonitorManager { get/set via objc_associated_object }`

      **Simpler alternative (preferred):** Add `GooseBLEHRMonitorManager` as a non-extension class in the same file. In `GooseBLEClient.swift` (or via a stored property added in an `@objc` bridging pattern), store the manager instance.

      **Practical decision:** Since adding stored properties to extensions is not supported in Swift, use a file-level `final class GooseBLEHRMonitorManager` that lives in `GooseBLEClient+HRMonitor.swift`. Add to `GooseBLEClient.swift` a single stored property: `let hrMonitorManager = GooseBLEHRMonitorManager()`. The `GooseBLEClient+HRMonitor.swift` extension then exposes `startHRMonitorScan()`, `stopHRMonitorScan()`, and `connectHRMonitor(_ device: GooseDiscoveredDevice)` as public methods that delegate to `hrMonitorManager`.

      **GooseBLEHRMonitorManager must:**
      1. `func start(queue: DispatchQueue)` — initializes `CBCentralManager(delegate: self, queue: queue, options: [CBCentralManagerOptionRestoreIdentifierKey: "com.goose.swift.hr-monitor"])`
      2. `func startScan()` — calls `central.scanForPeripherals(withServices: [CBUUID(string: "180D")], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])`
      3. `func stopScan()` — calls `central.stopScan()`
      4. In `centralManager(_:didDiscover:advertisementData:rssi:)`:
         - Extract device name: sanitized `(peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "unknown_hr_monitor").trimmingCharacters(in: .whitespacesAndNewlines).prefix(64).description`
         - Replace empty name with `"unknown_hr_monitor"`
         - Add `GooseDiscoveredDevice(id: peripheral.identifier, name: sanitizedName, rssi: RSSI.intValue, generation: "hr_monitor")` to `discoveredHRDevices`, sort by RSSI descending
         - Dispatch update to owner on main thread: `DispatchQueue.main.async { self.owner?.discoveredHRDevices = ... }` — OR publish via a separate `@Published` on a helper `ObservableObject`. For simplicity: use `DispatchQueue.main.async { self.owner?.objectWillChange.send() }`
      5. `func connect(_ device: GooseDiscoveredDevice)` — finds peripheral by device.id, calls `central.connect(peripheral, options: nil)`
      6. In `centralManager(_:didConnect:)`:
         - Discover services: `peripheral.delegate = self; peripheral.discoverServices([CBUUID(string: "180D")])`
         - Update `hrConnectionState = "connected"`
      7. In `peripheral(_:didDiscoverServices:)`:
         - For each service with UUID `180D`, discover characteristics: `peripheral.discoverCharacteristics([CBUUID(string: "2A37")], for: service)`
      8. In `peripheral(_:didDiscoverCharacteristicsFor:)`:
         - For characteristic with UUID `2A37`, call `peripheral.setNotifyValue(true, for: characteristic)`
      9. In `peripheral(_:didUpdateValueFor:error:)` for 0x2A37:
         - Build `GooseNotificationEvent(deviceID: peripheral.identifier, serviceUUID: "180D", characteristicUUID: "2A37", value: characteristic.value ?? Data(), capturedAt: Date())`
         - Call `owner?.onNotification?(event)` to route into GooseAppModel.handleNotification and the capture pipeline
         - Also call `owner?.handleStandardHeartRate(characteristic.value ?? Data(), characteristic: characteristic, capturedAt: Date())` for live HR display
      10. In `centralManager(_:didDisconnectPeripheral:error:)`:
          - Update `hrConnectionState = "disconnected"`
          - Set `hrPeripheral = nil`

      **GooseBLEClient+HRMonitor.swift extension methods:**
      ```swift
      func startHRMonitorScan() {
          hrMonitorManager.owner = self
          hrMonitorManager.start(queue: coreBluetoothQueue)
          hrMonitorManager.startScan()
          record(source: "ble.hr_monitor", title: "scan.start")
      }
      func stopHRMonitorScan() {
          hrMonitorManager.stopScan()
          record(source: "ble.hr_monitor", title: "scan.stop")
      }
      func connectHRMonitor(_ device: GooseDiscoveredDevice) {
          hrMonitorManager.connect(device)
          record(source: "ble.hr_monitor", title: "connect.requested", body: device.name)
      }
      ```

      **In `GooseBLEClient.swift`:** add stored property `let hrMonitorManager = GooseBLEHRMonitorManager()` (alongside existing `let bleUIStateAggregator...`).
    </action>
    <acceptance_criteria>
      - `GooseSwift/GooseBLEClient+HRMonitor.swift` exists
      - File contains `final class GooseBLEHRMonitorManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate`
      - File contains `extension GooseBLEClient` with `startHRMonitorScan()`, `stopHRMonitorScan()`, `connectHRMonitor(_:)` methods
      - `startHRMonitorScan()` scans for `CBUUID(string: "180D")` — not `whoopServices`
      - 0x2A37 characteristic updates call `owner?.onNotification?(event)` where event has `characteristicUUID: "2A37"`
      - `GooseBLEClient.swift` has `let hrMonitorManager = GooseBLEHRMonitorManager()` stored property
      - Swift build succeeds with no compile errors
    </acceptance_criteria>
  </task>

  <task id="P02-T03" type="execute">
    <title>Fix GooseAppModel+NotificationPipeline.swift to handle "HR_MONITOR" rustDeviceType in gooseFrames reassembly</title>
    <read_first>
      - GooseSwift/GooseAppModel+NotificationPipeline.swift (lines 783–844: gooseFrames implementation; critical: the 0xaa frame-start search logic)
      - GooseSwift/GooseAppModel+NotificationPipeline.swift (lines 704–714: notificationIngestResult — calls gooseFrames)
      - .planning/phases/08-additional-wearables-e2e/08-RESEARCH.md (F-03: HR GATT bytes are NOT 0xaa-delimited WHOOP frames; standard GATT bytes will be dropped)
      - .planning/phases/08-additional-wearables-e2e/08-CONTEXT.md (D-09: HR monitor notifications routed via rustDeviceType = "HR_MONITOR")
    </read_first>
    <action>
      The `gooseFrames(in:event:)` function in `GooseAppModel+NotificationPipeline.swift` searches
      for `0xaa` start bytes in the raw BLE notification data. For WHOOP devices this is correct.
      For standard 0x2A37 HR notifications, the raw bytes will never contain `0xaa` as a frame
      start — the bytes are a GATT measurement payload, not a WHOOP proprietary frame.

      Fix: In `notificationIngestResult(for:)`, add an early-return path for HR_MONITOR that wraps
      the raw 0x2A37 bytes directly as a single "frame" without WHOOP frame reassembly:

      ```swift
      nonisolated func notificationIngestResult(for event: GooseNotificationEvent) -> NotificationIngestResult {
          // HR monitor: raw 0x2A37 bytes are standard GATT measurements, not WHOOP frames.
          // Treat the entire notification value as a single frame hex string for storage.
          if event.rustDeviceType == "HR_MONITOR" {
              let frameHex = event.value.hexString
              guard !frameHex.isEmpty else {
                  return NotificationIngestResult(event: event, frames: [], bufferedBytes: 0, expectedBytes: nil, droppedBytes: 0, usedBufferedData: false)
              }
              return NotificationIngestResult(
                  event: event,
                  frames: [NotificationFrame(hex: frameHex)],
                  bufferedBytes: 0,
                  expectedBytes: nil,
                  droppedBytes: 0,
                  usedBufferedData: false
              )
          }
          let reassembly = gooseFrames(in: event.value, event: event)
          return NotificationIngestResult(
              event: event,
              frames: reassembly.frames.map { NotificationFrame(hex: $0.hexString) },
              bufferedBytes: reassembly.bufferedBytes,
              expectedBytes: reassembly.expectedBytes,
              droppedBytes: reassembly.droppedBytes,
              usedBufferedData: reassembly.usedBufferedData
          )
      }
      ```

      This ensures HR monitor raw bytes pass through as a storable frame without being discarded
      by the WHOOP `0xaa` reassembly logic.
    </action>
    <acceptance_criteria>
      - `GooseAppModel+NotificationPipeline.swift` `notificationIngestResult(for:)` contains an `if event.rustDeviceType == "HR_MONITOR"` early-return branch
      - The HR_MONITOR branch returns a `NotificationIngestResult` with exactly one `NotificationFrame` containing the hex of the raw 0x2A37 bytes
      - The WHOOP path (non-HR_MONITOR) is unchanged
      - Swift build succeeds with no compile errors
    </acceptance_criteria>
  </task>

  <task id="P02-T04" type="execute">
    <title>Add Swift unit tests for WearableDescriptor.genericHRMonitor and rustDeviceType extension</title>
    <read_first>
      - GooseSwiftTests/GooseBLETypesTests.swift (existing test file for rustDeviceType and WearableDescriptor — from Phase 6 P03)
      - GooseSwift/GooseBLETypes.swift (current state after T01 — genericHRMonitor and HR_MONITOR rustDeviceType)
      - .planning/phases/06-whoop-gen4-ios-support/06-P03-SUMMARY.md (GooseSwiftTests target setup — bundle ID, TEST_HOST)
    </read_first>
    <action>
      In `GooseSwiftTests/GooseBLETypesTests.swift`, add test methods to the existing test class:

      1. `func test_genericHRMonitor_serviceUUIDPrefix()` — assert `WearableDescriptor.genericHRMonitor.serviceUUIDPrefix == "180d"`
      2. `func test_genericHRMonitor_commandCharacteristicPrefix_empty()` — assert `WearableDescriptor.genericHRMonitor.commandCharacteristicPrefix == ""`
      3. `func test_genericHRMonitor_isCommandCharacteristic_returnsFalseForAll()` — create a mock characteristic with any UUID and verify `genericHRMonitor.isCommandCharacteristic` returns false (since prefix is empty, `hasPrefix("")` is true — wait: `"".hasPrefix("")` is `true`! This is a bug risk.) Fix: in `WearableDescriptor.isCommandCharacteristic`, add guard: `guard !commandCharacteristicPrefix.isEmpty else { return false }`. Update `GooseBLETypes.swift` accordingly.
      4. `func test_rustDeviceType_2A37_returnsHRMonitor()` — create `GooseNotificationEvent` with `characteristicUUID: "2A37"` (uppercase), assert `rustDeviceType == "HR_MONITOR"`
      5. `func test_rustDeviceType_2a37_lowercase_returnsHRMonitor()` — create event with `characteristicUUID: "2a37"`, assert `rustDeviceType == "HR_MONITOR"`
      6. `func test_rustDeviceType_610800_stillReturnsGEN4()` — create event with `characteristicUUID: "61080003-..."`, assert `rustDeviceType == "GEN4"`
      7. `func test_rustDeviceType_fd4b_stillReturnsGOOSE()` — create event with `characteristicUUID: "fd4b0003-..."`, assert `rustDeviceType == "GOOSE"`

      For test 3: also update `GooseBLETypes.swift` `isCommandCharacteristic` to add the guard for empty prefix:
      ```swift
      func isCommandCharacteristic(_ c: CBCharacteristic) -> Bool {
          guard !commandCharacteristicPrefix.isEmpty else { return false }
          return c.uuid.uuidString.lowercased().hasPrefix(commandCharacteristicPrefix)
      }
      ```
      And similarly for `isCommandUUID`:
      ```swift
      func isCommandUUID(_ uuid: CBUUID) -> Bool {
          guard !commandCharacteristicPrefix.isEmpty else { return false }
          return uuid.uuidString.lowercased().hasPrefix(commandCharacteristicPrefix)
      }
      ```
    </action>
    <acceptance_criteria>
      - `GooseSwiftTests/GooseBLETypesTests.swift` contains at least 4 new test methods for Phase 8 additions
      - `WearableDescriptor.isCommandCharacteristic` has empty-prefix guard: `guard !commandCharacteristicPrefix.isEmpty else { return false }`
      - `WearableDescriptor.isCommandUUID` has same empty-prefix guard
      - `WearableDescriptor.genericHRMonitor.isCommandCharacteristic(anyChar)` returns `false` (verifiable by reading the guard)
      - Swift build succeeds; test target compiles
    </acceptance_criteria>
  </task>

</tasks>

<verification>
  1. `grep "genericHRMonitor" GooseSwift/GooseBLETypes.swift` — static instance present
  2. `grep "HR_MONITOR" GooseSwift/GooseBLETypes.swift` — rustDeviceType branch present
  3. `ls GooseSwift/GooseBLEClient+HRMonitor.swift` — extension file exists
  4. `grep "startHRMonitorScan\|stopHRMonitorScan\|connectHRMonitor" GooseSwift/GooseBLEClient+HRMonitor.swift` — public methods present
  5. `grep "HR_MONITOR" GooseSwift/GooseAppModel+NotificationPipeline.swift` — early-return branch present
  6. `grep "commandCharacteristicPrefix.isEmpty" GooseSwift/GooseBLETypes.swift` — empty-prefix guard present
  7. Swift build succeeds: Xcode or `xcodebuild -scheme GooseSwift -destination 'generic/platform=iOS Simulator' build`
</verification>

<success_criteria>
  - [ ] `WearableDescriptor.genericHRMonitor` exists with correct UUIDs
  - [ ] `GooseNotificationEvent.rustDeviceType` returns `"HR_MONITOR"` for 0x2A37 characteristics
  - [ ] `GooseBLEClient+HRMonitor.swift` exists with scan/connect/notify logic using a dedicated `CBCentralManager`
  - [ ] `GooseAppModel+NotificationPipeline.swift` passes HR_MONITOR raw bytes through without 0xaa reassembly
  - [ ] `isCommandCharacteristic` and `isCommandUUID` have empty-prefix guard
  - [ ] Swift unit tests cover the new WearableDescriptor and rustDeviceType additions
  - [ ] WEAR-02 requirement is fully satisfied
</success_criteria>
