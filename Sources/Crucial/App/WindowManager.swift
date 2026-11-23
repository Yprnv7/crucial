import SwiftUI
import AppKit

@MainActor
public final class WindowManager: ObservableObject {
    public static let shared = WindowManager()

    @Published public var selectedNav: CrucialNavSection = .dashboard
    @Published public var selectedItem: FileItem? = nil
    @Published public var activeSearchQuery: String = ""

    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?

    private init() {}

    public func navigate(to section: CrucialNavSection, item: FileItem? = nil) {
        self.selectedNav = section
        if let item {
            self.selectedItem = item
        }
        focusMainWindow()
    }

    public func openCategory(_ category: JunkCategory) {
        navigate(to: .category(category))
    }

    public func focusMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }

        // Search through application windows
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
            self.mainWindow = window
            return
        }

        // If no window exists, create and open it
        openMainWindow()
    }

    public func registerMainWindow(_ window: NSWindow) {
        self.mainWindow = window
    }

    public func openMainWindow() {
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = MainWindowView()
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1140, height: 740),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Crucial"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 980, height: 620)

        self.mainWindow = window
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
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 400),
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
