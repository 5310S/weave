import XCTest

import Foundation
@testable import weave

final class PeerManagerTests: XCTestCase {
    func testFiltersNearbyPeers() async {

        let manager = PeerManager()
        let userLocation = try! Peer(latitude: 37.7749, longitude: -122.4194)
        let nearby = try! Peer(latitude: 37.7750, longitude: -122.4195)
        let farAway = try! Peer(latitude: 40.7128, longitude: -74.0060)

        await manager.add(nearby)
        await manager.add(farAway)


        let filteredPeers = await manager.peers(near: userLocation.latitude, longitude: userLocation.longitude, radius: 10.0)
        XCTAssertTrue(filteredPeers.contains(nearby))
        XCTAssertFalse(filteredPeers.contains(farAway))
    }

    func testRemovingPeerUpdatesIndex() async {
        let manager = PeerManager()
        let peer = try! Peer(latitude: 37.0, longitude: -122.0)
        await manager.add(peer)
        XCTAssertEqual(await manager.allPeers().count, 1)
        let prefix = String(peer.geohash.prefix(5))
        XCTAssertEqual(await manager.peers(inGeohash: prefix), [peer])
        await manager.remove(id: peer.id)
        XCTAssertEqual(await manager.allPeers().count, 0)
        XCTAssertTrue(await manager.peers(inGeohash: prefix).isEmpty)
    }

    func testNearestPeersReturnsSortedResults() async {
        let manager = PeerManager()
        let origin = try! Peer(latitude: 0.0, longitude: 0.0)
        let nearer = try! Peer(latitude: 0.0, longitude: 0.05) // ~5.5km east
        let near = try! Peer(latitude: 0.0, longitude: 0.1)   // ~11km east

        await manager.add(near)
        await manager.add(nearer)

        let results = await manager.nearestPeers(to: origin.latitude, longitude: origin.longitude, limit: 2)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0], nearer)
        XCTAssertEqual(results[1], near)

    }

    func testNearestPeersRespectsAttributeFilters() async {
        let manager = PeerManager()
        let origin = try! Peer(latitude: 0.0, longitude: 0.0)
        let hikingPeer = try! Peer(latitude: 0.0, longitude: 0.05, attributes: ["hobby": "hiking"])
        let gamingPeer = try! Peer(latitude: 0.0, longitude: 0.02, attributes: ["hobby": "gaming"])

        await manager.add(hikingPeer)
        await manager.add(gamingPeer)

        let results = await manager.nearestPeers(to: origin.latitude,
                                           longitude: origin.longitude,
                                           limit: 5,
                                           matching: ["hobby": "hiking"])
        XCTAssertEqual(results, [hikingPeer])

    }

    func testNearestPeersMatchesNaiveImplementation() async {
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

        for peer in peers { await manager.add(peer) }

        let optimized = await manager.nearestPeers(to: originLat, longitude: originLon, limit: 5)

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

        let naive = await manager.allPeers().sorted {
            distance((originLat, originLon), ($0.latitude, $0.longitude)) <
            distance((originLat, originLon), ($1.latitude, $1.longitude))
        }

        XCTAssertEqual(optimized, Array(naive.prefix(5)))
    }

    func testAttributeFilteringReturnsMatches() async {
        let manager = PeerManager()
        let hiker = try! Peer(latitude: 0.0, longitude: 0.0, attributes: ["hobby": "hiking"])
        let gamer = try! Peer(latitude: 0.0, longitude: 0.0, attributes: ["hobby": "gaming"])

        await manager.add(hiker)
        await manager.add(gamer)

        let results = await manager.peers(near: 0.0, longitude: 0.0, radius: 1.0, matching: ["hobby": "hiking"])
        XCTAssertEqual(results, [hiker])

    }

    func testUpdatingPeerLocation() async {
        let manager = PeerManager()
        let peer = try! Peer(latitude: 0.0, longitude: 0.0)
        await manager.add(peer)
        let oldPrefix = String(peer.geohash.prefix(5))
        await manager.updateLocation(id: peer.id, latitude: 1.0, longitude: 1.0)
        let updated = await manager.peer(id: peer.id)!
        XCTAssertEqual(updated.latitude, 1.0)
        XCTAssertEqual(updated.longitude, 1.0)
        let newPrefix = String(updated.geohash.prefix(5))
        XCTAssertNotEqual(oldPrefix, newPrefix)
        XCTAssertTrue(await manager.peers(inGeohash: newPrefix).contains(updated))
        XCTAssertFalse(await manager.peers(inGeohash: oldPrefix).contains(updated))
    }


    func testUpdatingPeerAttributes() async {
        let manager = PeerManager()
        let peer = try! Peer(latitude: 0.0, longitude: 0.0, attributes: ["hobby": "gaming"])
        await manager.add(peer)
        await manager.updateAttributes(id: peer.id, attributes: ["hobby": "hiking"])
        let updated = await manager.peer(id: peer.id)
        XCTAssertEqual(updated?.attributes["hobby"], "hiking")
    }

    func testUpdatingSingleAttribute() async {
        let manager = PeerManager()
        let peer = try! Peer(latitude: 0.0, longitude: 0.0)
        await manager.add(peer)
        await manager.updateAttribute(id: peer.id, key: "hobby", value: "chess")
        let updated = await manager.peer(id: peer.id)
        XCTAssertEqual(updated?.attributes["hobby"], "chess")
    }

    func testRemovingAttribute() async {
        let manager = PeerManager()
        let peer = try! Peer(latitude: 0.0, longitude: 0.0, attributes: ["hobby": "chess"])
        await manager.add(peer)
        await manager.removeAttribute(id: peer.id, key: "hobby")
        let updated = await manager.peer(id: peer.id)
        XCTAssertNil(updated?.attributes["hobby"])
    }

    func testUpdatingPeerAddress() async {
        let manager = PeerManager()
        let peer = try! Peer(address: "1.2.3.4", port: 1000, latitude: 0.0, longitude: 0.0)
        await manager.add(peer)
        await manager.updateAddress(id: peer.id, address: "5.6.7.8", port: 2000)
        let updated = await manager.peer(id: peer.id)
        XCTAssertEqual(updated?.address, "5.6.7.8")
        XCTAssertEqual(updated?.port, 2000)
    }

    func testUpdatingPeerName() async {
        let manager = PeerManager()
        let peer = try! Peer(name: "Old", latitude: 0.0, longitude: 0.0)
        await manager.add(peer)
        await manager.updateName(id: peer.id, name: "New")
        let updated = await manager.peer(id: peer.id)
        XCTAssertEqual(updated?.name, "New")
        XCTAssertNotEqual(updated?.lastSeen, peer.lastSeen)
    }

    func testMatchPeersRanksByAttributeScoreThenDistance() async {
        let manager = PeerManager()
        let origin = try! Peer(latitude: 0.0, longitude: 0.0, attributes: ["hobby": "hiking"])
        let nearMatch = try! Peer(latitude: 0.0, longitude: 0.05, attributes: ["hobby": "hiking"])
        let farMatch = try! Peer(latitude: 0.0, longitude: 1.0, attributes: ["hobby": "hiking"])
        let nonMatch = try! Peer(latitude: 0.0, longitude: 0.05, attributes: ["hobby": "gaming"])

        await manager.add(nearMatch)
        await manager.add(farMatch)
        await manager.add(nonMatch)

        let matches = await manager.matchPeers(for: origin, radius: 2000.0, limit: 2)
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0], nearMatch)
        XCTAssertEqual(matches[1], farMatch)
    }

    func testPrunesStalePeers() async {
        let manager = PeerManager()
        let fresh = try! Peer(latitude: 0.0, longitude: 0.0)
        let stale = try! Peer(latitude: 0.0, longitude: 0.0, lastSeen: Date(timeIntervalSinceNow: -7200))
        await manager.add(fresh)
        await manager.add(stale)

        await manager.pruneStale(before: Date(timeIntervalSinceNow: -3600))

        XCTAssertEqual(await manager.allPeers(), [fresh])
    }

    func testPruneStaleRemovesLikedPeers() async {
        let manager = PeerManager()
        let fresh = try! Peer(latitude: 0.0, longitude: 0.0)
        let stale = try! Peer(latitude: 0.0, longitude: 0.0, lastSeen: Date(timeIntervalSinceNow: -7200))
        await manager.add(fresh)
        await manager.add(stale)
        await manager.like(id: fresh.id)
        await manager.like(id: stale.id)

        await manager.pruneStale(before: Date(timeIntervalSinceNow: -3600))

        XCTAssertEqual(await manager.likedPeers(), [fresh])
    }

    func testUpdateLastSeenChangesTimestamp() async {
        let manager = PeerManager()
        let oldDate = Date(timeIntervalSince1970: 0)
        let peer = try! Peer(latitude: 0.0, longitude: 0.0, lastSeen: oldDate)
        await manager.add(peer)

        let newDate = Date(timeIntervalSince1970: 100)
        await manager.updateLastSeen(id: peer.id, at: newDate)

        let updated = await manager.peer(id: peer.id)
        XCTAssertEqual(updated?.lastSeen, newDate)
    }

    func testPersistenceRoundTrip() async throws {
        let manager = PeerManager()
        let timestamp = Date(timeIntervalSince1970: 1234)
        let peer = try! Peer(latitude: 1.0, longitude: 2.0, lastSeen: timestamp)
        await manager.add(peer)

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let store = PeerStore(url: tmp)
        try await manager.save(to: store)

        let restored = PeerManager()
        try await restored.load(from: store)
        XCTAssertEqual(await restored.allPeers(), [peer])
        XCTAssertEqual(await restored.peer(id: peer.id)?.lastSeen, timestamp)
    }

    func testBlockedPeersPersistThroughStore() async throws {
        let manager = PeerManager()
        let peer = try! Peer(latitude: 0.0, longitude: 0.0)
        await manager.add(peer)
        await manager.block(id: peer.id)

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let store = PeerStore(url: tmp)
        try await manager.save(to: store)

        let restored = PeerManager()
        try await restored.load(from: store)

        XCTAssertEqual(await restored.allPeers().count, 0)
        await restored.unblock(id: peer.id)
        XCTAssertEqual(await restored.allPeers(), [peer])
    }

    func testLikedPeersAreReturned() async {
        let manager = PeerManager()
        let peer = try! Peer(latitude: 0.0, longitude: 0.0)
        await manager.add(peer)
        await manager.like(id: peer.id)

        XCTAssertEqual(await manager.likedPeers(), [peer])

        await manager.block(id: peer.id)
        XCTAssertTrue(await manager.likedPeers().isEmpty)
    }

    func testLikedPeersPersistThroughStore() async throws {
        let manager = PeerManager()
        let peer = try! Peer(latitude: 0.0, longitude: 0.0)
        await manager.add(peer)
        await manager.like(id: peer.id)

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let store = PeerStore(url: tmp)
        try await manager.save(to: store)

        let restored = PeerManager()
        try await restored.load(from: store)

        XCTAssertEqual(await restored.likedPeers(), [peer])
    }

    func testMutualLikesReturnPeersWhoLikeUser() async {
        let manager = PeerManager()
        let myID = UUID()
        let liker = try! Peer(latitude: 0.0, longitude: 0.0, attributes: ["likes": myID.uuidString])
        let nonLiker = try! Peer(latitude: 0.0, longitude: 0.0)
        await manager.add(liker)
        await manager.add(nonLiker)
        await manager.like(id: liker.id)
        await manager.like(id: nonLiker.id)

        let matches = await manager.mutualLikes(for: myID)
        XCTAssertEqual(matches, [liker])
    }

    func testBlockedPeersAreExcludedFromQueries() async {
        let manager = PeerManager()
        let first = try! Peer(latitude: 0.0, longitude: 0.0)
        let second = try! Peer(latitude: 0.0, longitude: 0.0)
        await manager.add(first)
        await manager.add(second)

        await manager.block(id: second.id)

        XCTAssertEqual(await manager.allPeers(), [first])
        XCTAssertFalse(await manager.peers(near: 0.0, longitude: 0.0, radius: 1.0).contains(second))

        await manager.unblock(id: second.id)
        let all = await manager.allPeers()
        XCTAssertTrue(all.contains(first))
        XCTAssertTrue(all.contains(second))
    }

    func testConnectUpdatesLastSeen() async {
        let manager = PeerManager()
        let oldDate = Date(timeIntervalSince1970: 0)
        let peer = try! Peer(latitude: 0.0, longitude: 0.0, lastSeen: oldDate)
        await manager.add(peer)

        let success = await manager.connect(to: peer.id)
        XCTAssertTrue(success)
        let updated = await manager.peer(id: peer.id)
        XCTAssertNotEqual(updated?.lastSeen, oldDate)
    }

    func testConnectFailsForBlockedPeer() async {
        let manager = PeerManager()
        let peer = try! Peer(latitude: 0.0, longitude: 0.0)
        await manager.add(peer)
        await manager.block(id: peer.id)

        XCTAssertFalse(await manager.connect(to: peer.id))
    }

    func testGeohashEncoding() async {
        let sf = try! Peer(latitude: 37.7749, longitude: -122.4194)
        XCTAssertEqual(sf.geohash, "9q8yyk8y")
    }

    func testPeersInGeohashPrefix() async {
        let manager = PeerManager()
        let sf = try! Peer(latitude: 37.7749, longitude: -122.4194)
        let la = try! Peer(latitude: 34.0522, longitude: -118.2437)
        await manager.add(sf)
        await manager.add(la)

        let prefix = String(sf.geohash.prefix(5))
        let results = await manager.peers(inGeohash: prefix)
        XCTAssertEqual(results, [sf])
    }

    func testPeersInShorterGeohashPrefix() async {
        let manager = PeerManager()
        let sf = try! Peer(latitude: 37.7749, longitude: -122.4194)
        let la = try! Peer(latitude: 34.0522, longitude: -118.2437)
        await manager.add(sf)
        await manager.add(la)

        let shortPrefix = String(sf.geohash.prefix(3))
        let results = await manager.peers(inGeohash: shortPrefix)
        XCTAssertTrue(results.contains(sf))
        XCTAssertFalse(results.contains(la))
    }

    func testPeersInLongerGeohashPrefix() async {
        let manager = PeerManager()
        let first = try! Peer(latitude: 37.7749, longitude: -122.4194)
        let second = try! Peer(latitude: 37.7750, longitude: -122.4195)
        await manager.add(first)
        await manager.add(second)

        var prefixLength = 6
        while prefixLength <= first.geohash.count &&
              String(first.geohash.prefix(prefixLength)) == String(second.geohash.prefix(prefixLength)) {
            prefixLength += 1
        }
        XCTAssertLessThanOrEqual(prefixLength, first.geohash.count)
        XCTAssertGreaterThan(prefixLength, 5)

        let longPrefix = String(first.geohash.prefix(prefixLength))
        let results = await manager.peers(inGeohash: longPrefix)
        XCTAssertEqual(results, [first])
    }


    func testPeersInGeohashPrefixWithAttributeFilter() async {
        let manager = PeerManager()
        let sfHiker = try! Peer(latitude: 37.7749, longitude: -122.4194, attributes: ["hobby": "hiking"])
        let sfBaker = try! Peer(latitude: 37.7750, longitude: -122.4195, attributes: ["hobby": "baking"])
        let laHiker = try! Peer(latitude: 34.0522, longitude: -118.2437, attributes: ["hobby": "hiking"])
        await manager.add(sfHiker)
        await manager.add(sfBaker)
        await manager.add(laHiker)

        let prefix = String(sfHiker.geohash.prefix(5))
        let results = await manager.peers(inGeohash: prefix, matching: ["hobby": "hiking"])
        XCTAssertEqual(results, [sfHiker])
    }


    func testRecentPeersReturnsMostRecentFirst() async {
        let manager = PeerManager()
        let older = try! Peer(latitude: 0.0, longitude: 0.0, lastSeen: Date(timeIntervalSinceNow: -3600))
        let newer = try! Peer(latitude: 0.0, longitude: 0.0)
        let blocked = try! Peer(latitude: 0.0, longitude: 0.0)

        await manager.add(older)
        await manager.add(newer)
        await manager.add(blocked)
        await manager.block(id: blocked.id)

        let results = await manager.recentPeers(limit: 5)
        XCTAssertEqual(results, [newer, older])

    }

    /// Ensures the manager handles concurrent access without crashing or losing peers.
    func testConcurrentAccess() async {
        let manager = PeerManager()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    let peer = try! Peer(latitude: 0.0, longitude: 0.0)
                    await manager.add(peer)
                }
            }
        }

        XCTAssertEqual(await manager.allPeers().count, 100)
    }

    /// Invokes `nearestPeers` while other tasks mutate the manager to ensure thread safety.
    func testNearestPeersThreadSafetyDuringMutation() async {
        let manager = PeerManager()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    let peer = try! Peer(latitude: 0.0, longitude: 0.0)
                    await manager.add(peer)
                }

                group.addTask {
                    _ = await manager.nearestPeers(to: 0.0, longitude: 0.0, limit: 5)
                }
            }
        }

        XCTAssertEqual(await manager.allPeers().count, 100)
        XCTAssertLessThanOrEqual(await manager.nearestPeers(to: 0.0, longitude: 0.0, limit: 5).count, 5)
    }
}
