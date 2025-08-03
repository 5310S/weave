#if canImport(CoreLocation)
import XCTest
import CoreLocation
@testable import weave

final class LocationServiceTests: XCTestCase {
    func testLocationUpdatesFeedPeerManager() async throws {
        let expectation = expectation(description: "location update")
        let service = LocationService()
        let manager = PeerManager()
        let peer = try Peer(latitude: 0.0, longitude: 0.0)
        await manager.add(peer)

        service.onLocationUpdate = { lat, lon in
            Task {
                await manager.updateLocation(id: peer.id, latitude: lat, longitude: lon)
                expectation.fulfill()
            }
        }

        // Simulate a location update
        let simulated = CLLocation(latitude: 50.0, longitude: 8.0)
        service.locationManager(CLLocationManager(), didUpdateLocations: [simulated])

        waitForExpectations(timeout: 1.0)
        let updated = await manager.peer(id: peer.id)
        XCTAssertEqual(updated?.latitude, 50.0)
        XCTAssertEqual(updated?.longitude, 8.0)

        service.stop()
        XCTAssertNil(service.onLocationUpdate)
    }

    func testErrorPropagation() {
        let delegateExpectation = expectation(description: "delegate error")
        let closureExpectation = expectation(description: "closure error")
        let service = LocationService()

        class Delegate: LocationServiceDelegate {
            var expectation: XCTestExpectation?

            func locationService(_ service: LocationService, didUpdateLatitude latitude: Double, longitude: Double) {}

            func locationService(_ service: LocationService, didFailWithError error: Error) {
                expectation?.fulfill()
            }
        }

        let delegate = Delegate()
        delegate.expectation = delegateExpectation
        service.delegate = delegate

        service.onError = { _ in closureExpectation.fulfill() }

        let error = NSError(domain: "test", code: 1)
        service.locationManager(CLLocationManager(), didFailWithError: error)

        wait(for: [delegateExpectation, closureExpectation], timeout: 1.0)
        service.stop()
    }

    func testStopClearsDelegateAndClosures() {
        let service = LocationService()

        class Delegate: LocationServiceDelegate {
            func locationService(_ service: LocationService, didUpdateLatitude latitude: Double, longitude: Double) {}
            func locationService(_ service: LocationService, didFailWithError error: Error) {}
        }

        let delegate = Delegate()
        service.delegate = delegate
        service.onLocationUpdate = { _, _ in }
        service.onError = { _ in }

        service.stop()

        XCTAssertNil(service.delegate)
        XCTAssertNil(service.onLocationUpdate)
        XCTAssertNil(service.onError)
    }
}
#endif
