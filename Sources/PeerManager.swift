import Foundation

/// Manages known peers and provides basic discovery utilities.
class PeerManager {
    private var peerIndex: [UUID: Peer] = [:]

    /// Adds or updates a peer in the manager.
    func add(_ peer: Peer) {
        peerIndex[peer.id] = peer
    }

    /// Removes a peer by id.
    func remove(id: UUID) {
        peerIndex.removeValue(forKey: id)
    }

    /// Returns all known peers.
    func allPeers() -> [Peer] {
        Array(peerIndex.values)
    }

    /// Returns peers within the given radius (in kilometers) of the provided location.
    /// Optional attribute filters can further restrict the results.
    func peers(near latitude: Double,
               longitude: Double,
               radius: Double,
               matching filters: [String: String] = [:]) -> [Peer] {
        return peerIndex.values.filter { peer in
            distance(from: (latitude, longitude), to: (peer.latitude, peer.longitude)) <= radius &&
            filters.allSatisfy { key, value in peer.attributes[key] == value }
        }
    }

    /// Returns up to `limit` peers sorted by proximity to the provided location.
    func nearestPeers(to latitude: Double, longitude: Double, limit: Int) -> [Peer] {
        let sorted = peerIndex.values.sorted {
            distance(from: (latitude, longitude), to: ($0.latitude, $0.longitude)) <
            distance(from: (latitude, longitude), to: ($1.latitude, $1.longitude))
        }
        return Array(sorted.prefix(limit))
    }

    /// Haversine distance between two coordinates in kilometers.
    private func distance(from: (Double, Double), to: (Double, Double)) -> Double {
        let earthRadiusKm = 6371.0
        let deltaLat = (to.0 - from.0) * Double.pi / 180
        let deltaLon = (to.1 - from.1) * Double.pi / 180
        let a = sin(deltaLat/2) * sin(deltaLat/2) +
                cos(from.0 * Double.pi / 180) * cos(to.0 * Double.pi / 180) *
                sin(deltaLon/2) * sin(deltaLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        return earthRadiusKm * c
    }
}
