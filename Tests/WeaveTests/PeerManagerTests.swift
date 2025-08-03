import XCTest
import Foundation
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

    func testNearestPeersRespectsAttributeFilters() {
        let manager = PeerManager()
        let origin = Peer(latitude: 0.0, longitude: 0.0)
        let hikingPeer = Peer(latitude: 0.0, longitude: 0.05, attributes: ["hobby": "hiking"])
        let gamingPeer = Peer(latitude: 0.0, longitude: 0.02, attributes: ["hobby": "gaming"])

        manager.add(hikingPeer)
        manager.add(gamingPeer)

        let results = manager.nearestPeers(to: origin.latitude,
                                           longitude: origin.longitude,
                                           limit: 5,
                                           matching: ["hobby": "hiking"])
        XCTAssertEqual(results, [hikingPeer])
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

    func testUpdatingPeerLocation() {
        let manager = PeerManager()
        let peer = Peer(latitude: 0.0, longitude: 0.0)
        manager.add(peer)
        manager.updateLocation(id: peer.id, latitude: 1.0, longitude: 1.0)
        let updated = manager.peer(id: peer.id)
        XCTAssertEqual(updated?.latitude, 1.0)
        XCTAssertEqual(updated?.longitude, 1.0)
    }

    func testUpdatingPeerAttributes() {
        let manager = PeerManager()
        let peer = Peer(latitude: 0.0, longitude: 0.0, attributes: ["hobby": "gaming"])
        manager.add(peer)
        manager.updateAttributes(id: peer.id, attributes: ["hobby": "hiking"])
        let updated = manager.peer(id: peer.id)
        XCTAssertEqual(updated?.attributes["hobby"], "hiking")
    }

    func testUpdatingSingleAttribute() {
        let manager = PeerManager()
        let peer = Peer(latitude: 0.0, longitude: 0.0)
        manager.add(peer)
        manager.updateAttribute(id: peer.id, key: "hobby", value: "chess")
        let updated = manager.peer(id: peer.id)
        XCTAssertEqual(updated?.attributes["hobby"], "chess")
    }

    func testRemovingAttribute() {
        let manager = PeerManager()
        let peer = Peer(latitude: 0.0, longitude: 0.0, attributes: ["hobby": "chess"])
        manager.add(peer)
        manager.removeAttribute(id: peer.id, key: "hobby")
        let updated = manager.peer(id: peer.id)
        XCTAssertNil(updated?.attributes["hobby"])
    }

    func testUpdatingPeerAddress() {
        let manager = PeerManager()
        let peer = Peer(address: "1.2.3.4", port: 1000, latitude: 0.0, longitude: 0.0)
        manager.add(peer)
        manager.updateAddress(id: peer.id, address: "5.6.7.8", port: 2000)
        let updated = manager.peer(id: peer.id)
        XCTAssertEqual(updated?.address, "5.6.7.8")
        XCTAssertEqual(updated?.port, 2000)
    }

    func testMatchPeersRanksByAttributeScoreThenDistance() {
        let manager = PeerManager()
        let origin = Peer(latitude: 0.0, longitude: 0.0, attributes: ["hobby": "hiking"])
        let nearMatch = Peer(latitude: 0.0, longitude: 0.05, attributes: ["hobby": "hiking"])
        let farMatch = Peer(latitude: 0.0, longitude: 1.0, attributes: ["hobby": "hiking"])
        let nonMatch = Peer(latitude: 0.0, longitude: 0.05, attributes: ["hobby": "gaming"])

        manager.add(nearMatch)
        manager.add(farMatch)
        manager.add(nonMatch)

        let matches = manager.matchPeers(for: origin, radius: 2000.0, limit: 2)
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0], nearMatch)
        XCTAssertEqual(matches[1], farMatch)
    }

    func testPrunesStalePeers() {
        let manager = PeerManager()
        let fresh = Peer(latitude: 0.0, longitude: 0.0)
        let stale = Peer(latitude: 0.0, longitude: 0.0, lastSeen: Date(timeIntervalSinceNow: -7200))
        manager.add(fresh)
        manager.add(stale)

        manager.pruneStale(before: Date(timeIntervalSinceNow: -3600))

        XCTAssertEqual(manager.allPeers(), [fresh])
    }

    func testUpdateLastSeenChangesTimestamp() {
        let manager = PeerManager()
        let oldDate = Date(timeIntervalSince1970: 0)
        let peer = Peer(latitude: 0.0, longitude: 0.0, lastSeen: oldDate)
        manager.add(peer)

        let newDate = Date(timeIntervalSince1970: 100)
        manager.updateLastSeen(id: peer.id, at: newDate)

        let updated = manager.peer(id: peer.id)
        XCTAssertEqual(updated?.lastSeen, newDate)
    }

    func testPersistenceRoundTrip() throws {
        let manager = PeerManager()
        let timestamp = Date(timeIntervalSince1970: 1234)
        let peer = Peer(latitude: 1.0, longitude: 2.0, lastSeen: timestamp)
        manager.add(peer)

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let store = PeerStore(url: tmp)
        try manager.save(to: store)

        let restored = PeerManager()
        try restored.load(from: store)
        XCTAssertEqual(restored.allPeers(), [peer])
        XCTAssertEqual(restored.peer(id: peer.id)?.lastSeen, timestamp)
    }

    func testBlockedPeersAreExcludedFromQueries() {
        let manager = PeerManager()
        let first = Peer(latitude: 0.0, longitude: 0.0)
        let second = Peer(latitude: 0.0, longitude: 0.0)
        manager.add(first)
        manager.add(second)

        manager.block(id: second.id)

        XCTAssertEqual(manager.allPeers(), [first])
        XCTAssertFalse(manager.peers(near: 0.0, longitude: 0.0, radius: 1.0).contains(second))

        manager.unblock(id: second.id)
        let all = manager.allPeers()
        XCTAssertTrue(all.contains(first))
        XCTAssertTrue(all.contains(second))
    }

    func testConnectUpdatesLastSeen() {
        let manager = PeerManager()
        let oldDate = Date(timeIntervalSince1970: 0)
        let peer = Peer(latitude: 0.0, longitude: 0.0, lastSeen: oldDate)
        manager.add(peer)

        let success = manager.connect(to: peer.id)
        XCTAssertTrue(success)
        let updated = manager.peer(id: peer.id)
        XCTAssertNotEqual(updated?.lastSeen, oldDate)
    }

    func testConnectFailsForBlockedPeer() {
        let manager = PeerManager()
        let peer = Peer(latitude: 0.0, longitude: 0.0)
        manager.add(peer)
        manager.block(id: peer.id)

        XCTAssertFalse(manager.connect(to: peer.id))
    }
}
