import Foundation

/// Manages known peers and provides basic discovery utilities.
class PeerManager {
    private var peerIndex: [UUID: Peer] = [:]
    private var blocked: Set<UUID> = []

    /// Marks a peer as blocked, excluding it from discovery APIs.
    func block(id: UUID) {
        blocked.insert(id)
    }

    /// Removes a peer from the blocked list.
    func unblock(id: UUID) {
        blocked.remove(id)
    }

    /// Adds or updates a peer in the manager.
    func add(_ peer: Peer) {
        peerIndex[peer.id] = peer
    }

    /// Removes a peer by id.
    func remove(id: UUID) {
        peerIndex.removeValue(forKey: id)
        blocked.remove(id)
    }

    /// Returns the peer with the given id, if present.
    func peer(id: UUID) -> Peer? {
        peerIndex[id]
    }

    /// Updates a peer's geographic location if it exists in the manager.
    func updateLocation(id: UUID, latitude: Double, longitude: Double) {
        guard var peer = peerIndex[id] else { return }
        peer.latitude = latitude
        peer.longitude = longitude
        peer.lastSeen = Date()
        peerIndex[id] = peer
    }

    /// Replaces a peer's attributes dictionary if it exists in the manager.
    func updateAttributes(id: UUID, attributes: [String: String]) {
        guard var peer = peerIndex[id] else { return }
        peer.attributes = attributes
        peer.lastSeen = Date()
        peerIndex[id] = peer
    }

    /// Sets or replaces a single attribute on the peer if present.
    func updateAttribute(id: UUID, key: String, value: String) {
        guard var peer = peerIndex[id] else { return }
        peer.attributes[key] = value
        peer.lastSeen = Date()
        peerIndex[id] = peer
    }

    /// Removes a single attribute from the peer if present.
    func removeAttribute(id: UUID, key: String) {
        guard var peer = peerIndex[id] else { return }
        peer.attributes.removeValue(forKey: key)
        peer.lastSeen = Date()
        peerIndex[id] = peer
    }

    /// Updates a peer's network address and port if it exists in the manager.
    func updateAddress(id: UUID, address: String?, port: UInt16?) {
        guard var peer = peerIndex[id] else { return }
        peer.address = address
        peer.port = port
        peer.lastSeen = Date()
        peerIndex[id] = peer
    }

    /// Updates the last-seen timestamp for the given peer to the provided date (defaults to now).
    func updateLastSeen(id: UUID, at date: Date = Date()) {
        guard var peer = peerIndex[id] else { return }
        peer.lastSeen = date
        peerIndex[id] = peer
    }

    /// Simulates connecting to the peer with the given id. Returns `true` if the
    /// peer exists and is not blocked. A successful connection refreshes the
    /// peer's last-seen timestamp.
    func connect(to id: UUID) -> Bool {
        guard var peer = peerIndex[id], !blocked.contains(id) else { return false }
        peer.lastSeen = Date()
        peerIndex[id] = peer
        return true
    }

    /// Returns all known peers.
    func allPeers() -> [Peer] {
        peerIndex.values.filter { !blocked.contains($0.id) }
    }

    /// Returns peers within the given radius (in kilometers) of the provided location.
    /// Optional attribute filters can further restrict the results.
    func peers(near latitude: Double,
               longitude: Double,
               radius: Double,
               matching filters: [String: String] = [:]) -> [Peer] {
        return peerIndex.values.filter { peer in
            !blocked.contains(peer.id) &&
            distance(from: (latitude, longitude), to: (peer.latitude, peer.longitude)) <= radius &&
            filters.allSatisfy { key, value in peer.attributes[key] == value }
        }
    }

    /// Returns up to `limit` peers sorted by proximity to the provided location.
    func nearestPeers(to latitude: Double, longitude: Double, limit: Int) -> [Peer] {
        let sorted = peerIndex.values
            .filter { !blocked.contains($0.id) }
            .sorted {
                distance(from: (latitude, longitude), to: ($0.latitude, $0.longitude)) <
                distance(from: (latitude, longitude), to: ($1.latitude, $1.longitude))
            }
        return Array(sorted.prefix(limit))
    }

    /// Returns up to `limit` peers within `radius` kilometers of the given peer,
    /// ranked first by number of matching attribute key/value pairs and then by
    /// proximity (closest first).
    func matchPeers(for peer: Peer, radius: Double, limit: Int) -> [Peer] {
        let results: [(peer: Peer, score: Int, distance: Double)] = peerIndex.values.compactMap { candidate in
            guard candidate.id != peer.id, !blocked.contains(candidate.id) else { return nil }
            let dist = distance(from: (peer.latitude, peer.longitude), to: (candidate.latitude, candidate.longitude))
            guard dist <= radius else { return nil }

            let score = peer.attributes.reduce(0) { acc, pair in
                acc + (candidate.attributes[pair.key] == pair.value ? 1 : 0)
            }
            return (candidate, score, dist)
        }

        return results
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.distance < rhs.distance
                } else {
                    return lhs.score > rhs.score
                }
            }
            .prefix(limit)
            .map { $0.peer }
    }

    /// Removes peers that were last seen before the provided cutoff date.
    func pruneStale(before cutoff: Date) {
        peerIndex = peerIndex.filter { $0.value.lastSeen >= cutoff }
        blocked = blocked.filter { peerIndex[$0] != nil }
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

    /// Persists all known peers using the provided store.
    func save(to store: PeerStore) throws {
        try store.save(Array(peerIndex.values))
    }

    /// Loads peers from the provided store, replacing any existing peers.
    func load(from store: PeerStore) throws {
        let peers = try store.load()
        peerIndex = Dictionary(uniqueKeysWithValues: peers.map { ($0.id, $0) })
        blocked = blocked.filter { peerIndex[$0] != nil }
    }
}
