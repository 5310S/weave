import XCTest
@testable import weave

final class P2PNodeTests: XCTestCase {
    /// Simple mock host that records whether its lifecycle methods were invoked.
    final class MockHost: LibP2PHosting {
        var startCount = 0
        var bootstrapped: [String] = []
        var natEnabled = false
        var stopCount = 0

        func start() { startCount += 1 }
        func bootstrap(peers: [String]) { bootstrapped = peers }
        func enableNAT() { natEnabled = true }
        func stop() { stopCount += 1 }
        func openStream(to peer: Peer) -> LibP2PStream { NoopLibP2PStream(peer: peer) }
        func setStreamHandler(_ handler: @escaping (LibP2PStream) -> Void) {}
    }

    func testStartBootstrapsAndEnablesNAT() async {
        let mock = MockHost()
        let node = P2PNode(bootstrapPeers: ["1.2.3.4:4001"], hostBuilder: { mock })

        XCTAssertFalse(await node.isRunning)
        await node.start()

        XCTAssertTrue(await node.isRunning)
        XCTAssertEqual(mock.startCount, 1)
        XCTAssertEqual(mock.bootstrapped, ["1.2.3.4:4001"])
        XCTAssertTrue(mock.natEnabled)
    }

    func testStopShutsDownHost() async {
        let mock = MockHost()
        let node = P2PNode(hostBuilder: { mock })
        await node.start()
        await node.stop()

        XCTAssertFalse(await node.isRunning)
        XCTAssertEqual(mock.stopCount, 1)
    }

    func testSendThrowsWhenPeerLacksPublicKey() async throws {
        let node = P2PNode()
        let peer = try Peer(latitude: 0, longitude: 0)
        let message = Data("hi".utf8)

        do {
            _ = try await node.send(message, to: peer)
            XCTFail("Expected to throw")
        } catch {
            XCTAssertEqual(error as? P2PNode.P2PError, .missingPeerPublicKey)
        }
    }

    func testReceiveThrowsWhenPeerLacksPublicKey() async throws {
        let node = P2PNode()
        let peer = try Peer(latitude: 0, longitude: 0)
        let data = Data("hi".utf8)

        do {
            _ = try await node.receive(data, from: peer)
            XCTFail("Expected to throw")
        } catch {
            XCTAssertEqual(error as? P2PNode.P2PError, .missingPeerPublicKey)
        }
    }


    func testSharedKeyDerivationOccursOncePerPeer() throws {
        var derivationCalls = 0
        let node = P2PNode(keyDerivation: { privateKey, peerPublicKey in
            derivationCalls += 1
            return try Encryption.deriveSharedSecret(privateKey: privateKey, peerPublicKey: peerPublicKey)
        })

        let peerKeys = Encryption.generateKeyPair()
        var peer = try Peer(publicKey: peerKeys.publicKey, latitude: 0, longitude: 0)
        let message = Data("hello".utf8)

        _ = try node.send(message, to: peer)
        _ = try node.send(message, to: peer)
        XCTAssertEqual(derivationCalls, 1)

        let newKeys = Encryption.generateKeyPair()
        peer.publicKey = newKeys.publicKey
        _ = try node.send(message, to: peer)
        XCTAssertEqual(derivationCalls, 2)

    }

    func testCacheEvictsLeastRecentlyUsedPeer() throws {
        var derivationCalls = 0
        let node = P2PNode(keyDerivation: { privateKey, peerPublicKey in
            derivationCalls += 1
            return try Encryption.deriveSharedSecret(privateKey: privateKey, peerPublicKey: peerPublicKey)
        })

        let message = Data("hi".utf8)
        var peers: [Peer] = []

        // Fill the cache to its limit
        for _ in 0..<100 {
            let keys = Encryption.generateKeyPair()
            let peer = try Peer(publicKey: keys.publicKey, latitude: 0, longitude: 0)
            peers.append(peer)
            _ = try node.send(message, to: peer)
        }

        // Access the first peer again so it becomes most recently used
        _ = try node.send(message, to: peers[0])
        XCTAssertEqual(derivationCalls, 100)

        // Add a new peer which should evict the least recently used (peers[1])
        let extraKeys = Encryption.generateKeyPair()
        let extraPeer = try Peer(publicKey: extraKeys.publicKey, latitude: 0, longitude: 0)
        _ = try node.send(message, to: extraPeer)
        XCTAssertEqual(derivationCalls, 101)

        // Sending to peers[1] should derive again since it was evicted
        _ = try node.send(message, to: peers[1])
        XCTAssertEqual(derivationCalls, 102)

        // peers[0] should still be cached
        _ = try node.send(message, to: peers[0])
        XCTAssertEqual(derivationCalls, 102)
    }

    // MARK: - Stream based messaging

    /// Mock stream used for simulating libp2p streams in tests.
    final class MockStream: LibP2PStream {
        let peer: Peer
        var dataHandler: ((Data) -> Void)?
        weak var remote: MockStream?

        init(peer: Peer) { self.peer = peer }

        func write(_ data: Data) { remote?.dataHandler?(data) }
        func setDataHandler(_ handler: @escaping (Data) -> Void) { dataHandler = handler }
    }

    /// Mock host capable of opening streams to connected peers.
    final class StreamHost: LibP2PHosting {
        let selfPeer: Peer
        var peers: [UUID: (host: StreamHost, peer: Peer)] = [:]
        var handler: ((LibP2PStream) -> Void)?

        init(selfPeer: Peer) { self.selfPeer = selfPeer }

        func connect(to host: StreamHost, as peer: Peer) { peers[peer.id] = (host, peer) }

        func start() {}
        func bootstrap(peers: [String]) {}
        func enableNAT() {}
        func stop() {}

        func openStream(to peer: Peer) -> LibP2PStream {
            let local = MockStream(peer: peer)
            if let (remoteHost, _) = peers[peer.id] {
                let remote = MockStream(peer: self.selfPeer)
                local.remote = remote
                remote.remote = local
                remoteHost.handler?(remote)
            }
            return local
        }

        func setStreamHandler(_ handler: @escaping (LibP2PStream) -> Void) { self.handler = handler }
    }

    func testRoundTripMessageBetweenTwoNodes() async throws {
        let keysA = Encryption.generateKeyPair()
        let peerA = try Peer(publicKey: keysA.publicKey, latitude: 0, longitude: 0)
        let keysB = Encryption.generateKeyPair()
        let peerB = try Peer(publicKey: keysB.publicKey, latitude: 0, longitude: 0)

        let hostA = StreamHost(selfPeer: peerA)
        let hostB = StreamHost(selfPeer: peerB)
        hostA.connect(to: hostB, as: peerB)
        hostB.connect(to: hostA, as: peerA)

        let nodeA = P2PNode(hostBuilder: { hostA })
        let nodeB = P2PNode(hostBuilder: { hostB })

        let expA = expectation(description: "NodeA received")
        let expB = expectation(description: "NodeB received")

        await nodeA.setMessageHandler { data, peer in
            XCTAssertEqual(String(decoding: data, as: UTF8.self), "pong")
            XCTAssertEqual(peer.id, peerB.id)
            expA.fulfill()
        }
        await nodeB.setMessageHandler { data, peer in
            XCTAssertEqual(String(decoding: data, as: UTF8.self), "ping")
            XCTAssertEqual(peer.id, peerA.id)
            expB.fulfill()
        }

        await nodeA.start()
        await nodeB.start()

        let streamAB = await nodeA.openStream(to: peerB)!
        try await nodeA.sendMessage(Data("ping".utf8), over: streamAB)
        await fulfillment(of: [expB], timeout: 1.0)

        let streamBA = await nodeB.openStream(to: peerA)!
        try await nodeB.sendMessage(Data("pong".utf8), over: streamBA)
        await fulfillment(of: [expA], timeout: 1.0)
    }
}
