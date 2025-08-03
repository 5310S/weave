import Foundation

/// Represents a peer in the Weave network.
/// Peers are identified by a unique ID and may advertise
/// a network address and their geographic location.
struct Peer: Identifiable, Codable, Equatable, Hashable {
    enum PeerError: Error {
        case invalidLatitude(Double)
        case invalidLongitude(Double)
    }

    let id: UUID

    /// Optional human-friendly display name.
    var name: String?

    var address: String?
    var port: UInt16?
    /// Public key advertised by the peer for encrypted communication.
    var publicKey: Data?
    var latitude: Double
    var longitude: Double

    /// Arbitrary attributes describing the peer, used for filtering.
    var attributes: [String: String]
    /// When this peer was last seen or updated. This value participates in
    /// equality checks so that two `Peer` instances representing different
    /// observation times are treated as distinct states.
    var lastSeen: Date

    /// Geohash representation of the peer's location for spatial indexing.
    var geohash: String {
        GeoHash.encode(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, address, port, publicKey, latitude, longitude, attributes, lastSeen
    }

    init(id: UUID = UUID(),
         name: String? = nil,

         address: String? = nil,
         port: UInt16? = nil,
         publicKey: Data? = nil,
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
        self.publicKey = publicKey
        self.latitude = latitude
        self.longitude = longitude
        self.attributes = attributes
        self.lastSeen = lastSeen
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let name = try container.decodeIfPresent(String.self, forKey: .name)
        let address = try container.decodeIfPresent(String.self, forKey: .address)
        let port = try container.decodeIfPresent(UInt16.self, forKey: .port)
        let publicKey = try container.decodeIfPresent(Data.self, forKey: .publicKey)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        let attributes = try container.decode([String: String].self, forKey: .attributes)
        let lastSeen = try container.decode(Date.self, forKey: .lastSeen)
        try self.init(id: id,
                      name: name,
                      address: address,
                      port: port,
                      publicKey: publicKey,
                      latitude: latitude,
                      longitude: longitude,
                      attributes: attributes,
                      lastSeen: lastSeen)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(port, forKey: .port)
        try container.encodeIfPresent(publicKey, forKey: .publicKey)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(attributes, forKey: .attributes)
        try container.encode(lastSeen, forKey: .lastSeen)
    }

    static func == (lhs: Peer, rhs: Peer) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.address == rhs.address &&
        lhs.port == rhs.port &&
        lhs.publicKey == rhs.publicKey &&
        lhs.latitude == rhs.latitude &&
        lhs.longitude == rhs.longitude &&
        lhs.attributes == rhs.attributes &&
        lhs.lastSeen == rhs.lastSeen

    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(address)
        hasher.combine(port)
        hasher.combine(publicKey)
        hasher.combine(latitude)
        hasher.combine(longitude)
        hasher.combine(attributes)
        hasher.combine(lastSeen)
    }
}
