import Foundation

// Demonstration of using the PeerManager alongside a placeholder
// networking node that will eventually speak libp2p.
let node = P2PNode(bootstrapPeers: ["bootstrap.weave.example:4001"])
node.start()
defer { node.stop() }
let manager = PeerManager()

// Assume the current user is in San Francisco
let selfLat = 37.7749
let selfLon = -122.4194
let me = Peer(name: "Me", latitude: selfLat, longitude: selfLon, attributes: ["hobby": "hiking"])

// Add a peer in San Francisco
let movingPeer = Peer(name: "Alice", latitude: 37.7750, longitude: -122.4183, attributes: ["hobby": "hiking", "likes": me.id.uuidString])
manager.add(movingPeer)

// Add another peer in Los Angeles with the same hobby
let laPeer = Peer(name: "Bob", latitude: 34.0522, longitude: -118.2437, attributes: ["hobby": "hiking"])
manager.add(laPeer)

// Query peers sharing the same geohash prefix as the moving peer (coarse area match)
let prefix = String(movingPeer.geohash.prefix(5))
let geohashPeers = manager.peers(inGeohash: prefix)
print("Peers in geohash prefix \(prefix): \(geohashPeers.count)")

var nearbyPeers = manager.peers(near: selfLat, longitude: selfLon, radius: 5000.0)
print("Peers within 5000km: \(nearbyPeers.count)")

// Connect to the moving peer and refresh its last-seen timestamp
if manager.connect(to: movingPeer.id) {
    print("Connected to moving peer")
}

// Like and then unlike the moving peer
manager.like(id: movingPeer.id)
print("Liked peers: \(manager.likedPeers().count)")
manager.unlike(id: movingPeer.id)
print("Liked peers after unlike: \(manager.likedPeers().count)")
// Like again to demonstrate mutual match detection
manager.like(id: movingPeer.id)
let mutual = manager.mutualLikes(for: me.id)
print("Mutual matches: \(mutual.count)")

// Block the Los Angeles peer
manager.block(id: laPeer.id)
nearbyPeers = manager.peers(near: selfLat, longitude: selfLon, radius: 5000.0)
print("Peers after blocking LA user: \(nearbyPeers.count)")

// Update the peer's location to New York
manager.updateLocation(id: movingPeer.id, latitude: 40.7128, longitude: -74.0060)
nearbyPeers = manager.peers(near: selfLat, longitude: selfLon, radius: 5.0)
print("Nearby peers after move: \(nearbyPeers.count)")

// Update the peer's network address
manager.updateAddress(id: movingPeer.id, address: "203.0.113.1", port: 8080)
if let updated = manager.peer(id: movingPeer.id) {
    print("Peer network address: \(updated.address ?? "n/a"):\(updated.port ?? 0)")
}

// Change the peer's display name
manager.updateName(id: movingPeer.id, name: "Traveler")
print("Peer name after update: \(manager.peer(id: movingPeer.id)?.name ?? "none")")

// Update a single attribute and then remove it
manager.updateAttribute(id: movingPeer.id, key: "hobby", value: "climbing")
print("Updated hobby: \(manager.peer(id: movingPeer.id)?.attributes["hobby"] ?? "none")")
manager.removeAttribute(id: movingPeer.id, key: "hobby")
print("Hobby after removal: \(manager.peer(id: movingPeer.id)?.attributes["hobby"] ?? "none")")

let hikers = manager.peers(near: selfLat, longitude: selfLon, radius: 5000.0, matching: ["hobby": "hiking"])
print("Hikers within 5000km: \(hikers.count)")

let matches = manager.matchPeers(for: me, radius: 5000.0, limit: 5)
print("Top matches by hobby within 5000km: \(matches.count)")

let nearestHikers = manager.nearestPeers(to: selfLat,
                                         longitude: selfLon,
                                         limit: 3,
                                         matching: ["hobby": "hiking"])
print("Nearest hikers: \(nearestHikers.count)")

// Persist peers to disk and load them back
let storeURL = URL(fileURLWithPath: "/tmp/peers.json")
let store = PeerStore(url: storeURL)
try? manager.save(to: store)
let restored = PeerManager()
try? restored.load(from: store)
print("Restored \(restored.allPeers().count) peer(s) from disk (blocked peers excluded)")
restored.unblock(id: laPeer.id)
print("After unblocking LA user post-restore: \(restored.allPeers().count) peer(s)")

// Demonstrate pruning stale peers
let stalePeer = Peer(latitude: 35.0, longitude: -120.0, lastSeen: Date(timeIntervalSinceNow: -7200))
manager.add(stalePeer)
print("Total peers before pruning: \(manager.allPeers().count)")
manager.pruneStale(before: Date(timeIntervalSinceNow: -3600))
print("Peers after pruning stale entries: \(manager.allPeers().count)")

// Fetch the most recently seen peers
let recent = manager.recentPeers(limit: 2)
print("Most recently seen peers: \(recent.count)")
