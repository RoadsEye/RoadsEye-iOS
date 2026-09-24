import Foundation

/// Handles the app's throwaway storage: the temporary directory (including the
/// dedicated video temp folder) and `Library/Caches`.
///
/// Saved recordings live in `Documents/RoadsEye` and are **never** touched here —
/// clearing the cache only removes files the app can safely regenerate.
final class CacheManager {
    static let shared = CacheManager()

    private init() {}

    // MARK: - Locations

    /// Directories that are considered cache and may be emptied.
    private var cacheDirectories: [URL] {
        var directories: [URL] = [FileManager.default.temporaryDirectory]
        if let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            directories.append(caches)
        }
        return directories
    }

    // MARK: - Size

    /// Total bytes currently used by the cache directories.
    func calculateCacheSize() async -> Int64 {
        await Task.detached(priority: .utility) { [directories = cacheDirectories] in
            let fm = FileManager.default
            var total: Int64 = 0

            for directory in directories {
                guard let enumerator = fm.enumerator(
                    at: directory,
                    includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey],
                    options: []
                ) else { continue }

                for case let url as URL in enumerator {
                    let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey])
                    guard values?.isRegularFile == true else { continue }
                    total += Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
                }
            }

            return total
        }.value
    }

    // MARK: - Clearing

    /// Empties the cache directories and the shared URL cache.
    /// - Parameter excludedPaths: files that must be left alone (e.g. an in-flight recording).
    /// - Returns: the number of bytes freed.
    @discardableResult
    func clearCache(excluding excludedPaths: [String] = []) async -> Int64 {
        let before = await calculateCacheSize()

        await Task.detached(priority: .utility) { [directories = cacheDirectories] in
            let fm = FileManager.default

            for directory in directories {
                guard let items = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { continue }

                for url in items {
                    // Never remove a file that's still being written to.
                    if excludedPaths.contains(where: { $0.hasPrefix(url.path) || url.path.hasPrefix($0) }) { continue }
                    try? fm.removeItem(at: url)
                }
            }
        }.value

        URLCache.shared.removeAllCachedResponses()

        // Recreate the dedicated video temp folder so recording still works
        // immediately after a clear.
        _ = TempVideoManager.shared.videoTempDirectory
        try? FileManager.default.createDirectory(
            at: TempVideoManager.shared.videoTempDirectory,
            withIntermediateDirectories: true
        )

        let after = await calculateCacheSize()
        return max(0, before - after)
    }

    // MARK: - Formatting

    /// Human-readable size string, e.g. "12.4 MB".
    func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
