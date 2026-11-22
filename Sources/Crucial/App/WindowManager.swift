import SwiftUI
import AppKit

@MainActor
public final class WindowManager {
    public static let shared = WindowManager()

    private var finderWindow: NSWindow?
    private var settingsWindow: NSWindow?

    private init() {}

    public func openFinderWindow() {
        if let window = finderWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = FileFinderView()
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Crucial — File Finder & Vitality Inspector"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false

        self.finderWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func openSettingsWindow() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = SettingsView()
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Crucial Settings"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false

        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
