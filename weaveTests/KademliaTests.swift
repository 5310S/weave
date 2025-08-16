import XCTest
@testable import weave

final class KademliaTests: XCTestCase {
    /// Two nodes should be able to exchange a value through the simplified
    /// Kademlia network using UDP messages.
    func testNetworkStoreAndLookup() async throws {
        let nodeA = KademliaNode(id: 1, port: 4100)
        try nodeA.start()
        defer { nodeA.stop() }

        let nodeB = KademliaNode(id: 2, port: 4101)
        try nodeB.start()
        defer { nodeB.stop() }

        // Join B to A's network and store a value on A
        nodeB.join(bootstrapHost: "127.0.0.1", port: 4100)
        nodeA.store(value: "hello", for: 99)

        // Lookup from B and wait for asynchronous completion
        let value = await withCheckedContinuation { continuation in
            nodeB.findValue(for: 99) { result in
                continuation.resume(returning: result)
            }
        }
        XCTAssertEqual(value, "hello")
    }
}
