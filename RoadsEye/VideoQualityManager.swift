import Foundation
import AVFoundation

/// Maps the user-facing quality setting to concrete capture/encode parameters.
final class VideoQualityManager {
    static let shared = VideoQualityManager()

    private init() {}

    /// Camera sensor capture resolution used for format selection.
    func captureSize(for quality: String) -> CGSize {
        switch quality {
        case "High":   return CGSize(width: 1920, height: 1080)
        case "Low":    return CGSize(width: 640, height: 480)
        default:       return CGSize(width: 1280, height: 720)
        }
    }

    /// Output file resolution (landscape) written by the asset writer.
    func encodeSize(for quality: String) -> CGSize {
        switch quality {
        case "High":   return CGSize(width: 1920, height: 1080)
        case "Low":    return CGSize(width: 720, height: 480)
        default:       return CGSize(width: 1280, height: 720)
        }
    }

    /// Average video bitrate in bits per second.
    func bitrate(for quality: String) -> Int {
        switch quality {
        case "High":   return 6_000_000
        case "Low":    return 2_000_000
        default:       return 4_000_000
        }
    }
}
