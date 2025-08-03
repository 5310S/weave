import XCTest
@testable import weave

final class GeoHashTests: XCTestCase {
    func testEncodeDecodeRoundTrip() {
        let coordinates: [(Double, Double)] = [
            (0.0, 0.0),
            (37.7749, -122.4194),
            (51.5074, -0.1278)
        ]
        let precisions = [4, 8, 12]

        for (lat, lon) in coordinates {
            for precision in precisions {
                let hash = GeoHash.encode(latitude: lat, longitude: lon, precision: precision)
                let (decodedLat, decodedLon) = GeoHash.decode(hash)
                let (latErr, lonErr) = errorForPrecision(precision)
                XCTAssertLessThanOrEqual(abs(decodedLat - lat), latErr / 2)
                XCTAssertLessThanOrEqual(abs(decodedLon - lon), lonErr / 2)
                let reencoded = GeoHash.encode(latitude: decodedLat, longitude: decodedLon, precision: precision)
                XCTAssertEqual(reencoded, hash)
            }
        }
    }

    private func errorForPrecision(_ precision: Int) -> (Double, Double) {
        var latBits = 0
        var lonBits = 0
        for i in 0..<(precision * 5) {
            if i % 2 == 0 { lonBits += 1 } else { latBits += 1 }
        }
        let latErr = 180.0 / Double(1 << latBits)
        let lonErr = 360.0 / Double(1 << lonBits)
        return (latErr, lonErr)
    }
}
