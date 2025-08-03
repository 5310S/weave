import Foundation

// Demonstration of using the PeerManager. In the future this will
// integrate with libp2p for real peer discovery and messaging.
let manager = PeerManager()

// Assume the current user is in San Francisco
let selfLat = 37.7749
let selfLon = -122.4194

// Add a nearby peer and a distant peer
manager.add(Peer(latitude: 37.7750, longitude: -122.4183)) // within ~0.1km
manager.add(Peer(latitude: 40.7128, longitude: -74.0060))   // New York

let nearbyPeers = manager.peers(near: selfLat, longitude: selfLon, radius: 5.0)
print("Discovered \(nearbyPeers.count) nearby peer(s)")
