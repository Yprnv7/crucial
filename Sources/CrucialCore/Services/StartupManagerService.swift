import Foundation
import Observation

@Observable
@MainActor
public final class StartupManagerService {
    public static let shared = StartupManagerService()

    public var items: [StartupItemInfo] = []
    public var isScanning: Bool = false
    public var lastErrorMessage: String?

    private init() {}

    public func scanStartupItems() async {
        isScanning = true
        lastErrorMessage = nil

        let discovered = await Task.detached(priority: .utility) { () -> [StartupItemInfo] in
            Self.loadLaunchAgents()
        }.value

        items = discovered
        isScanning = false
    }

    private nonisolated static func loadLaunchAgents() -> [StartupItemInfo] {
        let searchDirs: [(url: URL, isSystem: Bool)] = [
            (URL.homeDirectory.appending(path: "Library/LaunchAgents"), false),
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
        return discovered.sorted { ($0.isOrphaned ? 0 : 1) < ($1.isOrphaned ? 0 : 1) }
    }

    private nonisolated static func parseLaunchAgent(url: URL, isSystem: Bool) -> StartupItemInfo? {
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
        let newURL = item.isEnabled
            ? URL(fileURLWithPath: currentPath + ".disabled")
            : URL(fileURLWithPath: currentPath.replacing(".disabled", with: ""))

        do {
            try FileManager.default.moveItem(at: item.plistURL, to: newURL)
            lastErrorMessage = nil
            Task {
                await scanStartupItems()
            }
        } catch {
            lastErrorMessage = "Permission denied modifying '\(item.label)': \(error.localizedDescription)"
        }
    }

    public func trashItem(_ item: StartupItemInfo) {
        do {
            try FileManager.default.trashItem(at: item.plistURL, resultingItemURL: nil)
            items.removeAll { $0.id == item.id }
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Could not move '\(item.label)' to Trash: \(error.localizedDescription)"
        }
    }
}
