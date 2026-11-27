import AppKit
import Foundation
import Observation

@Observable
@MainActor
public final class PermissionsService {
    public static let shared = PermissionsService()

    public var hasFullDiskAccess: Bool = false
    public var userAuthorizedFolders: [URL] = []

    private init() {
        checkPermissions()
    }

    public func checkPermissions() {
        let tccDB = URL.homeDirectory.appending(path: "Library/Application Support/com.apple.TCC/TCC.db")
        if let fileHandle = try? FileHandle(forReadingFrom: tccDB) {
            try? fileHandle.close()
            hasFullDiskAccess = true
        } else {
            hasFullDiskAccess = false
        }
    }

    public func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    public func requestFolderAccess() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Grant Access"
        panel.message = "Select a folder (such as Developer projects or Downloads) for Crucial to inspect."

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return nil
        }

        if !userAuthorizedFolders.contains(selectedURL) {
            userAuthorizedFolders.append(selectedURL)
        }
        return selectedURL
    }
}
