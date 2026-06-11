import Foundation
import Network


// Thread contract: start()/stop() may be called from any thread; the pathUpdateHandler
// runs on the dedicated monitor queue and dispatches callbacks to the main thread.
final class GooseNetworkMonitor {
  private let monitor = NWPathMonitor()
  private let monitorQueue = DispatchQueue(label: "com.goose.swift.network-monitor", qos: .utility)
  private var isStarted = false

  // True when the last NWPath status was .satisfied.
  // Initialised to true so launch is not falsely blocked before the first path update
  // (NWPathMonitor delivers the first update asynchronously after start() is called).
  private(set) var isReachable: Bool = true

  // Callback invoked on the main thread on every reachability change.
  // Consistent with GooseBLEBondingManager.onBondingStateChange and
  // GooseBLEClient.onConnectionStateChange — callback pattern, not Combine.
  var onReachabilityChange: ((Bool) -> Void)?

  // Starts monitoring. Repeated calls after the first are no-ops.
  func start() {
    guard !isStarted else { return }
    isStarted = true
    monitor.pathUpdateHandler = { [weak self] path in
      guard let self else { return }
      let reachable = path.status == .satisfied
      guard reachable != self.isReachable else { return }
      self.isReachable = reachable
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.onReachabilityChange?(reachable)
      }
    }
    monitor.start(queue: monitorQueue)
  }

  // Stops monitoring and cancels the underlying NWPathMonitor.
  func stop() {
    monitor.cancel()
  }
}
