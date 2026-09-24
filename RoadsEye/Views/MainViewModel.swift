import SwiftUI
import AVFoundation
import PhotosUI
import UIKit
import CoreLocation

class MainViewModel: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var isRecording = false

    // Auto recording state
    @Published var isAutoRecordingEnabled = false
    @Published var isAutoRecordingActive = false

    private var timeTimer: Timer? = nil
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    override init() {
        super.init()
        setupBackgroundTaskHandling()
        
        // Load auto recording state
        isAutoRecordingEnabled = UserDefaults.standard.bool(forKey: "autoRecordEnabled")
        
        // Set up notification observers for auto recording
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAutoRecordingStarted),
            name: Notification.Name("AutoRecordingStarted"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAutoRecordingStopped),
            name: Notification.Name("AutoRecordingStopped"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopTimers()
    }
    
    // Auto recording handlers
    @objc private func handleAutoRecordingStarted() {
        DispatchQueue.main.async {
            self.isAutoRecordingActive = true
            self.isRecording = true
            self.isPlaying = true
        }
    }
    
    @objc private func handleAutoRecordingStopped() {
        DispatchQueue.main.async {
            self.isAutoRecordingActive = false
            self.isRecording = false
            self.isPlaying = false
        }
    }
    
    private func setupBackgroundTaskHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppBackgrounding),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppForegrounding),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func handleAppBackgrounding() {
        if isPlaying || isRecording {
            backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
                self?.endBackgroundTask()
            }
            ensureTimersContinueInBackground()
        }
    }
    
    @objc private func handleAppForegrounding() {
        if backgroundTask != .invalid {
            endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    private func ensureTimersContinueInBackground() {
        stopTimers()
        createBackgroundCapableTimers()
    }
    
    private func createBackgroundCapableTimers() {
        guard timeTimer == nil else { return }
        
        timeTimer = Timer(timeInterval: 1.0, repeats: true) { _ in
            // updateTime() to be revamped
        }
        RunLoop.main.add(timeTimer!, forMode: .common)
    }
    
    func startTimers() {
        createBackgroundCapableTimers()
    }
    
    func stopTimers() {
        timeTimer?.invalidate()
        timeTimer = nil
    }
}
