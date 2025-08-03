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

    init(id: UUID = UUID(),
         address: String? = nil,
         port: UInt16? = nil,
         latitude: Double,
         longitude: Double,
         attributes: [String: String] = [:]) {

        self.id = id
        self.address = address
        self.port = port
        self.latitude = latitude
        self.longitude = longitude

        self.attributes = attributes

    }
}
