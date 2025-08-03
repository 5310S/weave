#if canImport(CoreLocation) && os(iOS)
import XCTest
import CoreLocation
@testable import weave

final class LocationServiceTests: XCTestCase {
    func testLocationUpdatesFeedPeerManager() throws {
        let expectation = expectation(description: "location update")
        let service = LocationService()
        let manager = PeerManager()
        let peer = try Peer(latitude: 0.0, longitude: 0.0)
        manager.add(peer)

        service.onLocationUpdate = { lat, lon in
            manager.updateLocation(id: peer.id, latitude: lat, longitude: lon)
            expectation.fulfill()
        }

        // Simulate a location update
        let simulated = CLLocation(latitude: 50.0, longitude: 8.0)
        service.locationManager(CLLocationManager(), didUpdateLocations: [simulated])

        waitForExpectations(timeout: 1.0)
        let updated = manager.peer(id: peer.id)
        XCTAssertEqual(updated?.latitude, 50.0)
        XCTAssertEqual(updated?.longitude, 8.0)
    }
}
#endif
