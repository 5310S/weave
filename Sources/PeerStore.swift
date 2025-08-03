import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
#if canImport(Security)
import Security
#else
// On platforms without the Security framework (e.g. Linux), declare a
// compatible alias so the code can compile. The key is stored using
// `UserDefaults` in this case which is not as secure but keeps tests running.
typealias OSStatus = Int32
#endif

/// Persists and restores peers (and the block/liked lists) to and from disk using JSON
/// encoding.
struct PeerStore {
    let url: URL

    private struct Snapshot: Codable {
        var peers: [Peer]
        var blocked: [UUID]
        var liked: [UUID]

        init(peers: [Peer], blocked: [UUID], liked: [UUID] = []) {
            self.peers = peers
            self.blocked = blocked
            self.liked = liked
        }
    }

    /// Errors that can be thrown by `PeerStore`.
    enum StoreError: Error, LocalizedError {
        case keychainError(OSStatus)
        case encryptionFailed
        case decryptionFailed

        var errorDescription: String? {
            switch self {
            case .keychainError(let status):
#if canImport(Security)
                if let message = SecCopyErrorMessageString(status, nil) as String? {
                    return message
                }
#endif
                return "Keychain operation failed with status \(status)"
            case .encryptionFailed:
                return "Failed to encrypt data"
            case .decryptionFailed:
                return "Failed to decrypt data"
            }
        }
    }

    private static let keyTag = "com.weave.peerstorekey"

    /// Retrieves an existing encryption key or creates one if needed. On Apple
    /// platforms the key is stored in the Keychain; elsewhere a less secure
    /// `UserDefaults` storage is used for testing purposes.
    private func loadOrCreateKey() throws -> SymmetricKey {
#if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.keyTag,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        var status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess, let data = item as? Data {
            return SymmetricKey(data: data)
        }

        guard status == errSecItemNotFound else {
            throw StoreError.keychainError(status)
        }

        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.keyTag,
            kSecValueData as String: data
        ]
        status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw StoreError.keychainError(status)
        }
        return key
#else
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.keyTag) {
            return SymmetricKey(data: data)
        }
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        defaults.set(data, forKey: Self.keyTag)
        return key
#endif
    }

    /// Saves the provided peers and blocked/liked IDs to disk, overwriting any
    /// existing file. Data is encrypted using AES.GCM before being written.
    func save(peers: [Peer], blocked: [UUID], liked: [UUID] = []) throws {
        let snapshot = Snapshot(peers: peers, blocked: blocked, liked: liked)
        let data = try JSONEncoder().encode(snapshot)
        let key = try loadOrCreateKey()
        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.seal(data, using: key)
        } catch {
            throw StoreError.encryptionFailed
        }
        try sealedBox.combined.write(to: url, options: .atomic)
    }

    /// Loads peers and blocked/liked IDs from disk. Returns empty collections if the
    /// file does not exist. For backward compatibility with older save formats,
    /// a plain array of peers can still be decoded.
    func load() throws -> (peers: [Peer], blocked: [UUID], liked: [UUID]) {
        guard FileManager.default.fileExists(atPath: url.path) else { return ([], [], []) }
        let data = try Data(contentsOf: url)
        let key = try loadOrCreateKey()

        do {
            let box = try AES.GCM.SealedBox(combined: data)
            let decrypted = try AES.GCM.open(box, using: key)
            if let snapshot = try? JSONDecoder().decode(Snapshot.self, from: decrypted) {
                return (snapshot.peers, snapshot.blocked, snapshot.liked)
            }
        } catch {
            // Fallback: attempt to decode plain JSON for backward compatibility
            if let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
                return (snapshot.peers, snapshot.blocked, snapshot.liked)
            }
            if let peers = try? JSONDecoder().decode([Peer].self, from: data) {
                return (peers, [], [])
            }
            throw StoreError.decryptionFailed
        }

        throw StoreError.decryptionFailed
    }
}
