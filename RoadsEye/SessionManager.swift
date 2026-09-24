import Foundation
import Photos
import UIKit
import SwiftUI
import AVFoundation

/// Owns the AVCaptureSession and is the single place where camera hardware
/// configuration (device selection, format/FPS, zoom) is applied.
class SessionManager: NSObject, ObservableObject {
    // MARK: - Singleton
    static let shared = SessionManager()

    // MARK: - Published Properties
    @Published private(set) var isSessionRunning = false
    @Published var captureSession: AVCaptureSession?

    // MARK: - Private Properties
    private var isSessionSetup = false
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var settingsObserver: NSObjectProtocol?
    private let recordingManager = RecordingManager.shared
    private let sessionQueue = DispatchQueue(label: "com.app.sessionManager.sessionQueue", qos: .userInitiated)
    public private(set) var currentFPS: Int = 30
    public private(set) var currentQuality: String = "Medium"
    private var currentZoomSetting: String = "0.5x"
    private var isRecording = false
    private var isAppInForeground = true

    // MARK: - Init & Deinit
    override init() {
        super.init()
        currentQuality = UserDefaults.standard.string(forKey: "selectedQuality") ?? "Medium"
        currentZoomSetting = UserDefaults.standard.string(forKey: "selectedFOV") ?? "0.5x"

        // A single observer covers FPS, quality, and zoom changes.
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSettingsChangeIfNeeded()
        }

        setupAppLifecycleObservers()
    }

    deinit {
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - App Lifecycle Observers
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func appDidEnterBackground() {
        isAppInForeground = false
        if !isRecording {
            stopCaptureSession()
        }
    }

    @objc private func appDidBecomeActive() {
        isAppInForeground = true
        safelyStartCaptureSession()
    }

    // MARK: - Settings Handling
    private func handleSettingsChangeIfNeeded() {
        let fps = Int(UserDefaults.standard.string(forKey: "selectedFPS") ?? "30") ?? 30
        let quality = UserDefaults.standard.string(forKey: "selectedQuality") ?? "Medium"
        let zoom = UserDefaults.standard.string(forKey: "selectedFOV") ?? "0.5x"

        if fps != currentFPS || quality != currentQuality || zoom != currentZoomSetting {
            configureCamera()
        }
    }

    // MARK: - Permissions
    func setupAndRequestPermissions() {
        checkCameraPermissions { [weak self] granted in
            guard granted else {
                print("Camera permission denied")
                return
            }
            self?.checkPhotoLibraryPermissions { [weak self] photoGranted in
                guard photoGranted else {
                    print("Photo library permission denied")
                    return
                }
                self?.setupCaptureSession()
            }
        }
    }

    private func checkCameraPermissions(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
        default:
            completion(false)
        }
    }

    private func checkPhotoLibraryPermissions(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                completion(newStatus == .authorized || newStatus == .limited)
            }
        default:
            completion(false)
        }
    }

    // MARK: - Session Setup
    private func setupCaptureSession() {
        guard !isSessionSetup else {
            print("Session already set up")
            return
        }
        isSessionSetup = true

        let session = AVCaptureSession()
        DispatchQueue.main.async {
            self.captureSession = session
        }

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            session.beginConfiguration()
            // Formats are selected directly, so input priority replaces presets.
            session.sessionPreset = .inputPriority
            self.applyCameraSettings(to: session)
            session.commitConfiguration()

            guard !session.inputs.isEmpty else {
                print("Failed to add camera input")
                DispatchQueue.main.async { self.isSessionSetup = false }
                return
            }

            // RecordingManager adds its video data output and delegate.
            self.recordingManager.setupWithSession(session: session)

            self.safelyStartCaptureSession()
        }
    }

    // MARK: - Camera Configuration (device, format, FPS, zoom)
    /// Re-applies the user's quality/FPS/zoom settings to the live session.
    func configureCamera() {
        guard let session = captureSession else {
            print("Cannot configure camera: no capture session")
            return
        }

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            session.beginConfiguration()
            self.applyCameraSettings(to: session)
            session.commitConfiguration()
        }
    }

    /// Must be called on `sessionQueue` between begin/commitConfiguration.
    private func applyCameraSettings(to session: AVCaptureSession) {
        let fps = Int(UserDefaults.standard.string(forKey: "selectedFPS") ?? "30") ?? 30
        let quality = UserDefaults.standard.string(forKey: "selectedQuality") ?? "Medium"
        let zoomSetting = UserDefaults.standard.string(forKey: "selectedFOV") ?? "0.5x"

        let wantsUltraWide = zoomSetting == "0.5x"
        let zoomFactor: CGFloat = zoomSetting == "2x" ? 2.0 : 1.0
        let desiredType: AVCaptureDevice.DeviceType = wantsUltraWide ? .builtInUltraWideCamera : .builtInWideAngleCamera

        let currentInput = session.inputs
            .compactMap { $0 as? AVCaptureDeviceInput }
            .first { $0.device.hasMediaType(.video) }

        var device = currentInput?.device

        // Switch cameras if the zoom setting requires a different physical camera.
        if device == nil || device?.deviceType != desiredType {
            let newDevice = AVCaptureDevice.default(desiredType, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)

            if let newDevice = newDevice, newDevice != device,
               let newInput = try? AVCaptureDeviceInput(device: newDevice) {
                if let currentInput = currentInput {
                    session.removeInput(currentInput)
                }
                if session.canAddInput(newInput) {
                    session.addInput(newInput)
                    device = newDevice
                    print("Switched to camera: \(newDevice.localizedName)")
                } else if let currentInput = currentInput, session.canAddInput(currentInput) {
                    session.addInput(currentInput)
                }
            }
        }

        guard let device = device else {
            print("No camera device available")
            return
        }

        let targetSize = VideoQualityManager.shared.captureSize(for: quality)

        do {
            try device.lockForConfiguration()

            if let format = Self.bestFormat(for: device, targetSize: targetSize, fps: fps),
               device.activeFormat != format {
                device.activeFormat = format
            }

            // Clamp to what the chosen format actually supports.
            let maxSupported = device.activeFormat.videoSupportedFrameRateRanges
                .map { $0.maxFrameRate }.max() ?? 30
            let appliedFPS = min(fps, Int(maxSupported))
            let frameDuration = CMTime(value: 1, timescale: CMTimeScale(appliedFPS))
            device.activeVideoMinFrameDuration = frameDuration
            device.activeVideoMaxFrameDuration = frameDuration

            let zoom = max(min(zoomFactor, device.maxAvailableVideoZoomFactor), device.minAvailableVideoZoomFactor)
            device.videoZoomFactor = zoom

            device.unlockForConfiguration()

            let dims = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
            print("Camera configured: \(dims.width)x\(dims.height) @ \(appliedFPS)fps, zoom \(zoomSetting) (\(device.localizedName))")

            DispatchQueue.main.async {
                self.currentFPS = appliedFPS
                self.currentQuality = quality
                self.currentZoomSetting = zoomSetting
                FPSManager.shared.updateFPS()
            }
        } catch {
            print("Failed to configure camera: \(error.localizedDescription)")
        }
    }

    /// Picks the capture format matching the target resolution that supports the
    /// requested frame rate. Preset-based selection capped at 30fps, which is why
    /// 60fps used to silently fail.
    private static func bestFormat(for device: AVCaptureDevice, targetSize: CGSize, fps: Int) -> AVCaptureDevice.Format? {
        let targetWidth = Int32(targetSize.width)
        let targetHeight = Int32(targetSize.height)

        var exactMatch: (format: AVCaptureDevice.Format, maxRate: Double)?
        var exactSizeAnyRate: (format: AVCaptureDevice.Format, maxRate: Double)?
        var largerFallback: (format: AVCaptureDevice.Format, width: Int32)?

        for format in device.formats {
            let desc = format.formatDescription
            guard CMFormatDescriptionGetMediaSubType(desc) == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange else { continue }

            let dims = CMVideoFormatDescriptionGetDimensions(desc)
            let maxRate = format.videoSupportedFrameRateRanges.map { $0.maxFrameRate }.max() ?? 0

            if dims.width == targetWidth && dims.height == targetHeight {
                if maxRate >= Double(fps) {
                    // Prefer the lowest sufficient max rate (avoids slo-mo formats).
                    if exactMatch == nil || maxRate < exactMatch!.maxRate {
                        exactMatch = (format, maxRate)
                    }
                }
                if exactSizeAnyRate == nil || maxRate > exactSizeAnyRate!.maxRate {
                    exactSizeAnyRate = (format, maxRate)
                }
            } else if dims.width >= targetWidth && dims.height >= targetHeight && maxRate >= Double(fps) {
                if largerFallback == nil || dims.width < largerFallback!.width {
                    largerFallback = (format, dims.width)
                }
            }
        }

        return exactMatch?.format ?? largerFallback?.format ?? exactSizeAnyRate?.format
    }

    // MARK: - Lifecycle Handlers
    func handleAppActive() {
        isAppInForeground = true
        safelyStartCaptureSession()
    }

    func handleAppBackground() {
        isAppInForeground = false
        if !isRecording {
            stopCaptureSession()
        }
    }

    // MARK: - Session Control
    func safelyStartCaptureSession() {
        guard let session = captureSession, !session.isRunning, (isAppInForeground || isRecording) else {
            return
        }

        sessionQueue.async { [weak self] in
            guard let self = self, !session.isRunning else { return }
            session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = true
                print("Capture session started")
            }
        }
    }

    func stopCaptureSession() {
        guard let session = captureSession, session.isRunning, !isRecording, !isAppInForeground else {
            return
        }

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            session.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
                print("Capture session stopped")
            }
        }
    }

    // MARK: - Recording
    func startRecording() {
        if let session = captureSession, !session.isRunning {
            safelyStartCaptureSession()
        }

        DispatchQueue.main.async {
            self.isRecording = true
            self.recordingManager.startRecording()
            self.beginBackgroundTask()
        }
    }

    func stopRecording() {
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingManager.stopRecording(saveVideo: true)

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                self.endBackgroundTask()
                if !self.isAppInForeground {
                    self.stopCaptureSession()
                }
            }
        }
    }

    // MARK: - Background Task
    private func beginBackgroundTask() {
        guard isRecording else { return }

        endBackgroundTask()

        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            print("Background task expired")
            self?.endBackgroundTask()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
            guard let self = self, self.backgroundTask != .invalid else { return }
            self.endBackgroundTask()
        }

        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
