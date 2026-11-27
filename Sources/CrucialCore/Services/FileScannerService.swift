import Foundation
import Observation

@Observable
@MainActor
public final class FileScannerService {
    public static let shared = FileScannerService()

    public var isScanning: Bool = false
    public var scanProgressMessage: String = ""
    public var itemsByCategory: [JunkCategory: [FileItem]] = [:]
    public var totalCleanableBytes: Int64 = 0
    public var hardwareInfo: DiskHardwareInfo = DiskHardwareInfo()

    private var activeScanTask: Task<Void, Never>?

    private init() {
        refreshDiskSpace()
    }

    public var diskTotalBytes: Int64 { hardwareInfo.totalBytes }
    public var diskFreeBytes: Int64 { hardwareInfo.freeBytes }

    public var usedDiskPercent: Double {
        guard hardwareInfo.totalBytes > 0 else { return 0 }
        let used = Double(hardwareInfo.usedBytes)
        return max(0, min(1, used / Double(hardwareInfo.totalBytes)))
    }

    public func refreshDiskSpace() {
        let home = URL.homeDirectory
        if let values = try? home.resourceValues(forKeys: [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]) {
            let name = values.volumeName ?? "Macintosh HD"
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let free = values.volumeAvailableCapacityForImportantUsage ?? 0
            hardwareInfo = DiskHardwareInfo(
                volumeName: name,
                fileSystem: hardwareInfo.fileSystem,
                smartStatus: hardwareInfo.smartStatus,
                isSolidState: hardwareInfo.isSolidState,
                totalBytes: total,
                freeBytes: free,
                applicationsBytes: hardwareInfo.applicationsBytes,
                userMediaBytes: hardwareInfo.userMediaBytes,
                developerCachesBytes: hardwareInfo.developerCachesBytes
            )
        }
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
        for i in items.indices {
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
        for i in items.indices {
            items[i].isSelected = (items[i].assessment.level == .safeToDelete)
        }
        itemsByCategory[category] = items
        recalculateCleanableBytes()
    }

    public func recalculateCleanableBytes() {
        var total: Int64 = 0
        for items in itemsByCategory.values {
            for item in items where item.isSelected {
                total += item.size
            }
        }
        totalCleanableBytes = total
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
            for items in itemsByCategory.values {
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
            for items in itemsByCategory.values {
                itemsToTrash.append(contentsOf: items.filter { $0.isSelected && $0.assessment.level != .vital })
            }
        }

        let result = SafetyTrashService.shared.trashBatch(items: itemsToTrash)
        let trashedIds = Set(itemsToTrash.map(\.id))

        for cat in itemsByCategory.keys {
            itemsByCategory[cat]?.removeAll { trashedIds.contains($0.id) }
        }

        recalculateCleanableBytes()
        refreshDiskSpace()
        return result
    }

    public func scanQuickCleanDashboard() async {
        activeScanTask?.cancel()
        isScanning = true
        scanProgressMessage = "Scanning storage categories..."
        itemsByCategory = [:]
        totalCleanableBytes = 0

        let home = URL.homeDirectory
        let scanTask = Task.detached(priority: .utility) { () -> ([JunkCategory: [FileItem]], DiskHardwareInfo) in
            let items = Self.crawlCleanableCategories(home: home)
            let hw = await Self.measureHardwareAndVolumeInfo(home: home, scannedItems: items)
            return (items, hw)
        }
        activeScanTask = Task { _ = await scanTask.value }

        let (found, measuredHW) = await scanTask.value
        guard !Task.isCancelled else { return }

        itemsByCategory = found
        hardwareInfo = measuredHW
        recalculateCleanableBytes()
        isScanning = false
        let formatted = ByteCountFormatter.string(fromByteCount: totalCleanableBytes, countStyle: .file)
        scanProgressMessage = "Scan complete: \(formatted) cleanable."
    }

    private nonisolated static func measureHardwareAndVolumeInfo(
        home: URL,
        scannedItems: [JunkCategory: [FileItem]]
    ) async -> DiskHardwareInfo {
        let values = try? home.resourceValues(forKeys: [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ])

        let totalBytes = Int64(values?.volumeTotalCapacity ?? 0)
        let freeBytes = values?.volumeAvailableCapacityForImportantUsage ?? 0
        var volumeName = values?.volumeName ?? "Macintosh HD"
        var fileSystem = "APFS"
        var smartStatus = "Verified"
        var isSSD = true

        // Query real hardware / container vitals from diskutil
        let plistData = await SubprocessRunner.runData(
            executable: "/usr/sbin/diskutil",
            arguments: ["info", "-plist", "/"]
        )
        if !plistData.isEmpty,
           let dict = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
            if let vName = dict["VolumeName"] as? String, !vName.isEmpty {
                volumeName = vName
            }
            if let fs = dict["FilesystemName"] as? String ?? dict["FilesystemType"] as? String {
                fileSystem = fs
            }
            if let smart = dict["SMARTStatus"] as? String, !smart.isEmpty {
                smartStatus = smart
            }
            if let ssd = dict["SolidState"] as? Bool {
                isSSD = ssd
            }
        }

        let appsBytes = FileSystemSizer.size(at: URL(fileURLWithPath: "/Applications"))
        let downloadsBytes = FileSystemSizer.size(at: home.appending(path: "Downloads"))
        let moviesBytes = FileSystemSizer.size(at: home.appending(path: "Movies"))
        let musicBytes = FileSystemSizer.size(at: home.appending(path: "Music"))
        let devBytes = (scannedItems[.devArtifacts] ?? []).reduce(0) { $0 + $1.size }

        return DiskHardwareInfo(
            volumeName: volumeName,
            fileSystem: fileSystem,
            smartStatus: smartStatus,
            isSolidState: isSSD,
            totalBytes: totalBytes,
            freeBytes: freeBytes,
            applicationsBytes: appsBytes,
            userMediaBytes: downloadsBytes + moviesBytes + musicBytes,
            developerCachesBytes: devBytes
        )
    }

    private nonisolated static func crawlCleanableCategories(home: URL) -> [JunkCategory: [FileItem]] {
        var foundItems: [JunkCategory: [FileItem]] = [:]

        // 1. Xcode DerivedData
        let xcodeDerivedData = home.appending(path: "Library/Developer/Xcode/DerivedData")
        if FileManager.default.fileExists(atPath: xcodeDerivedData.path),
           let items = try? FileManager.default.contentsOfDirectory(
               at: xcodeDerivedData,
               includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey, .contentModificationDateKey]
           ) {
            for itemURL in items {
                if Task.isCancelled { return foundItems }
                let size = FileSystemSizer.size(at: itemURL)
                if size > 1_000_000 {
                    let modDate = (try? itemURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                    let assessment = VitalityEngine.shared.assess(url: itemURL, size: size, isDirectory: true)
                    let item = FileItem(
                        url: itemURL,
                        name: "Xcode: \(itemURL.lastPathComponent)",
                        size: size,
                        isDirectory: true,
                        modificationDate: modDate,
                        category: .devArtifacts,
                        assessment: assessment,
                        isSelected: true
                    )
                    foundItems[.devArtifacts, default: []].append(item)
                }
            }
        }

        // 2. User Caches (~/Library/Caches)
        let userCaches = home.appending(path: "Library/Caches")
        if FileManager.default.fileExists(atPath: userCaches.path),
           let cacheFolders = try? FileManager.default.contentsOfDirectory(
               at: userCaches,
               includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey, .contentModificationDateKey]
           ) {
            for cacheURL in cacheFolders {
                if Task.isCancelled { return foundItems }
                let size = FileSystemSizer.size(at: cacheURL)
                if size > 5_000_000 {
                    let modDate = (try? cacheURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                    let assessment = VitalityEngine.shared.assess(url: cacheURL, size: size, isDirectory: true)
                    let item = FileItem(
                        url: cacheURL,
                        name: cacheURL.lastPathComponent,
                        size: size,
                        isDirectory: true,
                        modificationDate: modDate,
                        category: .systemCache,
                        assessment: assessment,
                        isSelected: true
                    )
                    foundItems[.systemCache, default: []].append(item)
                }
            }
        }

        // 3. Diagnostic Logs (~/Library/Logs)
        let userLogs = home.appending(path: "Library/Logs")
        if FileManager.default.fileExists(atPath: userLogs.path),
           let logFolders = try? FileManager.default.contentsOfDirectory(
               at: userLogs,
               includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey, .contentModificationDateKey]
           ) {
            for logURL in logFolders {
                if Task.isCancelled { return foundItems }
                let size = FileSystemSizer.size(at: logURL)
                if size > 1_000_000 {
                    let modDate = (try? logURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                    let assessment = VitalityEngine.shared.assess(url: logURL, size: size, isDirectory: true)
                    let item = FileItem(
                        url: logURL,
                        name: "Log: \(logURL.lastPathComponent)",
                        size: size,
                        isDirectory: true,
                        modificationDate: modDate,
                        category: .systemCache,
                        assessment: assessment,
                        isSelected: true
                    )
                    foundItems[.systemCache, default: []].append(item)
                }
            }
        }

        // 4. Developer Build Artifacts across standard workspace directories
        let devRoots = [
            home.appending(path: "Developer"),
            home.appending(path: "Development"),
            home.appending(path: "Projects"),
            home.appending(path: "Code"),
            home.appending(path: "workspace"),
            home.appending(path: "Desktop"),
            home.appending(path: "Documents")
        ]
        for root in devRoots where FileManager.default.fileExists(atPath: root.path) {
            if Task.isCancelled { return foundItems }
            scanDevCachesRecursively(at: root, maxDepth: 4, depth: 0, results: &foundItems)
        }

        // 5. Large Downloads
        let downloads = home.appending(path: "Downloads")
        if FileManager.default.fileExists(atPath: downloads.path),
           let dlItems = try? FileManager.default.contentsOfDirectory(
               at: downloads,
               includingPropertiesForKeys: [.isSymbolicLinkKey, .contentAccessDateKey, .contentModificationDateKey, .isDirectoryKey]
           ) {
            for dlURL in dlItems {
                if Task.isCancelled { return foundItems }
                let values = try? dlURL.resourceValues(forKeys: [.isSymbolicLinkKey, .contentAccessDateKey, .contentModificationDateKey, .isDirectoryKey])
                if values?.isSymbolicLink == true { continue }

                let ext = dlURL.pathExtension.lowercased()
                let size = FileSystemSizer.size(at: dlURL)
                if ["dmg", "pkg", "zip", "iso"].contains(ext) || size > 100_000_000 {
                    let accessDate = values?.contentAccessDate ?? values?.contentModificationDate
                    let isDir = values?.isDirectory ?? false
                    let assessment = VitalityEngine.shared.assess(url: dlURL, size: size, isDirectory: isDir)
                    let item = FileItem(
                        url: dlURL,
                        name: dlURL.lastPathComponent,
                        size: size,
                        isDirectory: isDir,
                        lastAccessDate: accessDate,
                        category: .largeUnused,
                        assessment: assessment,
                        isSelected: assessment.level == .safeToDelete
                    )
                    foundItems[.largeUnused, default: []].append(item)
                }
            }
        }

        // 6. Orphaned Application Support
        let appSupport = home.appending(path: "Library/Application Support")
        if FileManager.default.fileExists(atPath: appSupport.path),
           let folders = try? FileManager.default.contentsOfDirectory(
               at: appSupport,
               includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey]
           ) {
            for folder in folders {
                if Task.isCancelled { return foundItems }
                let name = folder.lastPathComponent
                if name.lowercased().contains("apple") || name.hasPrefix(".") || name == "Dock" || name == "Finder" {
                    continue
                }
                let appPath1 = "/Applications/\(name).app"
                let appPath2 = "/System/Applications/\(name).app"
                let installed = FileManager.default.fileExists(atPath: appPath1) || FileManager.default.fileExists(atPath: appPath2)
                if !installed {
                    let size = FileSystemSizer.size(at: folder)
                    if size > 500_000 {
                        let assessment = VitalityEngine.shared.assess(url: folder, size: size, isDirectory: true)
                        let item = FileItem(
                            url: folder,
                            name: "Orphan: \(name)",
                            size: size,
                            isDirectory: true,
                            category: .appResidue,
                            assessment: assessment,
                            isSelected: true
                        )
                        foundItems[.appResidue, default: []].append(item)
                    }
                }
            }
        }

        for cat in foundItems.keys {
            foundItems[cat]?.sort { $0.size > $1.size }
        }

        return foundItems
    }

    private nonisolated static func scanDevCachesRecursively(
        at url: URL,
        maxDepth: Int,
        depth: Int,
        results: inout [JunkCategory: [FileItem]]
    ) {
        guard depth <= maxDepth, !Task.isCancelled else { return }
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let targetNames: Set<String> = ["node_modules", "target", ".venv", "__pycache__", ".next"]
        for item in contents {
            if Task.isCancelled { return }
            let values = try? item.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey, .contentModificationDateKey])
            if values?.isSymbolicLink == true { continue }

            let name = item.lastPathComponent
            if targetNames.contains(name) {
                let size = FileSystemSizer.size(at: item)
                if size > 500_000 {
                    let displayName = "\(url.lastPathComponent)/\(name)"
                    let assessment = VitalityEngine.shared.assess(url: item, size: size, isDirectory: true)
                    let fileItem = FileItem(
                        url: item,
                        name: displayName,
                        size: size,
                        isDirectory: true,
                        modificationDate: values?.contentModificationDate,
                        category: .devArtifacts,
                        assessment: assessment,
                        isSelected: true
                    )
                    results[.devArtifacts, default: []].append(fileItem)
                }
            } else if values?.isDirectory == true && !name.hasPrefix(".") && name != "Library" {
                scanDevCachesRecursively(at: item, maxDepth: maxDepth, depth: depth + 1, results: &results)
            }
        }
    }
}
