import XCTest
@testable import weave

final class P2PManagerTests: XCTestCase {
    func testListenerStarts() async throws {
        let manager = P2PManager()
        manager.startListening(on: 9999)
        // Wait briefly to allow listener to start
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(manager.isListening)
    }
}
