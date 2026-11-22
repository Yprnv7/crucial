import Foundation
import AppKit

public struct StartupItemInfo: Identifiable, Sendable {
    public let id = UUID()
    public let label: String
    public let plistURL: URL
    public let executablePath: String?
    public let isOrphaned: Bool // Binary no longer exists
    public var isEnabled: Bool
    public let isSystemLevel: Bool

    public var displayName: String {
        let parts = label.components(separatedBy: ".")
        if let last = parts.last, last.count > 2 {
            return last.capitalized
        }
        return label
    }
}

@MainActor
public final class StartupManagerService: ObservableObject {
    public static let shared = StartupManagerService()

    @Published public var items: [StartupItemInfo] = []
    @Published public var isScanning: Bool = false

    private init() {}

    public func scanStartupItems() async {
        isScanning = true

        let searchDirs: [(url: URL, isSystem: Bool)] = [
            (FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents"), false),
            (URL(fileURLWithPath: "/Library/LaunchAgents"), true)
        ]

        var discovered: [StartupItemInfo] = []

        for target in searchDirs {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: target.url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in files {
                let isPlist = url.pathExtension == "plist" || url.lastPathComponent.contains(".plist")
                guard isPlist else { continue }

                if let info = parseLaunchAgent(url: url, isSystem: target.isSystem) {
                    discovered.append(info)
                }
            }
        }

        self.items = discovered.sorted { ($0.isOrphaned ? 0 : 1) < ($1.isOrphaned ? 0 : 1) }
        self.isScanning = false
    }

    private func parseLaunchAgent(url: URL, isSystem: Bool) -> StartupItemInfo? {
        guard let data = try? Data(contentsOf: url),
              let dict = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any]
        else {
            let label = url.deletingPathExtension().lastPathComponent
            let isEnabled = !url.path.hasSuffix(".disabled")
            return StartupItemInfo(
                label: label,
                plistURL: url,
                executablePath: nil,
                isOrphaned: false,
                isEnabled: isEnabled,
                isSystemLevel: isSystem
            )
        }

        let label = dict["Label"] as? String ?? url.deletingPathExtension().lastPathComponent
        let args = dict["ProgramArguments"] as? [String]
        let program = dict["Program"] as? String ?? args?.first

        var isOrphaned = false
        if let exec = program {
            isOrphaned = !FileManager.default.fileExists(atPath: exec)
        }

        let isEnabled = !url.path.hasSuffix(".disabled") && ((dict["Disabled"] as? Bool) != true)

        return StartupItemInfo(
            label: label,
            plistURL: url,
            executablePath: program,
            isOrphaned: isOrphaned,
            isEnabled: isEnabled,
            isSystemLevel: isSystem
        )
    }

    public func toggleItem(_ item: StartupItemInfo) {
        let currentPath = item.plistURL.path
        let newURL: URL

        if item.isEnabled {
            // Disable by appending .disabled
            newURL = URL(fileURLWithPath: currentPath + ".disabled")
            try? FileManager.default.moveItem(at: item.plistURL, to: newURL)
        } else {
            // Re-enable
            let restoredPath = currentPath.replacingOccurrences(of: ".disabled", with: "")
            newURL = URL(fileURLWithPath: restoredPath)
            try? FileManager.default.moveItem(at: item.plistURL, to: newURL)
        }

        Task {
            await scanStartupItems()
        }
    }

    public func trashItem(_ item: StartupItemInfo) {
        try? FileManager.default.trashItem(at: item.plistURL, resultingItemURL: nil)
        items.removeAll { $0.id == item.id }
    }
}
