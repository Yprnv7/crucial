import Foundation
import AppKit

public struct AppResidueItem: Identifiable, Sendable {
    public let id = UUID()
    public let path: String
    public let url: URL
    public let name: String
    public let size: Int64
    public let categoryName: String
    public var isChecked: Bool

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

public struct InstalledAppInfo: Identifiable, Sendable {
    public let id = UUID()
    public let name: String
    public let bundleURL: URL
    public let bundleIdentifier: String
    public let version: String
    public let appSize: Int64
    public var residueItems: [AppResidueItem]

    public var totalFootprint: Int64 {
        appSize + residueItems.reduce(0) { $0 + $1.size }
    }

    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalFootprint, countStyle: .file)
    }

    public var icon: NSImage {
        NSWorkspace.shared.icon(forFile: bundleURL.path)
    }
}

@MainActor
public final class AppUninstallerService: ObservableObject {
    public static let shared = AppUninstallerService()

    @Published public var installedApps: [InstalledAppInfo] = []
    @Published public var selectedApp: InstalledAppInfo?
    @Published public var isScanning: Bool = false
    @Published public var progressMessage: String = ""

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

        self.installedApps = apps.sorted { $0.totalFootprint > $1.totalFootprint }
        if selectedApp == nil {
            selectedApp = self.installedApps.first
        }
        self.isScanning = false
        self.progressMessage = ""
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

        return InstalledAppInfo(
            name: name,
            bundleURL: url,
            bundleIdentifier: bundleID,
            version: version,
            appSize: appSize,
            residueItems: residue
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
            ("Saved Application State", home.appendingPathComponent("Library/Saved Application State")),
            ("WebKit Cache", home.appendingPathComponent("Library/WebKit")),
            ("HTTP Storage", home.appendingPathComponent("Library/HTTPStorages")),
            ("Launch Agents", home.appendingPathComponent("Library/LaunchAgents"))
        ]

        let searchTokens = [
            appName.lowercased(),
            bundleID.lowercased()
        ].filter { !$0.isEmpty }

        for target in searchTargets {
            guard let contents = try? fm.contentsOfDirectory(at: target.base, includingPropertiesForKeys: nil) else { continue }

            for itemURL in contents {
                let itemName = itemURL.lastPathComponent.lowercased()
                let matches = searchTokens.contains { token in
                    itemName == token || itemName.hasPrefix(token + ".") || itemName.hasPrefix(token + "-")
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

    public func uninstallApp(_ app: InstalledAppInfo) {
        // Stage residue items to Trash
        for residue in app.residueItems where residue.isChecked {
            try? FileManager.default.trashItem(at: residue.url, resultingItemURL: nil)
        }

        // Stage .app bundle to Trash
        try? FileManager.default.trashItem(at: app.bundleURL, resultingItemURL: nil)

        // Remove from list
        installedApps.removeAll { $0.id == app.id }
        if selectedApp?.id == app.id {
            selectedApp = installedApps.first
        }

        // Refresh scanner totals
        FileScannerService.shared.refreshDiskSpace()
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
