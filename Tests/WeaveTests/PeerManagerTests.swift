import XCTest
@testable import weave

final class PeerManagerTests: XCTestCase {
    func testFiltersNearbyPeers() {
        let manager = PeerManager()
        let userLocation = Peer(latitude: 37.7749, longitude: -122.4194)
        let nearby = Peer(latitude: 37.7750, longitude: -122.4195)
        let farAway = Peer(latitude: 40.7128, longitude: -74.0060)

        manager.add(nearby)
        manager.add(farAway)

        let filteredPeers = manager.peers(near: userLocation.latitude, longitude: userLocation.longitude, radius: 10.0)
        XCTAssertTrue(filteredPeers.contains(nearby))
        XCTAssertFalse(filteredPeers.contains(farAway))
    }

    func testRemovingPeerUpdatesIndex() {
        let manager = PeerManager()
        let peer = Peer(latitude: 37.0, longitude: -122.0)
        manager.add(peer)
        XCTAssertEqual(manager.allPeers().count, 1)
        manager.remove(id: peer.id)
        XCTAssertEqual(manager.allPeers().count, 0)
    }

    func testNearestPeersReturnsSortedResults() {
        let manager = PeerManager()
        let origin = Peer(latitude: 0.0, longitude: 0.0)
        let nearer = Peer(latitude: 0.0, longitude: 0.05) // ~5.5km east
        let near = Peer(latitude: 0.0, longitude: 0.1)   // ~11km east

        manager.add(near)
        manager.add(nearer)

        let results = manager.nearestPeers(to: origin.latitude, longitude: origin.longitude, limit: 2)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0], nearer)
        XCTAssertEqual(results[1], near)
    }

    func testAttributeFilteringReturnsMatches() {
        let manager = PeerManager()
        let hiker = Peer(latitude: 0.0, longitude: 0.0, attributes: ["hobby": "hiking"])
        let gamer = Peer(latitude: 0.0, longitude: 0.0, attributes: ["hobby": "gaming"])

        manager.add(hiker)
        manager.add(gamer)

        let results = manager.peers(near: 0.0, longitude: 0.0, radius: 1.0, matching: ["hobby": "hiking"])
        XCTAssertEqual(results, [hiker])
    }
}
