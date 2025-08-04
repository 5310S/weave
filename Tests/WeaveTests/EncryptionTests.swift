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

    func testNodesExchangeEncryptedMessagesOverStream() async throws {
        final class MockStream: LibP2PStream {
            let peer: Peer
            var dataHandler: ((Data) -> Void)?
            weak var remote: MockStream?
            var onWrite: ((Data) -> Void)?
            init(peer: Peer) { self.peer = peer }
            func write(_ data: Data) {
                onWrite?(data)
                remote?.dataHandler?(data)
            }
            func setDataHandler(_ handler: @escaping (Data) -> Void) { dataHandler = handler }
        }

        final class StreamHost: LibP2PHosting {
            let selfPeer: Peer
            var peers: [UUID: (host: StreamHost, peer: Peer)] = [:]
            var handler: ((LibP2PStream) -> Void)?

            init(selfPeer: Peer) { self.selfPeer = selfPeer }

            func connect(to host: StreamHost, as peer: Peer) { peers[peer.id] = (host, peer) }

            func start() {}
            func bootstrap(peers: [String]) {}
            func enableNAT() {}
            func stop() {}

            func openStream(to peer: Peer) throws -> LibP2PStream {
                let local = MockStream(peer: peer)
                if let (remoteHost, _) = peers[peer.id] {
                    let remote = MockStream(peer: self.selfPeer)
                    local.remote = remote
                    remote.remote = local
                    remoteHost.handler?(remote)
                }
                return local
            }

            func setStreamHandler(_ handler: @escaping (LibP2PStream) -> Void) { self.handler = handler }
        }

        let keysA = Encryption.generateKeyPair()
        let peerA = try Peer(publicKey: keysA.publicKey, latitude: 0, longitude: 0)
        let keysB = Encryption.generateKeyPair()
        let peerB = try Peer(publicKey: keysB.publicKey, latitude: 0, longitude: 0)

        let hostA = StreamHost(selfPeer: peerA)
        let hostB = StreamHost(selfPeer: peerB)
        hostA.connect(to: hostB, as: peerB)
        hostB.connect(to: hostA, as: peerA)

        let nodeA = P2PNode(hostBuilder: { hostA })
        let nodeB = P2PNode(hostBuilder: { hostB })

        let exp = expectation(description: "NodeB received message")
        await nodeB.setMessageHandler { message, peer in
            XCTAssertEqual(message.type, "greet")
            XCTAssertEqual(String(decoding: message.payload, as: UTF8.self), "hello")
            XCTAssertEqual(peer.id, peerA.id)
            exp.fulfill()
        }

        await nodeA.start()
        await nodeB.start()

        let stream = try await nodeA.openStream(to: peerB)! as! MockStream
        var captured: Data?
        stream.onWrite = { data in captured = data }

        let msg = Message(type: "greet", payload: Data("hello".utf8), metadata: nil)
        try await nodeA.sendMessage(msg, over: stream)

        await fulfillment(of: [exp], timeout: 1.0)

        XCTAssertNotNil(captured)
        XCTAssertNil(try? JSONDecoder().decode(Message.self, from: captured!))
    }
}

