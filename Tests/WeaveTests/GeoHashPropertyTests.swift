import XCTest
import SwiftCheck
@testable import weave

final class GeoHashPropertyTests: XCTestCase {
    func testRandomCoordinateRoundTrip() {
        let coordinateGen = Gen<(Double, Double, Int)> { rng in
            let lat = Double.random(in: -90.0...90.0, using: &rng)
            let lon = Double.random(in: -180.0...180.0, using: &rng)
            let precision = Int.random(in: 1...12, using: &rng)
            return (lat, lon, precision)
        }

        property("encoding then decoding returns original coordinates") <- forAll(coordinateGen) { (lat, lon, precision) in
            let hash = GeoHash.encode(latitude: lat, longitude: lon, precision: precision)
            guard let (decodedLat, decodedLon) = try? GeoHash.decode(hash) else {
                return false
            }
            let (latErr, lonErr) = errorForPrecision(precision)
            return abs(decodedLat - lat) <= latErr / 2 && abs(decodedLon - lon) <= lonErr / 2
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
