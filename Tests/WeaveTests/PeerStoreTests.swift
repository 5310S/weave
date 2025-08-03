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
}
