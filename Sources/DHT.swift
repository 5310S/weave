import Foundation
import LibP2P
import LibP2PCore
import Logging
#if canImport(NIO)
import NIO
#endif
#if canImport(LibP2PKademlia)
import LibP2PKademlia
#elseif canImport(Kademlia)
import Kademlia
#endif

/// Errors that can occur when writing values to the DHT.
public enum DHTError: Error, Sendable {
    /// Encoding the peer identifier set failed.
    case encodingFailed(Error)
    /// The underlying Kademlia `put` operation failed.
    case putFailed(Error)
}

/// Protocol describing a minimal distributed hash table used for peer discovery.
/// Implementations store peer IDs keyed by full geohashes and support lookups
/// by geohash prefix.
public protocol DHT: Sendable {
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
public actor InMemoryDHT: DHT, Sendable {
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
public actor LibP2PDHT: DHT, Sendable {
    /// Transport driving libp2p networking.
    private let transport: LibP2PCore.Transport
    /// Host managing connections and protocols.
    private let host: LibP2PCore.Host
    /// Kademlia DHT service running on the host.
    private let kademlia: KademliaDHT
    /// Event loop group backing the transport manager.
    private let group: EventLoopGroup
    /// Logger for reporting DHT operations.
    private let logger = Logger(label: "DHT")

    /// Creates a new libp2p backed DHT. A fresh transport and host are
    /// constructed and started using the modern libp2p APIs.
    public init() throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.group = group

        let transport = LibP2PCore.Transport(group: group)
        self.transport = transport

        let host = try LibP2PCore.Host(transport: transport)
        self.host = host

        self.kademlia = KademliaDHT(host: host)

        // Start the transport and host. The modern API uses synchronous
        // start methods which may throw.
        try transport.start()
        try host.start()
    }

    deinit {
        // Stop the transport and shut down the underlying event loops.
        try? transport.close()
        try? group.syncShutdownGracefully()
    }

    /// Connects this DHT's host to another peer in the network.
    public func bootstrap(to address: String) throws {
        let addr = try Multiaddr(address)
        _ = try host.dial(addr)
    }

    /// The multiaddresses this node is currently listening on.
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
                logger.error("Failed to encode peer set for key \(key): \(error)")
                throw DHTError.encodingFailed(error)
            }
            do {
                try await kademlia.put(key: key, value: data)
            } catch {
                logger.error("Failed to put peer set for key \(key): \(error)")
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
                logger.error("Failed to encode peer set for key \(key): \(error)")
                throw DHTError.encodingFailed(error)
            }
            do {
                try await kademlia.put(key: key, value: data)
            } catch {
                logger.error("Failed to put peer set for key \(key): \(error)")
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

