import CoreBluetooth
import Foundation


// Thread contract: all methods on this class must be called from the main thread.
// This is enforced by convention — every call site either runs on the @MainActor or
// dispatches via dispatchCoreBluetoothDelegateToMainIfNeeded before calling transition().
// Do NOT call transition() or access bondingState from a background queue.
final class GooseBLEBondingManager {
  // Internal state machine — drives bondingState via validated transitions.
  private var machine: StateMachine<GooseBLEBondingState, GooseBLEBondingEvent>

  // Read-only public access mirrors the machine's current state; satisfies private(set) semantics.
  var bondingState: GooseBLEBondingState { machine.state }

  // Callback invoked on every state transition (on main thread).
  var onBondingStateChange: ((GooseBLEBondingState) -> Void)?

  // UserDefaults keys owned by this manager.
  static let bondingStateKey = "goose.swift.ble.bondingState"
  static let bondingDeviceIDKey = "goose.swift.ble.bondingDeviceID"

  init() {
    let initial = GooseBLEBondingManager.loadInitialState()
    machine = StateMachine(initial: initial, transitions: gooseBLEBondingTransition)
  }

  func transition(to newState: GooseBLEBondingState) {
    guard newState != bondingState else { return }
    let event = GooseBLEBondingManager.event(for: newState)
    machine.handle(event)
    persistState()
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.onBondingStateChange?(self.bondingState)
    }
  }

  private func persistState() {
    switch bondingState {
    case .completed(let id):
      UserDefaults.standard.set(bondingState.persistenceKey, forKey: Self.bondingStateKey)
      UserDefaults.standard.set(id.uuidString, forKey: Self.bondingDeviceIDKey)
    case .notStarted, .cancelled:
      UserDefaults.standard.removeObject(forKey: Self.bondingStateKey)
      UserDefaults.standard.removeObject(forKey: Self.bondingDeviceIDKey)
    case .started, .subscribed:
      break // transient connection states — do not persist; meaningless after app restart
    }
  }

  private static func loadInitialState() -> GooseBLEBondingState {
    let key = UserDefaults.standard.string(forKey: bondingStateKey) ?? ""
    switch key {
    case "completed":
      if let uuidString = UserDefaults.standard.string(forKey: bondingDeviceIDKey),
         let uuid = UUID(uuidString: uuidString) {
        return .completed(deviceID: uuid)
      }
      return .notStarted
    default:
      return .notStarted
    }
  }

  // Maps a target GooseBLEBondingState to the corresponding event that produces it.
  // transition(to:) is total — every state has a corresponding event.
  private static func event(for state: GooseBLEBondingState) -> GooseBLEBondingEvent {
    switch state {
    case .notStarted:              return .reset
    case .started:                 return .start
    case .subscribed:              return .subscribe
    case .completed(let id):       return .complete(deviceID: id)
    case .cancelled(let reason):   return .cancel(reason: reason)
    }
  }
}
