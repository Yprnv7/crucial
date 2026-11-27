import SwiftUI

/// Primary macOS split-view navigation sidebar without bottom-pinned footers.
public struct SidebarView: View {
    @Environment(NavigationStore.self) private var navigation
    @Environment(FileScannerService.self) private var scanner
    @Environment(AppUninstallerService.self) private var uninstaller
    @Environment(DuplicateFinderService.self) private var duplicates

    private let categorySections: [JunkCategory] = [
        .devArtifacts,
        .systemCache,
        .appResidue,
        .largeUnused
    ]

    public init() {}

    public var body: some View {
        @Bindable var nav = navigation

        List(selection: $nav.sidebarSelection) {
            Section("Overview") {
                SidebarNavRow(section: .dashboard, badgeText: nil)
                    .tag(CrucialNavSection.dashboard)

                SidebarNavRow(section: .diskMap, badgeText: nil)
                    .tag(CrucialNavSection.diskMap)
            }

            Section("Cleanup Targets") {
                ForEach(categorySections) { category in
                    let bytes = (scanner.itemsByCategory[category] ?? []).reduce(0) { $0 + $1.size }
                    let badge = bytes > 0 ? ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) : nil
                    SidebarNavRow(section: .category(category), badgeText: badge)
                        .tag(CrucialNavSection.category(category))
                }
            }

            Section("Utilities") {
                SidebarNavRow(
                    section: .uninstaller,
                    badgeText: uninstaller.installedApps.isEmpty ? nil : "\(uninstaller.installedApps.count)"
                )
                .tag(CrucialNavSection.uninstaller)

                SidebarNavRow(
                    section: .duplicates,
                    badgeText: duplicates.totalWastedBytes > 0
                        ? ByteCountFormatter.string(fromByteCount: duplicates.totalWastedBytes, countStyle: .file)
                        : nil
                )
                .tag(CrucialNavSection.duplicates)

                SidebarNavRow(section: .maintenance, badgeText: nil)
                    .tag(CrucialNavSection.maintenance)

                SidebarNavRow(section: .startup, badgeText: nil)
                    .tag(CrucialNavSection.startup)

                SidebarNavRow(section: .fileFinder, badgeText: nil)
                    .tag(CrucialNavSection.fileFinder)
            }

            Section("Local Intelligence") {
                SidebarNavRow(section: .assistant, badgeText: nil)
                    .tag(CrucialNavSection.assistant)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 215, ideal: 235, max: 270)
    }
}

private struct SidebarNavRow: View {
    let section: CrucialNavSection
    let badgeText: String?

    var body: some View {
        HStack(spacing: CrucialSpacing.sm) {
            Label {
                Text(section.title)
                    .lineLimit(1)
            } icon: {
                Image(systemName: section.iconName)
                    .foregroundStyle(section.accentColor)
            }

            Spacer(minLength: CrucialSpacing.xs)

            if let badgeText {
                Text(badgeText)
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(CrucialTheme.textSecondary)
            }
        }
    }
}
