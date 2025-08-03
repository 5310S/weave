import XCTest
@testable import weave

final class P2PNodeTests: XCTestCase {
    /// Simple mock host that records whether its lifecycle methods were invoked.
    final class MockHost: LibP2PHosting {
        var started = false
        var bootstrapped: [String] = []
        var natEnabled = false
        var stopped = false

        func start() { started = true }
        func bootstrap(peers: [String]) { bootstrapped = peers }
        func enableNAT() { natEnabled = true }
        func stop() { stopped = true }
    }

    func testStartBootstrapsAndEnablesNAT() {
        let mock = MockHost()
        let node = P2PNode(bootstrapPeers: ["1.2.3.4:4001"], hostBuilder: { mock })

        XCTAssertFalse(node.isRunning)
        node.start()

        XCTAssertTrue(node.isRunning)
        XCTAssertTrue(mock.started)
        XCTAssertEqual(mock.bootstrapped, ["1.2.3.4:4001"])
        XCTAssertTrue(mock.natEnabled)
    }

    func testStopShutsDownHost() {
        let mock = MockHost()
        let node = P2PNode(hostBuilder: { mock })
        node.start()
        node.stop()

        XCTAssertFalse(node.isRunning)
        XCTAssertTrue(mock.stopped)
    }

    func testSendThrowsWhenPeerLacksPublicKey() throws {
        let node = P2PNode()
        let peer = try Peer(latitude: 0, longitude: 0)
        let message = Data("hi".utf8)

        XCTAssertThrowsError(try node.send(message, to: peer)) { error in
            XCTAssertEqual(error as? P2PNode.P2PError, .missingPeerPublicKey)
        }
    }

    func testReceiveThrowsWhenPeerLacksPublicKey() throws {
        let node = P2PNode()
        let peer = try Peer(latitude: 0, longitude: 0)
        let data = Data("hi".utf8)

        XCTAssertThrowsError(try node.receive(data, from: peer)) { error in
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
}
