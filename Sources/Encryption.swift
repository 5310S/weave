import Foundation
import Crypto

/// Helper utilities for generating key pairs, deriving shared secrets,
/// and performing symmetric encryption using AES.GCM.
enum Encryption {
    struct KeyPair {
        let privateKey: Curve25519.KeyAgreement.PrivateKey
        let publicKey: Data
    }

    /// Generates a Curve25519 key agreement key pair.
    static func generateKeyPair() -> KeyPair {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let publicKey = privateKey.publicKey.rawRepresentation
        return KeyPair(privateKey: privateKey, publicKey: publicKey)
    }

    /// Derives a symmetric key using Diffie-Hellman key agreement
    /// and HKDF-SHA256 key derivation.
    static func deriveSharedSecret(privateKey: Curve25519.KeyAgreement.PrivateKey,
                                   peerPublicKey: Data) throws -> SymmetricKey {
        let peerPub = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublicKey)
        let secret = try privateKey.sharedSecretFromKeyAgreement(with: peerPub)
        return secret.hkdfDerivedSymmetricKey(using: SHA256.self,
                                              salt: Data(),
                                              sharedInfo: Data(),
                                              outputByteCount: 32)
    }

    /// Encrypts the given plaintext using AES.GCM.
    static func encrypt(_ plaintext: Data, using key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else {
            throw EncryptionError.invalidSealedBox
        }
        return combined
    }

    /// Decrypts ciphertext previously produced by `encrypt`.
    static func decrypt(_ ciphertext: Data, using key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: ciphertext)
        return try AES.GCM.open(box, using: key)
    }

    enum EncryptionError: Error {
        case invalidSealedBox
    }
}

