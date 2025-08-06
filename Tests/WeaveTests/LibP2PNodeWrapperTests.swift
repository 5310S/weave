import XCTest
@testable import weave

final class LibP2PNodeWrapperTests: XCTestCase {
    /// Simple mock host used to verify that bootstrapping occurs when the node starts.
    final class MockHost: LibP2PHosting {
        var started = false
        var bootstrapped: [String] = []
        var handler: ((LibP2PStream) -> Void)?

        func start() async throws { started = true }
        func bootstrap(peers: [String]) throws { bootstrapped = peers }
        func stop() throws {}
        func openStream(to peer: Peer) throws -> LibP2PStream { NoopLibP2PStream(peer: peer) }
        func setStreamHandler(_ handler: @escaping (LibP2PStream) -> Void) { self.handler = handler }
    }

    func testStartBootstrapsPeers() async throws {
        let mock = MockHost()
        let node = LibP2PNode(bootstrapPeers: ["1.2.3.4:4001"], hostBuilder: { mock })

        try await node.start()

        XCTAssertTrue(mock.started)
        XCTAssertEqual(mock.bootstrapped, ["1.2.3.4:4001"])
    }

    // MARK: Message handling
    final class MockStream: LibP2PStream {
        let peer: Peer
        var dataHandler: ((Data) -> Void)?
        weak var remote: MockStream?

        init(peer: Peer) { self.peer = peer }

        func write(_ data: Data) throws { remote?.dataHandler?(data) }
        func setDataHandler(_ handler: @escaping (Data) -> Void) { dataHandler = handler }
    }

    final class StreamHost: LibP2PHosting {
        let selfPeer: Peer
        var peers: [UUID: (host: StreamHost, peer: Peer)] = [:]
        var handler: ((LibP2PStream) -> Void)?

        init(selfPeer: Peer) { self.selfPeer = selfPeer }

        func connect(to host: StreamHost, as peer: Peer) { peers[peer.id] = (host, peer) }

        func start() async throws {}
        func bootstrap(peers: [String]) throws {}
        func stop() throws {}

        func openStream(to peer: Peer) throws -> LibP2PStream {
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

    func testMessageRoundTrip() async throws {
        let peerA = try Peer(latitude: 0, longitude: 0)
        let peerB = try Peer(latitude: 0, longitude: 0)

        let hostA = StreamHost(selfPeer: peerA)
        let hostB = StreamHost(selfPeer: peerB)
        hostA.connect(to: hostB, as: peerB)
        hostB.connect(to: hostA, as: peerA)

        let nodeA = LibP2PNode(hostBuilder: { hostA })
        let nodeB = LibP2PNode(hostBuilder: { hostB })
        try await nodeA.start()
        try await nodeB.start()

        let expectation = expectation(description: "message delivered")
        await nodeB.setMessageHandler { message, peer in
            XCTAssertEqual(message.type, "text")
            XCTAssertEqual(String(data: message.payload, encoding: .utf8), "hi")
            XCTAssertEqual(peer.id, peerA.id)
            expectation.fulfill()
        }

        let stream = try await nodeA.openStream(to: peerB)
        let msg = Message(type: "text", payload: Data("hi".utf8), metadata: nil)
        try await nodeA.sendMessage(msg, over: stream!)
        await waitForExpectations(timeout: 1.0)
    }
}
