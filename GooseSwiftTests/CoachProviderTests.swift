import XCTest
@testable import GooseSwift

final class CoachProviderTests: XCTestCase {

  // MARK: - COACH-01: CoachProvider protocol shape (compile-time proof)

  func testCoachProviderProtocolHasRequiredMembers() {
    let provider: any CoachProvider = ChatGPTCoachProvider()
    XCTAssertFalse(provider.id.isEmpty, "provider.id must be non-empty")
    XCTAssertFalse(provider.displayName.isEmpty, "provider.displayName must be non-empty")
    // isAuthenticated: Bool — just accessing is a compile-time proof
    _ = provider.isAuthenticated
    // availablePresets: [CoachModelPreset] — must be accessible and non-empty for ChatGPT
    XCTAssertFalse(provider.availablePresets.isEmpty, "ChatGPTCoachProvider.availablePresets must be non-empty")
  }

  func testSendReturnsAsyncStreamShape() throws {
    // Wave 1: the AsyncStream<String> return type is proven at compile time by the protocol conformance.
    // A live network call is required to exercise the stream; skip in CI.
    throw XCTSkip("Wave 1: requires network; AsyncStream shape proven by compile")
  }
}
