import SwiftUI
import Combine

// Thread-safe boolean wrapper for initialization state
private class AtomicBool {
    private let lock = NSLock()
    private var _value: Bool
    
    init(value: Bool) {
        self._value = value
    }
    
    var value: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _value = newValue
        }
    }
}

// Mark SettingsViewModel as @unchecked Sendable to satisfy concurrency checking
class SettingsViewModel: ObservableObject, @unchecked Sendable {
    static let shared = SettingsViewModel()
    
    // Use AtomicBool for thread-safe initialization state
    private let isInitializing: AtomicBool = AtomicBool(value: true)
    private var cancellables = Set<AnyCancellable>()
    // Flag to prevent recursive didSet calls
    private var isUpdating = false
    // Signal for initialization completion
    private let initializationComplete = PassthroughSubject<Void, Never>()

    // MARK: - Appearance
    @Published var selectedAppearance: String = "System" {
        didSet {
            guard !isUpdating, !isInitializing.value else { return }
            UserDefaults.standard.set(selectedAppearance, forKey: "selectedAppearance")
            print("SettingsViewModel: selectedAppearance set to \(selectedAppearance)")
        }
    }
    
    // MARK: - Video Settings
    @Published var selectedQuality: String = "Medium" {
        didSet {
            guard !isUpdating, !isInitializing.value else { return }
            UserDefaults.standard.set(selectedQuality, forKey: "selectedQuality")
            print("SettingsViewModel: selectedQuality set to \(selectedQuality)")
        }
    }

    @Published var selectedFPS: String = "30" {
        didSet {
            guard !isUpdating, !isInitializing.value else { return }
            UserDefaults.standard.set(selectedFPS, forKey: "selectedFPS")
            print("SettingsViewModel: selectedFPS set to \(selectedFPS)")
        }
    }

    @Published var selectedFOV: String = "0.5x" {
        didSet {
            guard !isUpdating, !isInitializing.value else { return }
            UserDefaults.standard.set(selectedFOV, forKey: "selectedFOV")
            print("SettingsViewModel: selectedFOV set to \(selectedFOV)")
        }
    }

    // MARK: - Audio Settings
    @Published var isVoiceRecording: Bool = false {
        didSet {
            guard !isUpdating, !isInitializing.value else { return }
            UserDefaults.standard.set(isVoiceRecording, forKey: "isVoiceRecording")
            print("SettingsViewModel: isVoiceRecording set to \(isVoiceRecording)")
        }
    }

    // MARK: - Recording Settings
    @Published var selectedClipDuration: String = "1m" {
        didSet {
            guard !isUpdating, !isInitializing.value else { return }
            UserDefaults.standard.set(selectedClipDuration, forKey: "selectedClipDuration")
            print("SettingsViewModel: selectedClipDuration set to \(selectedClipDuration)")
        }
    }

    // Maximum Storage Limit
    @Published var maxStorageLimit: String = "2GB" {
        didSet {
            guard !isUpdating, !isInitializing.value else { return }
            UserDefaults.standard.set(maxStorageLimit, forKey: "maxStorageLimit")
            print("SettingsViewModel: maxStorageLimit set to \(maxStorageLimit)")
        }
    }

    @Published var isAutoRecording: Bool = false {
        didSet {
            guard !isUpdating, !isInitializing.value else { return }
            UserDefaults.standard.set(isAutoRecording, forKey: "autoRecordEnabled")
            AutoRecordManager.shared.setEnabled(isAutoRecording)
            print("SettingsViewModel: isAutoRecording set to \(isAutoRecording)")
        }
    }
    
    @Published var isCrashDetectionEnabled: Bool = false {
        didSet {
            guard !isUpdating, !isInitializing.value else { return }
            UserDefaults.standard.set(isCrashDetectionEnabled, forKey: "isCrashDetectionEnabled")
            print("SettingsViewModel: isCrashDetectionEnabled set to \(isCrashDetectionEnabled)")
        }
    }

    @Published var selectedDualCamera: Bool = false {
        didSet {
            guard !isUpdating, !isInitializing.value else { return }
            UserDefaults.standard.set(selectedDualCamera, forKey: "selectedDualCamera")
            print("SettingsViewModel: selectedDualCamera set to \(selectedDualCamera)")
        }
    }

    @Published var autoRecordSpeedThreshold: Double = 5.0 {
        didSet {
            guard !isUpdating, !isInitializing.value else { return }
            UserDefaults.standard.set(autoRecordSpeedThreshold, forKey: "autoRecordSpeedThreshold")
            print("SettingsViewModel: autoRecordSpeedThreshold set to \(autoRecordSpeedThreshold)")
        }
    }

    @Published var autoRecordDurationThreshold: Double = 5.0 {
        didSet {
            guard !isUpdating, !isInitializing.value else { return }
            UserDefaults.standard.set(autoRecordDurationThreshold, forKey: "autoRecordDurationThreshold")
            print("SettingsViewModel: autoRecordDurationThreshold set to \(autoRecordDurationThreshold)")
        }
    }
    
    // MARK: - UI Settings (Free Features)
    @Published var isShowingLocation: Bool = true {
        didSet {
            guard !isUpdating, !isInitializing.value else { return }
            UserDefaults.standard.set(isShowingLocation, forKey: "isShowingLocation")
            print("SettingsViewModel: isShowingLocation set to \(isShowingLocation)")
            notifyOverlaySettingsChanged()
        }
    }
    
    @Published var isShowingDate: Bool = true {
        didSet {
            guard !isUpdating, !isInitializing.value else { return }
            UserDefaults.standard.set(isShowingDate, forKey: "isShowingDate")
            print("SettingsViewModel: isShowingDate set to \(isShowingDate)")
            notifyOverlaySettingsChanged()
        }
    }
    
    @Published var isShowingTime: Bool = true {
        didSet {
            guard !isUpdating, !isInitializing.value else { return }
            UserDefaults.standard.set(isShowingTime, forKey: "isShowingTime")
            print("SettingsViewModel: isShowingTime set to \(isShowingTime)")
            notifyOverlaySettingsChanged()
        }
    }
    
    @Published var isShowingSpeed: Bool = true {
        didSet {
            guard !isUpdating, !isInitializing.value else { return }
            UserDefaults.standard.set(isShowingSpeed, forKey: "isShowingSpeed")
            print("SettingsViewModel: isShowingSpeed set to \(isShowingSpeed)")
            notifyOverlaySettingsChanged()
        }
    }
    
    @Published var isShowingFPS: Bool = true {
        didSet {
            guard !isUpdating, !isInitializing.value else { return }
            UserDefaults.standard.set(isShowingFPS, forKey: "isShowingFPS")
            print("SettingsViewModel: isShowingFPS set to \(isShowingFPS)")
            notifyOverlaySettingsChanged()
        }
    }
    
    @Published var embedOverlayInVideo: Bool = true {
        didSet {
            guard !isUpdating, !isInitializing.value else { return }
            UserDefaults.standard.set(embedOverlayInVideo, forKey: "embedOverlayInVideo")
            print("SettingsViewModel: embedOverlayInVideo set to \(embedOverlayInVideo)")
            notifyOverlaySettingsChanged()
        }
    }
    
    @Published var overlayQuality: String = "Medium" {
        didSet {
            guard !isUpdating, !isInitializing.value else { return }
            UserDefaults.standard.set(overlayQuality, forKey: "overlayQuality")
            print("SettingsViewModel: overlayQuality set to \(overlayQuality)")
            notifyOverlaySettingsChanged()
        }
    }
    
    @Published var isDrivingOverlayEnabled: Bool = true {
        didSet {
            guard !isUpdating, !isInitializing.value else { return }
            UserDefaults.standard.set(isDrivingOverlayEnabled, forKey: "isDrivingOverlayEnabled")
            if !isDrivingOverlayEnabled {
                isOverlayAlwaysActive = false
            }
            print("SettingsViewModel: isDrivingOverlayEnabled set to \(isDrivingOverlayEnabled)")
            notifyOverlaySettingsChanged()
        }
    }
    
    @Published var isOverlayAlwaysActive: Bool = true {
        didSet {
            guard !isUpdating, !isInitializing.value else { return }
            if isOverlayAlwaysActive && !isDrivingOverlayEnabled {
                isUpdating = true
                isOverlayAlwaysActive = false
                isUpdating = false
            }
            UserDefaults.standard.set(isOverlayAlwaysActive, forKey: "isOverlayAlwaysActive")
            print("SettingsViewModel: isOverlayAlwaysActive set to \(isOverlayAlwaysActive)")
            notifyOverlaySettingsChanged()
        }
    }
    
    @Published var selectedSpeedUnits: String = "MPH" {
        didSet {
            guard !isUpdating, !isInitializing.value else { return }
            UserDefaults.standard.set(selectedSpeedUnits, forKey: "selectedSpeedUnits")
            print("SettingsViewModel: selectedSpeedUnits set to \(selectedSpeedUnits)")
        }
    }
    
    // MARK: - Init
    init() {
        // Register default UserDefaults values
        let defaults: [String: Any] = [
            "selectedQuality": "Medium",
            "selectedFPS": "30",
            "selectedFOV": "0.5x",
            "isVoiceRecording": false,
            "selectedClipDuration": "1m",
            "maxStorageLimit": "2GB",
            "autoRecordEnabled": false,
            "isCrashDetectionEnabled": false,
            "selectedDualCamera": false,
            "autoRecordSpeedThreshold": 5.0,
            "autoRecordDurationThreshold": 5.0,
            "isShowingLocation": true,
            "isShowingDate": true,
            "isShowingTime": true,
            "isShowingSpeed": true,
            "isShowingFPS": true,
            "embedOverlayInVideo": true,
            "overlayQuality": "Medium",
            "isDrivingOverlayEnabled": true,
            "isOverlayAlwaysActive": true,
            "selectedSpeedUnits": "MPH",
            "selectedAppearance": "System"
        ]
        UserDefaults.standard.register(defaults: defaults)
        
        // Load initial values from UserDefaults
        selectedQuality = UserDefaults.standard.string(forKey: "selectedQuality") ?? "Medium"
        selectedFPS = UserDefaults.standard.string(forKey: "selectedFPS") ?? "30"
        selectedFOV = UserDefaults.standard.string(forKey: "selectedFOV") ?? "0.5x"
        isVoiceRecording = UserDefaults.standard.bool(forKey: "isVoiceRecording")
        selectedClipDuration = UserDefaults.standard.string(forKey: "selectedClipDuration") ?? "1m"
        maxStorageLimit = UserDefaults.standard.string(forKey: "maxStorageLimit") ?? "2GB"
        isAutoRecording = UserDefaults.standard.bool(forKey: "autoRecordEnabled")
        isCrashDetectionEnabled = UserDefaults.standard.bool(forKey: "isCrashDetectionEnabled")
        selectedDualCamera = UserDefaults.standard.bool(forKey: "selectedDualCamera")
        autoRecordSpeedThreshold = UserDefaults.standard.double(forKey: "autoRecordSpeedThreshold")
        autoRecordDurationThreshold = UserDefaults.standard.double(forKey: "autoRecordDurationThreshold")
        isShowingLocation = UserDefaults.standard.bool(forKey: "isShowingLocation")
        isShowingDate = UserDefaults.standard.bool(forKey: "isShowingDate")
        isShowingTime = UserDefaults.standard.bool(forKey: "isShowingTime")
        isShowingSpeed = UserDefaults.standard.bool(forKey: "isShowingSpeed")
        isShowingFPS = UserDefaults.standard.bool(forKey: "isShowingFPS")
        embedOverlayInVideo = UserDefaults.standard.bool(forKey: "embedOverlayInVideo")
        overlayQuality = UserDefaults.standard.string(forKey: "overlayQuality") ?? "Medium"
        isDrivingOverlayEnabled = UserDefaults.standard.bool(forKey: "isDrivingOverlayEnabled")
        isOverlayAlwaysActive = UserDefaults.standard.bool(forKey: "isOverlayAlwaysActive")
        selectedSpeedUnits = UserDefaults.standard.string(forKey: "selectedSpeedUnits") ?? "MPH"
        selectedAppearance = UserDefaults.standard.string(forKey: "selectedAppearance") ?? "System"
        
        // Complete initialization
        isInitializing.value = false
        initializationComplete.send(())
    }

    private func notifyOverlaySettingsChanged() {
        NotificationCenter.default.post(name: NSNotification.Name("OverlaySettingsChanged"), object: nil)
    }
    
    // Computed property for storage in MB (used by Account tab and storage enforcement)
    var maxStorageMB: Int {
        switch maxStorageLimit {
        case "5GB": return 5000
        case "10GB": return 10000
        default: return 2000
        }
    }
}
