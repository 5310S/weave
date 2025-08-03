import Foundation

/// Persists and restores peers to and from disk using JSON encoding.
struct PeerStore {
    let url: URL

    /// Saves the provided peers to disk, overwriting any existing file.
    func save(_ peers: [Peer]) throws {
        let data = try JSONEncoder().encode(peers)
        try data.write(to: url, options: .atomic)
    }

    /// Loads peers from disk, returning an empty array if the file does not exist.
    func load() throws -> [Peer] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Peer].self, from: data)
    }
}
