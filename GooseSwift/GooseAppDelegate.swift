import UIKit


final class GooseAppDelegate: NSObject, UIApplicationDelegate {

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    UIApplication.shared.registerForRemoteNotifications()
    return true
  }

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
    Task { @MainActor in
      GooseSwiftApp.sharedModel?.setAPNSDeviceToken(hex)
    }
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    // Expected on simulator and unprovisioned builds — soft failure; upload token gate
    // will keep uploads skipped (logged as skip.no_apns_token) until registration succeeds.
    Task { @MainActor in
      GooseSwiftApp.sharedModel?.ble.record(
        level: .warn,
        source: "app.apns",
        title: "register.failed",
        body: error.localizedDescription
      )
    }
  }
}
