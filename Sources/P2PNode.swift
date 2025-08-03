import Foundation
import Crypto

/// A placeholder networking node that will integrate libp2p in the future.
/// For now it simply tracks bootstrap peers and whether the node is running.
final class P2PNode {
    /// Addresses of peers used to join the wider network.
    private let bootstrapPeers: [String]
    /// Indicates whether the node is actively running.
    private(set) var isRunning: Bool = false

    /// Private key used for Curve25519 key agreement.
    private let privateKey: Curve25519.KeyAgreement.PrivateKey
    /// Public key that can be shared with peers.
    let publicKey: Data

    init(bootstrapPeers: [String] = []) {
        self.bootstrapPeers = bootstrapPeers
        let pair = Encryption.generateKeyPair()
        self.privateKey = pair.privateKey
        self.publicKey = pair.publicKey
    }

    /// Starts the networking stack. In a real implementation this would
    /// initialise libp2p, perform NAT traversal and begin listening for peers.
    func start() {
        isRunning = true
    }

    /// Stops the networking stack and cleans up resources.
    func stop() {
        isRunning = false
    }

    /// Encrypts `message` for the given peer using a shared secret.
    func send(_ message: Data, to peer: Peer) throws -> Data {
        let key = try sharedKey(with: peer)
        return try Encryption.encrypt(message, using: key)
    }

    /// Decrypts data received from the given peer using the shared secret.
    func receive(_ data: Data, from peer: Peer) throws -> Data {
        let key = try sharedKey(with: peer)
        return try Encryption.decrypt(data, using: key)
    }

    /// Derives a symmetric key from our private key and the peer's public key.
    private func sharedKey(with peer: Peer) throws -> SymmetricKey {
        guard let base64 = peer.attributes["publicKey"],
              let data = Data(base64Encoded: base64) else {
            throw P2PError.missingPeerPublicKey
        }
        return try Encryption.deriveSharedSecret(privateKey: privateKey, peerPublicKey: data)
    }

    enum P2PError: Error {
        case missingPeerPublicKey
    }
}

