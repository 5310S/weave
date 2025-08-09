import XCTest
@testable import weave

final class LibP2PIntegrationTests: XCTestCase {
    func testPeerDiscoveryAcrossDHT() async throws {
        let dhtA = try LibP2PDHT()
        let dhtB = try LibP2PDHT()
        // Connect the DHT instances so stored values propagate
        let addrsA = await dhtA.listenAddresses
        for addr in addrsA { try await dhtB.bootstrap(to: addr) }
        let addrsB = await dhtB.listenAddresses
        for addr in addrsB { try await dhtA.bootstrap(to: addr) }

        let peerID = UUID()
        try await dhtA.store(peerID: peerID, geohash: "u4pruydqqvj")
        // Small delay to allow propagation
        try await Task.sleep(nanoseconds: 200_000_000)
        let results = await dhtB.lookup(prefix: "u4pr")
        XCTAssertTrue(results.contains(peerID))
    }

    func testMessageExchangeOverLibP2P() async throws {
        let hostA = try LibP2PHost()
        let hostB = try LibP2PHost()
        let nodeA = LibP2PNode(hostBuilder: { hostA })
        let nodeB = LibP2PNode(hostBuilder: { hostB })

        let received = expectation(description: "message received")
        await nodeB.setMessageHandler { message, peer in
            XCTAssertEqual(message.type, "greeting")
            XCTAssertEqual(String(data: message.payload, encoding: .utf8), "hello")
            received.fulfill()
        }

        try await nodeB.start()
        // Extract an IPv4/tcp address for nodeB
        guard let addrB = hostB.listenAddresses.first else {
            XCTFail("nodeB missing listen address")
            return
        }
        let comps = addrB.split(separator: "/")
        let ip = String(comps[2])
        let port = UInt16(comps[4])!
        let peerB = try Peer(address: ip, port: port, latitude: 0, longitude: 0)

        try await nodeA.start()
        let stream = try await nodeA.openStream(to: peerB)!
        let msg = Message(type: "greeting", payload: Data("hello".utf8), metadata: nil)
        try await nodeA.sendMessage(msg, over: stream)

        await fulfillment(of: [received], timeout: 5.0)
    }
}
