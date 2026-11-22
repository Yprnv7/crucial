import SwiftUI
import AppKit

public struct AppUninstallerView: View {
    @ObservedObject var uninstaller = AppUninstallerService.shared
    @State private var searchText = ""
    @State private var showingUninstallAlert = false
    @State private var isTargetedForDrop = false

    public init() {}

    private var filteredApps: [InstalledAppInfo] {
        if searchText.isEmpty {
            return uninstaller.installedApps
        }
        return uninstaller.installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        HSplitView {
            // Left Pane: Installed Apps List & Drop Target
            VStack(spacing: 0) {
                // Header & Search
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(ThingsTheme.accent.opacity(0.12))
                                .frame(width: 32, height: 32)
                            Image(systemName: "trash.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(ThingsTheme.accent)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text("App Uninstaller")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(ThingsTheme.textPrimary)
                            Text("\(uninstaller.installedApps.count) applications detected")
                                .font(.system(size: 11))
                                .foregroundStyle(ThingsTheme.textSecondary)
                        }

                        Spacer()

                        Button {
                            Task {
                                await uninstaller.scanInstalledApplications()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11))
                                .foregroundStyle(ThingsTheme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Search Field
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundStyle(ThingsTheme.textTertiary)
                        TextField("Filter apps...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 11)).foregroundStyle(ThingsTheme.textTertiary)
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(ThingsTheme.cardRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(14)
                .background(ThingsTheme.sidebar)

                Divider().background(ThingsTheme.borderSubtle)

                // Drag & Drop Hint Banner
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 11))
                    Text("Drag and drop any .app here to inspect residue")
                        .font(.system(size: 10))
                }
                .foregroundStyle(isTargetedForDrop ? ThingsTheme.accent : ThingsTheme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isTargetedForDrop ? ThingsTheme.accent.opacity(0.1) : ThingsTheme.cardRaised.opacity(0.5))

                Divider().background(ThingsTheme.borderSubtle)

                // Apps List
                if uninstaller.isScanning {
                    VStack(spacing: 12) {
                        ProgressView().scaleEffect(0.8)
                        Text(uninstaller.progressMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(ThingsTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: Binding(
                        get: { uninstaller.selectedApp?.id },
                        set: { newID in
                            uninstaller.selectedApp = uninstaller.installedApps.first { $0.id == newID }
                        }
                    )) {
                        ForEach(filteredApps) { app in
                            appRow(app)
                                .tag(app.id)
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 320, maxWidth: 440)
            .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url, url.pathExtension == "app" else { return }
                    DispatchQueue.main.async {
                        if let customApp = uninstaller.analyzeSingleApp(url: url) {
                            uninstaller.selectedApp = customApp
                        }
                    }
                }
                return true
            }

            // Right Pane: Residue Inspection & Complete Trashing
            VStack(spacing: 0) {
                if let app = uninstaller.selectedApp {
                    appDetailPane(app)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "app.dashed")
                            .font(.system(size: 36))
                            .foregroundStyle(ThingsTheme.textTertiary)
                        Text("Select an Application")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ThingsTheme.textPrimary)
                        Text("Crucial will trace its container, cache stores, and preference plists.")
                            .font(.system(size: 11))
                            .foregroundStyle(ThingsTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 420, maxWidth: .infinity)
            .background(ThingsTheme.canvas)
        }
        .onAppear {
            if uninstaller.installedApps.isEmpty && !uninstaller.isScanning {
                Task {
                    await uninstaller.scanInstalledApplications()
                }
            }
        }
        .alert(isPresented: $showingUninstallAlert) {
            guard let app = uninstaller.selectedApp else {
                return Alert(title: Text("Error"))
            }
            return Alert(
                title: Text("Completely Uninstall \(app.name)?"),
                message: Text("Crucial will safely stage the application bundle and all \(app.residueItems.count) support files (\(app.formattedTotalSize)) into your macOS Trash."),
                primaryButton: .destructive(Text("Move to Trash")) {
                    uninstaller.uninstallApp(app)
                },
                secondaryButton: .cancel(Text("Cancel"))
            )
        }
    }

    private func appRow(_ app: InstalledAppInfo) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ThingsTheme.textPrimary)
                    .lineLimit(1)

                Text("v\(app.version)")
                    .font(.system(size: 10))
                    .foregroundStyle(ThingsTheme.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(app.formattedTotalSize)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ThingsTheme.textPrimary)

                if !app.residueItems.isEmpty {
                    Text("\(app.residueItems.count) residue items")
                        .font(.system(size: 9))
                        .foregroundStyle(ThingsTheme.accent)
                }
            }
        }
        .padding(.vertical, 3)
    }

    private func appDetailPane(_ app: InstalledAppInfo) -> some View {
        VStack(spacing: 0) {
            // App Header Card
            HStack(spacing: 14) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(app.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(ThingsTheme.textPrimary)

                        ThingsTag("v\(app.version)", color: ThingsTheme.infoIndigo)
                    }

                    Text(app.bundleIdentifier)
                        .font(.system(size: 11))
                        .foregroundStyle(ThingsTheme.textSecondary)

                    Text(app.bundleURL.path)
                        .font(.system(size: 10))
                        .foregroundStyle(ThingsTheme.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(app.formattedTotalSize)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(ThingsTheme.accent)

                    Text("Total Space Reclaimable")
                        .font(.system(size: 10))
                        .foregroundStyle(ThingsTheme.textTertiary)
                }
            }
            .padding(20)
            .background(ThingsTheme.card)

            Divider().background(ThingsTheme.borderSubtle)

            // Residue Breakdown List
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("PACKAGE FILES & ASSOCIATED RESIDUE")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(ThingsTheme.textTertiary)
                        .tracking(0.5)

                    // 1. Application Bundle
                    residueRow(
                        name: "\(app.name).app (Executable Bundle)",
                        path: app.bundleURL.path,
                        size: app.appSize,
                        category: "Application",
                        isChecked: true
                    )

                    // 2. Residue Items
                    if app.residueItems.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(ThingsTheme.accent)
                            Text("No external Application Support or Cache clutter detected for this app.")
                                .font(.system(size: 11))
                                .foregroundStyle(ThingsTheme.textSecondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ThingsTheme.cardRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        ForEach(app.residueItems) { item in
                            residueRow(
                                name: item.name,
                                path: item.path,
                                size: item.size,
                                category: item.categoryName,
                                isChecked: item.isChecked
                            )
                        }
                    }
                }
                .padding(20)
            }

            Divider().background(ThingsTheme.borderSubtle)

            // Action Footer
            HStack {
                Button {
                    NSWorkspace.shared.selectFile(app.bundleURL.path, inFileViewerRootedAtPath: "")
                } label: {
                    Text("Reveal in Finder")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ThingsTheme.cardRaised)
                        .foregroundStyle(ThingsTheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    showingUninstallAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Uninstall & Move All to Trash")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(ThingsTheme.accent)
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(ThingsTheme.sidebar)
        }
    }

    private func residueRow(name: String, path: String, size: Int64, category: String, isChecked: Bool) -> some View {
        HStack(spacing: 10) {
            ThingsCheckbox(isChecked: isChecked) {}
                .disabled(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(ThingsTheme.textPrimary)
                        .lineLimit(1)

                    ThingsTag(category, color: ThingsTheme.infoIndigo)
                }

                Text(path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                    .font(.system(size: 10))
                    .foregroundStyle(ThingsTheme.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ThingsTheme.textPrimary)
        }
        .padding(10)
        .background(ThingsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(ThingsTheme.border, lineWidth: 1)
        )
    }
}
