import Foundation
import AppKit

public enum TrashError: LocalizedError {
    case protectedItem(String)
    case recycleFailed(String)

    public var errorDescription: String? {
        switch self {
        case .protectedItem(let path):
            return "Crucial Safety Lock: '\(path)' is marked as Protected/Vital and cannot be deleted."
        case .recycleFailed(let path):
            return "Failed to move '\(path)' to macOS Trash."
        }
    }
}

public struct TrashedRecord: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let originalURL: URL
    public let trashedAt: Date
    public let size: Int64
    public let name: String
}

@MainActor
public final class SafetyTrashService: ObservableObject {
    public static let shared = SafetyTrashService()

    @Published public var history: [TrashedRecord] = []
    @Published public var lastDeletedCount: Int = 0
    @Published public var lastFreedBytes: Int64 = 0

    private init() {}

    public func trash(item: FileItem) throws {
        guard item.assessment.level != .vital else {
            throw TrashError.protectedItem(item.path)
        }

        var resultingURL: NSURL?
        do {
            try FileManager.default.trashItem(at: item.url, resultingItemURL: &resultingURL)
            let record = TrashedRecord(
                originalURL: item.url,
                trashedAt: Date(),
                size: item.size,
                name: item.name
            )
            self.history.insert(record, at: 0)
            self.lastDeletedCount = 1
            self.lastFreedBytes = item.size
        } catch {
            throw TrashError.recycleFailed(item.path)
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

        self.lastDeletedCount = successCount
        self.lastFreedBytes = freed

        return (successCount, failCount, freed)
    }

    public func openTrash() {
        if let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first {
            NSWorkspace.shared.open(trashURL)
        }
    }
}
