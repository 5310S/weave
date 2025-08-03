import Foundation

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

    /// Saves the provided peers and blocked/liked IDs to disk, overwriting any
    /// existing file.
    func save(peers: [Peer], blocked: [UUID], liked: [UUID] = []) throws {
        let snapshot = Snapshot(peers: peers, blocked: blocked, liked: liked)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    /// Loads peers and blocked/liked IDs from disk. Returns empty collections if the
    /// file does not exist. For backward compatibility with older save formats,
    /// a plain array of peers can still be decoded.
    func load() throws -> (peers: [Peer], blocked: [UUID], liked: [UUID]) {
        guard FileManager.default.fileExists(atPath: url.path) else { return ([], [], []) }
        let data = try Data(contentsOf: url)
        if let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            return (snapshot.peers, snapshot.blocked, snapshot.liked)
        }

        let peers = try JSONDecoder().decode([Peer].self, from: data)
        return (peers, [], [])
    }
}
