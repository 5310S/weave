import XCTest
import Foundation
@testable import weave

final class DHTTests: XCTestCase {
    func testLookupReturnsIDsForMatchingPrefixes() async {
        let dht = InMemoryDHT()
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        let loc1 = (37.7749, -122.4194) // San Francisco
        let loc2 = (37.7750, -122.4195) // very close to loc1
        let loc3 = (40.7128, -74.0060)  // New York

        await dht.store(peerID: id1, latitude: loc1.0, longitude: loc1.1)
        await dht.store(peerID: id2, latitude: loc2.0, longitude: loc2.1)
        await dht.store(peerID: id3, latitude: loc3.0, longitude: loc3.1)

        let hash1 = GeoHash.encode(latitude: loc1.0, longitude: loc1.1)
        let prefix = String(hash1.prefix(7))

        let results = await dht.lookup(prefix: prefix)
        XCTAssertEqual(Set(results), Set([id1, id2]))

        let unrelatedPrefix = String(GeoHash.encode(latitude: loc3.0, longitude: loc3.1).prefix(2))
        let unrelatedResults = await dht.lookup(prefix: unrelatedPrefix)
        XCTAssertEqual(unrelatedResults, [id3])
    }

    func testRemoveDeletesIDsAndEmptiesBuckets() async {
        let dht = InMemoryDHT()
        let id1 = UUID()
        let id2 = UUID()
        let location = (51.501, -0.141)
        await dht.store(peerID: id1, latitude: location.0, longitude: location.1)
        await dht.store(peerID: id2, latitude: location.0, longitude: location.1)
        await dht.remove(peerID: id1, latitude: location.0, longitude: location.1)
        let fullHash = GeoHash.encode(latitude: location.0, longitude: location.1)
        let remaining = await dht.lookup(prefix: fullHash)
        XCTAssertEqual(Set(remaining), Set([id2]))
        await dht.remove(peerID: id2, latitude: location.0, longitude: location.1)
        let empty = await dht.lookup(prefix: fullHash)
        XCTAssertTrue(empty.isEmpty)
    }
}
