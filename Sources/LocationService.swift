#if canImport(CoreLocation)
import Foundation
import CoreLocation

/// Delegate protocol to receive location updates and errors.
protocol LocationServiceDelegate: AnyObject {
    func locationService(_ service: LocationService, didUpdateLatitude latitude: Double, longitude: Double)
    func locationService(_ service: LocationService, didFailWithError error: Error)
}

/// Errors that can be emitted by ``LocationService``.
enum LocationServiceError: Error {
    case authorizationDenied
    case authorizationRestricted
}

/// A simple wrapper around `CLLocationManager` that requests
/// permission and forwards coordinate updates to its delegate or
/// callback.
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var didStop = false

    /// Delegate that receives location updates.
    weak var delegate: LocationServiceDelegate?

    /// Optional closure called when coordinates change.
    var onLocationUpdate: ((Double, Double) -> Void)?

    /// Optional closure called when errors occur.
    var onError: ((Error) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
    }

    /// Begins requesting authorization and, once granted, updates.
    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied:
            let error = LocationServiceError.authorizationDenied
            delegate?.locationService(self, didFailWithError: error)
            onError?(error)
        case .restricted:
            let error = LocationServiceError.authorizationRestricted
            delegate?.locationService(self, didFailWithError: error)
            onError?(error)
        default:
            break
        }
    }

    /// Stops location updates and clears callbacks.
    func stop() {
        guard !didStop else { return }
        didStop = true
        manager.stopUpdatingLocation()
        manager.delegate = nil
        delegate = nil
        onLocationUpdate = nil
        onError = nil
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied:
            let error = LocationServiceError.authorizationDenied
            delegate?.locationService(self, didFailWithError: error)
            onError?(error)
        case .restricted:
            let error = LocationServiceError.authorizationRestricted
            delegate?.locationService(self, didFailWithError: error)
            onError?(error)
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        delegate?.locationService(self, didUpdateLatitude: lat, longitude: lon)
        onLocationUpdate?(lat, lon)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        delegate?.locationService(self, didFailWithError: error)
        onError?(error)
    }

    deinit {
        stop()
    }
}
#endif
