import CoreBluetooth
import Foundation
import OSLog

// MARK: - WearableDescriptor

struct WearableDescriptor {
  let serviceUUIDPrefix: String
  let commandCharacteristicPrefix: String

  func isCommandCharacteristic(_ c: CBCharacteristic) -> Bool {
    guard !commandCharacteristicPrefix.isEmpty else { return false }
    return c.uuid.uuidString.lowercased().hasPrefix(commandCharacteristicPrefix)
  }

  func isCommandUUID(_ uuid: CBUUID) -> Bool {
    guard !commandCharacteristicPrefix.isEmpty else { return false }
    return uuid.uuidString.lowercased().hasPrefix(commandCharacteristicPrefix)
  }
}

extension WearableDescriptor {
  // Gen5 service UUID prefix fd4b0001-, command UUID prefix fd4b0002-
  static let whoopGen5 = WearableDescriptor(
    serviceUUIDPrefix: "fd4b0001",
    commandCharacteristicPrefix: "fd4b0002"
  )

  // Gen4 service UUID prefix 61080001-, command UUID prefix 61080002-
  static let whoopGen4 = WearableDescriptor(
    serviceUUIDPrefix: "61080001",
    commandCharacteristicPrefix: "61080002"
  )

  // Standard Bluetooth Heart Rate Service 0x180D / HR Measurement 0x2A37
  // HR monitors are read-only notify devices with no command characteristic
  static let genericHRMonitor = WearableDescriptor(
    serviceUUIDPrefix: "180d",
    commandCharacteristicPrefix: ""
  )
}

// MARK: -

enum GooseLogLevel: String {
  case debug
  case info
  case warn
  case error
}

struct GooseDiscoveredDevice: Identifiable, Equatable {
  let id: UUID
  let name: String
  let rssi: Int
  let generation: String
}

struct GooseMessage: Identifiable {
  let id = UUID()
  let timestamp: Date
  let level: GooseLogLevel
  let source: String
  let title: String
  let body: String
}

struct GooseNotificationEvent {
  let deviceID: UUID
  let serviceUUID: String
  let characteristicUUID: String
  let value: Data
  let capturedAt: Date

  var rustDeviceType: String {
    if characteristicUUID.lowercased().hasPrefix("610800") {
      return "GEN4"
    }
    let normalizedUUID = characteristicUUID.replacingOccurrences(of: "-", with: "").lowercased()
    if normalizedUUID == "2a37" || normalizedUUID.hasPrefix("00002a37") {
      return "HR_MONITOR"
    }
    return "GOOSE"
  }
}

struct GooseBLENotificationContext {
  let activeDeviceName: String
  let connectionState: String
}

struct GooseCommandWriteEvent {
  let deviceID: UUID
  let serviceUUID: String
  let characteristicUUID: String
  let commandName: String
  let commandNumber: UInt8?
  let sequence: UInt8?
  let payload: Data
  let frame: Data
  let writeType: String
  let source: String
  let capturedAt: Date
}

enum GooseSyncToastPhase: String {
  case syncing
  case synced
  case failed
}

struct GooseSyncToast: Identifiable, Equatable {
  let id = UUID()
  let phase: GooseSyncToastPhase
  let title: String
  let detail: String
}

struct GooseHistoricalSyncProgress {
  let status: String
  let detail: String
  let packetCount: Int
  let isTerminal: Bool
  let failed: Bool
  let capturedAt: Date
}

struct GooseHistoricalRangeTelemetry {
  let capturedAt: Date
  let status: String
  let commandSequence: UInt8
  let resultCode: UInt8
  let resultName: String
  let payloadHex: String
  let bodyHex: String
  let revisionOrStatus: UInt8?
  let wordsFromOffset1: [UInt32]
  let pageCurrent: UInt32?
  let pageOldest: UInt32?
  let pageEnd: UInt32?
  let pagesBehind: Int64?
  let pendingResponseCount: Int
  let retryCount: Int
  let notes: String
}

struct GooseSyncFailure: Identifiable, Equatable {
  let id = UUID()
  let title: String
  let message: String
  let occurredAt: Date
}

struct GooseDebugCommandDefinition: Identifiable, Equatable {
  let id: String
  let title: String
  let commandNumber: UInt8
  let family: String
  let risk: String
  let detail: String
  let defaultPayloadHex: String?
  let requiresPayloadHex: Bool
  let payloadHint: String

  var canSendFromButton: Bool {
    defaultPayloadHex != nil || !requiresPayloadHex
  }

  var allowsRemoteInvocation: Bool {
    risk == "read" || risk == "keyed read"
  }

  var remoteURLExample: String {
    guard allowsRemoteInvocation else {
      return "Remote invocation disabled"
    }
    if requiresPayloadHex {
      return "gooseswift://debug-command/\(id)?payload=<hex>"
    }
    return "gooseswift://debug-command/\(id)"
  }
}

struct GooseDebugCommandResponse: Identifiable, Equatable {
  let id: UUID
  let commandID: String
  let title: String
  let commandNumber: UInt8
  let sequence: UInt8
  let requestedAt: Date
  let completedAt: Date?
  let status: String
  let result: String
  let requestPayloadHex: String
  let requestFrameHex: String
  let responsePayloadHex: String
  let responseBodyHex: String
  let source: String

  var summary: String {
    let time = completedAt ?? requestedAt
    let body = responseBodyHex.isEmpty ? "no body" : "body \(responseBodyHex)"
    return "\(status) | \(result) | seq \(sequence) | \(body) | \(time.formatted(date: .omitted, time: .standard))"
  }
}

// MARK: - WhoopGeneration

/// Encapsulates all generation-specific behavior for WHOOP band communication.
/// Adding support for a new generation means adding a case here and filling in
/// the three requirements below — everything else in the app picks it up automatically.
enum WhoopGeneration: CustomStringConvertible {
  case gen4
  case gen5

  // MARK: Detection

  /// Infer generation from the command characteristic that was assigned during GATT discovery.
  static func detect(from characteristic: CBCharacteristic) -> WhoopGeneration {
    characteristic.uuid.uuidString.lowercased().hasPrefix("61080002") ? .gen4 : .gen5
  }

  // MARK: Display

  var description: String {
    switch self {
    case .gen4: return "WHOOP 4.0"
    case .gen5: return "WHOOP 5.0"
    }
  }

  // MARK: Frame building

  /// The hello frame sent immediately after the command characteristic is ready.
  /// Gen5 uses a captured static frame; Gen4 sends GET_HELLO (cmd 145) in Gen4 framing.
  var helloFrame: Data {
    switch self {
    case .gen5: return GooseHello.clientHelloFrame
    case .gen4: return buildCommandFrame(sequence: 0x23, command: 145, data: [])
    }
  }

  /// Build a correctly-framed command packet for this generation.
  func buildCommandFrame(sequence: UInt8, command: UInt8, data: [UInt8]) -> Data {
    switch self {
    case .gen5:
      return GooseBLEClient.buildV5CommandFrame(sequence: sequence, command: command, data: data)
    case .gen4:
      return Self.buildGen4CommandFrame(sequence: sequence, command: command, data: data)
    }
  }

  // MARK: Gen4 internals

  /// Gen4 frame layout: [0xaa, len_lo, len_hi, crc8(len_bytes), payload..., crc32 x4]
  ///
  /// Gen4 frames are intentionally unpadded — unlike `buildV5CommandFrame`,
  /// which rounds the payload up to a 4-byte boundary. Confirmed from the
  /// PacketLogger capture of the official iOS app: it emits `cmd 120` with a
  /// 65-byte args field (not a multiple of 4), proving no padding is applied.
  /// Our unpadded frames also round-trip cleanly with the strap.
  private static func buildGen4CommandFrame(sequence: UInt8, command: UInt8, data: [UInt8]) -> Data {
    var payload: [UInt8] = [GooseBLEClient.V5PacketType.command, sequence, command]
    payload.append(contentsOf: data)
    let totalLen = payload.count + 4
    let lenBytes: [UInt8] = [UInt8(totalLen & 0xff), UInt8((totalLen >> 8) & 0xff)]
    let headerCRC = crc8(lenBytes)
    var frame: [UInt8] = [0xaa, lenBytes[0], lenBytes[1], headerCRC]
    frame.append(contentsOf: payload)
    let payloadCRC = GooseBLEClient.crc32(payload)
    frame.append(contentsOf: [
      UInt8(payloadCRC & 0xff),
      UInt8((payloadCRC >> 8) & 0xff),
      UInt8((payloadCRC >> 16) & 0xff),
      UInt8((payloadCRC >> 24) & 0xff),
    ])
    return Data(frame)
  }

  /// CRC-8, polynomial 0x07, init 0x00 — matches Rust protocol.rs implementation.
  private static func crc8(_ bytes: [UInt8]) -> UInt8 {
    var crc = UInt8(0)
    for byte in bytes {
      crc ^= byte
      for _ in 0..<8 {
        crc = crc & 0x80 != 0 ? (crc << 1) ^ 0x07 : crc << 1
      }
    }
    return crc
  }
}


// MARK: - BLE Bonding State

enum GooseBLEBondingState: Hashable {
  case notStarted
  case started
  case subscribed
  case completed(deviceID: UUID)
  case cancelled(reason: String)

  var isReady: Bool {
    if case .completed = self { return true }
    return false
  }

  var connectionStateString: String {
    switch self {
    case .notStarted:          return "disconnected"
    case .started:             return "connecting"
    case .subscribed:          return "discovering"
    case .completed:           return "ready"
    case .cancelled(let r):    return r.isEmpty ? "disconnected" : r
    }
  }

  var persistenceKey: String {
    switch self {
    case .notStarted:   return "notStarted"
    case .started:      return "started"
    case .subscribed:   return "subscribed"
    case .completed:    return "completed"
    case .cancelled:    return "notStarted"
    }
  }
}

// MARK: - BLE Bonding Events

/// Events that drive `GooseBLEBondingState` transitions inside `GooseBLEBondingManager`.
enum GooseBLEBondingEvent {
  case start
  case subscribe
  case complete(deviceID: UUID)
  case cancel(reason: String)
  case reset
}

/// Transition table encoding the legal bonding graph.
///
/// Legal edges:
///   notStarted  + start    → started
///   started     + subscribe → subscribed
///   subscribed  + complete  → completed(deviceID:)
///   any         + reset     → notStarted
///   any         + cancel    → cancelled(reason:)
///
/// All other (state, event) pairs return nil — invalid transition.
func gooseBLEBondingTransition(
  _ state: GooseBLEBondingState,
  _ event: GooseBLEBondingEvent
) -> GooseBLEBondingState? {
  switch event {
  case .reset:
    return .notStarted
  case .cancel(let reason):
    return .cancelled(reason: reason)
  case .start:
    guard case .notStarted = state else { return nil }
    return .started
  case .subscribe:
    guard case .started = state else { return nil }
    return .subscribed
  case .complete(let deviceID):
    guard case .subscribed = state else { return nil }
    return .completed(deviceID: deviceID)
  }
}

