import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as Menu Bar accessory (no Dock icon clutter)
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct CrucialApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Crucial", systemImage: "bolt.shield.fill") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}
