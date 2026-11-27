import CryptoKit
import Foundation
import Observation

@Observable
@MainActor
public final class DuplicateFinderService {
    public static let shared = DuplicateFinderService()

    public var duplicateGroups: [DuplicateGroup] = []
    public var isScanning: Bool = false
    public var progressMessage: String = ""
    public var totalWastedBytes: Int64 = 0
    public var lastErrorMessage: String?

    private var activeTask: Task<Void, Never>?

    private init() {}

    public func scanForDuplicates(in items: [FileItem]) async {
        activeTask?.cancel()
        isScanning = true
        lastErrorMessage = nil
        progressMessage = "Grouping candidate files by exact byte size..."

        let result = await Task.detached(priority: .utility) { () -> ([DuplicateGroup], Int64) in
            Self.detectDuplicates(in: items)
        }.value

        duplicateGroups = result.0
        totalWastedBytes = result.1
        isScanning = false
        progressMessage = ""
    }

    /// Runs the 3-stage pipeline:
    /// 1) Exact byte size grouping -> 2) 4 KB header+tail fingerprint -> 3) Full SHA-256 verification.
    public nonisolated static func detectDuplicates(in items: [FileItem]) -> ([DuplicateGroup], Int64) {
        let candidates = items.filter { !$0.isDirectory && $0.size > 100_000 }
        let sizeGroups = Dictionary(grouping: candidates, by: \.size).filter { $0.value.count > 1 }

        var groups: [DuplicateGroup] = []
        var totalWasted: Int64 = 0

        for (_, matchingSizeItems) in sizeGroups {
            if Task.isCancelled { break }

            // Stage 2: 4 KB header + tail fast pre-filter
            var preHashDict: [String: [FileItem]] = [:]
            for item in matchingSizeItems {
                if let preHash = computeHeaderTailHash(for: item.url, size: item.size) {
                    preHashDict[preHash, default: []].append(item)
                }
            }

            // Stage 3: Full SHA-256 cryptographic confirmation only on pre-filter matches
            for (_, preMatched) in preHashDict where preMatched.count > 1 {
                var fullHashDict: [String: [FileItem]] = [:]
                for item in preMatched {
                    if let fullHash = computeFullSHA256(for: item.url) {
                        fullHashDict[fullHash, default: []].append(item)
                    }
                }

                for (hash, verifiedFiles) in fullHashDict where verifiedFiles.count > 1 {
                    let sorted = verifiedFiles.sorted {
                        ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
                    }
                    guard let original = sorted.first else { continue }
                    let duplicates = Array(sorted.dropFirst())
                    let group = DuplicateGroup(
                        hash: hash,
                        size: original.size,
                        original: original,
                        duplicates: duplicates
                    )
                    groups.append(group)
                    totalWasted += group.totalWastedBytes
                }
            }
        }

        return (groups.sorted { $0.totalWastedBytes > $1.totalWastedBytes }, totalWasted)
    }

    private nonisolated static func computeHeaderTailHash(for url: URL, size: Int64) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let chunkLen = 4096
        var hasher = SHA256()
        let head = (try? handle.read(upToCount: chunkLen)) ?? Data()
        hasher.update(data: head)

        if size > Int64(chunkLen) {
            let tailOffset = UInt64(max(0, size - Int64(chunkLen)))
            try? handle.seek(toOffset: tailOffset)
            let tail = (try? handle.read(upToCount: chunkLen)) ?? Data()
            hasher.update(data: tail)
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private nonisolated static func computeFullSHA256(for url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let data = (try? handle.read(upToCount: 64 * 1024)) ?? Data()
            if data.isEmpty { return false }
            hasher.update(data: data)
            return true
        }) {}

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public func trashDuplicate(item: FileItem) {
        do {
            try SafetyTrashService.shared.trash(item: item)
            for i in duplicateGroups.indices {
                duplicateGroups[i].duplicates.removeAll { $0.id == item.id }
            }
            duplicateGroups.removeAll { $0.duplicates.isEmpty }
            recalculateWastedBytes()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func trashAllDuplicates() {
        var failures: [String] = []
        var trashedIDs: Set<UUID> = []

        for group in duplicateGroups {
            for dup in group.duplicates {
                do {
                    try SafetyTrashService.shared.trash(item: dup)
                    trashedIDs.insert(dup.id)
                } catch {
                    failures.append("\(dup.name): \(error.localizedDescription)")
                }
            }
        }

        for i in duplicateGroups.indices {
            duplicateGroups[i].duplicates.removeAll { trashedIDs.contains($0.id) }
        }
        duplicateGroups.removeAll { $0.duplicates.isEmpty }
        recalculateWastedBytes()
        lastErrorMessage = failures.isEmpty ? nil : failures.joined(separator: "\n")
    }

    private func recalculateWastedBytes() {
        totalWastedBytes = duplicateGroups.reduce(0) { $0 + $1.totalWastedBytes }
    }
}
