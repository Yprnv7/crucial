import Foundation
import CryptoKit

public enum ScanPacingMode: String, CaseIterable, Identifiable, Sendable {
    case pacedBurst = "Paced Bursts (~10% CPU)"
    case turbo = "Turbo Full Speed (97% CPU)"

    public var id: String { rawValue }

    public var subtitle: String {
        switch self {
        case .pacedBurst:
            return "Micro-bursts with cooling intervals to maintain CPU around 10% (cool & quiet)"
        case .turbo:
            return "Uncapped multi-core burst (up to 97% CPU) to finish scanning at maximum speed"
        }
    }
}

public struct DuplicateGroup: Identifiable, Sendable {
    public let id = UUID()
    public let size: Int64
    public let hash: String
    public var files: [FileItem]
}

@MainActor
public final class FileScannerService: ObservableObject {
    public static let shared = FileScannerService()

    @Published public var isScanning: Bool = false
    @Published public var scanProgressMessage: String = ""
    @Published public var itemsByCategory: [JunkCategory: [FileItem]] = [:]
    @Published public var duplicateGroups: [DuplicateGroup] = []
    @Published public var totalCleanableBytes: Int64 = 0
    @Published public var diskTotalBytes: Int64 = 0
    @Published public var diskFreeBytes: Int64 = 0
    @Published public var pacingMode: ScanPacingMode = .pacedBurst

    private init() {
        refreshDiskSpace()
    }

    public func refreshDiskSpace() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        if let values = try? home.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) {
            self.diskTotalBytes = Int64(values.volumeTotalCapacity ?? 0)
            self.diskFreeBytes = values.volumeAvailableCapacityForImportantUsage ?? 0
        }
    }

    public var usedDiskPercent: Double {
        guard diskTotalBytes > 0 else { return 0 }
        let used = Double(diskTotalBytes - diskFreeBytes)
        return max(0, min(1, used / Double(diskTotalBytes)))
    }

    public func toggleSelection(for itemId: UUID, in category: JunkCategory) {
        guard var items = itemsByCategory[category] else { return }
        if let idx = items.firstIndex(where: { $0.id == itemId }) {
            items[idx].isSelected.toggle()
            itemsByCategory[category] = items
            recalculateCleanableBytes()
        }
    }

    public func selectAll(in category: JunkCategory, selected: Bool) {
        guard var items = itemsByCategory[category] else { return }
        for i in 0..<items.count {
            if selected && items[i].assessment.level == .vital {
                items[i].isSelected = false
            } else {
                items[i].isSelected = selected
            }
        }
        itemsByCategory[category] = items
        recalculateCleanableBytes()
    }

    public func selectSafeOnly(in category: JunkCategory) {
        guard var items = itemsByCategory[category] else { return }
        for i in 0..<items.count {
            items[i].isSelected = (items[i].assessment.level == .safeToDelete)
        }
        itemsByCategory[category] = items
        recalculateCleanableBytes()
    }

    public func recalculateCleanableBytes() {
        var total: Int64 = 0
        for (_, items) in itemsByCategory {
            for item in items where item.isSelected {
                total += item.size
            }
        }
        self.totalCleanableBytes = total
    }

    public func getSelectedCountAndBytes(for category: JunkCategory? = nil) -> (count: Int, bytes: Int64) {
        var count = 0
        var bytes: Int64 = 0

        if let category {
            if let items = itemsByCategory[category] {
                for item in items where item.isSelected {
                    count += 1
                    bytes += item.size
                }
            }
        } else {
            for (_, items) in itemsByCategory {
                for item in items where item.isSelected {
                    count += 1
                    bytes += item.size
                }
            }
        }
        return (count, bytes)
    }

    public func cleanSelected(in category: JunkCategory? = nil) -> (succeeded: Int, failed: Int, bytesFreed: Int64) {
        var itemsToTrash: [FileItem] = []

        if let category {
            if let items = itemsByCategory[category] {
                itemsToTrash = items.filter { $0.isSelected && $0.assessment.level != .vital }
            }
        } else {
            for (_, items) in itemsByCategory {
                itemsToTrash.append(contentsOf: items.filter { $0.isSelected && $0.assessment.level != .vital })
            }
        }

        let result = SafetyTrashService.shared.trashBatch(items: itemsToTrash)
        let trashedIds = Set(itemsToTrash.map { $0.id })

        for cat in itemsByCategory.keys {
            itemsByCategory[cat]?.removeAll { trashedIds.contains($0.id) }
        }

        recalculateCleanableBytes()
        refreshDiskSpace()
        return result
    }

    // MARK: - Non-Blocking Paced & Turbo Scan
    public func scanQuickCleanDashboard() async {
        self.isScanning = true
        self.scanProgressMessage = "Initializing scanner..."
        self.itemsByCategory = [:]
        self.totalCleanableBytes = 0

        let currentPacing = self.pacingMode
        let home = FileManager.default.homeDirectoryForCurrentUser

        // Run scanner on detached Utility QoS thread so UI never stutters
        let found = await Task.detached(priority: .utility) { () -> [JunkCategory: [FileItem]] in
            var foundItems: [JunkCategory: [FileItem]] = [:]

            // 1. Xcode DerivedData
            let xcodeDerivedData = home.appendingPathComponent("Library/Developer/Xcode/DerivedData")
            if FileManager.default.fileExists(atPath: xcodeDerivedData.path) {
                await MainActor.run {
                    FileScannerService.shared.scanProgressMessage = "Scanning Xcode DerivedData..."
                }
                if let items = try? FileManager.default.contentsOfDirectory(at: xcodeDerivedData, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]) {
                    for itemURL in items {
                        let size = await Self.calculateSizePaced(at: itemURL, pacing: currentPacing)
                        if size > 1_000_000 { // > 1 MB
                            let modDate = (try? itemURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                            let assessment = VitalityEngine.shared.assess(url: itemURL, size: size, isDirectory: true)
                            let item = FileItem(url: itemURL, name: "Xcode: \(itemURL.lastPathComponent)", size: size, isDirectory: true, modificationDate: modDate, category: .devArtifacts, assessment: assessment, isSelected: true)
                            foundItems[.devArtifacts, default: []].append(item)
                        }

                        if currentPacing == .pacedBurst {
                            await Task.yield()
                            try? await Task.sleep(nanoseconds: 8_000_000) // 8ms cooldown burst
                        }
                    }
                }
            }

            // 2. User Caches (~/Library/Caches)
            let userCaches = home.appendingPathComponent("Library/Caches")
            if FileManager.default.fileExists(atPath: userCaches.path) {
                await MainActor.run {
                    FileScannerService.shared.scanProgressMessage = "Scanning ~/Library/Caches..."
                }
                if let cacheFolders = try? FileManager.default.contentsOfDirectory(at: userCaches, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]) {
                    for cacheURL in cacheFolders {
                        let size = await Self.calculateSizePaced(at: cacheURL, pacing: currentPacing)
                        if size > 5_000_000 { // > 5 MB
                            let modDate = (try? cacheURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                            let assessment = VitalityEngine.shared.assess(url: cacheURL, size: size, isDirectory: true)
                            let item = FileItem(url: cacheURL, name: cacheURL.lastPathComponent, size: size, isDirectory: true, modificationDate: modDate, category: .systemCache, assessment: assessment, isSelected: true)
                            foundItems[.systemCache, default: []].append(item)
                        }

                        if currentPacing == .pacedBurst {
                            await Task.yield()
                            try? await Task.sleep(nanoseconds: 6_000_000) // 6ms cooldown burst
                        }
                    }
                }
            }

            // 3. User Logs (~/Library/Logs)
            let userLogs = home.appendingPathComponent("Library/Logs")
            if FileManager.default.fileExists(atPath: userLogs.path) {
                await MainActor.run {
                    FileScannerService.shared.scanProgressMessage = "Scanning Diagnostic Logs..."
                }
                if let logFolders = try? FileManager.default.contentsOfDirectory(at: userLogs, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]) {
                    for logURL in logFolders {
                        let size = await Self.calculateSizePaced(at: logURL, pacing: currentPacing)
                        if size > 1_000_000 { // > 1 MB
                            let modDate = (try? logURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                            let assessment = VitalityEngine.shared.assess(url: logURL, size: size, isDirectory: true)
                            let item = FileItem(url: logURL, name: "Log: \(logURL.lastPathComponent)", size: size, isDirectory: true, modificationDate: modDate, category: .systemCache, assessment: assessment, isSelected: true)
                            foundItems[.systemCache, default: []].append(item)
                        }

                        if currentPacing == .pacedBurst {
                            await Task.yield()
                            try? await Task.sleep(nanoseconds: 5_000_000)
                        }
                    }
                }
            }

            // 4. Developer Directories for node_modules, target, .venv, .next
            let devScanRoots = [
                home.appendingPathComponent("Development"),
                home.appendingPathComponent("Projects"),
                home.appendingPathComponent("Developer"),
                home.appendingPathComponent("Code"),
                home.appendingPathComponent("workspace"),
                home.appendingPathComponent(".gemini/antigravity/scratch"),
                home.appendingPathComponent("Desktop"),
                home.appendingPathComponent("Documents")
            ]

            for root in devScanRoots {
                guard FileManager.default.fileExists(atPath: root.path) else { continue }
                await MainActor.run {
                    FileScannerService.shared.scanProgressMessage = "Searching developer caches in \(root.lastPathComponent)..."
                }
                await Self.scanDevCachesRecursivelyPaced(at: root, maxDepth: 4, depth: 0, pacing: currentPacing, results: &foundItems)
            }

            // 5. Old Large Downloads
            let downloads = home.appendingPathComponent("Downloads")
            if FileManager.default.fileExists(atPath: downloads.path) {
                await MainActor.run {
                    FileScannerService.shared.scanProgressMessage = "Scanning Downloads folder..."
                }
                if let dlItems = try? FileManager.default.contentsOfDirectory(at: downloads, includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey, .contentModificationDateKey, .isDirectoryKey]) {
                    for dlURL in dlItems {
                        let ext = dlURL.pathExtension.lowercased()
                        let size = await Self.calculateSizePaced(at: dlURL, pacing: currentPacing)
                        if ext == "dmg" || ext == "pkg" || ext == "zip" || ext == "iso" || size > 100_000_000 {
                            let values = try? dlURL.resourceValues(forKeys: [.contentAccessDateKey, .contentModificationDateKey, .isDirectoryKey])
                            let accessDate = values?.contentAccessDate ?? values?.contentModificationDate
                            let isDir = values?.isDirectory ?? false
                            let assessment = VitalityEngine.shared.assess(url: dlURL, size: size, isDirectory: isDir)
                            let item = FileItem(url: dlURL, name: dlURL.lastPathComponent, size: size, isDirectory: isDir, lastAccessDate: accessDate, category: .largeUnused, assessment: assessment, isSelected: assessment.level == .safeToDelete)
                            foundItems[.largeUnused, default: []].append(item)
                        }

                        if currentPacing == .pacedBurst {
                            await Task.yield()
                            try? await Task.sleep(nanoseconds: 4_000_000)
                        }
                    }
                }
            }

            // 6. Orphaned Application Support Residue
            let appSupport = home.appendingPathComponent("Library/Application Support")
            if FileManager.default.fileExists(atPath: appSupport.path) {
                await MainActor.run {
                    FileScannerService.shared.scanProgressMessage = "Checking for uninstalled app residue..."
                }
                if let folders = try? FileManager.default.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: [.isDirectoryKey]) {
                    for folder in folders {
                        let name = folder.lastPathComponent
                        if name.lowercased().contains("apple") || name.hasPrefix(".") || name == "Dock" || name == "Finder" {
                            continue
                        }
                        let appPath1 = "/Applications/\(name).app"
                        let appPath2 = "/System/Applications/\(name).app"
                        let installed = FileManager.default.fileExists(atPath: appPath1) || FileManager.default.fileExists(atPath: appPath2)
                        if !installed {
                            let size = await Self.calculateSizePaced(at: folder, pacing: currentPacing)
                            if size > 500_000 { // > 500 KB
                                let assessment = VitalityEngine.shared.assess(url: folder, size: size, isDirectory: true)
                                let item = FileItem(url: folder, name: "Orphan: \(name)", size: size, isDirectory: true, category: .appResidue, assessment: assessment, isSelected: true)
                                foundItems[.appResidue, default: []].append(item)
                            }
                        }

                        if currentPacing == .pacedBurst {
                            await Task.yield()
                            try? await Task.sleep(nanoseconds: 5_000_000)
                        }
                    }
                }
            }

            // Sort items inside each category by size descending
            for cat in foundItems.keys {
                foundItems[cat]?.sort { $0.size > $1.size }
            }

            return foundItems
        }.value

        self.itemsByCategory = found
        recalculateCleanableBytes()
        self.isScanning = false
        self.scanProgressMessage = "Scan complete. Found \(ByteCountFormatter.string(fromByteCount: totalCleanableBytes, countStyle: .file)) cleanable."
        self.refreshDiskSpace()
    }

    private static func scanDevCachesRecursivelyPaced(
        at url: URL,
        maxDepth: Int,
        depth: Int,
        pacing: ScanPacingMode,
        results: inout [JunkCategory: [FileItem]]
    ) async {
        guard depth <= maxDepth else { return }
        guard let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey]) else { return }

        for item in contents {
            let name = item.lastPathComponent
            if name == "node_modules" || name == "target" || name == ".venv" || name == "__pycache__" || name == ".next" {
                let size = await calculateSizePaced(at: item, pacing: pacing)
                let parentName = url.lastPathComponent
                let displayName = "\(parentName)/\(name)"
                let modDate = (try? item.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                let assessment = VitalityEngine.shared.assess(url: item, size: size, isDirectory: true)
                let fileItem = FileItem(url: item, name: displayName, size: size, isDirectory: true, modificationDate: modDate, category: .devArtifacts, assessment: assessment, isSelected: true)
                results[.devArtifacts, default: []].append(fileItem)

                if pacing == .pacedBurst {
                    await Task.yield()
                    try? await Task.sleep(nanoseconds: 8_000_000) // 8ms rest
                }
            } else if !name.hasPrefix(".") && name != "Library" && name != "node_modules" && name != "target" {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                    await scanDevCachesRecursivelyPaced(at: item, maxDepth: maxDepth, depth: depth + 1, pacing: pacing, results: &results)
                }
            }
        }
    }

    public static func calculateSizePaced(at url: URL, pacing: ScanPacingMode) async -> Int64 {
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
            return 0
        }

        if !isDir.boolValue {
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            return (attrs?[.size] as? Int64) ?? 0
        }

        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]) else {
            return 0
        }

        var total: Int64 = 0
        var count = 0

        while let fileURL = enumerator.nextObject() as? URL {
            let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            if values?.isDirectory != true {
                total += Int64(values?.fileSize ?? 0)
            }

            count += 1
            // In Paced mode, yield and micro-sleep every 150 files to keep average CPU at ~10%
            if pacing == .pacedBurst && count % 150 == 0 {
                await Task.yield()
                try? await Task.sleep(nanoseconds: 4_000_000) // 4ms micro-cooldown
            }
        }
        return total
    }

    public func calculateSize(at url: URL) -> Int64 {
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
            return 0
        }

        if !isDir.boolValue {
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            return (attrs?[.size] as? Int64) ?? 0
        }

        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            if values?.isDirectory != true {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        return total
    }
}
