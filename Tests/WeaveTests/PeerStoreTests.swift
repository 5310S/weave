import XCTest
@testable import weave

final class PeerStoreTests: XCTestCase {
    func testEncryptedSaveLoadRoundTrip() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = PeerStore(url: tempURL)
        let peer = Peer(latitude: 10.0, longitude: 20.0, attributes: ["foo": "bar"])
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
}
