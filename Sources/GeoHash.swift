import Foundation

/// Utility for encoding geographic coordinates into a geohash string.
/// Geohashes compactly represent latitude/longitude pairs and can be used
/// for coarse spatial grouping, e.g. when indexing peers in a distributed
/// hash table.
struct GeoHash {
    private static let base32: [Character] = Array("0123456789bcdefghjkmnpqrstuvwxyz")
    private static let decodeMap: [Character: Int] = {
        var map: [Character: Int] = [:]
        for (index, char) in base32.enumerated() {
            map[char] = index
        }
        return map
    }()

    /// Encodes the given latitude and longitude into a geohash string with the
    /// specified precision (number of characters).
    static func encode(latitude: Double, longitude: Double, precision: Int = 8) -> String {
        var latInterval = (-90.0, 90.0)
        var lonInterval = (-180.0, 180.0)
        var isEven = true
        var bit = 0
        var ch = 0
        var hash: [Character] = []

        while hash.count < precision {
            if isEven {
                let mid = (lonInterval.0 + lonInterval.1) / 2
                if longitude > mid {
                    ch |= 1 << (4 - bit)
                    lonInterval.0 = mid
                } else {
                    lonInterval.1 = mid
                }
            } else {
                let mid = (latInterval.0 + latInterval.1) / 2
                if latitude > mid {
                    ch |= 1 << (4 - bit)
                    latInterval.0 = mid
                } else {
                    latInterval.1 = mid
                }
            }

            isEven.toggle()
            if bit < 4 {
                bit += 1
            } else {
                hash.append(base32[ch])
                bit = 0
                ch = 0
            }
        }

        return String(hash)
    }

    /// Decodes a geohash string back into a latitude/longitude pair.
    /// - Parameter hash: The geohash string to decode.
    /// - Returns: A tuple containing the latitude and longitude at the center of the geohash cell.
    static func decode(_ hash: String) -> (latitude: Double, longitude: Double) {
        var latInterval = (-90.0, 90.0)
        var lonInterval = (-180.0, 180.0)
        var isEven = true

        for character in hash {
            guard let value = decodeMap[character] else { continue }
            for mask in [16, 8, 4, 2, 1] {
                if isEven {
                    let mid = (lonInterval.0 + lonInterval.1) / 2
                    if value & mask != 0 {
                        lonInterval.0 = mid
                    } else {
                        lonInterval.1 = mid
                    }
                } else {
                    let mid = (latInterval.0 + latInterval.1) / 2
                    if value & mask != 0 {
                        latInterval.0 = mid
                    } else {
                        latInterval.1 = mid
                    }
                }
                isEven.toggle()
            }
        }

        let latitude = (latInterval.0 + latInterval.1) / 2
        let longitude = (lonInterval.0 + lonInterval.1) / 2
        return (latitude, longitude)
    }
}

