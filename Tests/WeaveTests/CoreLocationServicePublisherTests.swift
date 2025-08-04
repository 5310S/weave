#if canImport(CoreLocation) && canImport(Combine)
import XCTest
import CoreLocation
import Combine
@testable import weave

final class CoreLocationServicePublisherTests: XCTestCase {
    private var cancellables = Set<AnyCancellable>()

    func testLocationPublisherEmitsCoordinates() {
        let service = CoreLocationService()
        let expectation = expectation(description: "publisher emits")

        service.locationPublisher
            .sink { lat, lon in
                XCTAssertEqual(lat, 42.0)
                XCTAssertEqual(lon, -71.0)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        let simulated = CLLocation(latitude: 42.0, longitude: -71.0)
        service.locationManager(CLLocationManager(), didUpdateLocations: [simulated])

        waitForExpectations(timeout: 1.0)
        service.stop()
    }
}
#endif
