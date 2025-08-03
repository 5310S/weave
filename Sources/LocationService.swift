#if canImport(CoreLocation)
import Foundation
import CoreLocation

/// Delegate protocol to receive location updates.
protocol LocationServiceDelegate: AnyObject {
    func locationService(_ service: LocationService, didUpdateLatitude latitude: Double, longitude: Double)
}

/// A simple wrapper around `CLLocationManager` that requests
/// permission and forwards coordinate updates to its delegate or
/// callback.
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    /// Delegate that receives location updates.
    weak var delegate: LocationServiceDelegate?

    /// Optional closure called when coordinates change.
    var onLocationUpdate: ((Double, Double) -> Void)?

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
        default:
            break
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        delegate?.locationService(self, didUpdateLatitude: lat, longitude: lon)
        onLocationUpdate?(lat, lon)
    }
}
#endif
