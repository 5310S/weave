import Foundation
import Crypto

#if canImport(LibP2P)
import LibP2P

/// Concrete implementation backed by the real `swift-libp2p` Host.
struct LibP2PHost: LibP2PHosting {
    /// Underlying libp2p host instance.
    private let host: Host

    init() {
        // Build a default host using libp2p's builder which configures
        // transports, muxers and security implementations suitable for most
        // use cases.
        self.host = try! HostBuilder().build()
    }

    /// Start listening for connections.
    func start() {
        // Many libp2p operations return an EventLoopFuture. Waiting here keeps
        // the abstraction simple for callers.
        _ = try? host.start().wait()
    }

    /// Connect to a list of bootstrap peers so the node can discover the wider
    /// network. Peers are expressed as multiaddrs in string form.
    func bootstrap(peers: [String]) {
        let addresses = peers.compactMap { try? Multiaddr($0) }
        for address in addresses {
            _ = try? host.bootstrap(to: address).wait()
        }
    }

    /// Enable NAT traversal via AutoNAT/UPnP so the node becomes reachable from
    /// outside the local network.
    func enableNAT() {
        _ = try? host.enableNAT().wait()
    }

    /// Shut down the host and release any associated resources.
    func stop() {
        _ = try? host.stop().wait()
    }
}
#endif

/// Abstraction over the underlying libp2p host so it can be mocked in tests.
protocol LibP2PHosting {
    /// Start listening for connections and initialise any required services.
    func start()
    /// Connect to a set of bootstrap peers to join the network.
    func bootstrap(peers: [String])
    /// Enable NAT traversal so the node is reachable from the public internet.
    func enableNAT()
    /// Shut down the host and release any resources.
    func stop()
}

/// Default no-op implementation used until a real libp2p host is wired in.
struct NoopLibP2PHost: LibP2PHosting {
    func start() {}
    func bootstrap(peers: [String]) {}
    func enableNAT() {}
    func stop() {}
}

/// A networking node backed by a libp2p host.
/// The node is initialised with a list of bootstrap peers and is responsible
/// for starting and stopping the underlying host.
actor P2PNode {
    /// Addresses of peers used to join the wider network.
    private let bootstrapPeers: [String]
    /// Factory used to create the libp2p host. Injected to allow mocking in tests.
    private let hostBuilder: @Sendable () -> LibP2PHosting
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

    init(bootstrapPeers: [String] = [],
         hostBuilder: @escaping () -> LibP2PHosting = {
#if canImport(LibP2P)
            LibP2PHost()
#else
            NoopLibP2PHost()
#endif
         },
         keyDerivation: @escaping (Curve25519.KeyAgreement.PrivateKey, Data) throws -> SymmetricKey = Encryption.deriveSharedSecret) {

        self.bootstrapPeers = bootstrapPeers
        self.hostBuilder = hostBuilder
        self.keyDerivation = keyDerivation
        let pair = Encryption.generateKeyPair()
        self.privateKey = pair.privateKey
        self.publicKey = pair.publicKey

    }

    /// Starts the networking stack by creating a libp2p host, performing
    /// bootstrap against known peers and enabling NAT traversal.
    func start() {
        guard !isRunning else { return }

        let host = hostBuilder()
        self.host = host

        host.start()
        if !bootstrapPeers.isEmpty {
            host.bootstrap(peers: bootstrapPeers)
        }
        host.enableNAT()

        isRunning = true
    }

    /// Stops the networking stack and cleans up resources by shutting down the host.
    func stop() {
        guard isRunning else { return }
        host?.stop()
        host = nil
        isRunning = false
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
}

