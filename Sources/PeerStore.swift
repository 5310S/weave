import Foundation
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#else
// Minimal stand-ins for the CryptoKit APIs used in PeerStore so that the code
// can compile in environments without the real libraries. The implementation
// simply XORs data with the key for "encryption" and should not be used in
// production.
struct SymmetricKey {
    struct SymmetricKeySize { static let bits256 = SymmetricKeySize() }
    let data: Data
    init(size: SymmetricKeySize) {
        self.data = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
    }
    init(data: Data) { self.data = data }
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try data.withUnsafeBytes(body)
    }
}
enum AES {
    enum GCM {
        struct SealedBox { let combined: Data }
        static func seal(_ data: Data, using key: SymmetricKey) throws -> SealedBox {
            let xored = data.enumerated().map { $0.element ^ key.data[$0.offset % key.data.count] }
            return SealedBox(combined: Data(xored))
        }
        static func open(_ box: SealedBox, using key: SymmetricKey) throws -> Data {
            let decrypted = box.combined.enumerated().map { $0.element ^ key.data[$0.offset % key.data.count] }
            return Data(decrypted)
        }
    }
}
#endif
#if canImport(Security)
import Security
#else
// On platforms without the Security framework (e.g. Linux), declare a
// compatible alias so the code can compile. The key is stored in a file with
// restrictive permissions instead of the Keychain.
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
    /// platforms the key is stored in the Keychain; elsewhere it is stored in a
    /// file with restrictive permissions.
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
        if let data = Self.readKeyFile(at: keyURL) {
            return SymmetricKey(data: data)
        }
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        try Self.writeKeyFile(data, to: keyURL)
        return key
#endif
    }

#if !canImport(Security)
    /// URL of the key file used on platforms without Keychain access.
    private var keyURL: URL {
        url.deletingLastPathComponent().appendingPathComponent("\(Self.keyTag).key")
    }

    /// Atomically reads the key file if it exists.
    static func readKeyFile(at url: URL) -> Data? {
        try? Data(contentsOf: url)
    }

    /// Atomically writes the key file with restrictive permissions.
    static func writeKeyFile(_ data: Data, to url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
#endif

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
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
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

extension PeerStore {
    /// Builds buckets keyed by geohash prefixes for the stored peers. Each
    /// bucket contains peers whose geohash (derived from their stored latitude
    /// and longitude) shares the same prefix of the specified length.
    /// - Parameter prefixLength: Number of characters to use for the prefix key.
    /// - Returns: Dictionary mapping geohash prefixes to the peers in that cell.
    func geohashBuckets(prefixLength: Int) throws -> [String: [Peer]] {
        let (peers, _, _) = try load()
        return peers.reduce(into: [String: [Peer]]()) { dict, peer in
            let hash = GeoHash.encode(latitude: peer.latitude, longitude: peer.longitude)
            let prefix = String(hash.prefix(prefixLength))
            dict[prefix, default: []].append(peer)
        }
    }

    /// Returns peers whose geohash begins with the provided prefix by consulting
    /// the geohash buckets built from the stored peers.
    /// - Parameter prefix: The geohash prefix to search for.
    func lookup(prefix: String) throws -> [Peer] {
        let buckets = try geohashBuckets(prefixLength: prefix.count)
        return buckets[prefix] ?? []
    }
}
