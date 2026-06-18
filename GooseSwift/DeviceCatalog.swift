import Foundation

// DeviceCatalog — centralises all Gen4/Gen5 capability branching.
// Construct from connectedCapabilities (which may be nil when disconnected).
// See D3 in 89-CONTEXT.md.

struct DeviceCatalog {
  let capabilities: DeviceCapabilities?

  // Returns true when the device uses the Gen4 page-sequence historical sync protocol
  // (i.e. WHOOP 4 straps that require cmd 34 → 22 → 23 with page offsets).
  // Replaces all: connectedCapabilities?.historicalSync == .pageSequence
  var usesPageSequenceSync: Bool {
    capabilities?.historicalSync == .pageSequence
  }

  // Returns true when the device uses the Gen4 wire protocol.
  // Replaces all: connectedCapabilities?.wireProtocol == .gen4
  var isGen4: Bool {
    capabilities?.wireProtocol == .gen4
  }

  // Human-readable generation label for logging ("gen4" / "gen5" / "unknown").
  // Replaces: connectedCapabilities.map { $0.wireProtocol == .gen4 ? "gen4" : "gen5" } ?? "unknown"
  var generationLabel: String {
    guard let caps = capabilities else { return "unknown" }
    return caps.wireProtocol == .gen4 ? "gen4" : "gen5"
  }

  // Returns the retry label used in DebugAndSync for log messages.
  // Replaces: connectedCapabilities?.historicalSync == .pageSequence ? "gen4 cmd34→22→23" : "GET_DATA_RANGE then SEND_HISTORICAL_DATA"
  var historicalRetryLabel: String {
    usesPageSequenceSync ? "gen4 cmd34→22→23" : "GET_DATA_RANGE then SEND_HISTORICAL_DATA"
  }

  // Returns the device type string used in HistoricalHandlers for log messages.
  // Replaces: switch connectedCapabilities?.historicalSync { case .pageSequence: "GEN4" }
  var historicalDeviceType: String {
    usesPageSequenceSync ? "GEN4" : (capabilities?.wireProtocol.bridgeString ?? "GOOSE")
  }
}
