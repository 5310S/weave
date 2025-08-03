import Foundation

// Demonstration of using the PeerManager. In the future this will
// integrate with libp2p for real peer discovery and messaging.
let manager = PeerManager()

// Assume the current user is in San Francisco
let selfLat = 37.7749
let selfLon = -122.4194
let me = Peer(latitude: selfLat, longitude: selfLon, attributes: ["hobby": "hiking"])

// Add a peer in San Francisco
let movingPeer = Peer(latitude: 37.7750, longitude: -122.4183, attributes: ["hobby": "hiking"])
manager.add(movingPeer)

// Add another peer in Los Angeles with the same hobby
let laPeer = Peer(latitude: 34.0522, longitude: -118.2437, attributes: ["hobby": "hiking"])
manager.add(laPeer)

var nearbyPeers = manager.peers(near: selfLat, longitude: selfLon, radius: 5.0)
print("Discovered \(nearbyPeers.count) nearby peer(s)")

// Update the peer's location to New York
manager.updateLocation(id: movingPeer.id, latitude: 40.7128, longitude: -74.0060)
nearbyPeers = manager.peers(near: selfLat, longitude: selfLon, radius: 5.0)
print("Nearby peers after move: \(nearbyPeers.count)")

let hikers = manager.peers(near: selfLat, longitude: selfLon, radius: 5000.0, matching: ["hobby": "hiking"])
print("Hikers within 5000km: \(hikers.count)")

let matches = manager.matchPeers(for: me, radius: 5000.0, limit: 5)
print("Top matches by hobby within 5000km: \(matches.count)")

// Persist peers to disk and load them back
let storeURL = URL(fileURLWithPath: "/tmp/peers.json")
let store = PeerStore(url: storeURL)
try? manager.save(to: store)
let restored = PeerManager()
try? restored.load(from: store)
print("Restored \(restored.allPeers().count) peer(s) from disk")
