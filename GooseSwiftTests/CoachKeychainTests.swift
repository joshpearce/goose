import XCTest
@testable import GooseSwift

final class CoachKeychainTests: XCTestCase {

  // MARK: - COACH-02: Keychain roundtrip for Claude and Custom endpoint

  override func tearDown() {
    super.tearDown()
    // Clean up any Claude Keychain state left by tests
    try? ClaudeCredentialStore.delete()
  }

  func testClaudeKeychainRoundtrip() throws {
    let testKey = "test-key-\(UUID().uuidString)"

    // Save a key
    try ClaudeCredentialStore.save(testKey)

    // Load it back — must match
    let loaded = try ClaudeCredentialStore.load()
    XCTAssertEqual(loaded, testKey, "Loaded key must match the saved key")

    // Delete it
    try ClaudeCredentialStore.delete()

    // Load after delete — must be nil
    let afterDelete = try ClaudeCredentialStore.load()
    XCTAssertNil(afterDelete, "Key must be nil after deletion")
  }

  func testCustomEndpointKeychainRoundtrip() throws {
    throw XCTSkip("Wave 3: CustomEndpointCoachProvider not yet implemented")
  }
}
