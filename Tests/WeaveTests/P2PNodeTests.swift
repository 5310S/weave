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
}
