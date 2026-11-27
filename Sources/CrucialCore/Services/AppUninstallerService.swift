import AppKit
import Foundation
import Observation

@Observable
@MainActor
public final class AppUninstallerService {
    public static let shared = AppUninstallerService()

    public var installedApps: [InstalledAppInfo] = []
    public var selectedApp: InstalledAppInfo?
    public var isScanning: Bool = false
    public var progressMessage: String = ""
    public var lastResult: UninstallResult?
    public var isQuittingApp: Bool = false

    private init() {}

    public func scanInstalledApplications() async {
        isScanning = true
        progressMessage = "Scanning installed applications..."

        let runningSnapshot = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        let runningURLs = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleURL })

        let apps = await Task.detached(priority: .utility) { () -> [InstalledAppInfo] in
            Self.discoverApplications(runningBundleIDs: runningSnapshot, runningURLs: runningURLs)
        }.value

        installedApps = apps
        if let current = selectedApp {
            selectedApp = installedApps.first { $0.bundleURL == current.bundleURL } ?? installedApps.first
        } else {
            selectedApp = installedApps.first
        }

        isScanning = false
        progressMessage = ""
    }

    private nonisolated static func discoverApplications(
        runningBundleIDs: Set<String>,
        runningURLs: Set<URL>
    ) -> [InstalledAppInfo] {
        let appDirs = [
            URL(fileURLWithPath: "/Applications"),
            URL.homeDirectory.appending(path: "Applications")
        ]

        var apps: [InstalledAppInfo] = []
        for dir in appDirs {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents where url.pathExtension == "app" {
                let isRunning: (String, URL) -> Bool = { bid, bundleURL in
                    (!bid.isEmpty && runningBundleIDs.contains(bid)) || runningURLs.contains(bundleURL)
                }
                if let info = analyzeAppBundle(url: url, isRunningCheck: isRunning) {
                    apps.append(info)
                }
            }
        }

        return apps.sorted {
            if $0.isSystemProtected != $1.isSystemProtected {
                return !$0.isSystemProtected
            }
            return $0.totalFootprint > $1.totalFootprint
        }
    }

    public func selectApp(_ app: InstalledAppInfo) {
        var updated = app
        updated.isRunning = isApplicationRunning(bundleID: app.bundleIdentifier, bundleURL: app.bundleURL)
        selectedApp = updated

        if let idx = installedApps.firstIndex(where: { $0.id == app.id }) {
            installedApps[idx].isRunning = updated.isRunning
        }
    }

    public func inspectCustomApp(url: URL) {
        let resolved = url.resolvingSymlinksInPath()
        var isDir: ObjCBool = false
        guard resolved.isFileURL,
              resolved.pathExtension == "app",
              FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDir),
              isDir.boolValue
        else { return }

        if let existing = installedApps.first(where: { $0.bundleURL.path == resolved.path }) {
            selectApp(existing)
            return
        }

        let runningSnapshot = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        let runningURLs = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleURL })

        if let newApp = Self.analyzeAppBundle(url: resolved, isRunningCheck: { bid, bURL in
            (!bid.isEmpty && runningSnapshot.contains(bid)) || runningURLs.contains(bURL)
        }) {
            installedApps.insert(newApp, at: 0)
            selectApp(newApp)
        }
    }

    public func toggleResidueItem(appID: UUID, residueID: UUID) {
        if let appIndex = installedApps.firstIndex(where: { $0.id == appID }),
           let resIndex = installedApps[appIndex].residueItems.firstIndex(where: { $0.id == residueID }) {
            installedApps[appIndex].residueItems[resIndex].isChecked.toggle()
            if selectedApp?.id == appID {
                selectedApp = installedApps[appIndex]
            }
        } else if selectedApp?.id == appID,
                  let resIndex = selectedApp?.residueItems.firstIndex(where: { $0.id == residueID }) {
            selectedApp?.residueItems[resIndex].isChecked.toggle()
        }
    }

    public func toggleAllResidue(appID: UUID, checked: Bool) {
        if let appIndex = installedApps.firstIndex(where: { $0.id == appID }) {
            for i in installedApps[appIndex].residueItems.indices {
                installedApps[appIndex].residueItems[i].isChecked = checked
            }
            if selectedApp?.id == appID {
                selectedApp = installedApps[appIndex]
            }
        } else if selectedApp?.id == appID, let count = selectedApp?.residueItems.count {
            for i in 0..<count {
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

        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(100))
            if !isApplicationRunning(bundleID: app.bundleIdentifier, bundleURL: app.bundleURL) {
                updateAppRunningStatus(appID: app.id, isRunning: false)
                return true
            }
        }

        for running in runningInstances {
            running.forceTerminate()
        }
        try? await Task.sleep(for: .milliseconds(200))

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
        if !bundleID.isEmpty && !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty {
            return true
        }
        return NSWorkspace.shared.runningApplications.contains { $0.bundleURL == bundleURL }
    }

    public nonisolated static func analyzeAppBundle(
        url: URL,
        isRunningCheck: (String, URL) -> Bool
    ) -> InstalledAppInfo? {
        guard let bundle = Bundle(url: url) else { return nil }
        let bundleID = bundle.bundleIdentifier ?? ""
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                   bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ??
                   url.deletingPathExtension().lastPathComponent
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"

        let appSize = FileSystemSizer.size(at: url)
        let residue = scanResidue(for: name, bundleID: bundleID)

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
            reason = "Crucial cannot uninstall itself while running."
        } else if bundleID.hasPrefix("com.apple.") && (url.path.hasPrefix("/Applications/Safari") || url.path.hasPrefix("/Applications/Utilities")) {
            isProtected = true
            reason = "Protected macOS core system application."
        }

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
            isRunning: isRunningCheck(bundleID, url)
        )
    }

    public nonisolated static func scanResidue(for appName: String, bundleID: String) -> [AppResidueItem] {
        var items: [AppResidueItem] = []
        let fm = FileManager.default
        let home = URL.homeDirectory

        let searchTargets: [(category: String, base: URL)] = [
            ("Application Support", home.appending(path: "Library/Application Support")),
            ("Caches", home.appending(path: "Library/Caches")),
            ("Preferences", home.appending(path: "Library/Preferences")),
            ("Containers", home.appending(path: "Library/Containers")),
            ("Group Containers", home.appending(path: "Library/Group Containers")),
            ("Saved Application State", home.appending(path: "Library/Saved Application State")),
            ("WebKit Cache", home.appending(path: "Library/WebKit")),
            ("HTTP Storage", home.appending(path: "Library/HTTPStorages")),
            ("Launch Agents", home.appending(path: "Library/LaunchAgents")),
            ("Logs & Diagnostics", home.appending(path: "Library/Logs"))
        ]

        let trimmedName = appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let compactName = trimmedName.replacing(" ", with: "")
        let trimmedID = bundleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var tokens: [String] = []
        if trimmedName.count >= 3 { tokens.append(trimmedName) }
        if compactName.count >= 3 && compactName != trimmedName { tokens.append(compactName) }
        if trimmedID.count >= 4 { tokens.append(trimmedID) }

        for target in searchTargets {
            guard let contents = try? fm.contentsOfDirectory(at: target.base, includingPropertiesForKeys: nil) else { continue }
            for itemURL in contents {
                let itemName = itemURL.lastPathComponent.lowercased()
                let matches = tokens.contains { token in
                    itemName == token ||
                    itemName.hasPrefix(token + ".") ||
                    itemName.hasPrefix(token + "-") ||
                    itemName.hasPrefix(token + "_") ||
                    itemName.hasSuffix("." + token) ||
                    (token.count >= 4 && (itemName.contains("." + token) || itemName.contains(token + "."))) ||
                    (token.count >= 6 && itemName.contains(token))
                }

                if matches {
                    let size = FileSystemSizer.size(at: itemURL)
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
        if app.isSystemProtected {
            let res = UninstallResult(
                appName: app.name,
                succeeded: false,
                bytesFreed: 0,
                itemsTrashed: 0,
                errorMessage: app.protectionReason ?? "This application is protected by macOS."
            )
            lastResult = res
            return res
        }

        if isApplicationRunning(bundleID: app.bundleIdentifier, bundleURL: app.bundleURL) {
            let quitSuccess = await quitApplication(app)
            if !quitSuccess {
                let res = UninstallResult(
                    appName: app.name,
                    succeeded: false,
                    bytesFreed: 0,
                    itemsTrashed: 0,
                    errorMessage: "\(app.name) is active. Quit it before moving files to Trash."
                )
                lastResult = res
                return res
            }
        }

        var totalFreed: Int64 = 0
        var itemsCount = 0
        var errors: [String] = []
        var trashedResidueIDs: Set<UUID> = []

        for residue in app.residueItems where residue.isChecked {
            do {
                try await SafetyTrashService.shared.recycleURLSafely(residue.url)
                totalFreed += residue.size
                itemsCount += 1
                trashedResidueIDs.insert(residue.id)
            } catch {
                errors.append("\(residue.name): \(error.localizedDescription)")
            }
        }

        var bundleTrashed = false
        if app.isBundleSelected {
            do {
                try await SafetyTrashService.shared.recycleURLSafely(app.bundleURL)
                totalFreed += app.appSize
                itemsCount += 1
                bundleTrashed = true
            } catch {
                errors.append("\(app.name).app: \(error.localizedDescription)")
            }
        }

        if bundleTrashed {
            installedApps.removeAll { $0.id == app.id }
            if selectedApp?.id == app.id {
                selectedApp = installedApps.first
            }
            FileScannerService.shared.refreshDiskSpace()
        } else if !trashedResidueIDs.isEmpty {
            if let idx = installedApps.firstIndex(where: { $0.id == app.id }) {
                installedApps[idx].residueItems.removeAll { trashedResidueIDs.contains($0.id) }
                if selectedApp?.id == app.id {
                    selectedApp = installedApps[idx]
                }
            }
            FileScannerService.shared.refreshDiskSpace()
        }

        let succeeded = bundleTrashed || (!trashedResidueIDs.isEmpty && !app.isBundleSelected)
        let result = UninstallResult(
            appName: app.name,
            succeeded: succeeded,
            bytesFreed: totalFreed,
            itemsTrashed: itemsCount,
            errorMessage: errors.isEmpty ? nil : errors.joined(separator: "; ")
        )
        lastResult = result
        return result
    }
}
