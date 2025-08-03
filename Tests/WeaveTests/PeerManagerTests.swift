import XCTest
@testable import weave

final class PeerManagerTests: XCTestCase {
    func testNearbyPeerFiltering() {
        let manager = PeerManager()
        let userLocation = Peer(latitude: 37.7749, longitude: -122.4194)
        let nearby = Peer(latitude: 37.7750, longitude: -122.4195)
        let farAway = Peer(latitude: 40.7128, longitude: -74.0060)

        manager.add(nearby)
        manager.add(farAway)

        let results = manager.peers(near: userLocation.latitude, longitude: userLocation.longitude, radius: 10.0)
        XCTAssertTrue(results.contains(nearby))
        XCTAssertFalse(results.contains(farAway))
    }

    func testRemovingPeer() {
        let manager = PeerManager()
        let peer = Peer(latitude: 37.0, longitude: -122.0)
        manager.add(peer)
        XCTAssertEqual(manager.allPeers().count, 1)
        manager.remove(id: peer.id)
        XCTAssertEqual(manager.allPeers().count, 0)
    }
}
