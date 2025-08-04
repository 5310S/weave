#if canImport(CoreLocation)
import XCTest
import CoreLocation
@testable import weave

final class LocationIntegrationTests: XCTestCase {
    func testLocationUpdatesModifyPeerCoordinates() async throws {
        let expectation = expectation(description: "location update")
        let manager = PeerManager()
        let peer = try Peer(latitude: 0.0, longitude: 0.0)
        await manager.add(peer)

        let service = LocationService()
        service.onLocationUpdate = { lat, lon in
            Task {
                await manager.updateLocation(id: peer.id, latitude: lat, longitude: lon)
                expectation.fulfill()
            }
        }

        service.start()

        let simulated = CLLocation(latitude: 10.0, longitude: 20.0)
        service.locationManager(CLLocationManager(), didUpdateLocations: [simulated])

        waitForExpectations(timeout: 1.0)
        let updated = await manager.peer(id: peer.id)
        XCTAssertEqual(updated?.latitude, 10.0)
        XCTAssertEqual(updated?.longitude, 20.0)

        service.stop()
    }
}
#endif
