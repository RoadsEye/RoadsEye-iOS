import CoreLocation
import SwiftUI

class LocationSpeedManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationSpeedManager()
    
    @Published var latitude: String = "Error"
    @Published var longitude: String = "Error"
    @Published var speed: Double = 0.0
    @Published var speedUnit: String = "mph"
    
    private var locationManager = CLLocationManager()
    private var speedTimer: Timer?
    
    override init() {
        super.init()
        
        // Load saved speed unit or set default based on locale asynchronously
        DispatchQueue.global(qos: .userInitiated).async {
            let currentLocale = Locale.current
            let defaultUnit = currentLocale.measurementSystem == .metric ? "KM/H" : "MPH"
            
            let savedUnit = UserDefaults.standard.string(forKey: "selectedSpeedUnits") ?? defaultUnit
            
            DispatchQueue.main.async {
                self.speedUnit = savedUnit
                if UserDefaults.standard.string(forKey: "selectedSpeedUnits") == nil {
                    UserDefaults.standard.set(savedUnit, forKey: "selectedSpeedUnits")
                }
            }
        }
        
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.delegate = self
        
        // IMPORTANT: Do NOT call requestWhenInUseAuthorization() here anymore
        // Permission request is now triggered from MainView
    }
    
    // New public method – call this from MainView when ready to ask/start
    func requestLocationPermissionAndStartIfNeeded() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            // Delegate will handle starting updates once authorized
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .restricted, .denied:
            print("LocationSpeedManager: Location access denied/restricted – will not start updates")
            // Optionally: post notification or update UI state to show explanation
        @unknown default:
            break
        }
    }
    
    private func startLocationUpdates() {
        locationManager.startUpdatingLocation()
        startSpeedUpdates()
    }
    
    private func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        stopSpeedUpdates()
    }
    
    func startSpeedUpdates() {
        if speedTimer == nil {
            speedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.updateSpeed()
            }
            RunLoop.main.add(speedTimer!, forMode: .common)
        }
    }
    
    func stopSpeedUpdates() {
        speedTimer?.invalidate()
        speedTimer = nil
    }
    
    private func updateSpeed() {
        guard let currentLocation = locationManager.location else { return }
        
        let rawSpeed = max(currentLocation.speed, 0)
        let multiplier = speedUnit.uppercased() == "MPH" ? 2.23694 : 3.6
        let displaySpeed = rawSpeed * multiplier
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if abs(self.speed - displaySpeed) > 0.1 {
                self.speed = displaySpeed
                NotificationCenter.default.post(name: NSNotification.Name("SpeedUpdated"), object: nil)
            }
        }
    }
    
    func setSpeedUnit(_ unit: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            UserDefaults.standard.set(unit, forKey: "selectedSpeedUnits")
            DispatchQueue.main.async {
                self.speedUnit = unit
            }
        }
    }
    
    func determineSpeedUnitForLocation() {
        let countryCode: String?
        
        if #available(iOS 16, *) {
            countryCode = Locale.current.region?.identifier
        } else {
            countryCode = Locale.current.regionCode
        }
        
        guard let code = countryCode else {
            setSpeedUnit("KM/H")
            return
        }
        
        let mphCountries = ["US", "GB", "LR", "MM"]
        
        if mphCountries.contains(code) {
            setSpeedUnit("MPH")
        } else {
            setSpeedUnit("KM/H")
        }
    }
    
    // Delegate methods
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.latitude = String(format: "%.7f", location.coordinate.latitude)
            self.longitude = String(format: "%.7f", location.coordinate.longitude)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationSpeedManager: Location manager error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .restricted, .denied:
            print("LocationSpeedManager: Location access denied/restricted")
            // You could post a notification here to show an in-app alert if needed
        case .notDetermined:
            // Do nothing – we already requested when needed
            break
        @unknown default:
            break
        }
    }
}
