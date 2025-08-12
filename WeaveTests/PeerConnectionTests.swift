import XCTest
@testable import Weave

final class PeerConnectionTests: XCTestCase {
    func testSendWithoutPeersDoesNotCrash() {
        let connection = PeerConnection()
        connection.send(text: "Hello")
        XCTAssertTrue(connection.messages.isEmpty)
    }
}
