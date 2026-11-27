import QuickLook
import SwiftUI

/// Primary NavigationSplitView shell connecting sidebar navigation, detail workspaces, toolbar, and Quick Look.
public struct MainWindowView: View {
    @Environment(NavigationStore.self) private var navigation
    @Environment(FileScannerService.self) private var scanner
    @Environment(CPUMonitorService.self) private var monitor
    @Environment(SystemFileSearchService.self) private var fileSearch

    public init() {}

    public var body: some View {
        @Bindable var nav = navigation

        NavigationSplitView {
            SidebarView()
        } detail: {
            detailDestination(for: navigation.selectedNav)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CrucialTheme.canvas)
        }
        .navigationTitle(navigation.selectedNav.title)
        .searchable(
            text: $nav.activeSearchQuery,
            placement: .toolbar,
            prompt: "Search files or filter list"
        )
        .onSubmit(of: .search) {
            let trimmed = navigation.activeSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            navigation.navigate(to: .fileFinder)
            Task { _ = await fileSearch.search(query: trimmed) }
        }
        .quickLookPreview($nav.quickLookURL)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await scanner.scanQuickCleanDashboard() }
                } label: {
                    Label("Scan Storage", systemImage: "arrow.clockwise")
                }
                .disabled(scanner.isScanning)
                .help("Rescan caches, developer artifacts, and disk capacity (Cmd+R)")

                Button {
                    navigation.navigate(to: .assistant)
                } label: {
                    Label("Assistant", systemImage: "cpu")
                }
                .help("Open Crucial Assistant")
            }

            ToolbarItem(placement: .status) {
                Text("CPU \(monitor.cpuPercent.formatted(.number.precision(.fractionLength(0))))%")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(CrucialTheme.textSecondary)
            }
        }
        .onAppear {
            monitor.startMonitoring()
            scanner.refreshDiskSpace()
        }
        .onDisappear {
            monitor.stopMonitoring()
        }
    }

    @ViewBuilder
    private func detailDestination(for section: CrucialNavSection) -> some View {
        switch section {
        case .dashboard:
            DashboardView()
        case .category(let category):
            CategoryDrilldownView(category: category)
        case .uninstaller:
            AppUninstallerView()
        case .diskMap:
            DiskSunburstView()
        case .duplicates:
            DuplicateFinderView()
        case .maintenance:
            SystemMaintenanceView()
        case .startup:
            StartupManagerView()
        case .fileFinder:
            SystemFileFinderView()
        case .assistant:
            AssistantView()
        }
    }
}
