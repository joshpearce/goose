import XCTest
@testable import GooseSwift

@MainActor
final class CoachProviderRegistryTests: XCTestCase {

  // MARK: - COACH-06: Registry persists active provider ID to UserDefaults

  func testRegistryPersistsActiveProviderID() {
    let registry = CoachProviderRegistry()
    registry.selectProvider(id: "chatgpt")
    let stored = UserDefaults.standard.string(forKey: "goose.coach.activeProviderId")
    XCTAssertEqual(stored, "chatgpt", "Selecting chatgpt must persist 'chatgpt' to goose.coach.activeProviderId")
  }

  // MARK: - COACH-01: Registry exposes all four providers (Waves 2-4 stubs)

  func testRegistryExposesAllFourProviders() throws {
    // Wave 2-4: ClaudeCoachProvider, GeminiCoachProvider, CustomEndpointCoachProvider
    // are added in those waves. This test re-enables in Plan 18-05.
    throw XCTSkip("providers added in Waves 2-4; re-enabled in Plan 18-05")
  }
}
