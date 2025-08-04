#if canImport(CoreLocation)
import Foundation
import CoreLocation
#if canImport(Combine)
import Combine
#endif

/// Delegate protocol to receive location updates and errors.
protocol LocationServiceDelegate: AnyObject {
    func locationService(_ service: CoreLocationService, didUpdateLatitude latitude: Double, longitude: Double)
    func locationService(_ service: CoreLocationService, didFailWithError error: Error)
}

/// Errors that can be emitted by ``CoreLocationService``.
enum LocationServiceError: Error {
    case authorizationDenied
    case authorizationRestricted
}

/// A simple wrapper around `CLLocationManager` that requests
/// permission and forwards coordinate updates to its delegate or
/// callback.  Location events can also be observed using Combine
/// publishers when available.
final class CoreLocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var didStop = false

    /// Peer manager and identifier used for automatically propagating
    /// location updates through the peer data flow. Both are optional so the
    /// service can still be used in isolation or with callbacks.
    private var peerManager: PeerManager?
    private var peerID: UUID?

    /// Delegate that receives location updates.
    weak var delegate: LocationServiceDelegate?

    /// Optional closure called when coordinates change.
    var onLocationUpdate: ((Double, Double) -> Void)?

    /// Optional closure called when errors occur.
    var onError: ((Error) -> Void)?

    #if canImport(Combine)
    private let locationSubject = PassthroughSubject<(Double, Double), Never>()
    /// Publishes new latitude/longitude pairs as they are received.
    var locationPublisher: AnyPublisher<(Double, Double), Never> {
        locationSubject.eraseToAnyPublisher()
    }

    private let errorSubject = PassthroughSubject<Error, Never>()
    /// Publishes errors produced by the service.
    var errorPublisher: AnyPublisher<Error, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    #endif

    override init() {
        super.init()
        manager.delegate = self
    }

    /// Creates a service that will forward location changes directly to a
    /// ``PeerManager`` for the specified peer identifier.
    init(peerManager: PeerManager, peerID: UUID) {
        self.peerManager = peerManager
        self.peerID = peerID
        super.init()
        manager.delegate = self
    }

    /// Associates this service with a peer manager after initialization.
    /// - Parameters:
    ///   - manager: The peer manager responsible for the peer.
    ///   - id: The identifier of the peer whose location should be updated.
    func track(manager: PeerManager, id: UUID) {
        self.peerManager = manager
        self.peerID = id
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
            #if canImport(Combine)
            errorSubject.send(error)
            #endif
        case .restricted:
            let error = LocationServiceError.authorizationRestricted
            delegate?.locationService(self, didFailWithError: error)
            onError?(error)
            #if canImport(Combine)
            errorSubject.send(error)
            #endif
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
        peerManager = nil
        peerID = nil
        #if canImport(Combine)
        locationSubject.send(completion: .finished)
        errorSubject.send(completion: .finished)
        #endif
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
            #if canImport(Combine)
            errorSubject.send(error)
            #endif
        case .restricted:
            let error = LocationServiceError.authorizationRestricted
            delegate?.locationService(self, didFailWithError: error)
            onError?(error)
            #if canImport(Combine)
            errorSubject.send(error)
            #endif
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
        if let peerManager, let peerID {
            Task {
                try? await peerManager.updateLocation(id: peerID, latitude: lat, longitude: lon)
            }
        }
        #if canImport(Combine)
        locationSubject.send((lat, lon))
        #endif
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        delegate?.locationService(self, didFailWithError: error)
        onError?(error)
        #if canImport(Combine)
        errorSubject.send(error)
        #endif
    }

    deinit {
        stop()
    }
}
#endif
