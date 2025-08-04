import Foundation
import LibP2P

/// Errors that can occur when writing values to the DHT.
public enum DHTError: Error {
    /// Encoding the peer identifier set failed.
    case encodingFailed(Error)
    /// The underlying Kademlia `put` operation failed.
    case putFailed(Error)
}

/// Protocol describing a minimal distributed hash table used for peer discovery.
/// Implementations store peer IDs keyed by full geohashes and support lookups
/// by geohash prefix.
public protocol DHT {
    /// Stores the given peer identifier under the provided full geohash.
    func store(peerID: UUID, geohash: String) async throws

    /// Removes the peer identifier from the given geohash bucket.
    func remove(peerID: UUID, geohash: String) async throws

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

    public func store(peerID: UUID, geohash: String) async throws {
        for length in 1...geohash.count {
            let key = String(geohash.prefix(length))
            var bucket = index[key] ?? Set<UUID>()
            bucket.insert(peerID)
            index[key] = bucket
        }
    }

    public func remove(peerID: UUID, geohash: String) async throws {
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

/// Distributed hash table backed by libp2p's Kademlia implementation.
/// Peer identifiers are stored under their full geohash as well as all
/// geohash prefixes to allow efficient prefix lookups.
public actor LibP2PDHT: DHT {
    /// Underlying libp2p host instance.
    private let host: Host
    /// Kademlia DHT service provided by the host.
    private let kademlia: KademliaDHT

    /// Creates a new libp2p backed DHT. A host may be provided when
    /// integrating with an existing libp2p node. If omitted a fresh host is
    /// constructed using libp2p's default `HostBuilder` and started
    /// automatically.
    public init(host: Host? = nil) throws {
        if let host {
            self.host = host
            self.kademlia = host.kademlia
        } else {
            do {
                let built = try HostBuilder().build()
                _ = try built.start().wait()
                self.host = built
                self.kademlia = built.kademlia
            } catch {
                throw error
            }
        }
    }

    /// Connects this DHT's host to another peer in the network.
    public func bootstrap(to address: String) {
        if let addr = try? Multiaddr(address) {
            _ = try? host.bootstrap(to: addr).wait()
        }
    }

    /// The multiaddresses this host is currently listening on.
    public var listenAddresses: [String] {
        host.listenAddresses.map { $0.description }
    }

    public func store(peerID: UUID, geohash: String) async throws {
        for length in 1...geohash.count {
            let key = String(geohash.prefix(length))
            var set = await loadSet(for: key)
            set.insert(peerID)
            let data: Data
            do {
                data = try JSONEncoder().encode(Array(set))
            } catch {
                print("[DHT] Failed to encode peer set for key \(key): \(error)")
                throw DHTError.encodingFailed(error)
            }
            do {
                try await kademlia.put(key: key, value: data)
            } catch {
                print("[DHT] Failed to put peer set for key \(key): \(error)")
                throw DHTError.putFailed(error)
            }
        }
    }

    public func remove(peerID: UUID, geohash: String) async throws {
        for length in 1...geohash.count {
            let key = String(geohash.prefix(length))
            var set = await loadSet(for: key)
            set.remove(peerID)
            let data: Data
            do {
                data = try JSONEncoder().encode(Array(set))
            } catch {
                print("[DHT] Failed to encode peer set for key \(key): \(error)")
                throw DHTError.encodingFailed(error)
            }
            do {
                try await kademlia.put(key: key, value: data)
            } catch {
                print("[DHT] Failed to put peer set for key \(key): \(error)")
                throw DHTError.putFailed(error)
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

