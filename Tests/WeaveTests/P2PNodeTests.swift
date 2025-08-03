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
}
