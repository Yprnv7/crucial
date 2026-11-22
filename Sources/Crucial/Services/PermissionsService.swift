import Foundation
import AppKit

@MainActor
public final class PermissionsService: ObservableObject {
    public static let shared = PermissionsService()

    @Published public var hasFullDiskAccess: Bool = false
    @Published public var userAuthorizedFolders: [URL] = []

    private init() {
        checkPermissions()
    }

    public func checkPermissions() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let testPaths = [
            home.appendingPathComponent("Library/Safari"),
            home.appendingPathComponent("Library/Mail")
        ]

        var accessGranted = false
        for testPath in testPaths {
            if FileManager.default.fileExists(atPath: testPath.path) {
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: testPath.path), !contents.isEmpty {
                    accessGranted = true
                    break
                }
            }
        }

        self.hasFullDiskAccess = accessGranted
    }

    public func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    public func requestFolderAccess(completion: @escaping @MainActor (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Grant Access to Crucial"
        panel.message = "Select a folder (such as your Dev projects or Downloads) for Crucial to scan and inspect."

        if panel.runModal() == .OK, let selectedURL = panel.url {
            if !self.userAuthorizedFolders.contains(selectedURL) {
                self.userAuthorizedFolders.append(selectedURL)
            }
            completion(selectedURL)
        } else {
            completion(nil)
        }
    }
}
