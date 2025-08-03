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

    func testPeersDifferingByLastSeenAreNotEqual() throws {
        let baseID = UUID()
        let first = try Peer(id: baseID, latitude: 0, longitude: 0, lastSeen: Date(timeIntervalSince1970: 0))
        let second = try Peer(id: baseID, latitude: 0, longitude: 0, lastSeen: Date(timeIntervalSince1970: 10))
        XCTAssertNotEqual(first, second)

        var set: Set<Peer> = [first, second]
        XCTAssertEqual(set.count, 2)
    }

    func testPeersWithIdenticalDataCollapseInSet() throws {
        let id = UUID()
        let timestamp = Date(timeIntervalSince1970: 0)
        let attrs = ["key": "value"]
        let keyData = Data([0x01, 0x02])
        let first = try Peer(id: id,
                             name: "Alice",
                             address: "1.2.3.4",
                             port: 8080,
                             publicKey: keyData,
                             latitude: 0,
                             longitude: 0,
                             attributes: attrs,
                             lastSeen: timestamp)
        let duplicate = try Peer(id: id,
                                 name: "Alice",
                                 address: "1.2.3.4",
                                 port: 8080,
                                 publicKey: keyData,
                                 latitude: 0,
                                 longitude: 0,
                                 attributes: attrs,
                                 lastSeen: timestamp)
        var set: Set<Peer> = [first]
        set.insert(duplicate)
        XCTAssertEqual(set.count, 1)
    }
}
