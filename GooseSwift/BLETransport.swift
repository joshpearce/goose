import Foundation

// BLETransport — the interface GooseAppModel and views depend on.
// CoreBluetoothBLETransport is the sole concrete implementation.
protocol BLETransport: AnyObject {

  // MARK: - State properties

  var bluetoothState: String { get }
  var connectionState: String { get }
  var isScanning: Bool { get }
  var liveHeartRateBPM: Int? { get }
  var liveHeartRateSource: String { get }
  var liveHeartRateUpdatedAt: Date? { get }
  var restingHeartRateEstimateBPM: Double? { get }
  var restingHeartRateEstimateSampleCount: Int { get }
  var restingHeartRateEstimateSource: String { get }
  var restingHeartRateEstimateUpdatedAt: Date? { get }
  var liveHRVRMSSD: Double? { get }
  var liveHRVRRIntervalCount: Int { get }
  var liveHRVSource: String { get }
  var liveHRVUpdatedAt: Date? { get }
  var hrConnectionState: String { get }
  var activeDeviceName: String { get }
  var activeDeviceIdentifier: UUID? { get }
  var selectedDeviceID: UUID? { get set }
  var connectedPeripheralUUID: String? { get }
  var connectedAt: Date? { get }
  var connectedCapabilities: DeviceCapabilities? { get }
  var lastSyncAt: Date? { get }
  var batteryLevelPercent: Int? { get }
  var batteryUpdatedAt: Date? { get }
  var batteryIsCharging: Bool? { get }
  var batteryPowerStatus: String { get }
  var firmwareVersion: String? { get }
  var modelNumber: String? { get }
  var hardwareRevision: String? { get }
  var softwareRevision: String? { get }
  var manufacturerName: String? { get }
  var historicalPacketCount: Int { get }
  var isHistoricalSyncing: Bool { get }
  var historicalSyncStatus: String { get }
  var historicalSyncFraction: Double? { get }
  var lastHistoricalSyncCompletedAt: Date? { get }
  var physiologyCaptureStatus: String { get }
  var lastPhysiologyCommandSummary: String { get }
  var highFrequencyHistorySyncActive: Bool { get }
  var highFrequencyHistorySyncStatus: String { get }
  var debugCommandStatus: String { get }
  var debugCommandResponses: [GooseDebugCommandResponse] { get }
  var canWriteAlarm: Bool { get }
  var canWriteHighFrequencyHistorySync: Bool { get }
  var canSyncHistorical: Bool { get }
  var canSyncClock: Bool { get }
  var syncToast: GooseSyncToast? { get }
  var lastSyncFailure: GooseSyncFailure? { get }
  var syncFailureSheet: GooseSyncFailure? { get set }
  var discoveredDevices: [GooseDiscoveredDevice] { get }
  var discoveredHRDevices: [GooseDiscoveredDevice] { get }
  var hrBluetoothState: String { get }
  var reconnectState: String { get }
  var hrReconnectState: String { get }
  var historicalSyncRunID: UUID { get }
  var lastHistoricalRangeCommandStatus: String { get }
  var alarmCommandStatus: String { get }
  var lastAlarmCommandFrameHex: String { get }
  var lastAlarmResponseSummary: String { get }
  var lastAlarmResponsePayloadHex: String { get }
  var lastAlarmEventSummary: String { get }
  var lastAlarmEventPayloadHex: String { get }
  var lastAlarmScheduledAt: Date? { get }
  var lastAlarmID: Int? { get }
  var strapClockDate: Date? { get }
  var strapClockOffsetSeconds: TimeInterval? { get }
  var strapClockUpdatedAt: Date? { get }
  var strapClockStatus: String { get }
  var highFrequencyHistorySyncDisplaySummary: String { get }
  var lastHighFrequencyHistorySyncResponse: String { get }
  var lastHighFrequencyHistorySyncEvent: String { get }
  var debugResearchCommands: [GooseDebugCommandDefinition] { get }
  var invalidFrameCount: Int { get }
  var historicalSyncBurstsCompleted: Int { get }
  var historicalSyncPagesTotal: Int? { get }

  // MARK: - Callback properties

  var onNotification: ((GooseNotificationEvent) -> Void)? { get set }
  var onRawNotification: ((GooseNotificationEvent) -> Void)? { get set }
  var onRawNotificationWithContext: ((GooseNotificationEvent, GooseBLENotificationContext) -> Void)? { get set }
  var onCommandWrite: ((GooseCommandWriteEvent) -> Void)? { get set }
  var onLiveHeartRate: ((Int, String, Date) -> Void)? { get set }
  var onHRVSample: ((Double, Int, String, Date) -> Void)? { get set }
  var onHRSpike: ((Int, String) -> Void)? { get set }
  var onConnectionStateChange: ((String) -> Void)? { get set }
  var onHRConnectionStateChange: ((String) -> Void)? { get set }
  var onHistoricalSyncProgress: ((GooseHistoricalSyncProgress) -> Void)? { get set }
  var onHistoricalRangeTelemetry: ((GooseHistoricalRangeTelemetry) -> Void)? { get set }
  var onMessage: ((GooseMessage) -> Void)? { get set }

  // MARK: - Sub-object accessors

  var messageStore: GooseMessageStore { get }
  var hrMonitorManager: GooseBLEHRMonitorManager { get }
  var bondingManager: GooseBLEBondingManager { get }
  var dataValidator: GooseBLEDataValidator { get }
  var historicalDirectWriteDatabasePath: String { get set }

  // MARK: - Action methods

  func requestBluetooth()
  func startScan()
  func startScan(reason: String, clearDiscovered: Bool)
  func stopScan()
  func stopScan(reason: String)
  func reconnectRemembered()
  func updateConnectionState(_ state: String)
  func record(source: String, title: String)
  func record(source: String, title: String, body: String)
  func recordLiveHeartRate(bpm: Int, source: String, capturedAt: Date)
  func syncHistoricalPackets()
  func writeClockCommand()
  func setWhoopAlarm(at date: Date, alarmID: Int)
  func disableWhoopAlarms()
  func buzz()
  func applyBatteryLevel(_ level: Int, isCharging: Bool?, source: String)
  func startPhysiologySignalCapture()
  func stopPhysiologySignalCapture()
  func startMovementHeartRateCapture()
  func stopMovementHeartRateCapture()
  func enterHighFrequencyHistorySync()
  func exitHighFrequencyHistorySync()
  func sendDebugResearchCommand(_ command: GooseDebugCommandDefinition)
  func previewHelloWorldToast()
  func setDebugCommandStatus(_ status: String)
}
