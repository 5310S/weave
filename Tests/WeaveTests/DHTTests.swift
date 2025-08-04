import XCTest
import Foundation
@testable import weave

final class DHTTests: XCTestCase {
    func testLookupReturnsIDsForMatchingPrefixes() async {
        let dht = InMemoryDHT()
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()
        await dht.store(peerID: id1, geohash: "abcd123")
        await dht.store(peerID: id2, geohash: "abef456")
        await dht.store(peerID: id3, geohash: "xyz789")
        let aResults = await dht.lookup(prefix: "a")
        XCTAssertEqual(Set(aResults), Set([id1, id2]))
        let abResults = await dht.lookup(prefix: "ab")
        XCTAssertEqual(Set(abResults), Set([id1, id2]))
        let abcResults = await dht.lookup(prefix: "abc")
        XCTAssertEqual(abcResults, [id1])
        XCTAssertTrue(await dht.lookup(prefix: "nope").isEmpty)
    }

    func testRemoveDeletesIDsAndEmptiesBuckets() async {
        let dht = InMemoryDHT()
        let id1 = UUID()
        let id2 = UUID()
        await dht.store(peerID: id1, geohash: "foo")
        await dht.store(peerID: id2, geohash: "foo")
        await dht.remove(peerID: id1, geohash: "foo")
        XCTAssertEqual(await dht.lookup(prefix: "f"), [id2])
        XCTAssertEqual(await dht.lookup(prefix: "foo"), [id2])
        await dht.remove(peerID: id2, geohash: "foo")
        XCTAssertTrue(await dht.lookup(prefix: "f").isEmpty)
        XCTAssertTrue(await dht.lookup(prefix: "foo").isEmpty)
    }
}
