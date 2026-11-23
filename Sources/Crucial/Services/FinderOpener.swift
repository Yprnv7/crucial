import Foundation
import AppKit

@MainActor
public enum FinderOpener {
    /// Opens macOS Finder and selects the specified file or folder, bringing Finder to the front.
    public static func reveal(path: String) {
        let cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPath.isEmpty else { return }

        let url = URL(fileURLWithPath: cleanPath)
        guard FileManager.default.fileExists(atPath: cleanPath) else {
            // If the exact file doesn't exist, try its parent directory
            let parentURL = url.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: parentURL.path) {
                NSWorkspace.shared.open(parentURL)
            }
            return
        }

        // Method 1: Official AppKit file viewer selection
        NSWorkspace.shared.activateFileViewerSelecting([url])

        // Method 2: High-reliability CLI fallback with /usr/bin/open -R
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-R", cleanPath]
        try? process.run()

        // Method 3: Unhide and activate Finder application to bring to front
        let finderApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder")
        for finder in finderApps {
            finder.activate(options: [.activateAllWindows])
        }
    }

    /// Reveals multiple items in macOS Finder
    public static func revealMultiple(paths: [String]) {
        let urls = paths.compactMap { path -> URL? in
            let clean = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty, FileManager.default.fileExists(atPath: clean) else { return nil }
            return URL(fileURLWithPath: clean)
        }
        guard !urls.isEmpty else { return }

        NSWorkspace.shared.activateFileViewerSelecting(urls)
        for url in urls.prefix(3) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-R", url.path]
            try? process.run()
        }

        let finderApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder")
        for finder in finderApps {
            finder.activate(options: [.activateAllWindows])
        }
    }
}
