import XCTest

import Foundation
import Dispatch
@testable import weave

final class PeerManagerTests: XCTestCase {
    func testFiltersNearbyPeers() {

        let manager = PeerManager()
        let userLocation = try! Peer(latitude: 37.7749, longitude: -122.4194)
        let nearby = try! Peer(latitude: 37.7750, longitude: -122.4195)
        let farAway = try! Peer(latitude: 40.7128, longitude: -74.0060)

        manager.add(nearby)
        manager.add(farAway)


        let filteredPeers = manager.peers(near: userLocation.latitude, longitude: userLocation.longitude, radius: 10.0)
        XCTAssertTrue(filteredPeers.contains(nearby))
        XCTAssertFalse(filteredPeers.contains(farAway))
    }

    func testRemovingPeerUpdatesIndex() {
        let manager = PeerManager()
        let peer = try! Peer(latitude: 37.0, longitude: -122.0)
        manager.add(peer)
        XCTAssertEqual(manager.allPeers().count, 1)
        let prefix = String(peer.geohash.prefix(5))
        XCTAssertEqual(manager.peers(inGeohash: prefix), [peer])
        manager.remove(id: peer.id)
        XCTAssertEqual(manager.allPeers().count, 0)
        XCTAssertTrue(manager.peers(inGeohash: prefix).isEmpty)
    }

    func testNearestPeersReturnsSortedResults() {
        let manager = PeerManager()
        let origin = try! Peer(latitude: 0.0, longitude: 0.0)
        let nearer = try! Peer(latitude: 0.0, longitude: 0.05) // ~5.5km east
        let near = try! Peer(latitude: 0.0, longitude: 0.1)   // ~11km east

        manager.add(near)
        manager.add(nearer)

        let results = manager.nearestPeers(to: origin.latitude, longitude: origin.longitude, limit: 2)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0], nearer)
        XCTAssertEqual(results[1], near)

    }

    func testNearestPeersRespectsAttributeFilters() {
        let manager = PeerManager()
        let origin = try! Peer(latitude: 0.0, longitude: 0.0)
        let hikingPeer = try! Peer(latitude: 0.0, longitude: 0.05, attributes: ["hobby": "hiking"])
        let gamingPeer = try! Peer(latitude: 0.0, longitude: 0.02, attributes: ["hobby": "gaming"])

        manager.add(hikingPeer)
        manager.add(gamingPeer)

        let results = manager.nearestPeers(to: origin.latitude,
                                           longitude: origin.longitude,
                                           limit: 5,
                                           matching: ["hobby": "hiking"])
        XCTAssertEqual(results, [hikingPeer])

    }

    func testNearestPeersMatchesNaiveImplementation() {
        let manager = PeerManager()
        let originLat = 0.0
        let originLon = 0.0

        let peers = [
            Peer(latitude: 0.0, longitude: 0.3),
            Peer(latitude: 0.0, longitude: 0.1),
            Peer(latitude: 0.0, longitude: -0.1),
            Peer(latitude: 0.2, longitude: 0.0),
            Peer(latitude: -0.2, longitude: 0.0)
        ]

        peers.forEach { manager.add($0) }

        let optimized = manager.nearestPeers(to: originLat, longitude: originLon, limit: 5)

        func distance(_ from: (Double, Double), _ to: (Double, Double)) -> Double {
            let earthRadiusKm = 6371.0
            let deltaLat = (to.0 - from.0) * Double.pi / 180
            let deltaLon = (to.1 - from.1) * Double.pi / 180
            let a = sin(deltaLat/2) * sin(deltaLat/2) +
                    cos(from.0 * Double.pi / 180) * cos(to.0 * Double.pi / 180) *
                    sin(deltaLon/2) * sin(deltaLon/2)
            let c = 2 * atan2(sqrt(a), sqrt(1-a))
            return earthRadiusKm * c
        }

        let naive = manager.allPeers().sorted {
            distance((originLat, originLon), ($0.latitude, $0.longitude)) <
            distance((originLat, originLon), ($1.latitude, $1.longitude))
        }

        XCTAssertEqual(optimized, Array(naive.prefix(5)))
    }

    func testAttributeFilteringReturnsMatches() {
        let manager = PeerManager()
        let hiker = try! Peer(latitude: 0.0, longitude: 0.0, attributes: ["hobby": "hiking"])
        let gamer = try! Peer(latitude: 0.0, longitude: 0.0, attributes: ["hobby": "gaming"])

        manager.add(hiker)
        manager.add(gamer)

        let results = manager.peers(near: 0.0, longitude: 0.0, radius: 1.0, matching: ["hobby": "hiking"])
        XCTAssertEqual(results, [hiker])

    }

    func testUpdatingPeerLocation() {
        let manager = PeerManager()
        let peer = try! Peer(latitude: 0.0, longitude: 0.0)
        manager.add(peer)
        let oldPrefix = String(peer.geohash.prefix(5))
        manager.updateLocation(id: peer.id, latitude: 1.0, longitude: 1.0)
        let updated = manager.peer(id: peer.id)!
        XCTAssertEqual(updated.latitude, 1.0)
        XCTAssertEqual(updated.longitude, 1.0)
        let newPrefix = String(updated.geohash.prefix(5))
        XCTAssertNotEqual(oldPrefix, newPrefix)
        XCTAssertTrue(manager.peers(inGeohash: newPrefix).contains(updated))
        XCTAssertFalse(manager.peers(inGeohash: oldPrefix).contains(updated))
    }


    func testUpdateLocationRejectsInvalidCoordinates() {
        let manager = PeerManager()
        let peer = try! Peer(latitude: 0.0, longitude: 0.0)
        manager.add(peer)

        manager.updateLocation(id: peer.id, latitude: 100.0, longitude: 0.0)
        var updated = manager.peer(id: peer.id)!
        XCTAssertEqual(updated.latitude, 0.0)
        XCTAssertEqual(updated.longitude, 0.0)

        manager.updateLocation(id: peer.id, latitude: 0.0, longitude: 200.0)
        updated = manager.peer(id: peer.id)!
        XCTAssertEqual(updated.latitude, 0.0)
        XCTAssertEqual(updated.longitude, 0.0)

    }

    func testUpdatingPeerAttributes() {
        let manager = PeerManager()
        let peer = try! Peer(latitude: 0.0, longitude: 0.0, attributes: ["hobby": "gaming"])
        manager.add(peer)
        manager.updateAttributes(id: peer.id, attributes: ["hobby": "hiking"])
        let updated = manager.peer(id: peer.id)
        XCTAssertEqual(updated?.attributes["hobby"], "hiking")
    }

    func testUpdatingSingleAttribute() {
        let manager = PeerManager()
        let peer = try! Peer(latitude: 0.0, longitude: 0.0)
        manager.add(peer)
        manager.updateAttribute(id: peer.id, key: "hobby", value: "chess")
        let updated = manager.peer(id: peer.id)
        XCTAssertEqual(updated?.attributes["hobby"], "chess")
    }

    func testRemovingAttribute() {
        let manager = PeerManager()
        let peer = try! Peer(latitude: 0.0, longitude: 0.0, attributes: ["hobby": "chess"])
        manager.add(peer)
        manager.removeAttribute(id: peer.id, key: "hobby")
        let updated = manager.peer(id: peer.id)
        XCTAssertNil(updated?.attributes["hobby"])
    }

    func testUpdatingPeerAddress() {
        let manager = PeerManager()
        let peer = try! Peer(address: "1.2.3.4", port: 1000, latitude: 0.0, longitude: 0.0)
        manager.add(peer)
        manager.updateAddress(id: peer.id, address: "5.6.7.8", port: 2000)
        let updated = manager.peer(id: peer.id)
        XCTAssertEqual(updated?.address, "5.6.7.8")
        XCTAssertEqual(updated?.port, 2000)
    }

    func testUpdatingPeerName() {
        let manager = PeerManager()
        let peer = try! Peer(name: "Old", latitude: 0.0, longitude: 0.0)
        manager.add(peer)
        manager.updateName(id: peer.id, name: "New")
        let updated = manager.peer(id: peer.id)
        XCTAssertEqual(updated?.name, "New")
        XCTAssertNotEqual(updated?.lastSeen, peer.lastSeen)
    }

    func testMatchPeersRanksByAttributeScoreThenDistance() {
        let manager = PeerManager()
        let origin = try! Peer(latitude: 0.0, longitude: 0.0, attributes: ["hobby": "hiking"])
        let nearMatch = try! Peer(latitude: 0.0, longitude: 0.05, attributes: ["hobby": "hiking"])
        let farMatch = try! Peer(latitude: 0.0, longitude: 1.0, attributes: ["hobby": "hiking"])
        let nonMatch = try! Peer(latitude: 0.0, longitude: 0.05, attributes: ["hobby": "gaming"])

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
        let fresh = try! Peer(latitude: 0.0, longitude: 0.0)
        let stale = try! Peer(latitude: 0.0, longitude: 0.0, lastSeen: Date(timeIntervalSinceNow: -7200))
        manager.add(fresh)
        manager.add(stale)

        manager.pruneStale(before: Date(timeIntervalSinceNow: -3600))

        XCTAssertEqual(manager.allPeers(), [fresh])
    }

    func testPruneStaleRemovesLikedPeers() {
        let manager = PeerManager()
        let fresh = try! Peer(latitude: 0.0, longitude: 0.0)
        let stale = try! Peer(latitude: 0.0, longitude: 0.0, lastSeen: Date(timeIntervalSinceNow: -7200))
        manager.add(fresh)
        manager.add(stale)
        manager.like(id: fresh.id)
        manager.like(id: stale.id)

        manager.pruneStale(before: Date(timeIntervalSinceNow: -3600))

        XCTAssertEqual(manager.likedPeers(), [fresh])
    }

    func testUpdateLastSeenChangesTimestamp() {
        let manager = PeerManager()
        let oldDate = Date(timeIntervalSince1970: 0)
        let peer = try! Peer(latitude: 0.0, longitude: 0.0, lastSeen: oldDate)
        manager.add(peer)

        let newDate = Date(timeIntervalSince1970: 100)
        manager.updateLastSeen(id: peer.id, at: newDate)

        let updated = manager.peer(id: peer.id)
        XCTAssertEqual(updated?.lastSeen, newDate)
    }

    func testPersistenceRoundTrip() throws {
        let manager = PeerManager()
        let timestamp = Date(timeIntervalSince1970: 1234)
        let peer = try! Peer(latitude: 1.0, longitude: 2.0, lastSeen: timestamp)
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

    func testBlockedPeersPersistThroughStore() throws {
        let manager = PeerManager()
        let peer = try! Peer(latitude: 0.0, longitude: 0.0)
        manager.add(peer)
        manager.block(id: peer.id)

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let store = PeerStore(url: tmp)
        try manager.save(to: store)

        let restored = PeerManager()
        try restored.load(from: store)

        XCTAssertEqual(restored.allPeers().count, 0)
        restored.unblock(id: peer.id)
        XCTAssertEqual(restored.allPeers(), [peer])
    }

    func testLikedPeersAreReturned() {
        let manager = PeerManager()
        let peer = try! Peer(latitude: 0.0, longitude: 0.0)
        manager.add(peer)
        manager.like(id: peer.id)

        XCTAssertEqual(manager.likedPeers(), [peer])

        manager.block(id: peer.id)
        XCTAssertTrue(manager.likedPeers().isEmpty)
    }

    func testLikedPeersPersistThroughStore() throws {
        let manager = PeerManager()
        let peer = try! Peer(latitude: 0.0, longitude: 0.0)
        manager.add(peer)
        manager.like(id: peer.id)

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let store = PeerStore(url: tmp)
        try manager.save(to: store)

        let restored = PeerManager()
        try restored.load(from: store)

        XCTAssertEqual(restored.likedPeers(), [peer])
    }

    func testMutualLikesReturnPeersWhoLikeUser() {
        let manager = PeerManager()
        let myID = UUID()
        let liker = try! Peer(latitude: 0.0, longitude: 0.0, attributes: ["likes": myID.uuidString])
        let nonLiker = try! Peer(latitude: 0.0, longitude: 0.0)
        manager.add(liker)
        manager.add(nonLiker)
        manager.like(id: liker.id)
        manager.like(id: nonLiker.id)

        let matches = manager.mutualLikes(for: myID)
        XCTAssertEqual(matches, [liker])
    }

    func testBlockedPeersAreExcludedFromQueries() {
        let manager = PeerManager()
        let first = try! Peer(latitude: 0.0, longitude: 0.0)
        let second = try! Peer(latitude: 0.0, longitude: 0.0)
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
        let peer = try! Peer(latitude: 0.0, longitude: 0.0, lastSeen: oldDate)
        manager.add(peer)

        let success = manager.connect(to: peer.id)
        XCTAssertTrue(success)
        let updated = manager.peer(id: peer.id)
        XCTAssertNotEqual(updated?.lastSeen, oldDate)
    }

    func testConnectFailsForBlockedPeer() {
        let manager = PeerManager()
        let peer = try! Peer(latitude: 0.0, longitude: 0.0)
        manager.add(peer)
        manager.block(id: peer.id)

        XCTAssertFalse(manager.connect(to: peer.id))
    }

    func testGeohashEncoding() {
        let sf = try! Peer(latitude: 37.7749, longitude: -122.4194)
        XCTAssertEqual(sf.geohash, "9q8yyk8y")
    }

    func testPeersInGeohashPrefix() {
        let manager = PeerManager()
        let sf = try! Peer(latitude: 37.7749, longitude: -122.4194)
        let la = try! Peer(latitude: 34.0522, longitude: -118.2437)
        manager.add(sf)
        manager.add(la)

        let prefix = String(sf.geohash.prefix(5))
        let results = manager.peers(inGeohash: prefix)
        XCTAssertEqual(results, [sf])
    }

    func testPeersInShorterGeohashPrefix() {
        let manager = PeerManager()
        let sf = try! Peer(latitude: 37.7749, longitude: -122.4194)
        let la = try! Peer(latitude: 34.0522, longitude: -118.2437)
        manager.add(sf)
        manager.add(la)

        let shortPrefix = String(sf.geohash.prefix(3))
        let results = manager.peers(inGeohash: shortPrefix)
        XCTAssertTrue(results.contains(sf))
        XCTAssertFalse(results.contains(la))
    }

    func testPeersInLongerGeohashPrefix() {
        let manager = PeerManager()
        let first = try! Peer(latitude: 37.7749, longitude: -122.4194)
        let second = try! Peer(latitude: 37.7750, longitude: -122.4195)
        manager.add(first)
        manager.add(second)

        var prefixLength = 6
        while prefixLength <= first.geohash.count &&
              String(first.geohash.prefix(prefixLength)) == String(second.geohash.prefix(prefixLength)) {
            prefixLength += 1
        }
        XCTAssertLessThanOrEqual(prefixLength, first.geohash.count)
        XCTAssertGreaterThan(prefixLength, 5)

        let longPrefix = String(first.geohash.prefix(prefixLength))
        let results = manager.peers(inGeohash: longPrefix)
        XCTAssertEqual(results, [first])
    }


    func testPeersInGeohashPrefixWithAttributeFilter() {
        let manager = PeerManager()
        let sfHiker = try! Peer(latitude: 37.7749, longitude: -122.4194, attributes: ["hobby": "hiking"])
        let sfBaker = try! Peer(latitude: 37.7750, longitude: -122.4195, attributes: ["hobby": "baking"])
        let laHiker = try! Peer(latitude: 34.0522, longitude: -118.2437, attributes: ["hobby": "hiking"])
        manager.add(sfHiker)
        manager.add(sfBaker)
        manager.add(laHiker)

        let prefix = String(sfHiker.geohash.prefix(5))
        let results = manager.peers(inGeohash: prefix, matching: ["hobby": "hiking"])
        XCTAssertEqual(results, [sfHiker])
    }


    func testRecentPeersReturnsMostRecentFirst() {
        let manager = PeerManager()
        let older = try! Peer(latitude: 0.0, longitude: 0.0, lastSeen: Date(timeIntervalSinceNow: -3600))
        let newer = try! Peer(latitude: 0.0, longitude: 0.0)
        let blocked = try! Peer(latitude: 0.0, longitude: 0.0)

        manager.add(older)
        manager.add(newer)
        manager.add(blocked)
        manager.block(id: blocked.id)

        let results = manager.recentPeers(limit: 5)
        XCTAssertEqual(results, [newer, older])

    }

    /// Ensures the manager handles concurrent access without crashing or losing peers.
    func testConcurrentAccess() {
        let manager = PeerManager()
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .default)

        for _ in 0..<100 {
            group.enter()
            queue.async {
                let peer = try! Peer(latitude: 0.0, longitude: 0.0)
                manager.add(peer)
                group.leave()
            }
        }

        group.wait()
        XCTAssertEqual(manager.allPeers().count, 100)
    }

    /// Invokes `nearestPeers` while other threads mutate the manager to ensure thread safety.
    func testNearestPeersThreadSafetyDuringMutation() {
        let manager = PeerManager()
        let queue = DispatchQueue.global(qos: .default)
        let group = DispatchGroup()

        for _ in 0..<100 {
            group.enter()
            queue.async {
                let peer = try! Peer(latitude: 0.0, longitude: 0.0)
                manager.add(peer)
                group.leave()
            }

            group.enter()
            queue.async {
                _ = manager.nearestPeers(to: 0.0, longitude: 0.0, limit: 5)
                group.leave()
            }
        }

        group.wait()

        XCTAssertEqual(manager.allPeers().count, 100)
        XCTAssertLessThanOrEqual(manager.nearestPeers(to: 0.0, longitude: 0.0, limit: 5).count, 5)
    }
}
