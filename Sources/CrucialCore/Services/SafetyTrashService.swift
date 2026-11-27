import AppKit
import Foundation
import Observation

@Observable
@MainActor
public final class SafetyTrashService {
    public static let shared = SafetyTrashService()

    public var history: [TrashedRecord] = []
    public var lastDeletedCount: Int = 0
    public var lastFreedBytes: Int64 = 0

    private let protectedResolvedPrefixes: [String] = [
        "/System", "/usr", "/bin", "/sbin", "/private/var", "/Library/Extensions"
    ]

    private init() {}

    public func trash(item: FileItem) throws {
        guard item.assessment.level != .vital else {
            throw TrashError.protectedItem(item.path)
        }

        let resolved = item.url.resolvingSymlinksInPath().path
        if protectedResolvedPrefixes.contains(where: { resolved.hasPrefix($0) }) {
            throw TrashError.symlinkTargetProtected(item.path)
        }

        do {
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: item.url, resultingItemURL: &resultingURL)
            let record = TrashedRecord(
                originalURL: item.url,
                trashedAt: .now,
                size: item.size,
                name: item.name
            )
            history.insert(record, at: 0)
            lastDeletedCount = 1
            lastFreedBytes += item.size
        } catch {
            throw TrashError.recycleFailed(item.path, error.localizedDescription)
        }
    }

    public func trashBatch(items: [FileItem]) -> (succeeded: Int, failed: Int, bytesFreed: Int64) {
        var successCount = 0
        var failCount = 0
        var freed: Int64 = 0

        for item in items {
            do {
                try trash(item: item)
                successCount += 1
                freed += item.size
            } catch {
                failCount += 1
            }
        }

        lastDeletedCount = successCount
        return (successCount, failCount, freed)
    }

    /// Safely stages an arbitrary URL (such as an app bundle or residue directory) to Trash without AppleScript injection.
    public func recycleURLSafely(_ url: URL) async throws {
        let resolved = url.resolvingSymlinksInPath().path
        if protectedResolvedPrefixes.contains(where: { resolved.hasPrefix($0) }) {
            throw TrashError.symlinkTargetProtected(url.path)
        }

        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        } catch {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                NSWorkspace.shared.recycle([url]) { recycled, recycleError in
                    if let recycleError {
                        continuation.resume(throwing: TrashError.recycleFailed(url.path, recycleError.localizedDescription))
                    } else if recycled.isEmpty {
                        continuation.resume(throwing: TrashError.recycleFailed(url.path, "Finder did not recycle the item."))
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }

    public func openTrash() {
        if let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first {
            NSWorkspace.shared.open(trashURL)
        }
    }
}
