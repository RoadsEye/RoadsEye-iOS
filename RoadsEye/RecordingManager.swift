import Foundation
import AVFoundation
import UIKit
import CoreLocation

class RecordingManager: NSObject {
    // MARK: - Singleton
    static let shared = RecordingManager()
   
    // MARK: - Properties
    private var captureSession: AVCaptureSession?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var assetWriterManager: AssetWriterManager?
   
    // State tracking
    private(set) var isRecording = false
    private var isStoppingRecording = false
    private var shouldSaveVideo = false
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    // Video buffer for crash detection
    private var currentRecordingURL: URL?
    /// The last finished segment, joined onto the current one for clips so a
    /// clip taken just after a segment boundary still has its full length.
    private var previousSegmentURL: URL?
   
    // NEW: Segmented Recording
    private var segmentTimer: Timer?
    private var currentSegmentStartTime: Date?
    private var segmentDurationSeconds: Double = 60.0  // Default 1 minute

    // Configuration
    private var videoSize = CGSize(width: 1920, height: 1080)
    private var frameRate = 30
    private var recordingOrientation: UIInterfaceOrientation?

    // Overlay optimization
    private var lastOverlayText: String?
    private var lastOverlayImage: UIImage?
    private var lastOverlaySize: CGSize?

    // Watermark (always shown)
    private let watermarkText = "Clipped By: Road's Eye"
    private var lastWatermarkImage: UIImage?
    private var lastWatermarkSize: CGSize?

    // Recovery
    private var recoveryAttempts = 0
    private let maxRecoveryAttempts = 3
    private var isRecovering = false

    // Observers
    private var overlaySettingsObserver: NSObjectProtocol?
    private var speedUpdateObserver: NSObjectProtocol?
    private var clipDurationObserver: NSObjectProtocol?

    // Debounce for duration updates
    private var lastDurationUpdate = Date.distantPast

    // MARK: - Initialization
    private override init() {
        super.init()
        if UserDefaults.standard.object(forKey: "embedOverlayInVideo") == nil {
            UserDefaults.standard.set(true, forKey: "embedOverlayInVideo")
        }

        overlaySettingsObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OverlaySettingsChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.clearOverlayCache()
        }
       
        speedUpdateObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SpeedUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if self.isRecording {
                IdleTimerManager.shared.reinforceIdleTimer(reason: "Speed update during recording")
            }
        }
       
        // FIXED: Debounced duration observer
        clipDurationObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateSegmentDurationIfNeeded()
        }
    }
   
    deinit {
        if let observer = overlaySettingsObserver { NotificationCenter.default.removeObserver(observer) }
        if let observer = speedUpdateObserver { NotificationCenter.default.removeObserver(observer) }
        if let observer = clipDurationObserver { NotificationCenter.default.removeObserver(observer) }
        segmentTimer?.invalidate()
        endBackgroundTask()
        cleanupVideoBuffer()
    }
   
    // MARK: - Debounced Duration Update
    private func updateSegmentDurationIfNeeded() {
        guard Date().timeIntervalSince(lastDurationUpdate) > 0.5 else { return } // Prevent spam
       
        lastDurationUpdate = Date()
        let durationStr = UserDefaults.standard.string(forKey: "selectedClipDuration") ?? "1m"
        let newDuration: Double = {
            switch durationStr.lowercased() {
            case "30s": return 30
            case "1m":  return 60
            case "2m":  return 120
            case "3m":  return 180
            default:    return 60
            }
        }()
       
        if abs(newDuration - segmentDurationSeconds) > 0.1 {
            segmentDurationSeconds = newDuration
            print("RecordingManager: Segment duration updated to \(segmentDurationSeconds)s")
           
            if isRecording {
                startNewSegment()  // Restart timer with new duration
            }
        }
    }

    // MARK: - Session Setup
    func setupWithSession(session: AVCaptureSession) {
        guard !session.isRunning else {
            print("RecordingManager: Cannot setup session - already running")
            return
        }
       
        captureSession = session
       
        session.outputs.forEach { session.removeOutput($0) }
       
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = false
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.app.assetwriter.queue"))
       
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            videoDataOutput = videoOutput
        } else {
            print("RecordingManager: Could not add video data output to session")
        }

        assetWriterManager = AssetWriterManager()
    }

    // MARK: - Recording Control
    func startRecording() {
        DispatchQueue.main.async {
            self.startRecordingOnMainThread()
        }
    }

    private func startRecordingOnMainThread() {
        guard let captureSession = captureSession, captureSession.isRunning else {
            print("RecordingManager: Cannot start - session not ready")
            return
        }
       
        if isRecording {
            print("RecordingManager: Already recording")
            return
        }
       
        IdleTimerManager.shared.disableIdleTimer(reason: "Recording started")
        beginBackgroundTask()
       
        recordingOrientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.interfaceOrientation ?? .portrait
       
        configureRecordingSettings()
        updateSegmentDurationIfNeeded()
       
        isRecording = true
        previousSegmentURL = nil
        clearOverlayCache()
       
        startNewSegment()
       
        NotificationCenter.default.post(name: NSNotification.Name("RecordingStarted"), object: nil)
        print("RecordingManager: Segmented Recording STARTED (duration: \(segmentDurationSeconds)s)")
    }

    private func startNewSegment() {
        if let url = currentRecordingURL {
            TempVideoManager.shared.removeFile(at: url)
        }
       
        let timestamp = Date().timeIntervalSince1970
        let filename = "segment_\(Int(timestamp)).mp4"
        let recordingURL = VideoFileManager.shared.getRoadsEyeDirectory().appendingPathComponent(filename)
       
        currentRecordingURL = recordingURL
        currentSegmentStartTime = Date()
       
        print("🔄 New segment started → \(filename) (\(segmentDurationSeconds)s)")
       
        assetWriterManager?.prepareForRecording(
            videoSize: videoSize,
            frameRate: frameRate,
            orientation: recordingOrientation,
            outputURL: recordingURL
        )
       
        segmentTimer?.invalidate()
        segmentTimer = Timer.scheduledTimer(withTimeInterval: segmentDurationSeconds, repeats: false) { [weak self] _ in
            print("⏰ Segment timer fired after \(self?.segmentDurationSeconds ?? 0)s")
            self?.finishCurrentSegmentAndStartNext()
        }
       
        if let timer = segmentTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
       
        print("RecordingManager: Segment timer scheduled for \(segmentDurationSeconds) seconds")
    }

    private func finishCurrentSegmentAndStartNext() {
        guard isRecording, let currentURL = currentRecordingURL else { return }
       
        print("Finishing current segment...")
       
        assetWriterManager?.finishWriting { [weak self] success, _ in
            guard let self = self else { return }
           
            DispatchQueue.main.async {
                if success {
                    self.previousSegmentURL = currentURL
                    Task { await VideoFileManager.shared.enforceStorageLimit() }
                    print("✅ Segment saved: \(currentURL.lastPathComponent)")
                }
                self.updateSegmentDurationIfNeeded()
                self.startNewSegment()
            }
        }
    }
   
    func stopRecording(saveVideo: Bool = false) {
        segmentTimer?.invalidate()
        segmentTimer = nil
       
        if isStoppingRecording {
            print("RecordingManager: Already stopping recording")
            return
        }
       
        isStoppingRecording = true
        shouldSaveVideo = saveVideo
       
        if isRecording {
            print("RecordingManager: Stopping recording, save video: \(saveVideo)")
           
            NotificationCenter.default.post(name: NSNotification.Name("RecordingStopped"), object: nil)
           
            assetWriterManager?.finishWriting { [weak self] success, _ in
                guard let self = self else { return }
               
                if success, let url = self.currentRecordingURL, self.assetWriterManager?.verifyFile(at: url) == true {
                    if self.shouldSaveVideo {
                        Task {
                            await VideoFileManager.shared.saveToPhotoLibrary(fileURL: url, isClippedVideo: false)
                            await VideoFileManager.shared.enforceStorageLimit()
                            self.cleanupVideoBuffer()
                        }
                    } else {
                        self.cleanupVideoBuffer()
                    }
                } else {
                    print("RecordingManager: File verification failed or writing unsuccessful")
                    self.cleanupVideoBuffer()
                }
               
                DispatchQueue.main.async {
                    self.isRecording = false
                    self.isStoppingRecording = false
                    self.recoveryAttempts = 0
                    self.endBackgroundTask()
                    IdleTimerManager.shared.enableIdleTimer(reason: "Recording stopped")
                }
            }
        } else {
            cleanupAfterStop()
        }
    }
   
    private func cleanupAfterStop() {
        isRecording = false
        isStoppingRecording = false
        endBackgroundTask()
        IdleTimerManager.shared.enableIdleTimer(reason: "No active recording")
        cleanupVideoBuffer()
        NotificationCenter.default.post(name: NSNotification.Name("RecordingStopped"), object: nil)
    }
   
    // MARK: - Snapshot for Clipping (Updated)
    func saveSnapshot(completion: @escaping (URL?) -> Void) {
        guard let currentURL = currentRecordingURL, FileManager.default.fileExists(atPath: currentURL.path) else {
            print("RecordingManager: No valid current recording for snapshot")
            completion(nil)
            return
        }
       
        print("RecordingManager: Creating snapshot for clipping from: \(currentURL.lastPathComponent)")
       
        assetWriterManager?.finishWriting { [weak self] success, _ in
            guard let self = self, success else {
                print("❌ Failed to finish current segment for snapshot")
                completion(nil)
                return
            }

            DispatchQueue.main.async {
                let sources = [self.previousSegmentURL, currentURL]
                    .compactMap { $0 }
                    .filter { FileManager.default.fileExists(atPath: $0.path) }
                self.previousSegmentURL = currentURL
                self.startNewSegment()

                Task {
                    let snapshotURL = await self.makeSnapshot(from: sources)
                    if let snapshotURL {
                        print("✅ Snapshot created successfully: \(snapshotURL.lastPathComponent)")
                    }
                    completion(snapshotURL)
                }
            }
        }
    }

    /// Copies a single segment, or joins the previous and current segments
    /// into one temp file. Falls back to the newest segment alone if joining fails.
    private func makeSnapshot(from sources: [URL]) async -> URL? {
        guard let newest = sources.last else { return nil }
        let snapshotURL = TempVideoManager.shared.uniqueTempURL(extension: "mp4")

        if sources.count > 1, await joinSegments(sources, into: snapshotURL) {
            return snapshotURL
        }

        do {
            try FileManager.default.removeItemIfExists(at: snapshotURL)
            try FileManager.default.copyItem(at: newest, to: snapshotURL)
            return snapshotURL
        } catch {
            print("RecordingManager: Snapshot copy failed: \(error)")
            return nil
        }
    }

    private func joinSegments(_ urls: [URL], into outputURL: URL) async -> Bool {
        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return false
        }

        do {
            var cursor = CMTime.zero
            for url in urls {
                let asset = AVURLAsset(url: url)
                guard let sourceTrack = try await asset.loadTracks(withMediaType: .video).first else { continue }
                let duration = try await asset.load(.duration)
                try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: sourceTrack, at: cursor)
                // Segments keep the orientation they were recorded in.
                track.preferredTransform = try await sourceTrack.load(.preferredTransform)
                cursor = CMTimeAdd(cursor, duration)
            }
            guard cursor > .zero else { return false }

            try FileManager.default.removeItemIfExists(at: outputURL)
            guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
                return false
            }
            if #available(iOS 18.0, *) {
                try await export.export(to: outputURL, as: .mp4)
            } else {
                export.outputURL = outputURL
                export.outputFileType = .mp4
                await export.export()
                guard export.status == .completed else { return false }
            }
            return FileManager.default.fileExists(atPath: outputURL.path)
        } catch {
            print("RecordingManager: Joining segments failed: \(error)")
            try? FileManager.default.removeItemIfExists(at: outputURL)
            return false
        }
    }
   
    private func cleanupVideoBuffer() {
        if let url = currentRecordingURL {
            TempVideoManager.shared.removeFile(at: url)
            print("RecordingManager: Cleaned up temp video: \(url.lastPathComponent)")
        }
        currentRecordingURL = nil
    }

    // MARK: - Video Configuration
    private func configureRecordingSettings() {
        frameRate = Int(UserDefaults.standard.string(forKey: "selectedFPS") ?? "30") ?? 30

        let quality = UserDefaults.standard.string(forKey: "selectedQuality") ?? "Medium"
        let size = VideoQualityManager.shared.encodeSize(for: quality)
        videoSize = CGSize(width: max(size.width, size.height), height: min(size.width, size.height))
    }

    // MARK: - Background Task Management
    private func beginBackgroundTask() {
        endBackgroundTask()
       
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
       
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            if let self = self, self.backgroundTaskID != .invalid {
                self.endBackgroundTask()
            }
        }
    }
   
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
   
    // MARK: - Overlay Management
    private func clearOverlayCache() {
        lastOverlayText = nil
        lastOverlayImage = nil
        lastOverlaySize = nil
        lastWatermarkImage = nil
        lastWatermarkSize = nil
        print("RecordingManager: Overlay cache cleared")
    }
   
    // MARK: - Text Overlay Implementation (unchanged)
    func addTextOverlayToBuffer(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let viewModel = SettingsViewModel.shared
        let shouldAddOverlay = viewModel.embedOverlayInVideo
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let currentSize = CGSize(width: width, height: height)

        // === WATERMARK ===
        let baseFontSize: CGFloat = min(CGFloat(width), CGFloat(height)) * 0.04
        let watermarkFont = UIFont.boldSystemFont(ofSize: baseFontSize)
        let watermarkAttributes: [NSAttributedString.Key: Any] = [
            .font: watermarkFont,
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor.black,
            .strokeWidth: -2.0
        ]

        let watermarkSize = (watermarkText as NSString).size(withAttributes: watermarkAttributes)
        let yOffsetFromBottom: CGFloat = CGFloat(height) * 0.10
        let watermarkRect = CGRect(
            x: (CGFloat(width) - watermarkSize.width) / 2,
            y: CGFloat(height) - watermarkSize.height - yOffsetFromBottom,
            width: watermarkSize.width,
            height: watermarkSize.height
        )

        var watermarkImage: UIImage?
        if let cached = lastWatermarkImage, lastWatermarkSize == currentSize {
            watermarkImage = cached
        } else {
            UIGraphicsBeginImageContextWithOptions(currentSize, false, 1.0)
            defer { UIGraphicsEndImageContext() }
            UIColor.clear.setFill()
            UIRectFill(CGRect(origin: .zero, size: currentSize))
            (watermarkText as NSString).draw(in: watermarkRect.integral, withAttributes: watermarkAttributes)
            watermarkImage = UIGraphicsGetImageFromCurrentImageContext()
            lastWatermarkImage = watermarkImage
            lastWatermarkSize = currentSize
        }

        // === USER OVERLAY ===
        var overlayImage: UIImage?
        if shouldAddOverlay {
            let isShowingLocation = viewModel.isShowingLocation
            let isShowingDate = viewModel.isShowingDate
            let isShowingTime = viewModel.isShowingTime
            let isShowingSpeed = viewModel.isShowingSpeed
            let isShowingFPS = viewModel.isShowingFPS
           
            let locationManager = LocationSpeedManager.shared
            let latitude = locationManager.latitude
            let longitude = locationManager.longitude
            let speed = String(format: "%.1f", locationManager.speed)
            let speedUnit = locationManager.speedUnit
           
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = isShowingDate ? dateFormatter.string(from: Date()) : ""
           
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            let timeString = isShowingTime ? timeFormatter.string(from: Date()) : ""
           
            var overlayComponents: [String] = []
            if isShowingLocation { overlayComponents.append("Lat: \(latitude), Lon: \(longitude)") }
            if isShowingDate { overlayComponents.append(dateString) }
            if isShowingTime { overlayComponents.append(timeString) }
            if isShowingSpeed { overlayComponents.append("Speed: \(speed) \(speedUnit)") }
            if isShowingFPS { overlayComponents.append("FPS: \(frameRate)") }
           
            let overlayText = overlayComponents.joined(separator: "\n")
           
            if !overlayText.isEmpty {
                let overlayFontSize = min(CGFloat(width), CGFloat(height)) * 0.03
                let font = UIFont.boldSystemFont(ofSize: overlayFontSize)
                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.white,
                    .backgroundColor: UIColor.black.withAlphaComponent(0.5)
                ]
               
                let textSize = (overlayText as NSString).size(withAttributes: textAttributes)
                let textPadding: CGFloat = overlayFontSize * 0.5
                let textRect = CGRect(
                    x: textPadding,
                    y: textPadding,
                    width: textSize.width + textPadding,
                    height: textSize.height + textPadding
                )
               
                if let cachedText = lastOverlayText,
                   let cachedImg = lastOverlayImage,
                   let cachedSize = lastOverlaySize,
                   cachedText == overlayText,
                   cachedSize == currentSize {
                    overlayImage = cachedImg
                } else {
                    UIGraphicsBeginImageContextWithOptions(currentSize, false, 1.0)
                    defer { UIGraphicsEndImageContext() }
                    UIColor.clear.setFill()
                    UIRectFill(CGRect(origin: .zero, size: currentSize))
                    (overlayText as NSString).draw(in: textRect, withAttributes: textAttributes)
                    overlayImage = UIGraphicsGetImageFromCurrentImageContext()
                    lastOverlayText = overlayText
                    lastOverlayImage = overlayImage
                    lastOverlaySize = currentSize
                }
            }
        }

        UIGraphicsBeginImageContextWithOptions(currentSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: currentSize))
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

        overlayImage?.draw(at: .zero)
        watermarkImage?.draw(at: .zero)

        guard let finalImage = UIGraphicsGetImageFromCurrentImageContext(),
              let finalBuffer = pixelBufferFromImage(finalImage, width: width, height: height) else {
            print("RecordingManager: Failed to composite final image with watermark")
            return pixelBuffer
        }

        return finalBuffer
    }
   
    private func pixelBufferFromImage(_ image: UIImage, width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
       
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                        width,
                                        height,
                                        kCVPixelFormatType_32ARGB,
                                        attrs,
                                        &pixelBuffer)
       
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            print("RecordingManager: Failed to create pixel buffer, status: \(status)")
            return nil
        }
       
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
       
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
            print("RecordingManager: Failed to create CGContext for pixel buffer")
            return nil
        }
       
        context.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: width, height: height))
       
        return buffer
    }
   
    // MARK: - Public Methods
    func getCurrentRecordingURL() -> URL? {
        return currentRecordingURL
    }
   
    func handleAppStateChange(active: Bool) {
        if active {
            if isRecording && assetWriterManager?.isWriterActive() == false {
                startRecording()
                IdleTimerManager.shared.disableIdleTimer(reason: "App became active during recording")
            }
        } else {
            if isRecording {
                stopRecording(saveVideo: false)
            } else {
                endBackgroundTask()
                IdleTimerManager.shared.enableIdleTimer(reason: "App went to background")
                NotificationCenter.default.post(name: NSNotification.Name("RecordingStopped"), object: nil)
            }
        }
    }
   
    // MARK: - Recovery Methods
    private func handleRecoveryAttempt() {
        guard !isRecovering else { return }
        isRecovering = true

        if recoveryAttempts < maxRecoveryAttempts {
            recoveryAttempts += 1
            print("RecordingManager: Attempting recovery #\(recoveryAttempts)")

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                if self.isRecording {
                    self.startNewSegment()
                }
                self.isRecovering = false
            }
        } else {
            print("RecordingManager: Too many recovery attempts, giving up")
            recoveryAttempts = 0
            DispatchQueue.main.async { [weak self] in
                self?.stopRecording(saveVideo: false)
                self?.isRecovering = false
            }
        }
    }
}

// MARK: - AVCapture Delegates
extension RecordingManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording, !isStoppingRecording, CMSampleBufferIsValid(sampleBuffer) else {
            return
        }
       
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("RecordingManager: Could not get pixel buffer")
            return
        }
       
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
       
        if let overlaidBuffer = addTextOverlayToBuffer(pixelBuffer) {
            assetWriterManager?.processVideoPixelBuffer(overlaidBuffer, withPresentationTime: timestamp)
        } else {
            assetWriterManager?.processVideoSampleBuffer(sampleBuffer)
        }
       
        if assetWriterManager?.hasWriterFailed() == true {
            print("RecordingManager: AssetWriter failed")
            handleRecoveryAttempt()
        }
    }
}
