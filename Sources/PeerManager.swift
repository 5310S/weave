import Foundation
import Dispatch

/// Manages known peers and provides basic discovery utilities.
final class PeerManager: @unchecked Sendable {

    private var peerIndex: [UUID: Peer] = [:]
    private var blocked: Set<UUID> = []
    private var liked: Set<UUID> = []
    /// Maps full geohashes to the IDs of peers within that cell.
    private var geohashIndex: [String: Set<UUID>] = [:]
    private let queue = DispatchQueue(label: "PeerManager.queue", attributes: .concurrent)

    /// Marks a peer as blocked, excluding it from discovery APIs.
    func block(id: UUID) {
        queue.sync(flags: .barrier) {
            blocked.insert(id)
            liked.remove(id)
        }
    }

    /// Removes a peer from the blocked list.
    func unblock(id: UUID) {
        _ = queue.sync(flags: .barrier) {
            blocked.remove(id)
        }
    }

    /// Marks a peer as liked if it exists and is not blocked.
    func like(id: UUID) {
        queue.sync(flags: .barrier) {
            guard peerIndex[id] != nil, !blocked.contains(id) else { return }
            liked.insert(id)
        }
    }

    /// Removes a peer from the liked list.
    func unlike(id: UUID) {
        _ = queue.sync(flags: .barrier) {
            liked.remove(id)
        }
    }

    /// Returns all liked peers that are not currently blocked.
    func likedPeers() -> [Peer] {
        queue.sync {
            liked.compactMap { peerIndex[$0] }.filter { !blocked.contains($0.id) }
        }
    }

    /// Returns liked peers that have indicated they like the given user.
    /// A peer is considered a mutual match if its attributes contain the
    /// provided `userID` under the key "likes".
    func mutualLikes(for userID: UUID) -> [Peer] {
        queue.sync {
            liked.compactMap { peerIndex[$0] }
                .filter { $0.attributes["likes"] == userID.uuidString && !blocked.contains($0.id) }
        }
    }


    /// Adds or updates a peer in the manager.
    func add(_ peer: Peer) {
        queue.sync(flags: .barrier) {
            if let existing = peerIndex[peer.id] {
                let oldKey = existing.geohash
                if var bucket = geohashIndex[oldKey] {
                    bucket.remove(peer.id)
                    if bucket.isEmpty {
                        geohashIndex.removeValue(forKey: oldKey)
                    } else {
                        geohashIndex[oldKey] = bucket
                    }
                }
            }
            peerIndex[peer.id] = peer
            let key = peer.geohash
            var bucket = geohashIndex[key] ?? Set<UUID>()
            bucket.insert(peer.id)
            geohashIndex[key] = bucket
        }
    }

    /// Removes a peer by id.
    func remove(id: UUID) {
        queue.sync(flags: .barrier) {
            if let peer = peerIndex.removeValue(forKey: id) {
                let key = peer.geohash
                if var bucket = geohashIndex[key] {
                    bucket.remove(id)
                    if bucket.isEmpty {
                        geohashIndex.removeValue(forKey: key)
                    } else {
                        geohashIndex[key] = bucket
                    }
                }
            }
            blocked.remove(id)
            liked.remove(id)
        }
    }

    /// Returns the peer with the given id, if present.
    func peer(id: UUID) -> Peer? {
        queue.sync {
            peerIndex[id]
        }
    }

    /// Updates a peer's geographic location if it exists in the manager.
    func updateLocation(id: UUID, latitude: Double, longitude: Double) {
        queue.sync(flags: .barrier) {
            guard var peer = peerIndex[id],
                  (-90.0...90.0).contains(latitude),
                  (-180.0...180.0).contains(longitude) else { return }
            let oldKey = peer.geohash
            peer.latitude = latitude
            peer.longitude = longitude
            peer.lastSeen = Date()
            peerIndex[id] = peer
            let newKey = peer.geohash
            if oldKey != newKey {
                if var bucket = geohashIndex[oldKey] {
                    bucket.remove(id)
                    if bucket.isEmpty {
                        geohashIndex.removeValue(forKey: oldKey)
                    } else {
                        geohashIndex[oldKey] = bucket
                    }
                }
                var newBucket = geohashIndex[newKey] ?? Set<UUID>()
                newBucket.insert(id)
                geohashIndex[newKey] = newBucket
            }
        }
    }

    /// Replaces a peer's attributes dictionary if it exists in the manager.
    func updateAttributes(id: UUID, attributes: [String: String]) {
        queue.sync(flags: .barrier) {
            guard var peer = peerIndex[id] else { return }
            peer.attributes = attributes
            peer.lastSeen = Date()
            peerIndex[id] = peer
        }
    }

    /// Sets or replaces a single attribute on the peer if present.
    func updateAttribute(id: UUID, key: String, value: String) {
        queue.sync(flags: .barrier) {
            guard var peer = peerIndex[id] else { return }
            peer.attributes[key] = value
            peer.lastSeen = Date()
            peerIndex[id] = peer
        }
    }

    /// Removes a single attribute from the peer if present.
    func removeAttribute(id: UUID, key: String) {
        queue.sync(flags: .barrier) {
            guard var peer = peerIndex[id] else { return }
            peer.attributes.removeValue(forKey: key)
            peer.lastSeen = Date()
            peerIndex[id] = peer
        }
    }

    /// Updates a peer's network address and port if it exists in the manager.
    func updateAddress(id: UUID, address: String?, port: UInt16?) {
        queue.sync(flags: .barrier) {
            guard var peer = peerIndex[id] else { return }
            peer.address = address
            peer.port = port
            peer.lastSeen = Date()
            peerIndex[id] = peer
        }
    }

    /// Updates a peer's display name if it exists in the manager.
    func updateName(id: UUID, name: String?) {
        queue.sync(flags: .barrier) {
            guard var peer = peerIndex[id] else { return }
            peer.name = name
            peer.lastSeen = Date()
            peerIndex[id] = peer
        }
    }

    /// Updates the last-seen timestamp for the given peer to the provided date (defaults to now).
    func updateLastSeen(id: UUID, at date: Date = Date()) {
        queue.sync(flags: .barrier) {
            guard var peer = peerIndex[id] else { return }
            peer.lastSeen = date
            peerIndex[id] = peer
        }
    }

    /// Simulates connecting to the peer with the given id. Returns `true` if the
    /// peer exists and is not blocked. A successful connection refreshes the
    /// peer's last-seen timestamp.
    func connect(to id: UUID) -> Bool {
        queue.sync(flags: .barrier) {
            guard var peer = peerIndex[id], !blocked.contains(id) else { return false }
            peer.lastSeen = Date()
            peerIndex[id] = peer
            return true
        }
    }

    /// Returns all known peers.
    func allPeers() -> [Peer] {
        queue.sync {
            peerIndex.values.filter { !blocked.contains($0.id) }
        }
    }

    /// Returns peers within the given radius (in kilometers) of the provided location.
    /// Optional attribute filters can further restrict the results.
    func peers(near latitude: Double,
               longitude: Double,
               radius: Double,
               matching filters: [String: String] = [:]) -> [Peer] {
        queue.sync {
            peerIndex.values.filter { peer in
                !blocked.contains(peer.id) &&
                distance(from: (latitude, longitude), to: (peer.latitude, peer.longitude)) <= radius &&
                filters.allSatisfy { key, value in peer.attributes[key] == value }
            }
        }
    }


    /// Returns peers whose geohash begins with the specified prefix. Useful for
    /// coarse location-based grouping using geohash bucketing.
    func peers(inGeohash prefix: String) -> [Peer] {
        peers(inGeohash: prefix, matching: [:])
    }


    /// Returns peers in the specified geohash prefix that match all provided
    /// attribute filters.
    func peers(inGeohash prefix: String, matching filters: [String: String]) -> [Peer] {
        queue.sync {
            let ids = geohashIndex.reduce(into: Set<UUID>()) { result, entry in
                if entry.key.hasPrefix(prefix) {
                    result.formUnion(entry.value)
                }
            }
            return ids.compactMap { id in
                guard let peer = peerIndex[id],
                      !blocked.contains(id),
                      peer.geohash.hasPrefix(prefix),
                      filters.allSatisfy({ k, v in peer.attributes[k] == v })
                else { return nil }
                return peer
            }
        }
    }

    /// Returns up to `limit` peers sorted by proximity to the provided location.
    /// Optional attribute filters can restrict the results to peers matching all
    /// specified key/value pairs.
    func nearestPeers(to latitude: Double,
                      longitude: Double,
                      limit: Int,
                      matching filters: [String: String] = [:]) -> [Peer] {
        queue.sync {
            let candidates = peerIndex.values
                .filter { peer in
                    !blocked.contains(peer.id) &&
                    filters.allSatisfy { key, value in peer.attributes[key] == value }
                }
                .map { peer -> (peer: Peer, distance: Double) in
                    let dist = distance(from: (latitude, longitude),
                                        to: (peer.latitude, peer.longitude))
                    return (peer, dist)
                }
                .sorted { $0.distance < $1.distance }

            return candidates.prefix(limit).map { $0.peer }
        }
    }

    /// Returns up to `limit` most recently seen peers, excluding any that are blocked.
    func recentPeers(limit: Int) -> [Peer] {
        queue.sync {
            let sorted = peerIndex.values
                .filter { !blocked.contains($0.id) }
                .sorted { $0.lastSeen > $1.lastSeen }
            return Array(sorted.prefix(limit))
        }
    }

    /// Returns up to `limit` peers within `radius` kilometers of the given peer,
    /// ranked first by number of matching attribute key/value pairs and then by
    /// proximity (closest first).
    func matchPeers(for peer: Peer, radius: Double, limit: Int) -> [Peer] {
        queue.sync {
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
    }

    /// Removes peers that were last seen before the provided cutoff date.
    func pruneStale(before cutoff: Date) {

        queue.sync(flags: .barrier) {
            peerIndex = peerIndex.filter { $0.value.lastSeen >= cutoff }
            blocked = blocked.filter { peerIndex[$0] != nil }

            liked = liked.filter { peerIndex[$0] != nil && !blocked.contains($0) }
            geohashIndex = Dictionary(grouping: peerIndex.values, by: { $0.geohash })
                .mapValues { Set($0.map { $0.id }) }

        }

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

    /// Persists all known peers along with blocked and liked IDs using the provided store.
    func save(to store: PeerStore) throws {
        let snapshot = queue.sync { (Array(peerIndex.values), Array(blocked), Array(liked)) }
        try store.save(peers: snapshot.0,
                      blocked: snapshot.1,
                      liked: snapshot.2)
    }

    /// Loads peers (and blocked/liked IDs) from the provided store, replacing any existing data.
    func load(from store: PeerStore) throws {
        let snapshot = try store.load()
        queue.sync(flags: .barrier) {
            peerIndex = Dictionary(uniqueKeysWithValues: snapshot.peers.map { ($0.id, $0) })
            blocked = Set(snapshot.blocked.filter { peerIndex[$0] != nil })
            liked = Set(snapshot.liked.filter { peerIndex[$0] != nil && !blocked.contains($0) })
            geohashIndex = Dictionary(grouping: snapshot.peers, by: { $0.geohash })
                .mapValues { Set($0.map { $0.id }) }
        }
    }

}
