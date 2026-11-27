import CrucialCore
import SwiftUI

/// Standard macOS keyboard shortcuts wired via App Commands.
struct CrucialCommands: Commands {
    private let navigation = NavigationStore.shared
    private let scanner = FileScannerService.shared

    var body: some Commands {
        CommandMenu("Navigate") {
            Button("Clean Dashboard") {
                navigation.navigate(to: .dashboard)
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Storage Breakdown") {
                navigation.navigate(to: .diskMap)
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("App Uninstaller") {
                navigation.navigate(to: .uninstaller)
            }
            .keyboardShortcut("3", modifiers: .command)

            Button("Duplicate Finder") {
                navigation.navigate(to: .duplicates)
            }
            .keyboardShortcut("4", modifiers: .command)

            Button("System Maintenance") {
                navigation.navigate(to: .maintenance)
            }
            .keyboardShortcut("5", modifiers: .command)

            Button("Startup Agents") {
                navigation.navigate(to: .startup)
            }
            .keyboardShortcut("6", modifiers: .command)

            Button("Deep File Finder") {
                navigation.navigate(to: .fileFinder)
            }
            .keyboardShortcut("7", modifiers: .command)

            Button("Crucial Assistant") {
                navigation.navigate(to: .assistant)
            }
            .keyboardShortcut("8", modifiers: .command)

            Divider()

            Button("Rescan Mac Storage") {
                Task { await scanner.scanQuickCleanDashboard() }
            }
            .keyboardShortcut("r", modifiers: .command)
        }
    }
}

@main
struct CrucialApp: App {
    var body: some Scene {
        Window("Crucial", id: "main") {
            MainWindowView()
                .environment(NavigationStore.shared)
                .environment(FileScannerService.shared)
                .environment(AppUninstallerService.shared)
                .environment(DuplicateFinderService.shared)
                .environment(SystemMaintenanceService.shared)
                .environment(StartupManagerService.shared)
                .environment(SystemFileSearchService.shared)
                .environment(CrucialChatService.shared)
                .environment(LocalLLMService.shared)
                .environment(PermissionsService.shared)
                .environment(SafetyTrashService.shared)
                .environment(CPUMonitorService.shared)
        }
        .defaultSize(width: 1180, height: 760)
        .windowToolbarStyle(.unified)
        .commands {
            CrucialCommands()
        }

        Settings {
            CrucialSettingsView()
                .environment(PermissionsService.shared)
                .environment(LocalLLMService.shared)
                .environment(SafetyTrashService.shared)
        }

        MenuBarExtra("Crucial", systemImage: "internaldrive") {
            CrucialMenuBarView()
                .environment(CPUMonitorService.shared)
                .environment(FileScannerService.shared)
        }
        .menuBarExtraStyle(.window)
    }
}
