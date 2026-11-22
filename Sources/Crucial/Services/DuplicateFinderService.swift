import Foundation
import CryptoKit

public struct CryptoDuplicateGroup: Identifiable, Sendable {
    public let id = UUID()
    public let hash: String
    public let size: Int64
    public let original: FileItem
    public var duplicates: [FileItem]

    public var totalWastedBytes: Int64 {
        Int64(duplicates.count) * size
    }

    public var formattedWastedSize: String {
        ByteCountFormatter.string(fromByteCount: totalWastedBytes, countStyle: .file)
    }
}

@MainActor
public final class DuplicateFinderService: ObservableObject {
    public static let shared = DuplicateFinderService()

    @Published public var duplicateGroups: [CryptoDuplicateGroup] = []
    @Published public var isScanning: Bool = false
    @Published public var progressMessage: String = ""
    @Published public var totalWastedBytes: Int64 = 0

    private init() {}

    public func scanForDuplicates(in items: [FileItem]) async {
        isScanning = true
        progressMessage = "Filtering potential duplicates by byte magnitude..."

        let candidates = items.filter { !$0.isDirectory && $0.size > 100_000 } // > 100 KB
        let sizeGroups = Dictionary(grouping: candidates, by: { $0.size }).filter { $0.value.count > 1 }

        progressMessage = "Analyzing cryptographic SHA-256 signatures across \(sizeGroups.count) size matches..."

        var groups: [CryptoDuplicateGroup] = []
        var totalWasted: Int64 = 0

        for (_, matchingFiles) in sizeGroups {
            var hashDict: [String: [FileItem]] = [:]

            for item in matchingFiles {
                if let hash = await computeSHA256(for: item.url) {
                    hashDict[hash, default: []].append(item)
                }
            }

            for (hash, files) in hashDict where files.count > 1 {
                // Sort by creation date so the oldest is marked as original
                let sorted = files.sorted { ($0.creationDate ?? Date.distantPast) < ($1.creationDate ?? Date.distantPast) }
                let original = sorted[0]
                let dups = Array(sorted.dropFirst())
                let group = CryptoDuplicateGroup(
                    hash: hash,
                    size: original.size,
                    original: original,
                    duplicates: dups
                )
                groups.append(group)
                totalWasted += group.totalWastedBytes
            }
        }

        // Sort groups by largest space wasted
        self.duplicateGroups = groups.sorted { $0.totalWastedBytes > $1.totalWastedBytes }
        self.totalWastedBytes = totalWasted
        self.isScanning = false
        self.progressMessage = ""
    }

    private func computeSHA256(for url: URL) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let handle = try FileHandle(forReadingFrom: url)
                    defer { try? handle.close() }

                    var hasher = SHA256()
                    while autoreleasepool(invoking: {
                        let data = handle.readData(ofLength: 64 * 1024)
                        if data.isEmpty { return false }
                        hasher.update(data: data)
                        return true
                    }) {}

                    let digest = hasher.finalize()
                    let hashString = digest.map { String(format: "%02x", $0) }.joined()
                    continuation.resume(returning: hashString)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    public func trashDuplicate(item: FileItem) {
        do {
            try SafetyTrashService.shared.trash(item: item)
            // Update local groups
            for i in 0..<duplicateGroups.count {
                duplicateGroups[i].duplicates.removeAll { $0.id == item.id }
            }
            duplicateGroups.removeAll { $0.duplicates.isEmpty }
            recalculateWastedBytes()
        } catch {
            // Handled safely
        }
    }

    public func trashAllDuplicates() {
        for group in duplicateGroups {
            for dup in group.duplicates {
                try? SafetyTrashService.shared.trash(item: dup)
            }
        }
        duplicateGroups.removeAll()
        totalWastedBytes = 0
    }

    private func recalculateWastedBytes() {
        totalWastedBytes = duplicateGroups.reduce(0) { $0 + $1.totalWastedBytes }
    }
}
