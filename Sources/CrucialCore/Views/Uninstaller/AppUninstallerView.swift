import SwiftUI
import UniformTypeIdentifiers

/// Application uninstaller that scans /Applications and correlates Library residue before Trashing.
public struct AppUninstallerView: View {
    @Environment(AppUninstallerService.self) private var uninstaller

    @State private var selectedAppID: InstalledAppInfo.ID?
    @State private var searchQuery = ""
    @State private var isDropTargeted = false

    public init() {}

    private var filteredApps: [InstalledAppInfo] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return uninstaller.installedApps }
        return uninstaller.installedApps.filter {
            $0.name.localizedStandardContains(trimmed)
                || $0.bundleIdentifier.localizedStandardContains(trimmed)
        }
    }

    private var currentApp: InstalledAppInfo? {
        guard let selectedAppID else { return uninstaller.selectedApp }
        return uninstaller.installedApps.first { $0.id == selectedAppID } ?? uninstaller.selectedApp
    }

    public var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack(spacing: CrucialSpacing.sm) {
                    TextField("Search apps", text: $searchQuery)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        Task { await uninstaller.scanInstalledApplications() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Rescan installed applications")
                    .disabled(uninstaller.isScanning)
                }
                .padding(CrucialSpacing.md)
                .background(CrucialTheme.card)

                Divider()

                if uninstaller.isScanning && uninstaller.installedApps.isEmpty {
                    VStack(spacing: CrucialSpacing.md) {
                        ProgressView()
                        Text(uninstaller.progressMessage)
                            .font(.caption)
                            .foregroundStyle(CrucialTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(CrucialTheme.canvas)
                } else if filteredApps.isEmpty {
                    ContentUnavailableView {
                        Label("No Matching Applications", systemImage: "app.dashed")
                    } description: {
                        Text("Adjust your search or drop any .app bundle onto this window to trace its caches and preferences.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(CrucialTheme.canvas)
                } else {
                    List(filteredApps, selection: $selectedAppID) { app in
                        AppRowView(app: app)
                            .tag(app.id)
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 270, idealWidth: 320, maxWidth: 400)

            if let currentApp {
                AppDetailPaneView(app: currentApp)
                    .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView {
                    Label("Select an Application", systemImage: "trash.square")
                } description: {
                    Text("Inspect bundle size, running status, and associated containers in ~/Library before uninstalling.")
                }
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
                .background(CrucialTheme.canvas)
            }
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(CrucialTheme.accent, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .padding(CrucialSpacing.md)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDroppedProviders(providers)
        }
        .onChange(of: selectedAppID) { _, newValue in
            if let newValue,
               let match = uninstaller.installedApps.first(where: { $0.id == newValue }) {
                uninstaller.selectApp(match)
            }
        }
        .task {
            if uninstaller.installedApps.isEmpty && !uninstaller.isScanning {
                await uninstaller.scanInstalledApplications()
            }
            if selectedAppID == nil {
                selectedAppID = uninstaller.selectedApp?.id ?? uninstaller.installedApps.first?.id
            }
        }
    }

    private func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.pathExtension.lowercased() == "app" else {
                return
            }
            Task { @MainActor in
                uninstaller.inspectCustomApp(url: url)
                selectedAppID = uninstaller.selectedApp?.id
            }
        }
        return true
    }
}
