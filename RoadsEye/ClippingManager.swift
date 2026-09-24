import Foundation
import AVFoundation
import UIKit
import Photos

class ClippingManager {
    static let shared = ClippingManager()
    
    private let processingQueue = DispatchQueue(label: "com.app.clipProcessing", qos: .userInitiated)
    
    private init() {}
    
    // MARK: - Main Clip Method
    func clipVideo(
        videoURL: URL,
        durationInMinutes: String,
        outputURL: URL? = nil,
        startOffset: Double = 0,
        completion: ((Bool, URL?) -> Void)? = nil
    ) async -> Bool {
        
        print("ClippingManager: Clipping video → Duration: \(durationInMinutes), Offset: \(startOffset)s, Source: \(videoURL.lastPathComponent)")
        
        DispatchQueue.main.async {
            AppNotificationsManager.shared.showNotification(title: "Clipping Started", body: "Saving clip...")
        }
        
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            print("ClippingManager: Source video does not exist")
            completion?(false, nil)
            return false
        }
        
        let finalOutputURL = outputURL ?? VideoFileManager.shared.getManualClipsDirectory()
            .appendingPathComponent("clip_\(Int(Date().timeIntervalSince1970)).mp4")
        
        do {
            let success = try await exportClippedVideo(
                asset: AVURLAsset(url: videoURL),
                durationInMinutes: durationInMinutes,
                startOffset: startOffset,
                outputURL: finalOutputURL
            )
            
            if success {
                await VideoFileManager.shared.saveToPhotoLibrary(fileURL: finalOutputURL, isClippedVideo: true)
                completion?(true, finalOutputURL)
            } else {
                completion?(false, nil)
            }
            return success
        } catch {
            print("ClippingManager: Clip failed - \(error.localizedDescription)")
            completion?(false, nil)
            return false
        }
    }
    
    // MARK: - Core Export (Fully Modernized)
    private func exportClippedVideo(
        asset: AVURLAsset,
        durationInMinutes: String,
        startOffset: Double,
        outputURL: URL
    ) async throws -> Bool {
        
        try FileManager.default.removeItemIfExists(at: outputURL)
        
        let durationSeconds: Double = {
            switch durationInMinutes.lowercased() {
            case "30s": return 30
            case "1m":  return 60
            case "2m":  return 120
            case "3m":  return 180
            default:    return 60
            }
        }()
        
        // Modern duration loading (fixes deprecation)
        let assetDuration: Double = await {
            if #available(iOS 16.0, *) {
                do {
                    let duration = try await asset.load(.duration)
                    return CMTimeGetSeconds(duration)
                } catch {
                    return CMTimeGetSeconds(asset.duration)
                }
            } else {
                return CMTimeGetSeconds(asset.duration)
            }
        }()
        
        let startTime = max(0.0, assetDuration + startOffset)
        let endTime = min(assetDuration, startTime + durationSeconds)
        
        let timeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            end: CMTime(seconds: endTime, preferredTimescale: 600)
        )
        
        guard assetDuration > 1.0 else {
            throw NSError(domain: "ClippingManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Source video too short"])
        }
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "ClippingManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not create export session"])
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.timeRange = timeRange
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Fixed Sendable issue by using local copy
        return await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                let success = exportSession.status == .completed &&
                             FileManager.default.fileExists(atPath: outputURL.path)
                
                if success {
                    print("✅ Clip exported successfully: \(outputURL.lastPathComponent)")
                } else {
                    let errorDesc = exportSession.error?.localizedDescription ?? "Unknown"
                    print("❌ Clip export failed: \(errorDesc)")
                }
                continuation.resume(returning: success)
            }
        }
    }
    
    // MARK: - Crash Clip
    func clipCrashVideo(videoURL: URL, outputURL: URL, completion: ((Bool, URL?) -> Void)? = nil) async -> Bool {
        return await clipVideo(
            videoURL: videoURL,
            durationInMinutes: "2m",
            outputURL: outputURL,
            startOffset: -120.0,
            completion: completion
        )
    }
}

// MARK: - Helper
extension FileManager {
    func removeItemIfExists(at url: URL) throws {
        guard fileExists(atPath: url.path) else { return }
        try removeItem(at: url)
    }
}
