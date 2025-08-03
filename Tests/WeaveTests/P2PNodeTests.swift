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

    func testConcurrentStartStop() async {
        let mock = MockHost()
        let node = P2PNode(hostBuilder: { mock })

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask { await node.start() }
            }
        }
        XCTAssertTrue(await node.isRunning)
        XCTAssertEqual(mock.startCount, 1)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask { await node.stop() }
            }
        }
        XCTAssertFalse(await node.isRunning)
        XCTAssertEqual(mock.stopCount, 1)
    }
}
