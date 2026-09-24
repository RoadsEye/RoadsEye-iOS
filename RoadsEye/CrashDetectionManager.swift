import Foundation
import CoreMotion
import CoreLocation

class CrashDetectionManager: ObservableObject {
    static let shared = CrashDetectionManager()
    
    @Published var isCrashDetectionEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isCrashDetectionEnabled, forKey: "isCrashDetectionEnabled")
            if isCrashDetectionEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }
    
    var isRecording: Bool = false
    var onCrashDetected: (() -> Void)?
    
    private let motionManager = CMMotionManager()
    private let locationManager = CLLocationManager()
    
    private var lastCrashDetectionTime: Date?
    private let crashCooldown: TimeInterval = 30.0
    
    private init() {
        self.isCrashDetectionEnabled = UserDefaults.standard.object(forKey: "isCrashDetectionEnabled") as? Bool ?? true
        if self.isCrashDetectionEnabled {
            startMonitoring()
        }
    }
    
    func setCrashDetectionEnabled(_ enabled: Bool) {
        isCrashDetectionEnabled = enabled
    }
    
    func updateRecordingState(_ isRecording: Bool) {
        self.isRecording = isRecording
        print("CrashDetectionManager: Recording state updated: \(isRecording)")
    }
    
    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else {
            print("CrashDetectionManager: Device motion not available")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 0.1
        if !motionManager.isDeviceMotionActive {
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let self = self, let motion = motion, error == nil else { return }
                
                let acceleration = motion.userAcceleration
                let totalG = sqrt(pow(acceleration.x, 2) + pow(acceleration.y, 2) + pow(acceleration.z, 2))
                
                if totalG > 1.75 && self.isRecording {
                    if let lastTime = self.lastCrashDetectionTime,
                       Date().timeIntervalSince(lastTime) < self.crashCooldown {
                        return
                    }
                    
                    self.lastCrashDetectionTime = Date()
                    print("🚨 Crash detected with acceleration: \(String(format: "%.2f", totalG))g")
                    self.handleCrashDetected()
                }
            }
        }
        
        locationManager.requestWhenInUseAuthorization()
    }
    
    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        print("CrashDetectionManager: Monitoring stopped")
    }
    
    private func handleCrashDetected() {
        guard isCrashDetectionEnabled else { return }
        print("CrashDetectionManager: Crash detected - notifying UI for countdown...")
        onCrashDetected?()
    }
    
    // MARK: - Save Crash Clip
    func saveCrashClip() async {
        print("CrashDetectionManager: Saving last 2 minutes crash clip...")
        
        await withCheckedContinuation { continuation in
            RecordingManager.shared.saveSnapshot { snapshotURL in
                Task {
                    guard let snapshotURL = snapshotURL else {
                        print("CrashDetectionManager: Failed to create snapshot")
                        AppNotificationsManager.shared.showNotification(
                            title: "Crash Clip Failed",
                            body: "Could not capture recording snapshot."
                        )
                        continuation.resume()
                        return
                    }
                    
                    let timestamp = Date().timeIntervalSince1970
                    let crashOutputURL = VideoFileManager.shared.getCrashClipsDirectory()
                        .appendingPathComponent("crash_\(Int(timestamp)).mp4")
                    
                    print("CrashDetectionManager: Clipping last 2min → \(crashOutputURL.lastPathComponent)")
                    
                    let success = await ClippingManager.shared.clipCrashVideo(
                        videoURL: snapshotURL,
                        outputURL: crashOutputURL
                    ) { success, finalURL in
                        DispatchQueue.main.async {
                            if success, let url = finalURL {
                                print("✅ Crash clip saved: \(url.lastPathComponent)")
                                AppNotificationsManager.shared.showNotification(
                                    title: "Crash Video Saved",
                                    body: "Last 2 minutes saved to CrashClips."
                                )
                            } else {
                                print("❌ Failed to save crash clip")
                                AppNotificationsManager.shared.showNotification(
                                    title: "Crash Clip Failed",
                                    body: "Could not save crash video."
                                )
                            }
                        }
                    }
                    
                    if !success {
                        await VideoFileManager.shared.saveToPhotoLibrary(fileURL: snapshotURL, isClippedVideo: true)
                    }
                    
                    // Restart recording
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        RecordingManager.shared.startRecording()
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
}
