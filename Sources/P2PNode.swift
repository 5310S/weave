import Foundation

/// A bidirectional libp2p stream.
protocol LibP2PStream {
    var peer: Peer { get }
    func write(_ data: Data)
    func setDataHandler(_ handler: @escaping (Data) -> Void)
}

/// Abstraction over the underlying libp2p host so it can be mocked in tests.
protocol LibP2PHosting {
    func start()
    func bootstrap(peers: [String])
    func enableNAT()
    func stop()
    func openStream(to peer: Peer) throws -> LibP2PStream
    func setStreamHandler(_ handler: @escaping (LibP2PStream) -> Void)
}

/// Default no-op implementation used when no real libp2p host is available.
struct NoopLibP2PHost: LibP2PHosting {
    func start() {}
    func bootstrap(peers: [String]) {}
    func enableNAT() {}
    func stop() {}
    func openStream(to peer: Peer) throws -> LibP2PStream { NoopLibP2PStream(peer: peer) }
    func setStreamHandler(_ handler: @escaping (LibP2PStream) -> Void) {}
}

struct NoopLibP2PStream: LibP2PStream {
    let peer: Peer
    func write(_ data: Data) {}
    func setDataHandler(_ handler: @escaping (Data) -> Void) {}
}

/// Placeholder networking node used in tests when cryptographic libraries are
/// unavailable. It provides just enough surface area for the rest of the package
/// to compile and for higher level components to interact with a stub node.
actor P2PNode {
    private(set) var isRunning: Bool = false

    init(bootstrapPeers: [String] = [],
         hostBuilder: @escaping @Sendable () throws -> LibP2PHosting = { NoopLibP2PHost() },
         keyDerivation: ((Data, Data) throws -> Data)? = nil) {}

    func start() async throws { isRunning = true }
    func stop() async { isRunning = false }

    enum P2PError: Error { case missingPeerPublicKey }

    func send(_ message: Data, to peer: Peer) throws -> Data { throw P2PError.missingPeerPublicKey }
    func receive(_ data: Data, from peer: Peer) throws -> Data { throw P2PError.missingPeerPublicKey }
    func invalidateSharedKey(for id: UUID) {}
}
