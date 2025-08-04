import XCTest
@testable import weave

final class EncryptionTests: XCTestCase {
    func testSharedSecretAgreement() throws {
        let alice = Encryption.generateKeyPair()
        let bob = Encryption.generateKeyPair()
        let secret1 = try Encryption.deriveSharedSecret(privateKey: alice.privateKey, peerPublicKey: bob.publicKey)
        let secret2 = try Encryption.deriveSharedSecret(privateKey: bob.privateKey, peerPublicKey: alice.publicKey)
        let data1 = secret1.withUnsafeBytes { Data($0) }
        let data2 = secret2.withUnsafeBytes { Data($0) }
        XCTAssertEqual(data1, data2)
    }

    func testEncryptDecryptRoundTrip() async throws {
        let aliceNode = P2PNode()
        let bobNode = P2PNode()

        let bobPeer = try Peer(id: UUID(), name: "Bob", address: nil, port: nil,
                               publicKey: bobNode.publicKey,
                               latitude: 0, longitude: 0)
        let alicePeer = try Peer(id: UUID(), name: "Alice", address: nil, port: nil,
                                 publicKey: aliceNode.publicKey,
                                 latitude: 0, longitude: 0)

        let message = "Hello Bob".data(using: .utf8)!
        let encrypted = try await aliceNode.send(message, to: bobPeer)
        let decrypted = try await bobNode.receive(encrypted, from: alicePeer)
        XCTAssertEqual(message, decrypted)
    }

    func testMessageEncryptionRoundTrip() throws {
        let alice = Encryption.generateKeyPair()
        let bob = Encryption.generateKeyPair()
        let original = Message(type: "greet", payload: Data("hi".utf8), metadata: nil)
        let encrypted = try original.encrypted(from: alice.privateKey, to: bob.publicKey)
        let decoded = try Message.decrypted(encrypted, with: bob.privateKey, senderPublicKey: alice.publicKey)
        XCTAssertEqual(original, decoded)
    }
}

