import Photos
import UIKit
import AVFoundation

// MARK: - Dedicated Temporary Storage Manager (Auto-Cleaned on Launch)
public class TempVideoManager {
    static let shared = TempVideoManager()

    // Dedicated subfolder inside NSTemporaryDirectory
    public let videoTempDirectory: URL = {
        let temp = FileManager.default.temporaryDirectory
        var folder = temp.appendingPathComponent("com.RoadsEye.VideoTemp", isDirectory: true)

        // Create folder if needed
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        // Exclude from iCloud backup
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? folder.setResourceValues(values)

        return folder
    }()

    /// Call this once when app launches — cleans everything from previous session
    static func cleanAllTemporaryVideos() {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: shared.videoTempDirectory, includingPropertiesForKeys: nil) else { return }

        for url in items {
            try? fm.removeItem(at: url)
        }
        print("TempVideoManager: Deleted \(items.count) leftover video files on app launch")
    }

    /// Generate unique temporary URL inside our dedicated folder
    func uniqueTempURL(extension ext: String = "mov") -> URL {
        let filename = "roads_eye_\(Date().timeIntervalSince1970)_\(UUID().uuidString.prefix(8)).\(ext)"
        return videoTempDirectory.appendingPathComponent(filename)
    }

    /// Safe delete — only allows files inside our folder
    func removeFile(at url: URL) {
        guard url.path.hasPrefix(videoTempDirectory.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - VideoFileManager
final class VideoFileManager: NSObject {
    static let shared = VideoFileManager()

    // In-memory guard against duplicate save attempts for the same file
    private var filesBeingSaved = Set<String>()
    private let saveLock = NSLock()

    // Photo-library asset IDs created by the app, so "Delete All" can remove them
    private let recordingAssetIDsKey = "photoAssetIDs_recordings"
    private let clipAssetIDsKey = "photoAssetIDs_clips"

    private override init() {
        super.init()
    }

    // MARK: - Call This at App Launch!
    static func cleanAllTemporaryVideosOnLaunch() {
        TempVideoManager.cleanAllTemporaryVideos()
    }

    // MARK: - Main Save Method
    func saveToPhotoLibrary(fileURL: URL, isClippedVideo: Bool = false) async {
        print("VideoFileManager: Starting save process for \(fileURL.lastPathComponent)")

        // Prevent duplicate save attempts for the same file
        saveLock.lock()
        let alreadySaving = filesBeingSaved.contains(fileURL.lastPathComponent)
        if !alreadySaving { filesBeingSaved.insert(fileURL.lastPathComponent) }
        saveLock.unlock()

        if alreadySaving {
            print("Already saving this file, skipping duplicate save attempt")
            return
        }
        defer {
            saveLock.lock()
            filesBeingSaved.remove(fileURL.lastPathComponent)
            saveLock.unlock()
        }

        guard await checkPhotoLibraryAuthorization() else {
            print("Photo library access not authorized")
            cleanupTemporaryFile(fileURL)
            return
        }

        guard verifyFile(at: fileURL) else {
            print("[Video Save] File verification FAILED for \(fileURL.lastPathComponent)")
            cleanupTemporaryFile(fileURL)
            return
        }

        let success = await saveUsingPhotosFramework(fileURL: fileURL, isClippedVideo: isClippedVideo)
        print("[Video Save] Photos framework save \(success ? "SUCCESS" : "FAILURE") for \(fileURL.lastPathComponent)")

        cleanupTemporaryFile(fileURL)
        await enforceStorageLimit()
    }

    // MARK: - Authorization Check
    private func checkPhotoLibraryAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    // MARK: - Photos Framework Save Method
    private func saveUsingPhotosFramework(fileURL: URL, isClippedVideo: Bool) async -> Bool {
        do {
            var createdAssetID: String?
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
                createdAssetID = request?.placeholderForCreatedAsset?.localIdentifier
            }

            // Remember the asset so "Delete All" can remove it from Photos later
            if let assetID = createdAssetID {
                let key = isClippedVideo ? clipAssetIDsKey : recordingAssetIDsKey
                var ids = UserDefaults.standard.stringArray(forKey: key) ?? []
                ids.append(assetID)
                UserDefaults.standard.set(ids, forKey: key)
            }
            return true
        } catch {
            print("Photos save error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Photo Library Deletion
    /// Deletes the app-created recordings from the photo library. iOS shows its
    /// own confirmation dialog; if the user cancels, the IDs are kept for retry.
    /// Clips (manual/crash) are preserved, mirroring the Files deletion.
    func deleteSavedRecordingsFromPhotoLibrary() async {
        let ids = UserDefaults.standard.stringArray(forKey: recordingAssetIDsKey) ?? []
        guard !ids.isEmpty else {
            print("VideoFileManager: No tracked photo-library recordings to delete")
            return
        }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        guard assets.count > 0 else {
            UserDefaults.standard.removeObject(forKey: recordingAssetIDsKey)
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets)
            }
            UserDefaults.standard.removeObject(forKey: recordingAssetIDsKey)
            print("VideoFileManager: Deleted \(assets.count) recordings from photo library")
        } catch {
            print("VideoFileManager: Photo library deletion failed or was cancelled: \(error.localizedDescription)")
        }
    }

    // MARK: - File Verification
    func verifyFile(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let fileSize = attributes[.size] as? UInt64, fileSize > 0 else { return false }

            guard let fileHandle = try? FileHandle(forReadingFrom: url) else { return false }
            defer { try? fileHandle.close() }
            guard let data = try? fileHandle.read(upToCount: 1024), !data.isEmpty else { return false }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Cleanup
    private func cleanupTemporaryFile(_ fileURL: URL) {
        TempVideoManager.shared.removeFile(at: fileURL)
    }

    // MARK: - RoadsEye Folder Helpers
    func ensureRoadsEyeFoldersExist() {
        let roadsEyeDir = getRoadsEyeDirectory()
        let manualClipsDir = getManualClipsDirectory()
        let crashClipsDir = getCrashClipsDirectory()

        do {
            for dir in [roadsEyeDir, manualClipsDir, crashClipsDir] {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }

            let markerURL = roadsEyeDir.appendingPathComponent("README_RoadsEye.txt")
            if !FileManager.default.fileExists(atPath: markerURL.path) {
                let content = """
                RoadsEye Dashcam Folder

                • Manual clips → /ManualClips
                • Crash clips   → /CrashClips

                This folder was created by the RoadsEye app.
                """
                try? content.write(to: markerURL, atomically: true, encoding: .utf8)
            }
            print("✅ SUCCESS: RoadsEye folders created/verified")
        } catch {
            print("❌ Failed to create RoadsEye folders: \(error.localizedDescription)")
        }
    }

    func getRoadsEyeDirectory() -> URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDir.appendingPathComponent("RoadsEye")
    }

    func getManualClipsDirectory() -> URL {
        return getRoadsEyeDirectory().appendingPathComponent("ManualClips")
    }

    func getCrashClipsDirectory() -> URL {
        return getRoadsEyeDirectory().appendingPathComponent("CrashClips")
    }

    // MARK: - Storage Calculation & Enforcement
    func calculateRoadsEyeStorageUsage() async -> Int64 {
        await withCheckedContinuation { continuation in
            let roadsEyeDir = getRoadsEyeDirectory()
            var total: Int64 = 0

            let enumerator = FileManager.default.enumerator(
                at: roadsEyeDir,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            )

            while let fileURL = enumerator?.nextObject() as? URL {
                // Only count actual video files
                let ext = fileURL.pathExtension.lowercased()
                guard ext == "mp4" || ext == "mov" else { continue }

                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    total += Int64(fileSize)
                }
            }

            let mb = total / (1024 * 1024)
            print("VideoFileManager: Total storage usage in RoadsEye folder: \(mb) MB")
            continuation.resume(returning: mb)
        }
    }

    func enforceStorageLimit() async {
        let maxMB = SettingsViewModel.shared.maxStorageMB
        let currentUsage = await calculateRoadsEyeStorageUsage()

        if currentUsage > maxMB {
            print("🚨 VideoFileManager: Storage limit exceeded (\(currentUsage)MB > \(maxMB)MB). Deleting oldest clips...")
            await deleteOldestFiles(untilUnderMB: maxMB)
        } else {
            print("✅ Storage under limit (\(currentUsage)MB / \(maxMB)MB)")
        }
    }

    private func deleteOldestFiles(untilUnderMB targetMB: Int) async {
        var allFiles: [(url: URL, date: Date, size: Int64)] = []

        for dir in [getRoadsEyeDirectory(), getManualClipsDirectory(), getCrashClipsDirectory()] {
            let enumerator = FileManager.default.enumerator(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )

            while let fileURL = enumerator?.nextObject() as? URL {
                let ext = fileURL.pathExtension.lowercased()
                guard ext == "mp4" || ext == "mov" else { continue }

                if let modDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    allFiles.append((fileURL, modDate, Int64(size)))
                }
            }
        }

        // Sort oldest first
        allFiles.sort { $0.date < $1.date }

        var currentUsage = await calculateRoadsEyeStorageUsage()
        var deletedCount = 0

        for file in allFiles {
            if currentUsage <= targetMB { break }

            do {
                try FileManager.default.removeItem(at: file.url)
                let deletedMB = file.size / (1024 * 1024)
                currentUsage -= deletedMB
                deletedCount += 1
                print("🗑 Deleted oldest clip: \(file.url.lastPathComponent) (\(deletedMB)MB)")
            } catch {
                print("❌ Failed to delete \(file.url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        print("✅ Storage cleanup complete. Deleted \(deletedCount) old clips. New usage: \(currentUsage)MB")
    }

    // MARK: - Delete All
    func deleteAllRoadsEyeFiles(excludeSpecialFolders: Bool = true) async -> Bool {
        let roadsEyeDir = getRoadsEyeDirectory()
        do {
            let items = try FileManager.default.contentsOfDirectory(at: roadsEyeDir, includingPropertiesForKeys: nil)
            for item in items {
                let folderName = item.lastPathComponent
                if excludeSpecialFolders && (folderName == "ManualClips" || folderName == "CrashClips") {
                    continue
                }
                try FileManager.default.removeItem(at: item)
            }
            print("VideoFileManager: Deleted all files in RoadsEye folder (special folders preserved)")
            return true
        } catch {
            print("VideoFileManager: Failed to delete all files: \(error)")
            return false
        }
    }
}
