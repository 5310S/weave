import Foundation

/// Protocol describing a minimal distributed hash table used for peer discovery.
/// Implementations store peer IDs keyed by full geohashes and support lookups
/// by geohash prefix.
public protocol DHT {
    /// Stores the given peer identifier under the provided full geohash.
    func store(peerID: UUID, geohash: String) async

    /// Removes the peer identifier from the given geohash bucket.
    func remove(peerID: UUID, geohash: String) async

    /// Returns all peer identifiers whose stored geohash begins with the prefix.
    func lookup(prefix: String) async -> [UUID]
}

/// Simple in-memory DHT implementation used for testing. This actor maintains
/// a dictionary mapping full geohashes to the set of peer identifiers within
/// that cell.
public actor InMemoryDHT: DHT {
    private var index: [String: Set<UUID>] = [:]

    public init() {}

    public func store(peerID: UUID, geohash: String) async {
        var bucket = index[geohash] ?? Set<UUID>()
        bucket.insert(peerID)
        index[geohash] = bucket
    }

    public func remove(peerID: UUID, geohash: String) async {
        guard var bucket = index[geohash] else { return }
        bucket.remove(peerID)
        if bucket.isEmpty {
            index.removeValue(forKey: geohash)
        } else {
            index[geohash] = bucket
        }
    }

    public func lookup(prefix: String) async -> [UUID] {
        index.reduce(into: [UUID]()) { result, entry in
            if entry.key.hasPrefix(prefix) {
                result.append(contentsOf: entry.value)
            }
        }
    }
}

