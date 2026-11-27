import SwiftUI

/// Right-hand detail pane displaying an application's bundle, residue items, and native uninstall confirmation.
public struct AppDetailPaneView: View {
    public let app: InstalledAppInfo

    @Environment(AppUninstallerService.self) private var uninstaller
    @State private var showUninstallConfirmation = false

    public init(app: InstalledAppInfo) {
        self.app = app
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: CrucialSpacing.lg) {
                    if let result = uninstaller.lastResult, result.appName == app.name {
                        resultNotice(result)
                    }

                    if app.isSystemProtected {
                        protectedBanner
                    }

                    bundleSection

                    residueSection
                }
                .padding(CrucialSpacing.xl)
            }
        }
        .background(CrucialTheme.canvas)
        .confirmationDialog(
            "Uninstall Selected Components of \(app.name)?",
            isPresented: $showUninstallConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                "Move \(app.formattedReclaimableSize) to Trash",
                role: .destructive
            ) {
                Task { _ = await uninstaller.uninstallApp(app) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The application bundle (if selected) and checked support files will be moved to macOS Trash.")
        }
    }

    private var headerBar: some View {
        HStack(spacing: CrucialSpacing.md) {
            FileIconImage(path: app.bundleURL.path, size: 44)

            VStack(alignment: .leading, spacing: CrucialSpacing.xxs) {
                HStack(spacing: CrucialSpacing.sm) {
                    Text(app.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(CrucialTheme.textPrimary)

                    if app.isRunning {
                        CrucialTag("Running", color: CrucialTheme.starOchre)
                    }
                }

                Text("\(app.bundleIdentifier)  |  Version \(app.version)")
                    .font(.caption)
                    .foregroundStyle(CrucialTheme.textSecondary)
            }

            Spacer()

            if app.isRunning && !app.isSystemProtected {
                Button {
                    Task { _ = await uninstaller.quitApplication(app) }
                } label: {
                    if uninstaller.isQuittingApp {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Quit App")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(uninstaller.isQuittingApp)
            }

            Button(role: .destructive) {
                showUninstallConfirmation = true
            } label: {
                Label("Move \(app.formattedReclaimableSize) to Trash", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(CrucialTheme.vitalCrimson)
            .disabled(app.reclaimableBytes == 0 || (app.isRunning && app.isBundleSelected && !app.isSystemProtected))
        }
        .padding(CrucialSpacing.lg)
        .background(CrucialTheme.card)
    }

    @ViewBuilder
    private func resultNotice(_ result: UninstallResult) -> some View {
        HStack(spacing: CrucialSpacing.sm) {
            Image(systemName: result.succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(result.succeeded ? CrucialTheme.accentInk : CrucialTheme.starOchre)

            if let errorMessage = result.errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(CrucialTheme.textPrimary)
            } else {
                Text("Moved \(result.itemsTrashed) items (\(ByteCountFormatter.string(fromByteCount: result.bytesFreed, countStyle: .file))) to Trash.")
                    .font(.subheadline)
                    .foregroundStyle(CrucialTheme.textPrimary)
            }
        }
        .padding(CrucialSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CrucialTheme.card, in: .rect(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(CrucialTheme.border, lineWidth: 1)
        }
    }

    private var protectedBanner: some View {
        HStack(spacing: CrucialSpacing.sm) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(CrucialTheme.vitalCrimson)

            Text(app.protectionReason ?? "Protected macOS application bundle. Only non-system user caches can be selected.")
                .font(.subheadline)
                .foregroundStyle(CrucialTheme.textPrimary)
        }
        .padding(CrucialSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CrucialTheme.card, in: .rect(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(CrucialTheme.border, lineWidth: 1)
        }
    }

    private var bundleSection: some View {
        VStack(alignment: .leading, spacing: CrucialSpacing.sm) {
            Text("Application Bundle")
                .font(.headline)
                .foregroundStyle(CrucialTheme.textPrimary)

            HStack(spacing: CrucialSpacing.md) {
                if app.isSystemProtected {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(CrucialTheme.vitalCrimson)
                        .frame(width: 24, height: 24)
                } else {
                    CrucialCheckbox(
                        isSelected: app.isBundleSelected,
                        label: "Include \(app.name) application bundle"
                    ) {
                        uninstaller.toggleBundleSelection(appID: app.id)
                    }
                }

                FileIconImage(path: app.bundleURL.path, size: 28)

                VStack(alignment: .leading, spacing: CrucialSpacing.xxs) {
                    Text(app.bundleURL.lastPathComponent)
                        .font(.body.weight(.medium))
                        .foregroundStyle(CrucialTheme.textPrimary)

                    Text(app.bundleURL.path)
                        .font(.caption)
                        .foregroundStyle(CrucialTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Text(ByteCountFormatter.string(fromByteCount: app.appSize, countStyle: .file))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(CrucialTheme.textPrimary)
            }
            .padding(CrucialSpacing.md)
            .background(CrucialTheme.card, in: .rect(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(CrucialTheme.border, lineWidth: 1)
            }
        }
    }

    private var residueSection: some View {
        VStack(alignment: .leading, spacing: CrucialSpacing.sm) {
            HStack {
                Text("Associated Support Files (\(app.residueItems.count))")
                    .font(.headline)
                    .foregroundStyle(CrucialTheme.textPrimary)

                Spacer()

                if !app.residueItems.isEmpty {
                    Button("Select All") {
                        uninstaller.toggleAllResidue(appID: app.id, checked: true)
                    }
                    .buttonStyle(.borderless)

                    Button("Clear") {
                        uninstaller.toggleAllResidue(appID: app.id, checked: false)
                    }
                    .buttonStyle(.borderless)
                }
            }

            if app.residueItems.isEmpty {
                Text("No associated caches, preferences, or container folders found in ~/Library.")
                    .font(.subheadline)
                    .foregroundStyle(CrucialTheme.textSecondary)
                    .padding(CrucialSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CrucialTheme.card, in: .rect(cornerRadius: 8, style: .continuous))
            } else {
                VStack(spacing: CrucialSpacing.xs) {
                    ForEach(app.residueItems) { residue in
                        AppResidueRowView(appID: app.id, residue: residue)
                    }
                }
            }
        }
    }
}
