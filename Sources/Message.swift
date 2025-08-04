import Foundation
import Crypto

struct Message: Codable, Equatable {
    let type: String
    let payload: Data
    let metadata: [String: String]?
}

extension Message {
    /// Encodes and encrypts the message using the given key pair and peer public key.
    func encrypted(from privateKey: Curve25519.KeyAgreement.PrivateKey,
                   to peerPublicKey: Data) throws -> Data {
        let data = try JSONEncoder().encode(self)
        return try Encryption.encryptMessage(data, from: privateKey, to: peerPublicKey)
    }

    /// Decrypts and decodes an encrypted message.
    static func decrypted(_ data: Data,
                          with privateKey: Curve25519.KeyAgreement.PrivateKey,
                          senderPublicKey: Data) throws -> Message {
        let plaintext = try Encryption.decryptMessage(data, with: privateKey, senderPublicKey: senderPublicKey)
        return try JSONDecoder().decode(Message.self, from: plaintext)
    }
}
