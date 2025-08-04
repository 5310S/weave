#if canImport(CoreLocation)
import XCTest
import CoreLocation
@testable import weave

final class CoreLocationServiceTests: XCTestCase {
    func testLocationUpdatesFeedPeerManager() async throws {
        let manager = PeerManager()
        let peer = try Peer(latitude: 0.0, longitude: 0.0)
        try await manager.add(peer)

        // Service automatically updates the peer manager when coordinates change
        let service = CoreLocationService(peerManager: manager, peerID: peer.id)

        // Simulate a location update
        let simulated = CLLocation(latitude: 50.0, longitude: 8.0)
        service.locationManager(CLLocationManager(), didUpdateLocations: [simulated])

        // Allow asynchronous update to complete
        try? await Task.sleep(nanoseconds: 50_000_000)

        let updated = await manager.peer(id: peer.id)
        XCTAssertEqual(updated?.latitude, 50.0)
        XCTAssertEqual(updated?.longitude, 8.0)

        service.stop()
    }

    func testErrorPropagation() {
        let delegateExpectation = expectation(description: "delegate error")
        let closureExpectation = expectation(description: "closure error")
        let service = CoreLocationService()

        class Delegate: LocationServiceDelegate {
            var expectation: XCTestExpectation?

            func locationService(_ service: CoreLocationService, didUpdateLatitude latitude: Double, longitude: Double) {}

            func locationService(_ service: CoreLocationService, didFailWithError error: Error) {
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

    func testAuthorizationDeniedAndRestrictedPropagateError() {
        let delegateExpectation = expectation(description: "delegate error")
        delegateExpectation.expectedFulfillmentCount = 2
        let closureExpectation = expectation(description: "closure error")
        closureExpectation.expectedFulfillmentCount = 2
        let service = CoreLocationService()

        class Delegate: LocationServiceDelegate {
            var expectation: XCTestExpectation?

            func locationService(_ service: CoreLocationService, didUpdateLatitude latitude: Double, longitude: Double) {}

            func locationService(_ service: CoreLocationService, didFailWithError error: Error) {
                expectation?.fulfill()
            }
        }

        let delegate = Delegate()
        delegate.expectation = delegateExpectation
        service.delegate = delegate

        service.onError = { _ in closureExpectation.fulfill() }

        service.locationManager(CLLocationManager(), didChangeAuthorization: .denied)
        service.locationManager(CLLocationManager(), didChangeAuthorization: .restricted)

        wait(for: [delegateExpectation, closureExpectation], timeout: 1.0)
        service.stop()
    }

    func testStopClearsDelegateAndClosures() {
        let service = CoreLocationService()

        class Delegate: LocationServiceDelegate {
            func locationService(_ service: CoreLocationService, didUpdateLatitude latitude: Double, longitude: Double) {}
            func locationService(_ service: CoreLocationService, didFailWithError error: Error) {}
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

    func testDeinitClearsManagerDelegate() {
        var service: CoreLocationService? = CoreLocationService()

        let mirror = Mirror(reflecting: service as Any)
        guard let manager = mirror.children.first(where: { $0.label == "manager" })?.value as? CLLocationManager else {
            XCTFail("Unable to access CLLocationManager")
            return
        }

        XCTAssertNotNil(manager.delegate)
        service = nil
        XCTAssertNil(manager.delegate)
    }
}
#endif
