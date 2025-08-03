import XCTest
@testable import weave

final class PeerTests: XCTestCase {
    func testInvalidLatitudeThrows() {
        XCTAssertThrowsError(try Peer(latitude: 100, longitude: 0)) { error in
            guard case Peer.PeerError.invalidLatitude = error else {
                XCTFail("Expected invalidLatitude error")
                return
            }
        }
    }

    func testInvalidLongitudeThrows() {
        XCTAssertThrowsError(try Peer(latitude: 0, longitude: 200)) { error in
            guard case Peer.PeerError.invalidLongitude = error else {
                XCTFail("Expected invalidLongitude error")
                return
            }
        }
    }
}
