import XCTest
@testable import weave

final class P2PNodeTests: XCTestCase {
    func testStartAndStopToggleRunningState() {
        let node = P2PNode(bootstrapPeers: ["1.2.3.4:4001"])
        XCTAssertFalse(node.isRunning)
        node.start()
        XCTAssertTrue(node.isRunning)
        node.stop()
        XCTAssertFalse(node.isRunning)
    }
}
