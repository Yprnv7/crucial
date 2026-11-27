import AppKit
import Foundation

@MainActor
public enum FinderOpener {
    /// Selects the specified file or directory in macOS Finder and activates Finder.
    public static func reveal(path: String) {
        let cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPath.isEmpty else { return }

        let url = URL(fileURLWithPath: cleanPath)
        guard FileManager.default.fileExists(atPath: cleanPath) else {
            let parentURL = url.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: parentURL.path) {
                NSWorkspace.shared.open(parentURL)
            }
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([url])

        let finderApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder")
        for finder in finderApps {
            finder.activate(options: [.activateAllWindows])
        }
    }

    /// Reveals multiple items simultaneously in macOS Finder.
    public static func revealMultiple(paths: [String]) {
        let urls = paths.compactMap { path -> URL? in
            let clean = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty, FileManager.default.fileExists(atPath: clean) else { return nil }
            return URL(fileURLWithPath: clean)
        }
        guard !urls.isEmpty else { return }

        NSWorkspace.shared.activateFileViewerSelecting(urls)

        let finderApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder")
        for finder in finderApps {
            finder.activate(options: [.activateAllWindows])
        }
    }
}
