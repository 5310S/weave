import Foundation
#if canImport(LibP2P)
import LibP2P
#endif

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

/// Simple in-memory DHT implementation used for testing. This actor
/// maintains a dictionary mapping geohash prefixes to the set of peer
/// identifiers stored under that prefix. Peers are indexed under their full
/// geohash as well as all prefixes, mirroring the behavior of the libp2p
/// backed implementation.
public actor InMemoryDHT: DHT {
    private var index: [String: Set<UUID>] = [:]

    public init() {}

    public func store(peerID: UUID, geohash: String) async {
        for length in 1...geohash.count {
            let key = String(geohash.prefix(length))
            var bucket = index[key] ?? Set<UUID>()
            bucket.insert(peerID)
            index[key] = bucket
        }
    }

    public func remove(peerID: UUID, geohash: String) async {
        for length in 1...geohash.count {
            let key = String(geohash.prefix(length))
            guard var bucket = index[key] else { continue }
            bucket.remove(peerID)
            if bucket.isEmpty {
                index.removeValue(forKey: key)
            } else {
                index[key] = bucket
            }
        }
    }

    public func lookup(prefix: String) async -> [UUID] {
        Array(index[prefix] ?? [])
    }
}

#if canImport(LibP2P)
/// Distributed hash table backed by libp2p's Kademlia implementation.
/// Peer identifiers are stored under their full geohash as well as all
/// geohash prefixes to allow efficient prefix lookups.
public actor LibP2PDHT: DHT {
    /// Underlying Kademlia DHT instance.
    private let kademlia: KademliaDHT

    /// Creates a new libp2p backed DHT. A host may be provided when
    /// integrating with an existing libp2p node. If omitted a fresh host is
    /// constructed using libp2p's default `HostBuilder`.
    public init(host: Host? = nil) {
        if let host {
            self.kademlia = host.kademlia
        } else {
            let built = try! HostBuilder().build()
            self.kademlia = built.kademlia
        }
    }

    public func store(peerID: UUID, geohash: String) async {
        for length in 1...geohash.count {
            let key = String(geohash.prefix(length))
            var set = await loadSet(for: key)
            set.insert(peerID)
            if let data = try? JSONEncoder().encode(Array(set)) {
                _ = try? await kademlia.put(key: key, value: data)
            }
        }
    }

    public func remove(peerID: UUID, geohash: String) async {
        for length in 1...geohash.count {
            let key = String(geohash.prefix(length))
            var set = await loadSet(for: key)
            set.remove(peerID)
            if let data = try? JSONEncoder().encode(Array(set)) {
                _ = try? await kademlia.put(key: key, value: data)
            }
        }
    }

    public func lookup(prefix: String) async -> [UUID] {
        let set = await loadSet(for: prefix)
        return Array(set)
    }

    /// Retrieves the set of peer identifiers stored for the given key.
    private func loadSet(for key: String) async -> Set<UUID> {
        guard let data = try? await kademlia.get(key: key),
              let decoded = try? JSONDecoder().decode([UUID].self, from: data) else {
            return []
        }
        return Set(decoded)
    }
}
#else
/// Fallback no-op implementation used when libp2p is unavailable. This allows
/// the package to build on platforms where the libp2p dependency cannot be
/// resolved (such as the testing environment).
public actor LibP2PDHT: DHT {
    public init() {}
    public func store(peerID: UUID, geohash: String) async {}
    public func remove(peerID: UUID, geohash: String) async {}
    public func lookup(prefix: String) async -> [UUID] { [] }
}
#endif

