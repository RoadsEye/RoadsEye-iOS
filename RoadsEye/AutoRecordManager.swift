import Foundation
import UIKit

class AutoRecordManager: NSObject {
    // MARK: - Singleton
    static let shared = AutoRecordManager()
    
    // MARK: - Properties
    private var speedThreshold: Double = 5.0
    private var speedDurationThreshold: TimeInterval = 3.0
    private var speedExceededStartTime: Date?
    private var isMonitoring = false
    private var isAutoRecordingActive = false
    private var timer: Timer?
    private var isPaused = false
    private var pauseTimer: Timer?
    
    // MARK: - Initialization
    private override init() {
        super.init()
        loadSettings()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(recordingStopped),
            name: Notification.Name("RecordingStopped"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopMonitoring()
        pauseTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        timer = Timer.scheduledTimer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(checkSpeed),
            userInfo: nil,
            repeats: true
        )
        
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        print("AutoRecordManager: Monitoring started")
    }
    
    func stopMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
        pauseTimer?.invalidate()
        pauseTimer = nil
        speedExceededStartTime = nil
        isPaused = false
        print("AutoRecordManager: Monitoring stopped")
    }
    
    func isEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "autoRecordEnabled")
    }
    
    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "autoRecordEnabled")
        UserDefaults.standard.synchronize()
        
        if enabled {
            startMonitoring()
        } else {
            stopMonitoring()
            if isAutoRecordingActive {
                forceStopRecording(saveVideo: true)
            }
        }
    }
    
    // MARK: - Private Methods
    private func loadSettings() {
        speedThreshold = UserDefaults.standard.double(forKey: "autoRecordSpeedThreshold")
        if speedThreshold == 0 {
            speedThreshold = 5.0
            UserDefaults.standard.set(speedThreshold, forKey: "autoRecordSpeedThreshold")
        }
        
        speedDurationThreshold = UserDefaults.standard.double(forKey: "autoRecordDurationThreshold")
        if speedDurationThreshold == 0 {
            speedDurationThreshold = 3.0
            UserDefaults.standard.set(speedDurationThreshold, forKey: "autoRecordDurationThreshold")
        }
        
        if isEnabled() {
            startMonitoring()
        }
    }
    
    @objc private func checkSpeed() {
        guard isMonitoring, isEnabled(), !isPaused else { return }

        // Read live values so threshold changes in Settings apply immediately
        let storedSpeed = UserDefaults.standard.double(forKey: "autoRecordSpeedThreshold")
        if storedSpeed > 0 { speedThreshold = storedSpeed }
        let storedDuration = UserDefaults.standard.double(forKey: "autoRecordDurationThreshold")
        if storedDuration > 0 { speedDurationThreshold = storedDuration }

        let currentSpeed = LocationSpeedManager.shared.speed
        
        if currentSpeed >= speedThreshold {
            if speedExceededStartTime == nil {
                speedExceededStartTime = Date()
                print("AutoRecordManager: Speed threshold exceeded, starting timer")
            } else {
                let elapsedTime = Date().timeIntervalSince(speedExceededStartTime!)
                
                if elapsedTime >= speedDurationThreshold && !isAutoRecordingActive {
                    startAutoRecording()
                }
            }
        } else {
            speedExceededStartTime = nil
        }
    }
    
    private func startAutoRecording() {
        guard !isAutoRecordingActive else { return }
        
        isAutoRecordingActive = true
        print("AutoRecordManager: Starting auto recording")
        
        if !RecordingManager.shared.isRecording {
            RecordingManager.shared.startRecording()
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("AutoRecordingStarted"),
                    object: nil
                )
            }
        }
    }
    
    private func stopAutoRecording() {
        guard isAutoRecordingActive else { return }
        
        isAutoRecordingActive = false
        print("AutoRecordManager: Stopping auto recording")
        
        if RecordingManager.shared.isRecording {
            RecordingManager.shared.stopRecording(saveVideo: true)
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("AutoRecordingStopped"),
                    object: nil
                )
            }
        }
    }
    
    // MARK: - Notification Handlers
    @objc private func recordingStopped() {
        if isEnabled() {
            isPaused = true
            speedExceededStartTime = nil
            print("AutoRecordManager: Pausing monitoring for 5 seconds after recording stop")
            
            pauseTimer?.invalidate()
            pauseTimer = Timer.scheduledTimer(
                timeInterval: 5.0,
                target: self,
                selector: #selector(resumeMonitoring),
                userInfo: nil,
                repeats: false
            )
            
            if let pauseTimer = pauseTimer {
                RunLoop.main.add(pauseTimer, forMode: .common)
            }
        }
    }
    
    @objc func resumeMonitoring() {
        isPaused = false
        print("AutoRecordManager: Resumed monitoring after pause")
    }
    
    @objc private func appDidEnterBackground() {
        // Keep monitoring active (segmented recording handles background)
    }
    
    @objc private func appWillEnterForeground() {
        if isEnabled() && !isMonitoring {
            startMonitoring()
        }
    }
    
    // MARK: - Manual Control (Used by MainView)
    func forceStartRecording() {
        isAutoRecordingActive = true
        RecordingManager.shared.startRecording()
    }
    
    func forceStopRecording(saveVideo: Bool = true) {
        isAutoRecordingActive = false
        RecordingManager.shared.stopRecording(saveVideo: saveVideo)
    }
}

// MARK: - Extension for UI Updates
extension AutoRecordManager {
    var isActive: Bool {
        return isAutoRecordingActive
    }
}
