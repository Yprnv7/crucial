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
            if let items = try? FileManager.default.contentsOfDirectory(at: xcodeDerivedData, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]) {
                for itemURL in items {
                    let size = calculateSize(at: itemURL)
                    if size > 1_000_000 { // > 1 MB
                        let assessment = VitalityEngine.shared.assess(url: itemURL, size: size, isDirectory: true)
                        let item = FileItem(url: itemURL, size: size, isDirectory: true, category: .devArtifacts, assessment: assessment, isSelected: true)
                        foundItems[.devArtifacts, default: []].append(item)
                    }
                }
            }
        }

        // 2. User Caches (~/Library/Caches)
        let userCaches = home.appendingPathComponent("Library/Caches")
        if FileManager.default.fileExists(atPath: userCaches.path) {
            self.scanProgressMessage = "Scanning ~/Library/Caches..."
            if let cacheFolders = try? FileManager.default.contentsOfDirectory(at: userCaches, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]) {
                for cacheURL in cacheFolders {
                    let size = calculateSize(at: cacheURL)
                    if size > 10_000_000 { // > 10 MB
                        let assessment = VitalityEngine.shared.assess(url: cacheURL, size: size, isDirectory: true)
                        let item = FileItem(url: cacheURL, size: size, isDirectory: true, category: .systemCache, assessment: assessment, isSelected: true)
                        foundItems[.systemCache, default: []].append(item)
                    }
                }
            }
        }

        // 3. User Logs (~/Library/Logs)
        let userLogs = home.appendingPathComponent("Library/Logs")
        if FileManager.default.fileExists(atPath: userLogs.path) {
            self.scanProgressMessage = "Scanning Diagnostic Logs..."
            if let logFolders = try? FileManager.default.contentsOfDirectory(at: userLogs, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]) {
                for logURL in logFolders {
                    let size = calculateSize(at: logURL)
                    if size > 5_000_000 { // > 5 MB
                        let assessment = VitalityEngine.shared.assess(url: logURL, size: size, isDirectory: true)
                        let item = FileItem(url: logURL, size: size, isDirectory: true, category: .systemCache, assessment: assessment, isSelected: true)
                        foundItems[.systemCache, default: []].append(item)
                    }
                }
            }
        }

        // 4. Common Developer Directories for node_modules, target, .venv
        let devScanRoots = [
            home.appendingPathComponent("Development"),
            home.appendingPathComponent("Projects"),
            home.appendingPathComponent("Developer"),
            home.appendingPathComponent("Code"),
            home.appendingPathComponent("workspace"),
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Documents")
        ]

        for root in devScanRoots {
            guard FileManager.default.fileExists(atPath: root.path) else { continue }
            self.scanProgressMessage = "Searching developer build caches in \(root.lastPathComponent)..."
            scanDevCachesRecursively(at: root, maxDepth: 4, depth: 0, results: &foundItems)
        }

        // 5. Old Large Downloads (> 200MB, 30+ days idle)
        let downloads = home.appendingPathComponent("Downloads")
        if FileManager.default.fileExists(atPath: downloads.path) {
            self.scanProgressMessage = "Scanning old downloads..."
            if let dlItems = try? FileManager.default.contentsOfDirectory(at: downloads, includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey, .contentModificationDateKey]) {
                for dlURL in dlItems {
                    let ext = dlURL.pathExtension.lowercased()
                    let size = calculateSize(at: dlURL)
                    if (ext == "dmg" || ext == "pkg" || ext == "zip" || ext == "iso" || size > 200_000_000) {
                        let values = try? dlURL.resourceValues(forKeys: [.contentAccessDateKey, .contentModificationDateKey])
                        let accessDate = values?.contentAccessDate ?? values?.contentModificationDate
                        let assessment = VitalityEngine.shared.assess(url: dlURL, size: size, isDirectory: false)
                        let item = FileItem(url: dlURL, size: size, isDirectory: false, lastAccessDate: accessDate, category: .largeUnused, assessment: assessment, isSelected: assessment.level == .safeToDelete)
                        foundItems[.largeUnused, default: []].append(item)
                    }
                }
            }
        }

        // Calculate total cleanable bytes
        var total: Int64 = 0
        for (_, items) in foundItems {
            for item in items where item.assessment.level == .safeToDelete {
                total += item.size
            }
        }

        self.itemsByCategory = foundItems
        self.totalCleanableBytes = total
        self.isScanning = false
        self.scanProgressMessage = "Scan complete. Found \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file)) cleanable."
        self.refreshDiskSpace()
    }

    private func scanDevCachesRecursively(at url: URL, maxDepth: Int, depth: Int, results: inout [JunkCategory: [FileItem]]) {
        guard depth <= maxDepth else { return }
        guard let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey]) else { return }

        for item in contents {
            let name = item.lastPathComponent
            if name == "node_modules" || name == "target" || name == ".venv" || name == "__pycache__" {
                let size = calculateSize(at: item)
                let assessment = VitalityEngine.shared.assess(url: item, size: size, isDirectory: true)
                let fileItem = FileItem(url: item, size: size, isDirectory: true, category: .devArtifacts, assessment: assessment, isSelected: true)
                results[.devArtifacts, default: []].append(fileItem)
            } else if !name.hasPrefix(".") && name != "Library" {
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
