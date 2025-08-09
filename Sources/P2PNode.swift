import Foundation
import Crypto
import Logging
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// Build a multiaddr string for the given address and port. The function
/// attempts to detect whether the address represents an IPv4, IPv6 or DNS
/// hostname and prefixes the multiaddr accordingly.
///
/// - Parameters:
///   - address: The peer's address in string form.
///   - port: The peer's port number.
/// - Returns: A multiaddr string such as "/ip4/1.2.3.4/tcp/4001".
func multiaddrString(for address: String, port: UInt16) -> String {
    var ipv4 = in_addr()
    var ipv6 = in6_addr()
    let prefix: String
    if address.withCString({ inet_pton(AF_INET, $0, &ipv4) }) == 1 {
        prefix = "ip4"
    } else if address.withCString({ inet_pton(AF_INET6, $0, &ipv6) }) == 1 {
        prefix = "ip6"
    } else {
        prefix = "dns"
    }
    return "/\(prefix)/\(address)/tcp/\(port)"
}

#if canImport(LibP2P)
import LibP2P
import LibP2PCore
import LibP2PTransportTCP

import NIO


/// Concrete implementation backed by the real `swift-libp2p` `Host`.
struct LibP2PHost: LibP2PHosting {
    /// Concrete transport used by the underlying host.
    private let transport: TCPTransport
    /// Libp2p host responsible for dialing and listening.
    private let host: LibP2P.Host
    /// Event loop group driving the networking stack.
    private let group: EventLoopGroup

    init() throws {

        // The latest libp2p API exposes builder utilities for constructing
        // transports and the host. We configure a basic TCP transport and
        // use it to build the host which manages connections.

        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.group = group

        // Create a TCP transport directly. Earlier revisions of swift-libp2p
        // provide synchronous constructors rather than builder utilities, so
        // no future is returned here.
        self.transport = try TCPTransport(eventLoopGroup: group)


        // Create the host backed by the previously configured transport.
        self.host = try LibP2PCore.HostBuilder(eventLoopGroup: group)
            .withTransport(transport)
            .build()
            .wait()

    }

    /// Start listening for connections.

    func start() async throws {
        // The new API returns an async task when starting; wait for completion
        // before returning to ensure listeners are ready.
        try await host.start()
    }

    /// Connect to a list of bootstrap peers so the node can discover the wider
    /// network. Peers are expressed as multiaddrs in string form.
    func bootstrap(peers: [String]) throws {
        for address in peers {
            let addr = try Multiaddr(address)
            // Dial synchronously and wait for the connection attempt to
            // complete before moving onto the next address.
            _ = try host.dial(addr)
        }
    }

    /// Shut down the host and release any associated resources.
    func stop() throws {
        // Shut down the host and then the underlying event loop group.
        try host.stop()
        try group.syncShutdownGracefully()
    }

    enum HostError: Error {
        case missingPeerAddress
    }

    /// Open a new stream to the given peer.
    func openStream(to peer: Peer) throws -> LibP2PStream {
        // Construct a multiaddr from the peer's address and port. Throw if
        // either is missing as callers are expected to provide fully resolved
        // peers when opening streams.
        guard let address = peer.address, let port = peer.port else {
            throw HostError.missingPeerAddress
        }
        let maddr = multiaddrString(for: address, port: port)
        let addr = try Multiaddr(maddr)
        let stream = try host.dial(addr)
        return HostStream(peer: peer, stream: stream)
    }

    /// Register a handler for incoming streams initiated by remote peers.
    func setStreamHandler(_ handler: @escaping (LibP2PStream) -> Void) {
        host.setStreamHandler { stream in
            // Derive a minimal `Peer` representation from the remote
            // connection. The remote address is extracted if available, but any
            // location information is left at defaults.
            let remoteAddr = stream.connection.remoteAddress
            let ip = remoteAddr.ipAddress ?? "0.0.0.0"
            let port = UInt16(remoteAddr.port ?? 0)
            if let peer = try? Peer(address: ip, port: port, latitude: 0, longitude: 0) {
                handler(HostStream(peer: peer, stream: stream))
            }
        }
    }

    /// The multiaddresses the underlying host is listening on.
    var listenAddresses: [String] {
        host.listeners.map { $0.address.description }
    }
}

/// Wrapper around libp2p's `LibP2PCore.Stream` type to conform to `LibP2PStream`.
private final class HostStream: LibP2PStream {
    let peer: Peer
    private let stream: LibP2PCore.Stream
    private let logger = Logger(label: "HostStream")

    init(peer: Peer, stream: LibP2PCore.Stream) {
        self.peer = peer
        self.stream = stream
    }

    func write(_ data: Data) throws {

        var buffer = ByteBufferAllocator().buffer(capacity: data.count)
        buffer.writeBytes(data)
        try stream.write(buffer).wait()

    }

    func setDataHandler(_ handler: @escaping (Data) -> Void) {
        Task.detached { [stream, logger] in
            do {
                while let buffer = try await stream.read() {
                    var buffer = buffer
                    if let data = buffer.readData(length: buffer.readableBytes) {
                        handler(data)
                    }
                }
            } catch {
                logger.error("Read loop failed: \(error)")
            }
        }
    }
}
#endif

/// A bidirectional libp2p stream.
protocol LibP2PStream {
    /// The peer this stream is connected to.
    var peer: Peer { get }
    /// Send raw bytes over the stream.
    func write(_ data: Data) throws
    /// Register a callback for inbound bytes.
    func setDataHandler(_ handler: @escaping (Data) -> Void)
}

/// Abstraction over the underlying libp2p host so it can be mocked in tests.
protocol LibP2PHosting {
    /// Start listening for connections and initialise any required services.
    func start() async throws
    /// Connect to a set of bootstrap peers to join the network.
    func bootstrap(peers: [String]) throws
    /// Shut down the host and release any resources.
    func stop() throws
    /// Open a new stream to the given peer.
    func openStream(to peer: Peer) throws -> LibP2PStream
    /// Set a handler for incoming streams initiated by remote peers.
    func setStreamHandler(_ handler: @escaping (LibP2PStream) -> Void)
}

struct NoopLibP2PStream: LibP2PStream {
    let peer: Peer
    func write(_ data: Data) throws {}
    func setDataHandler(_ handler: @escaping (Data) -> Void) {}
}

/// Minimal wrapper around a libp2p host that exposes basic networking
/// behaviour. This type is responsible for bootstrapping the host into the
/// network, opening streams to other peers and decoding inbound messages. It
/// purposefully omits any of the encryption or peer caching logic found in the
/// higher level `P2PNode` actor so it can be used in simpler scenarios or when
/// writing integration tests against the real libp2p implementation.
actor LibP2PNode {
    /// Known peers used to discover the wider network.
    private let bootstrapPeers: [String]
    /// Factory closure producing a host instance. Injected to allow mocking.
    private let hostBuilder: @Sendable () throws -> LibP2PHosting
    /// Underlying host once started.
    private var host: LibP2PHosting?
    /// Callback invoked for each successfully decoded inbound message.
    private var messageHandler: (@Sendable (Message, Peer) -> Void)?
    /// Logger instance for recording node events.
    private let logger = Logger(label: "LibP2PNode")

    init(bootstrapPeers: [String] = [],
         hostBuilder: @escaping @Sendable () throws -> LibP2PHosting = { @Sendable in
            return try LibP2PHost()
         }) {
        self.bootstrapPeers = bootstrapPeers
        self.hostBuilder = hostBuilder
    }

    /// Start the underlying host and bootstrap to the configured peers. A
    /// stream handler is registered so incoming messages are automatically
    /// decoded and forwarded to the registered message handler.
    func start() async throws {
        guard host == nil else { return }

        let host = try hostBuilder()
        self.host = host

        host.setStreamHandler { stream in
            Task { self.handleIncoming(stream: stream) }
        }
        do {
            try await host.start()
            if !bootstrapPeers.isEmpty {
                try host.bootstrap(peers: bootstrapPeers)
            }
        } catch {
            logger.error("Failed to start libp2p host: \(error)")
            throw error
        }
    }

    /// Shut the host down and remove any handlers.
    func stop() {
        if let host = host {
            do {
                try host.stop()
            } catch {
                logger.error("Failed to stop libp2p host: \(error)")
            }
        }
        host = nil
    }

    /// Register a callback to receive decoded messages from remote peers.
    func setMessageHandler(_ handler: @escaping @Sendable (Message, Peer) -> Void) {
        messageHandler = handler
    }

    /// Open a new stream to the given peer.
    func openStream(to peer: Peer) throws -> LibP2PStream? {
        guard let host = host else { return nil }
        let stream = try host.openStream(to: peer)
        stream.setDataHandler { data in
            Task { self.handleIncomingData(data, from: stream.peer) }
        }
        return stream
    }

    /// Encode and send a message over the provided stream.
    func sendMessage(_ message: Message, over stream: LibP2PStream) throws {
        let data = try JSONEncoder().encode(message)
        do {
            try stream.write(data)
        } catch {
            logger.error("Failed to write message to stream: \(error)")
            throw error
        }
    }

    /// Handles a newly opened incoming stream by registering a data handler.
    private func handleIncoming(stream: LibP2PStream) {
        stream.setDataHandler { data in
            Task { self.handleIncomingData(data, from: stream.peer) }
        }
    }

    /// Decode incoming data and forward to the registered handler if available.
    private func handleIncomingData(_ data: Data, from peer: Peer) {
        guard let handler = messageHandler else { return }
        if let message = try? JSONDecoder().decode(Message.self, from: data) {
            handler(message, peer)
        }
    }
}

/// A networking node backed by a libp2p host.
/// The node is initialised with a list of bootstrap peers and is responsible
/// for starting and stopping the underlying host.
actor P2PNode {
    /// Addresses of peers used to join the wider network.
    private let bootstrapPeers: [String]
    /// Factory used to create the libp2p host. Injected to allow mocking in tests.
    private let hostBuilder: @Sendable () throws -> LibP2PHosting
    /// The underlying libp2p host instance once started.
    private var host: LibP2PHosting?
    /// Indicates whether the node is actively running.
    private(set) var isRunning: Bool = false


    /// Private key used for Curve25519 key agreement.
    private let privateKey: Curve25519.KeyAgreement.PrivateKey
    /// Public key that can be shared with peers.
    let publicKey: Data

    /// Maximum number of peers to retain in the shared key cache.
    private let maxCachedPeers = 100
    /// Tracks peer access order for LRU eviction.
    private var accessOrder: [UUID] = []
    /// Cache of derived symmetric keys for peers, keyed by peer ID.
    private var sharedKeyCache: [UUID: SymmetricKey] = [:]
    /// Tracks the public key used when deriving the cached shared key.
    private var cachedPublicKeys: [UUID: Data] = [:]
    /// Function used to derive a shared key. Injected for testing to observe
    /// derivation calls.
    private let keyDerivation: (Curve25519.KeyAgreement.PrivateKey, Data) throws -> SymmetricKey


    /// Handler invoked for decrypted inbound messages.
    private var messageHandler: (@Sendable (Message, Peer) -> Void)?
    /// Handler invoked when decryption or decoding fails.
    private var errorHandler: (@Sendable (Error, Peer) -> Void)?

    /// Logger instance for high-level node events.
    private let logger = Logger(label: "P2PNode")


    init(bootstrapPeers: [String] = [],
         hostBuilder: @escaping @Sendable () throws -> LibP2PHosting = { @Sendable in
            return try LibP2PHost()
         },
         keyDerivation: @escaping (Curve25519.KeyAgreement.PrivateKey, Data) throws -> SymmetricKey = Encryption.deriveSharedSecret) {

        self.bootstrapPeers = bootstrapPeers
        self.hostBuilder = hostBuilder
        self.keyDerivation = keyDerivation
        let pair = Encryption.generateKeyPair()
        self.privateKey = pair.privateKey
        self.publicKey = pair.publicKey

    }

    /// Starts the networking stack by creating a libp2p host and performing
    /// bootstrap against known peers.
    func start() async throws {
        guard !isRunning else { return }

        let host = try hostBuilder()
        self.host = host
        host.setStreamHandler { stream in
            Task { self.handleIncoming(stream: stream) }
        }

        do {
            try await host.start()
        } catch {
            logger.error("Failed to start host: \(error)")
            throw error
        }

        if !bootstrapPeers.isEmpty {
            do {
                try host.bootstrap(peers: bootstrapPeers)
            } catch {
                logger.warning("Failed to bootstrap peers: \(error)")
            }
        }

        isRunning = true
    }

    /// Stops the networking stack and cleans up resources by shutting down the host.
    func stop() {
        guard isRunning else { return }
        if let host = host {
            do {
                try host.stop()
            } catch {
                logger.error("Failed to stop host: \(error)")
            }
        }
        host = nil
        isRunning = false
    }

    /// Register a callback to receive decrypted messages from peers.

    func setMessageHandler(_ handler: @escaping @Sendable (Message, Peer) -> Void) {

        messageHandler = handler
    }

    /// Register a callback to receive errors for failed inbound messages.
    func setErrorHandler(_ handler: @escaping @Sendable (Error, Peer) -> Void) {
        errorHandler = handler
    }

    /// Opens a new libp2p stream to the given peer.
    func openStream(to peer: Peer) throws -> LibP2PStream? {
        guard let host = host else { return nil }
        let stream = try host.openStream(to: peer)
        stream.setDataHandler { data in
            Task { self.handleIncomingData(data, over: stream) }
        }
        return stream
    }

    /// Encodes, encrypts and sends a message over an existing stream.
    func sendMessage(_ message: Message, over stream: LibP2PStream) throws {
        let key = try sharedKey(with: stream.peer)
        let data = try JSONEncoder().encode(message)
        let encrypted = try Encryption.encrypt(data, using: key)
        do {
            try stream.write(encrypted)
        } catch {
            logger.error("Failed to send encrypted message: \(error)")
            throw error
        }
    }

    /// Encrypts `message` for the given peer using a shared secret.
    func send(_ message: Data, to peer: Peer) throws -> Data {
        let key = try sharedKey(with: peer)
        return try Encryption.encrypt(message, using: key)
    }

    /// Decrypts data received from the given peer using the shared secret.
    func receive(_ data: Data, from peer: Peer) throws -> Data {
        let key = try sharedKey(with: peer)
        return try Encryption.decrypt(data, using: key)
    }

    /// Derives a symmetric key from our private key and the peer's public key.
    private func sharedKey(with peer: Peer) throws -> SymmetricKey {
        guard let publicKey = peer.publicKey else {
            throw P2PError.missingPeerPublicKey
        }
        if let cachedKey = sharedKeyCache[peer.id], cachedPublicKeys[peer.id] == publicKey {
            refreshAccessOrder(for: peer.id)
            return cachedKey
        }
        let key = try keyDerivation(privateKey, publicKey)
        sharedKeyCache[peer.id] = key
        cachedPublicKeys[peer.id] = publicKey
        refreshAccessOrder(for: peer.id)
        evictIfNeeded()
        return key
    }

    /// Removes any cached shared key for the given peer ID so a new one will
    /// be derived on next use. Call when a peer's public key changes.
    func invalidateSharedKey(for peerID: UUID) {
        sharedKeyCache.removeValue(forKey: peerID)
        cachedPublicKeys.removeValue(forKey: peerID)
        accessOrder.removeAll { $0 == peerID }
    }

    /// Records access to a peer's cached key.
    private func refreshAccessOrder(for peerID: UUID) {
        if let index = accessOrder.firstIndex(of: peerID) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(peerID)
    }

    /// Removes least recently used entries when the cache exceeds its limit.
    private func evictIfNeeded() {
        if accessOrder.count > maxCachedPeers, let lru = accessOrder.first {
            accessOrder.removeFirst()
            sharedKeyCache.removeValue(forKey: lru)
            cachedPublicKeys.removeValue(forKey: lru)
        }
    }

    enum P2PError: Error {
        case missingPeerPublicKey
    }

    /// Handles a newly opened incoming stream.
    private func handleIncoming(stream: LibP2PStream) {
        stream.setDataHandler { data in
            Task { self.handleIncomingData(data, over: stream) }
        }
    }

    /// Convenience wrapper that extracts the peer from the stream.
    private func handleIncomingData(_ data: Data, over stream: LibP2PStream) {
        handleIncomingData(data, from: stream.peer)
    }

    /// Decrypts data from a peer, decodes it to a `Message` and forwards it to the registered handler.
    private func handleIncomingData(_ data: Data, from peer: Peer) {
        guard let handler = messageHandler else { return }
        do {
            let key = try sharedKey(with: peer)
            let plaintext = try Encryption.decrypt(data, using: key)
            let message = try JSONDecoder().decode(Message.self, from: plaintext)
            handler(message, peer)
        } catch {
            if let errorHandler {
                errorHandler(error, peer)
            } else {
                logger.error("Failed to handle incoming data from \(peer.id): \(error)")
            }
        }
    }
}

