import CoreLocation
import Foundation

nonisolated enum AutoTickLocationAuthorizationStatus: Equatable {
    case notDetermined
    case restricted
    case denied
    case authorizedWhenInUse
    case authorizedAlways
    case unknown

    init(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        case .denied:
            self = .denied
        case .authorizedWhenInUse:
            self = .authorizedWhenInUse
        case .authorizedAlways:
            self = .authorizedAlways
        @unknown default:
            self = .unknown
        }
    }

    var canRequestCurrentLocation: Bool {
        self == .authorizedWhenInUse || self == .authorizedAlways
    }

    var canMonitorRegions: Bool {
        self == .authorizedWhenInUse || self == .authorizedAlways
    }

    var needsPermissionRequest: Bool {
        self == .notDetermined
    }

    var canRequestAlwaysAuthorization: Bool {
        self == .authorizedWhenInUse
    }

    var displayText: String {
        switch self {
        case .notDetermined:
            "Location permission has not been requested."
        case .restricted:
            "Location access is restricted on this device."
        case .denied:
            "Location access is denied. Auto Ticks will stay off until permission is allowed in Settings."
        case .authorizedWhenInUse:
            "Location access is allowed while Tick is open."
        case .authorizedAlways:
            "Background location access is allowed for saved Auto Tick rules."
        case .unknown:
            "Tick cannot read the current location permission state."
        }
    }
}

nonisolated enum AutoTickRegionEvent: Equatable {
    case arrival
    case departure
}

nonisolated struct AutoTickCoordinate: Equatable {
    let latitude: Double
    let longitude: Double
}

nonisolated struct AutoTickLocationState: Equatable {
    let authorizationStatus: AutoTickLocationAuthorizationStatus
    let latestCoordinate: AutoTickCoordinate?
    let statusMessage: String
    let errorMessage: String?
}

@MainActor
final class AutoTickLocationService: NSObject, CLLocationManagerDelegate {
    private static let regionIdentifierPrefix = "tick.autoTick."

    private let manager: CLLocationManager
    private(set) var authorizationStatus: AutoTickLocationAuthorizationStatus
    private(set) var latestCoordinate: AutoTickCoordinate?
    private(set) var statusMessage = "Auto Ticks use location only after you create and enable a rule."
    private(set) var errorMessage: String?

    var stateDidChange: ((AutoTickLocationState) -> Void)?
    var regionEventHandler: ((AutoTickRule.ID, AutoTickRegionEvent) -> Void)?

    init(manager: CLLocationManager = CLLocationManager()) {
        self.manager = manager
        self.authorizationStatus = AutoTickLocationAuthorizationStatus(manager.authorizationStatus)
        super.init()
        manager.delegate = self
    }

    var currentState: AutoTickLocationState {
        AutoTickLocationState(
            authorizationStatus: authorizationStatus,
            latestCoordinate: latestCoordinate,
            statusMessage: statusMessage,
            errorMessage: errorMessage
        )
    }

    func requestWhenInUseAuthorization() {
        errorMessage = nil

        guard authorizationStatus.needsPermissionRequest else {
            publishState()
            return
        }

        statusMessage = "Tick is asking for location access for Auto Ticks."
        publishState()
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        errorMessage = nil

        guard authorizationStatus.canRequestAlwaysAuthorization else {
            statusMessage = authorizationStatus.displayText
            publishState()
            return
        }

        statusMessage = "Tick is asking for background location access for saved Auto Tick rules."
        publishState()
        manager.requestAlwaysAuthorization()
    }

    func requestCurrentLocation() {
        errorMessage = nil

        guard CLLocationManager.locationServicesEnabled() else {
            errorMessage = "Location Services are off on this device."
            publishState()
            return
        }

        guard authorizationStatus.canRequestCurrentLocation else {
            if authorizationStatus.needsPermissionRequest {
                requestWhenInUseAuthorization()
            } else {
                errorMessage = authorizationStatus.displayText
                publishState()
            }
            return
        }

        statusMessage = "Getting current location for this Auto Tick rule."
        publishState()
        manager.requestLocation()
    }

    func refreshMonitoring(for rules: [AutoTickRule]) {
        stopStaleMonitoring(keeping: rules)

        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            statusMessage = "Region monitoring is not available on this device."
            publishState()
            return
        }

        guard authorizationStatus.canMonitorRegions else {
            statusMessage = authorizationStatus.displayText
            publishState()
            return
        }

        for rule in rules where rule.isEnabled {
            startMonitoring(rule)
        }

        statusMessage = rules.contains(where: \.isEnabled) ?
            "Auto Ticks is monitoring enabled rules." :
            "No Auto Tick rules are enabled."
        publishState()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = AutoTickLocationAuthorizationStatus(manager.authorizationStatus)
        statusMessage = authorizationStatus.displayText
        publishState()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }

        latestCoordinate = AutoTickCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        statusMessage = "Current location is ready for an Auto Tick rule."
        errorMessage = nil
        publishState()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = "Tick could not get the current location. \(error.localizedDescription)"
        publishState()
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let ruleID = ruleID(from: region.identifier) else {
            return
        }

        regionEventHandler?(ruleID, .arrival)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let ruleID = ruleID(from: region.identifier) else {
            return
        }

        regionEventHandler?(ruleID, .departure)
    }

    private func startMonitoring(_ rule: AutoTickRule) {
        let identifier = Self.regionIdentifier(for: rule.id)

        guard !manager.monitoredRegions.contains(where: { $0.identifier == identifier }) else {
            return
        }

        let radius = min(max(rule.radiusMeters, 1), manager.maximumRegionMonitoringDistance)
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: rule.latitude, longitude: rule.longitude),
            radius: radius,
            identifier: identifier
        )
        region.notifyOnEntry = rule.startsOnArrival
        region.notifyOnExit = rule.stopsOnDeparture
        manager.startMonitoring(for: region)
    }

    private func stopStaleMonitoring(keeping rules: [AutoTickRule]) {
        let desiredIdentifiers = Set(rules.filter(\.isEnabled).map { Self.regionIdentifier(for: $0.id) })

        for region in manager.monitoredRegions where region.identifier.hasPrefix(Self.regionIdentifierPrefix) {
            if !desiredIdentifiers.contains(region.identifier) {
                manager.stopMonitoring(for: region)
            }
        }
    }

    private func publishState() {
        stateDidChange?(currentState)
    }

    private static func regionIdentifier(for ruleID: AutoTickRule.ID) -> String {
        regionIdentifierPrefix + ruleID.uuidString
    }

    private func ruleID(from identifier: String) -> AutoTickRule.ID? {
        guard identifier.hasPrefix(Self.regionIdentifierPrefix) else {
            return nil
        }

        let uuidString = String(identifier.dropFirst(Self.regionIdentifierPrefix.count))
        return UUID(uuidString: uuidString)
    }
}
