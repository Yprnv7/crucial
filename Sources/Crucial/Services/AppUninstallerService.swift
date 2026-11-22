import Foundation
import AppKit

public struct AppResidueItem: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let path: String
    public let url: URL
    public let name: String
    public let size: Int64
    public let categoryName: String
    public var isChecked: Bool

    public init(
        id: UUID = UUID(),
        path: String,
        url: URL,
        name: String,
        size: Int64,
        categoryName: String,
        isChecked: Bool = true
    ) {
        self.id = id
        self.path = path
        self.url = url
        self.name = name
        self.size = size
        self.categoryName = categoryName
        self.isChecked = isChecked
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

public struct InstalledAppInfo: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let bundleURL: URL
    public let bundleIdentifier: String
    public let version: String
    public let appSize: Int64
    public var residueItems: [AppResidueItem]
    public var isBundleSelected: Bool
    public let isSystemProtected: Bool
    public let protectionReason: String?
    public var isRunning: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        bundleURL: URL,
        bundleIdentifier: String,
        version: String,
        appSize: Int64,
        residueItems: [AppResidueItem],
        isBundleSelected: Bool = true,
        isSystemProtected: Bool = false,
        protectionReason: String? = nil,
        isRunning: Bool = false
    ) {
        self.id = id
        self.name = name
        self.bundleURL = bundleURL
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.appSize = appSize
        self.residueItems = residueItems
        self.isBundleSelected = isBundleSelected
        self.isSystemProtected = isSystemProtected
        self.protectionReason = protectionReason
        self.isRunning = isRunning
    }

    public var checkedResidueCount: Int {
        residueItems.filter { $0.isChecked }.count
    }

    public var checkedResidueBytes: Int64 {
        residueItems.filter { $0.isChecked }.reduce(0) { $0 + $1.size }
    }

    public var reclaimableBytes: Int64 {
        let bundleCost = (isBundleSelected && !isSystemProtected) ? appSize : 0
        return bundleCost + checkedResidueBytes
    }

    public var totalFootprint: Int64 {
        appSize + residueItems.reduce(0) { $0 + $1.size }
    }

    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalFootprint, countStyle: .file)
    }

    public var formattedReclaimableSize: String {
        ByteCountFormatter.string(fromByteCount: reclaimableBytes, countStyle: .file)
    }

    public var icon: NSImage {
        NSWorkspace.shared.icon(forFile: bundleURL.path)
    }
}

public struct UninstallResult: Sendable {
    public let appName: String
    public let succeeded: Bool
    public let bytesFreed: Int64
    public let itemsTrashed: Int
    public let errorMessage: String?
}

@MainActor
public final class AppUninstallerService: ObservableObject {
    public static let shared = AppUninstallerService()

    @Published public var installedApps: [InstalledAppInfo] = []
    @Published public var selectedApp: InstalledAppInfo?
    @Published public var isScanning: Bool = false
    @Published public var progressMessage: String = ""
    @Published public var lastResult: UninstallResult?
    @Published public var isQuittingApp: Bool = false

    private init() {}

    public func scanInstalledApplications() async {
        isScanning = true
        progressMessage = "Scanning applications..."

        let appDirs = [
            URL(fileURLWithPath: "/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        var apps: [InstalledAppInfo] = []

        for dir in appDirs {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents where url.pathExtension == "app" {
                if let info = analyzeAppBundle(url: url) {
                    apps.append(info)
                }
            }
        }

        self.installedApps = apps.sorted {
            if $0.isSystemProtected != $1.isSystemProtected {
                return !$0.isSystemProtected
            }
            return $0.totalFootprint > $1.totalFootprint
        }

        if let current = selectedApp {
            selectedApp = self.installedApps.first { $0.bundleURL == current.bundleURL } ?? self.installedApps.first
        } else {
            selectedApp = self.installedApps.first
        }

        self.isScanning = false
        self.progressMessage = ""
    }

    public func selectApp(_ app: InstalledAppInfo) {
        // Refresh running status whenever an app is selected
        var updated = app
        updated.isRunning = isApplicationRunning(bundleID: app.bundleIdentifier, bundleURL: app.bundleURL)
        selectedApp = updated

        // Also update in the list
        if let idx = installedApps.firstIndex(where: { $0.id == app.id }) {
            installedApps[idx].isRunning = updated.isRunning
        }
    }

    public func inspectCustomApp(url: URL) {
        guard url.pathExtension == "app" else { return }
        if let existing = installedApps.first(where: { $0.bundleURL.path == url.path }) {
            selectApp(existing)
        } else if let newApp = analyzeAppBundle(url: url) {
            installedApps.insert(newApp, at: 0)
            selectApp(newApp)
        }
    }

    public func toggleResidueItem(appID: UUID, residueID: UUID) {
        if let appIndex = installedApps.firstIndex(where: { $0.id == appID }) {
            if let resIndex = installedApps[appIndex].residueItems.firstIndex(where: { $0.id == residueID }) {
                installedApps[appIndex].residueItems[resIndex].isChecked.toggle()
                if selectedApp?.id == appID {
                    selectedApp = installedApps[appIndex]
                }
            }
        } else if selectedApp?.id == appID {
            if let resIndex = selectedApp?.residueItems.firstIndex(where: { $0.id == residueID }) {
                selectedApp?.residueItems[resIndex].isChecked.toggle()
            }
        }
    }

    public func toggleAllResidue(appID: UUID, checked: Bool) {
        if let appIndex = installedApps.firstIndex(where: { $0.id == appID }) {
            for i in 0..<installedApps[appIndex].residueItems.count {
                installedApps[appIndex].residueItems[i].isChecked = checked
            }
            if selectedApp?.id == appID {
                selectedApp = installedApps[appIndex]
            }
        } else if selectedApp?.id == appID {
            for i in 0..<(selectedApp?.residueItems.count ?? 0) {
                selectedApp?.residueItems[i].isChecked = checked
            }
        }
    }

    public func toggleBundleSelection(appID: UUID) {
        if let appIndex = installedApps.firstIndex(where: { $0.id == appID }) {
            installedApps[appIndex].isBundleSelected.toggle()
            if selectedApp?.id == appID {
                selectedApp = installedApps[appIndex]
            }
        } else if selectedApp?.id == appID {
            selectedApp?.isBundleSelected.toggle()
        }
    }

    public func quitApplication(_ app: InstalledAppInfo) async -> Bool {
        isQuittingApp = true
        defer { isQuittingApp = false }

        var runningInstances: [NSRunningApplication] = []
        if !app.bundleIdentifier.isEmpty {
            runningInstances = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier)
        }
        if runningInstances.isEmpty {
            runningInstances = NSWorkspace.shared.runningApplications.filter { $0.bundleURL == app.bundleURL }
        }

        for running in runningInstances {
            running.terminate()
        }

        // Wait up to 2 seconds for clean exit
        for _ in 0..<20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            let stillRunning = isApplicationRunning(bundleID: app.bundleIdentifier, bundleURL: app.bundleURL)
            if !stillRunning {
                updateAppRunningStatus(appID: app.id, isRunning: false)
                return true
            }
        }

        // Force terminate if needed
        for running in runningInstances {
            running.forceTerminate()
        }
        try? await Task.sleep(nanoseconds: 200_000_000)

        let finalRunning = isApplicationRunning(bundleID: app.bundleIdentifier, bundleURL: app.bundleURL)
        updateAppRunningStatus(appID: app.id, isRunning: finalRunning)
        return !finalRunning
    }

    private func updateAppRunningStatus(appID: UUID, isRunning: Bool) {
        if let idx = installedApps.firstIndex(where: { $0.id == appID }) {
            installedApps[idx].isRunning = isRunning
        }
        if selectedApp?.id == appID {
            selectedApp?.isRunning = isRunning
        }
    }

    public func isApplicationRunning(bundleID: String, bundleURL: URL) -> Bool {
        if !bundleID.isEmpty {
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            if !running.isEmpty { return true }
        }
        return NSWorkspace.shared.runningApplications.contains { $0.bundleURL == bundleURL }
    }

    public func analyzeSingleApp(url: URL) -> InstalledAppInfo? {
        guard url.pathExtension == "app" else { return nil }
        return analyzeAppBundle(url: url)
    }

    private func analyzeAppBundle(url: URL) -> InstalledAppInfo? {
        guard let bundle = Bundle(url: url) else { return nil }
        let bundleID = bundle.bundleIdentifier ?? ""
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                   bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ??
                   url.deletingPathExtension().lastPathComponent
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"

        let appSize = calculateDirectorySize(url: url)
        let residue = scanResidue(for: name, bundleID: bundleID)

        // System protection & permission inspection
        var isProtected = false
        var reason: String? = nil

        let resolvedURL = url.resolvingSymlinksInPath()
        let fm = FileManager.default

        if url.path.hasPrefix("/System") || resolvedURL.path.hasPrefix("/System") {
            isProtected = true
            reason = "Protected by macOS System Integrity Protection (SIP)."
        } else if !fm.isWritableFile(atPath: url.path) {
            isProtected = true
            reason = "Owned by root / administrator. Write permissions required."
        } else if bundleID == "com.crucial.cleaner" || url.lastPathComponent == "Crucial.app" {
            isProtected = true
            reason = "Crucial cleaner cannot uninstall itself while running."
        } else if bundleID.hasPrefix("com.apple.") && (url.path.hasPrefix("/Applications/Safari") || url.path.hasPrefix("/Applications/Utilities")) {
            isProtected = true
            reason = "Protected macOS core system application."
        }

        let isRunning = isApplicationRunning(bundleID: bundleID, bundleURL: url)

        return InstalledAppInfo(
            name: name,
            bundleURL: url,
            bundleIdentifier: bundleID,
            version: version,
            appSize: appSize,
            residueItems: residue,
            isBundleSelected: !isProtected,
            isSystemProtected: isProtected,
            protectionReason: reason,
            isRunning: isRunning
        )
    }

    public func scanResidue(for appName: String, bundleID: String) -> [AppResidueItem] {
        var items: [AppResidueItem] = []
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        let searchTargets: [(category: String, base: URL)] = [
            ("Application Support", home.appendingPathComponent("Library/Application Support")),
            ("Caches", home.appendingPathComponent("Library/Caches")),
            ("Preferences", home.appendingPathComponent("Library/Preferences")),
            ("Containers", home.appendingPathComponent("Library/Containers")),
            ("Group Containers", home.appendingPathComponent("Library/Group Containers")),
            ("Saved Application State", home.appendingPathComponent("Library/Saved Application State")),
            ("WebKit Cache", home.appendingPathComponent("Library/WebKit")),
            ("HTTP Storage", home.appendingPathComponent("Library/HTTPStorages")),
            ("Launch Agents", home.appendingPathComponent("Library/LaunchAgents")),
            ("Logs & Diagnostics", home.appendingPathComponent("Library/Logs"))
        ]

        let trimmedName = appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let compactName = trimmedName.replacingOccurrences(of: " ", with: "")
        let trimmedID = bundleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var tokens: [String] = []
        if !trimmedName.isEmpty && trimmedName.count >= 3 { tokens.append(trimmedName) }
        if !compactName.isEmpty && compactName.count >= 3 && compactName != trimmedName { tokens.append(compactName) }
        if !trimmedID.isEmpty && trimmedID.count >= 4 { tokens.append(trimmedID) }

        for target in searchTargets {
            guard let contents = try? fm.contentsOfDirectory(at: target.base, includingPropertiesForKeys: nil) else { continue }

            for itemURL in contents {
                let itemName = itemURL.lastPathComponent.lowercased()

                let matches = tokens.contains { token in
                    if itemName == token { return true }
                    if itemName.hasPrefix(token + ".") || itemName.hasPrefix(token + "-") || itemName.hasPrefix(token + "_") { return true }
                    if itemName.hasSuffix("." + token) { return true }
                    if token.count >= 4 && (itemName.contains("." + token) || itemName.contains(token + ".")) { return true }
                    if token.count >= 6 && itemName.contains(token) { return true }
                    return false
                }

                if matches {
                    let size = calculateDirectorySize(url: itemURL)
                    if size > 0 {
                        items.append(AppResidueItem(
                            path: itemURL.path,
                            url: itemURL,
                            name: itemURL.lastPathComponent,
                            size: size,
                            categoryName: target.category,
                            isChecked: true
                        ))
                    }
                }
            }
        }

        return items
    }

    public func uninstallApp(_ app: InstalledAppInfo) async -> UninstallResult {
        // 1. Guard against system-protected apps
        if app.isSystemProtected {
            let res = UninstallResult(
                appName: app.name,
                succeeded: false,
                bytesFreed: 0,
                itemsTrashed: 0,
                errorMessage: app.protectionReason ?? "This application is protected and cannot be moved to Trash."
            )
            self.lastResult = res
            return res
        }

        // 2. Guard against running processes
        if isApplicationRunning(bundleID: app.bundleIdentifier, bundleURL: app.bundleURL) {
            let quitSuccess = await quitApplication(app)
            if !quitSuccess {
                let res = UninstallResult(
                    appName: app.name,
                    succeeded: false,
                    bytesFreed: 0,
                    itemsTrashed: 0,
                    errorMessage: "\(app.name) is currently running. Please quit the application before uninstalling."
                )
                self.lastResult = res
                return res
            }
        }

        var totalFreed: Int64 = 0
        var itemsCount = 0
        var errors: [String] = []

        // 3. Stage checked residue items to Trash
        var trashedResidueIDs: Set<UUID> = []
        for residue in app.residueItems where residue.isChecked {
            do {
                var trashedURL: NSURL?
                try FileManager.default.trashItem(at: residue.url, resultingItemURL: &trashedURL)
                totalFreed += residue.size
                itemsCount += 1
                trashedResidueIDs.insert(residue.id)
            } catch {
                errors.append("Residue '\(residue.name)': \(error.localizedDescription)")
            }
        }

        // 4. Stage .app bundle to Trash if selected
        var bundleTrashed = false
        if app.isBundleSelected {
            do {
                var trashedBundleURL: NSURL?
                try FileManager.default.trashItem(at: app.bundleURL, resultingItemURL: &trashedBundleURL)
                totalFreed += app.appSize
                itemsCount += 1
                bundleTrashed = true
            } catch {
                errors.append("Bundle '\(app.name).app': \(error.localizedDescription)")
            }
        }

        // 5. Update State
        if bundleTrashed {
            // Entire app successfully removed
            installedApps.removeAll { $0.id == app.id }
            if selectedApp?.id == app.id {
                selectedApp = installedApps.first
            }
            FileScannerService.shared.refreshDiskSpace()

            let result = UninstallResult(
                appName: app.name,
                succeeded: true,
                bytesFreed: totalFreed,
                itemsTrashed: itemsCount,
                errorMessage: errors.isEmpty ? nil : errors.joined(separator: ", ")
            )
            self.lastResult = result
            return result
        } else if !trashedResidueIDs.isEmpty {
            // App bundle was kept or failed, but some residue was trashed
            if let idx = installedApps.firstIndex(where: { $0.id == app.id }) {
                installedApps[idx].residueItems.removeAll { trashedResidueIDs.contains($0.id) }
                if selectedApp?.id == app.id {
                    selectedApp = installedApps[idx]
                }
            }
            FileScannerService.shared.refreshDiskSpace()

            let result = UninstallResult(
                appName: app.name,
                succeeded: app.isBundleSelected ? false : true,
                bytesFreed: totalFreed,
                itemsTrashed: itemsCount,
                errorMessage: errors.isEmpty ? nil : errors.joined(separator: ", ")
            )
            self.lastResult = result
            return result
        } else {
            // Nothing was trashed
            let result = UninstallResult(
                appName: app.name,
                succeeded: false,
                bytesFreed: 0,
                itemsTrashed: 0,
                errorMessage: errors.isEmpty ? "Failed to move files to Trash." : errors.joined(separator: ", ")
            )
            self.lastResult = result
            return result
        }
    }

    private func calculateDirectorySize(url: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            return (attrs?[.size] as? Int64) ?? 0
        }

        var total: Int64 = 0
        let resourceKeys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey]
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(resourceKeys)) {
            for case let fileURL as URL in enumerator {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys) else { continue }
                if resourceValues.isDirectory != true {
                    total += Int64(resourceValues.fileSize ?? 0)
                }
            }
        }
        return total
    }
}
