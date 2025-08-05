import Foundation
import Logging

@main
struct Main {
    static func main() async {
        LoggingSystem.bootstrap(StreamLogHandler.standardError)
        let logger = Logger(label: "Main")

        // Demonstration of using the PeerManager alongside a libp2p-backed
        // networking node. The node bootstraps to a well known peer so it can
        // discover the rest of the network as soon as the app launches.
        let node = LibP2PNode(bootstrapPeers: ["bootstrap.weave.example:4001"])
        try? await node.start()

        let manager = PeerManager()

        // Assume the current user is in San Francisco
        let selfLat = 37.7749
        let selfLon = -122.4194

        let me = try! Peer(name: "Me", latitude: selfLat, longitude: selfLon, attributes: ["hobby": "hiking"])
        try? await manager.add(me)

#if canImport(CoreLocation)
        // Track the device's location and feed updates into the peer manager
        let locationService = CoreLocationService()
        locationService.onLocationUpdate = { lat, lon in
            Task {
                try? await manager.updateLocation(id: me.id, latitude: lat, longitude: lon)
            }
        }
        locationService.start()
        defer { locationService.stop() }
#endif

        // Add a peer in San Francisco
        let movingPeer = try! Peer(name: "Alice", latitude: 37.7750, longitude: -122.4183, attributes: ["hobby": "hiking", "likes": me.id.uuidString])
        try? await manager.add(movingPeer)

        // Add another peer in Los Angeles with the same hobby
        let laPeer = try! Peer(name: "Bob", latitude: 34.0522, longitude: -118.2437, attributes: ["hobby": "hiking"])

        try? await manager.add(laPeer)

        // Query peers sharing the same geohash prefix as the moving peer (coarse area
        // match) and demonstrate attribute filtering.
        let prefix = String(movingPeer.geohash.prefix(5))
        let geohashPeers = await manager.peers(inGeohash: prefix)
        logger.info("Peers in geohash prefix \(prefix): \(geohashPeers.count)")
        let hikingInPrefix = await manager.peers(inGeohash: prefix, matching: ["hobby": "hiking"])
        logger.info("Hiking peers in geohash prefix \(prefix): \(hikingInPrefix.count)")

        var nearbyPeers = await manager.peers(near: selfLat, longitude: selfLon, radius: 5000.0)
        logger.info("Peers within 5000km: \(nearbyPeers.count)")

        // Connect to the moving peer and refresh its last-seen timestamp
        if await manager.connect(to: movingPeer.id) {
            logger.info("Connected to moving peer")
        }

        // Like and then unlike the moving peer
        await manager.like(id: movingPeer.id)
        logger.info("Liked peers: \(await manager.likedPeers().count)")
        await manager.unlike(id: movingPeer.id)
        logger.info("Liked peers after unlike: \(await manager.likedPeers().count)")
        // Like again to demonstrate mutual match detection
        await manager.like(id: movingPeer.id)
        let mutual = await manager.mutualLikes(for: me.id)
        logger.info("Mutual matches: \(mutual.count)")

        // Block the Los Angeles peer
        await manager.block(id: laPeer.id)
        nearbyPeers = await manager.peers(near: selfLat, longitude: selfLon, radius: 5000.0)
        logger.info("Peers after blocking LA user: \(nearbyPeers.count)")

        // Update the peer's location to New York
        try? await manager.updateLocation(id: movingPeer.id, latitude: 40.7128, longitude: -74.0060)
        nearbyPeers = await manager.peers(near: selfLat, longitude: selfLon, radius: 5.0)
        logger.info("Nearby peers after move: \(nearbyPeers.count)")

        // Update the peer's network address
        await manager.updateAddress(id: movingPeer.id, address: "203.0.113.1", port: 8080)
        if let updated = await manager.peer(id: movingPeer.id) {
            logger.info("Peer network address: \(updated.address ?? "n/a"):\(updated.port ?? 0)")
        }

        // Change the peer's display name
        await manager.updateName(id: movingPeer.id, name: "Traveler")
        logger.info("Peer name after update: \(await manager.peer(id: movingPeer.id)?.name ?? "none")")

        // Update a single attribute and then remove it
        await manager.updateAttribute(id: movingPeer.id, key: "hobby", value: "climbing")
        logger.info("Updated hobby: \(await manager.peer(id: movingPeer.id)?.attributes["hobby"] ?? "none")")
        await manager.removeAttribute(id: movingPeer.id, key: "hobby")
        logger.info("Hobby after removal: \(await manager.peer(id: movingPeer.id)?.attributes["hobby"] ?? "none")")

        let hikers = await manager.peers(near: selfLat, longitude: selfLon, radius: 5000.0, matching: ["hobby": "hiking"])
        logger.info("Hikers within 5000km: \(hikers.count)")

        let matches = await manager.matchPeers(for: me, radius: 5000.0, limit: 5)
        logger.info("Top matches by hobby within 5000km: \(matches.count)")

        let nearestHikers = await manager.nearestPeers(to: selfLat,
                                                 longitude: selfLon,
                                                 limit: 3,
                                                 matching: ["hobby": "hiking"])
        logger.info("Nearest hikers: \(nearestHikers.count)")

        // Persist peers to disk and load them back
        let storeURL = URL(fileURLWithPath: "/tmp/peers.json")
        let store = PeerStore(url: storeURL)
        try? await manager.save(to: store)
        let restored = PeerManager()
        try? await restored.load(from: store)
        logger.info("Restored \(await restored.allPeers().count) peer(s) from disk (blocked peers excluded)")
        await restored.unblock(id: laPeer.id)
        logger.info("After unblocking LA user post-restore: \(await restored.allPeers().count) peer(s)")

        // Demonstrate pruning stale peers
        let stalePeer = try! Peer(latitude: 35.0, longitude: -120.0, lastSeen: Date(timeIntervalSinceNow: -7200))
        try? await manager.add(stalePeer)
        logger.info("Total peers before pruning: \(await manager.allPeers().count)")
        try? await manager.pruneStale(before: Date(timeIntervalSinceNow: -3600))
        logger.info("Peers after pruning stale entries: \(await manager.allPeers().count)")

        // Fetch the most recently seen peers
        let recent = await manager.recentPeers(limit: 2)
        logger.info("Most recently seen peers: \(recent.count)")

        await node.stop()
    }
}

