import XCTest
import Foundation
@testable import weave

final class PeerStoreTests: XCTestCase {
    func testEncryptedSaveLoadRoundTrip() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = PeerStore(url: tempURL)
        let timestamp = Date(timeIntervalSince1970: 0)
        let peer = try Peer(latitude: 10.0, longitude: 20.0, attributes: ["foo": "bar"], lastSeen: timestamp)
        let blocked = [UUID()]
        let liked = [UUID()]
        try store.save(peers: [peer], blocked: blocked, liked: liked)
        let (loadedPeers, loadedBlocked, loadedLiked) = try store.load()
        XCTAssertEqual(loadedPeers, [peer])
        XCTAssertEqual(loadedBlocked, blocked)
        XCTAssertEqual(loadedLiked, liked)

        let data = try Data(contentsOf: tempURL)
        XCTAssertThrowsError(try JSONDecoder().decode([Peer].self, from: data))
    }

    func testKeyFilePersistsAcrossInstances() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let storeURL = tempDir.appendingPathComponent("store.json")

        let peer = try Peer(latitude: 0.0, longitude: 0.0)
        let store = PeerStore(url: storeURL)
        try store.save(peers: [peer], blocked: [])

        let keyURL = tempDir.appendingPathComponent("com.weave.peerstorekey.key")
        XCTAssertTrue(FileManager.default.fileExists(atPath: keyURL.path))

        // Create a new store instance and ensure the previous data can be read.
        let secondStore = PeerStore(url: storeURL)
        let loaded = try secondStore.load().peers
        XCTAssertEqual(loaded, [peer])

        // Verify restrictive permissions (0o600)
        let attrs = try FileManager.default.attributesOfItem(atPath: keyURL.path)
        let perms = attrs[.posixPermissions] as? Int
        XCTAssertEqual(perms, 0o600)
    }

    func testSaveToBrandNewDirectory() throws {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("subdir")
        let storeURL = baseURL.appendingPathComponent("store.json")
        let store = PeerStore(url: storeURL)
        let peer = try Peer(latitude: 1.0, longitude: 2.0)
        XCTAssertNoThrow(try store.save(peers: [peer], blocked: []))
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))
    }

    func testLookupByGeohashPrefixReturnsMatchingPeers() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = PeerStore(url: tempURL)
        let p1 = try Peer(latitude: 37.7749, longitude: -122.4194)
        let p2 = try Peer(latitude: 37.7750, longitude: -122.4195)
        let p3 = try Peer(latitude: 40.7128, longitude: -74.0060)
        try store.save(peers: [p1, p2, p3], blocked: [])
        let prefix = String(GeoHash.encode(latitude: p1.latitude, longitude: p1.longitude).prefix(7))
        let results = try store.lookup(prefix: prefix)
        XCTAssertEqual(Set(results.map { $0.id }), Set([p1.id, p2.id]))
    }
}
