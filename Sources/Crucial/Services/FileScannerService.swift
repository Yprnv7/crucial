import Foundation
import CryptoKit

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
            // Never pre-select vital items
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

    public func scanQuickCleanDashboard() async {
        self.isScanning = true
        self.scanProgressMessage = "Discovering cleanable files..."
        self.itemsByCategory = [:]
        self.totalCleanableBytes = 0

        let home = FileManager.default.homeDirectoryForCurrentUser
        var foundItems: [JunkCategory: [FileItem]] = [:]

        // 1. Xcode DerivedData
        let xcodeDerivedData = home.appendingPathComponent("Library/Developer/Xcode/DerivedData")
        if FileManager.default.fileExists(atPath: xcodeDerivedData.path) {
            self.scanProgressMessage = "Scanning Xcode DerivedData..."
            if let items = try? FileManager.default.contentsOfDirectory(at: xcodeDerivedData, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]) {
                for itemURL in items {
                    let size = calculateSize(at: itemURL)
                    if size > 1_000_000 { // > 1 MB
                        let modDate = (try? itemURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                        let assessment = VitalityEngine.shared.assess(url: itemURL, size: size, isDirectory: true)
                        let item = FileItem(url: itemURL, name: "Xcode: \(itemURL.lastPathComponent)", size: size, isDirectory: true, modificationDate: modDate, category: .devArtifacts, assessment: assessment, isSelected: true)
                        foundItems[.devArtifacts, default: []].append(item)
                    }
                }
            }
        }

        // 2. User Caches (~/Library/Caches)
        let userCaches = home.appendingPathComponent("Library/Caches")
        if FileManager.default.fileExists(atPath: userCaches.path) {
            self.scanProgressMessage = "Scanning ~/Library/Caches..."
            if let cacheFolders = try? FileManager.default.contentsOfDirectory(at: userCaches, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]) {
                for cacheURL in cacheFolders {
                    let size = calculateSize(at: cacheURL)
                    if size > 5_000_000 { // > 5 MB
                        let modDate = (try? cacheURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                        let assessment = VitalityEngine.shared.assess(url: cacheURL, size: size, isDirectory: true)
                        let item = FileItem(url: cacheURL, name: cacheURL.lastPathComponent, size: size, isDirectory: true, modificationDate: modDate, category: .systemCache, assessment: assessment, isSelected: true)
                        foundItems[.systemCache, default: []].append(item)
                    }
                }
            }
        }

        // 3. User Logs (~/Library/Logs)
        let userLogs = home.appendingPathComponent("Library/Logs")
        if FileManager.default.fileExists(atPath: userLogs.path) {
            self.scanProgressMessage = "Scanning Diagnostic Logs..."
            if let logFolders = try? FileManager.default.contentsOfDirectory(at: userLogs, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]) {
                for logURL in logFolders {
                    let size = calculateSize(at: logURL)
                    if size > 1_000_000 { // > 1 MB
                        let modDate = (try? logURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                        let assessment = VitalityEngine.shared.assess(url: logURL, size: size, isDirectory: true)
                        let item = FileItem(url: logURL, name: "Log: \(logURL.lastPathComponent)", size: size, isDirectory: true, modificationDate: modDate, category: .systemCache, assessment: assessment, isSelected: true)
                        foundItems[.systemCache, default: []].append(item)
                    }
                }
            }
        }

        // 4. Common Developer Directories for node_modules, target, .venv, .next
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
            self.scanProgressMessage = "Searching developer caches in \(root.lastPathComponent)..."
            scanDevCachesRecursively(at: root, maxDepth: 4, depth: 0, results: &foundItems)
        }

        // 5. Old Large Downloads (> 100MB, or DMGs/PKGs/ISOs)
        let downloads = home.appendingPathComponent("Downloads")
        if FileManager.default.fileExists(atPath: downloads.path) {
            self.scanProgressMessage = "Scanning Downloads folder..."
            if let dlItems = try? FileManager.default.contentsOfDirectory(at: downloads, includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey, .contentModificationDateKey, .isDirectoryKey]) {
                for dlURL in dlItems {
                    let ext = dlURL.pathExtension.lowercased()
                    let size = calculateSize(at: dlURL)
                    if ext == "dmg" || ext == "pkg" || ext == "zip" || ext == "iso" || size > 100_000_000 {
                        let values = try? dlURL.resourceValues(forKeys: [.contentAccessDateKey, .contentModificationDateKey, .isDirectoryKey])
                        let accessDate = values?.contentAccessDate ?? values?.contentModificationDate
                        let isDir = values?.isDirectory ?? false
                        let assessment = VitalityEngine.shared.assess(url: dlURL, size: size, isDirectory: isDir)
                        let item = FileItem(url: dlURL, name: dlURL.lastPathComponent, size: size, isDirectory: isDir, lastAccessDate: accessDate, category: .largeUnused, assessment: assessment, isSelected: assessment.level == .safeToDelete)
                        foundItems[.largeUnused, default: []].append(item)
                    }
                }
            }
        }

        // 6. Orphaned Application Support Residue
        let appSupport = home.appendingPathComponent("Library/Application Support")
        if FileManager.default.fileExists(atPath: appSupport.path) {
            self.scanProgressMessage = "Checking for uninstalled app residue..."
            if let folders = try? FileManager.default.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: [.isDirectoryKey]) {
                for folder in folders {
                    let name = folder.lastPathComponent
                    // Exclude Apple system folders
                    if name.lowercased().contains("apple") || name.hasPrefix(".") || name == "Dock" || name == "Finder" {
                        continue
                    }
                    let appPath1 = "/Applications/\(name).app"
                    let appPath2 = "/System/Applications/\(name).app"
                    let installed = FileManager.default.fileExists(atPath: appPath1) || FileManager.default.fileExists(atPath: appPath2)
                    if !installed {
                        let size = calculateSize(at: folder)
                        if size > 500_000 { // > 500 KB
                            let assessment = VitalityEngine.shared.assess(url: folder, size: size, isDirectory: true)
                            let item = FileItem(url: folder, name: "Orphan: \(name)", size: size, isDirectory: true, category: .appResidue, assessment: assessment, isSelected: true)
                            foundItems[.appResidue, default: []].append(item)
                        }
                    }
                }
            }
        }

        // Sort items inside each category by size descending
        for cat in foundItems.keys {
            foundItems[cat]?.sort { $0.size > $1.size }
        }

        self.itemsByCategory = foundItems
        recalculateCleanableBytes()
        self.isScanning = false
        self.scanProgressMessage = "Scan complete. Found \(ByteCountFormatter.string(fromByteCount: totalCleanableBytes, countStyle: .file)) cleanable."
        self.refreshDiskSpace()
    }

    private func scanDevCachesRecursively(at url: URL, maxDepth: Int, depth: Int, results: inout [JunkCategory: [FileItem]]) {
        guard depth <= maxDepth else { return }
        guard let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey]) else { return }

        for item in contents {
            let name = item.lastPathComponent
            if name == "node_modules" || name == "target" || name == ".venv" || name == "__pycache__" || name == ".next" {
                let size = calculateSize(at: item)
                let parentName = url.lastPathComponent
                let displayName = "\(parentName)/\(name)"
                let modDate = (try? item.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                let assessment = VitalityEngine.shared.assess(url: item, size: size, isDirectory: true)
                let fileItem = FileItem(url: item, name: displayName, size: size, isDirectory: true, modificationDate: modDate, category: .devArtifacts, assessment: assessment, isSelected: true)
                results[.devArtifacts, default: []].append(fileItem)
            } else if !name.hasPrefix(".") && name != "Library" && name != "node_modules" && name != "target" {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                    scanDevCachesRecursively(at: item, maxDepth: maxDepth, depth: depth + 1, results: &results)
                }
            }
        }
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
