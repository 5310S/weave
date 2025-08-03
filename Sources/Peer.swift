import Foundation

/// Represents a peer in the Weave network.
/// Peers are identified by a unique ID and may advertise
/// a network address and their geographic location.
struct Peer: Identifiable, Codable, Equatable {
    let id: UUID
    var address: String?
    var port: UInt16?
    var latitude: Double
    var longitude: Double
    /// Arbitrary attributes describing the peer, used for filtering.
    var attributes: [String: String]
    /// When this peer was last seen or updated.
    var lastSeen: Date

    init(id: UUID = UUID(),
         address: String? = nil,
         port: UInt16? = nil,
         latitude: Double,
         longitude: Double,
         attributes: [String: String] = [:],
         lastSeen: Date = Date()) {
        self.id = id
        self.address = address
        self.port = port
        self.latitude = latitude
        self.longitude = longitude
        self.attributes = attributes
        self.lastSeen = lastSeen
    }

    static func == (lhs: Peer, rhs: Peer) -> Bool {
        lhs.id == rhs.id &&
        lhs.address == rhs.address &&
        lhs.port == rhs.port &&
        lhs.latitude == rhs.latitude &&
        lhs.longitude == rhs.longitude &&
        lhs.attributes == rhs.attributes
    }
}
