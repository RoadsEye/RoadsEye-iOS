import Foundation
import AVFoundation
import UIKit

class AssetWriterManager: NSObject {
    // MARK: - Properties
    private var assetWriter: AVAssetWriter?
    private var assetWriterVideoInput: AVAssetWriterInput?
    private var currentRecordingURL: URL?

    // Pixel buffer adaptor for overlay rendering
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    // Synchronization
    private let writerQueue = DispatchQueue(label: "com.app.assetwriter.queue")
    private var firstVideoSampleTime: CMTime?

    // Configuration
    private var videoSize = CGSize(width: 1920, height: 1080)
    private var frameRate = 30
    private var recordingOrientation: UIInterfaceOrientation?

    private func bitrate(for size: CGSize) -> Int {
        let pixelCount = size.width * size.height
        if pixelCount <= 720 * 480 { return 2_000_000 }
        if pixelCount <= 1280 * 720 { return 4_000_000 }
        return 6_000_000
    }

    // MARK: - Prepare Recording
    func prepareForRecording(
        videoSize: CGSize,
        frameRate: Int,
        orientation: UIInterfaceOrientation?,
        outputURL: URL? = nil
    ) {
        self.videoSize = videoSize
        self.frameRate = frameRate
        self.recordingOrientation = orientation

        let finalURL = outputURL ?? TempVideoManager.shared.uniqueTempURL(extension: "mov")
        currentRecordingURL = finalURL

        print("AssetWriterManager preparing \(Int(videoSize.width))x\(Int(videoSize.height)) @ \(frameRate)fps → \(finalURL.lastPathComponent)")
        setupAssetWriter(at: finalURL)
    }

    func isWriterActive() -> Bool {
        return assetWriter?.status == .writing
    }

    func hasWriterFailed() -> Bool {
        return assetWriter?.status == .failed
    }

    // MARK: - Sample Buffer Processing
    func processVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        writerQueue.async { [weak self] in
            guard let self = self else { return }
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            if self.firstVideoSampleTime == nil {
                self.firstVideoSampleTime = timestamp
                self.startWritingIfNeeded(at: timestamp)
            }

            guard let writer = self.assetWriter, writer.status == .writing,
                  let videoInput = self.assetWriterVideoInput, videoInput.isReadyForMoreMediaData else { return }

            if !videoInput.append(sampleBuffer) {
                print("Failed to append video sample buffer")
            }
        }
    }

    func processVideoPixelBuffer(_ pixelBuffer: CVPixelBuffer, withPresentationTime presentationTime: CMTime) {
        writerQueue.async { [weak self] in
            guard let self = self else { return }

            if self.firstVideoSampleTime == nil {
                self.firstVideoSampleTime = presentationTime
                self.startWritingIfNeeded(at: presentationTime)
            }

            guard let writer = self.assetWriter, writer.status == .writing,
                  let videoInput = self.assetWriterVideoInput, videoInput.isReadyForMoreMediaData,
                  let adaptor = self.pixelBufferAdaptor else { return }

            if !adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
                print("Failed to append pixel buffer")
            }
        }
    }

    // MARK: - Private: Start Writing
    private func startWritingIfNeeded(at time: CMTime) {
        guard let writer = assetWriter, writer.status == .unknown else { return }
        if writer.startWriting() {
            writer.startSession(atSourceTime: time)
            print("Started writing session at time: \(time.seconds)")
        } else {
            print("Failed to start writing: \(writer.error?.localizedDescription ?? "Unknown error")")
        }
    }

    // MARK: - Asset Writer Setup
    private func setupAssetWriter(at url: URL) {
        do {
            assetWriter = try AVAssetWriter(url: url, fileType: .mp4)

            let videoOutputSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: videoSize.width,
                AVVideoHeightKey: videoSize.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: bitrate(for: videoSize),
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoMaxKeyFrameIntervalKey: frameRate
                ]
            ]

            assetWriterVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoOutputSettings)
            assetWriterVideoInput?.expectsMediaDataInRealTime = true
            assetWriterVideoInput?.transform = getTransformForCurrentOrientation()

            if let videoInput = assetWriterVideoInput, assetWriter?.canAdd(videoInput) == true {
                assetWriter?.add(videoInput)

                let sourcePixelBufferAttributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                    kCVPixelBufferWidthKey as String: Int(videoSize.width),
                    kCVPixelBufferHeightKey as String: Int(videoSize.height)
                ]

                pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: videoInput,
                    sourcePixelBufferAttributes: sourcePixelBufferAttributes
                )
            }

            firstVideoSampleTime = nil

            print("AVAssetWriter ready at \(url.lastPathComponent)")
        } catch {
            print("Failed to create AVAssetWriter: \(error.localizedDescription)")
        }
    }

    // MARK: - Finish Writing
    func finishWriting(completion: @escaping (Bool, URL?) -> Void) {
        guard let writer = assetWriter else {
            completion(false, nil)
            return
        }

        writerQueue.async { [weak self] in
            guard let self = self else {
                completion(false, nil)
                return
            }

            if writer.status == .writing {
                self.assetWriterVideoInput?.markAsFinished()

                writer.finishWriting {
                    let success = writer.status == .completed
                    if !success { print("AssetWriter failed: \(writer.error?.localizedDescription ?? "Unknown")") }
                    completion(success, self.currentRecordingURL)
                }
            } else {
                completion(writer.status == .completed, self.currentRecordingURL)
            }
        }
    }

    // MARK: - Orientation Transform
    /// Buffers arrive in the sensor's native landscape orientation (equivalent
    /// to interface landscapeRight). This transform is display metadata telling
    /// players how to rotate the video so it plays upright for the orientation
    /// the recording started in.
    private func getTransformForCurrentOrientation() -> CGAffineTransform {
        let w = videoSize.width
        let h = videoSize.height

        switch recordingOrientation ?? .portrait {
        case .portrait:
            // 90° clockwise
            return CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: h, ty: 0)
        case .portraitUpsideDown:
            // 270°
            return CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: w)
        case .landscapeLeft:
            // 180°
            return CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: w, ty: h)
        default:
            // landscapeRight matches the sensor's native orientation
            return .identity
        }
    }

    // MARK: - File Verification
    func verifyFile(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("File does not exist: \(url.lastPathComponent)")
            return false
        }

        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let size = attrs[.size] as? UInt64, size > 0 else {
                print("File has zero size: \(url.lastPathComponent)")
                return false
            }

            guard let handle = try? FileHandle(forReadingFrom: url),
                  let data = try? handle.read(upToCount: 1024), !data.isEmpty else {
                print("File exists but unreadable: \(url.lastPathComponent)")
                return false
            }
            try? handle.close()
            print("File verified: \(url.lastPathComponent) (\(size) bytes)")
            return true
        } catch {
            print("File verification error: \(error.localizedDescription)")
            return false
        }
    }
}
