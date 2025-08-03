import Foundation

/// Represents a peer in the Weave network.
/// Peers are identified by a unique ID and may advertise
/// a network address and their geographic location.
struct Peer: Identifiable, Codable, Equatable {
    enum PeerError: Error {
        case invalidLatitude(Double)
        case invalidLongitude(Double)
    }

    let id: UUID

    /// Optional human-friendly display name.
    var name: String?

    var address: String?
    var port: UInt16?
    var latitude: Double
    var longitude: Double

    /// Arbitrary attributes describing the peer, used for filtering.
    var attributes: [String: String]
    /// When this peer was last seen or updated.
    var lastSeen: Date

    /// Geohash representation of the peer's location for spatial indexing.
    var geohash: String {
        GeoHash.encode(latitude: latitude, longitude: longitude)
    }

    init(id: UUID = UUID(),
         name: String? = nil,

         address: String? = nil,
         port: UInt16? = nil,
         latitude: Double,
         longitude: Double,

         attributes: [String: String] = [:],
         lastSeen: Date = Date()) throws {
        guard (-90.0...90.0).contains(latitude) else {
            throw PeerError.invalidLatitude(latitude)
        }
        guard (-180.0...180.0).contains(longitude) else {
            throw PeerError.invalidLongitude(longitude)
        }

        self.id = id
        self.name = name

        self.address = address
        self.port = port
        self.latitude = latitude
        self.longitude = longitude
        self.attributes = attributes
        self.lastSeen = lastSeen
    }

    static func == (lhs: Peer, rhs: Peer) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.address == rhs.address &&
        lhs.port == rhs.port &&
        lhs.latitude == rhs.latitude &&
        lhs.longitude == rhs.longitude &&
        lhs.attributes == rhs.attributes

    }
}
