import Foundation

/// Symlink-safe filesystem sizing and inode counting helpers.
public enum FileSystemSizer: Sendable {
    /// Calculates the physical size of a file or directory without following symbolic links.
    public static func size(at url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [
            .isSymbolicLinkKey,
            .isDirectoryKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .fileSizeKey
        ]

        guard let rootValues = try? url.resourceValues(forKeys: keys) else {
            return 0
        }

        if rootValues.isSymbolicLink == true {
            return 0
        }

        if rootValues.isDirectory != true {
            return Int64(rootValues.fileSize ?? rootValues.totalFileAllocatedSize ?? 0)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: []
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if Task.isCancelled { break }
            guard let values = try? fileURL.resourceValues(forKeys: keys) else { continue }
            if values.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            if values.isDirectory != true {
                total += Int64(values.fileSize ?? values.totalFileAllocatedSize ?? 0)
            }
        }
        return total
    }

    /// Asynchronously computes directory size off the main thread.
    public nonisolated static func sizeAsync(at url: URL) async -> Int64 {
        await Task.detached(priority: .utility) {
            size(at: url)
        }.value
    }

    /// Synchronously counts entries inside a directory up to a bounded ceiling without following symlinks.
    public static func boundedFileCountSync(at url: URL, limit: Int = 5000) -> Int {
        let keys: Set<URLResourceKey> = [.isSymbolicLinkKey, .isDirectoryKey]
        guard let rootValues = try? url.resourceValues(forKeys: keys),
              rootValues.isSymbolicLink != true,
              rootValues.isDirectory == true,
              let enumerator = FileManager.default.enumerator(
                  at: url,
                  includingPropertiesForKeys: Array(keys),
                  options: []
              )
        else {
            return 1
        }

        var count = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: keys), values.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            count += 1
            if count >= limit { break }
        }
        return max(1, count)
    }

    /// Asynchronously counts entries inside a directory up to a bounded ceiling without following symlinks.
    public nonisolated static func boundedFileCount(at url: URL, limit: Int = 5000) async -> Int {
        await Task.detached(priority: .utility) {
            boundedFileCountSync(at: url, limit: limit)
        }.value
    }
}
