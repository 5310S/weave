import Foundation
import Crypto

#if canImport(LibP2P)
import LibP2P
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

    init(bootstrapPeers: [String] = [],
         hostBuilder: @escaping @Sendable () -> LibP2PHosting = { NoopLibP2PHost() }) {
        self.bootstrapPeers = bootstrapPeers
        self.hostBuilder = hostBuilder
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
        return try Encryption.deriveSharedSecret(privateKey: privateKey, peerPublicKey: publicKey)
    }

    enum P2PError: Error {
        case missingPeerPublicKey
    }
}

