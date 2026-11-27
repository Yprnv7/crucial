import SwiftUI

/// Primary overview combining live disk telemetry, Full Disk Access readiness, and category drill-downs.
public struct DashboardView: View {
    @Environment(FileScannerService.self) private var scanner
    @Environment(NavigationStore.self) private var navigation
    @Environment(PermissionsService.self) private var permissions

    @State private var showCleanConfirmation = false
    @State private var lastCleanSummary: String?

    private let dashboardCategories: [JunkCategory] = [
        .devArtifacts,
        .systemCache,
        .appResidue,
        .largeUnused
    ]

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CrucialSpacing.xl) {
                if !permissions.hasFullDiskAccess {
                    FullDiskAccessBanner(
                        onOpenSettings: { permissions.openFullDiskAccessSettings() },
                        onRefresh: { permissions.checkPermissions() }
                    )
                }

                DashboardSummaryCard(
                    onRescan: {
                        Task { await scanner.scanQuickCleanDashboard() }
                    },
                    onRequestClean: {
                        showCleanConfirmation = true
                    }
                )

                if let summary = lastCleanSummary {
                    CleanResultNotice(message: summary) {
                        lastCleanSummary = nil
                    }
                }

                VStack(alignment: .leading, spacing: CrucialSpacing.md) {
                    Text("Cleanup Categories")
                        .font(.headline)
                        .foregroundStyle(CrucialTheme.textPrimary)

                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 280, maximum: 480), spacing: CrucialSpacing.lg)
                        ],
                        spacing: CrucialSpacing.lg
                    ) {
                        ForEach(dashboardCategories) { category in
                            let items = scanner.itemsByCategory[category] ?? []
                            CategoryGridCard(
                                category: category,
                                items: items,
                                isScanning: scanner.isScanning
                            ) {
                                navigation.openCategory(category)
                            }
                        }
                    }
                }
            }
            .padding(CrucialSpacing.xl)
        }
        .background(CrucialTheme.canvas)
        .confirmationDialog(
            "Move Selected Items to Trash?",
            isPresented: $showCleanConfirmation,
            titleVisibility: .visible
        ) {
            let selection = scanner.getSelectedCountAndBytes()
            Button(
                "Move \(selection.count) Items (\(ByteCountFormatter.string(fromByteCount: selection.bytes, countStyle: .file))) to Trash",
                role: .destructive
            ) {
                let result = scanner.cleanSelected()
                let freedText = ByteCountFormatter.string(fromByteCount: result.bytesFreed, countStyle: .file)
                if result.failed > 0 {
                    lastCleanSummary = "Moved \(result.succeeded) items (\(freedText)) to Trash. \(result.failed) protected or locked items were skipped."
                } else {
                    lastCleanSummary = "Moved \(result.succeeded) items (\(freedText)) to Trash safely."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All selected files are sent to macOS Trash and can be restored from Finder if needed.")
        }
        .task {
            permissions.checkPermissions()
            if scanner.itemsByCategory.isEmpty && !scanner.isScanning {
                await scanner.scanQuickCleanDashboard()
            }
        }
    }
}

private struct FullDiskAccessBanner: View {
    let onOpenSettings: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: CrucialSpacing.md) {
            Image(systemName: "lock.shield")
                .font(.title2)
                .foregroundStyle(CrucialTheme.starOchre)

            VStack(alignment: .leading, spacing: CrucialSpacing.xxs) {
                Text("Full Disk Access Recommended")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CrucialTheme.textPrimary)

                Text("Grant Full Disk Access in System Settings so Crucial can measure ~/Library caches, Mail attachments, and application containers accurately.")
                    .font(.caption)
                    .foregroundStyle(CrucialTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button("Open Settings", action: onOpenSettings)
                .buttonStyle(.borderedProminent)
                .tint(CrucialTheme.starOchre)

            Button("Recheck", action: onRefresh)
                .buttonStyle(.bordered)
        }
        .padding(CrucialSpacing.lg)
        .background(CrucialTheme.card, in: .rect(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(CrucialTheme.border, lineWidth: 1)
        }
    }
}

private struct DashboardSummaryCard: View {
    @Environment(FileScannerService.self) private var scanner

    let onRescan: () -> Void
    let onRequestClean: () -> Void

    private static let primaryButtonFill = Color(red: 0.031, green: 0.478, blue: 0.384) // #087A62

    var body: some View {
        let selected = scanner.getSelectedCountAndBytes()
        let formattedTotal = ByteCountFormatter.string(fromByteCount: scanner.diskTotalBytes, countStyle: .file)
        let formattedFree = ByteCountFormatter.string(fromByteCount: scanner.diskFreeBytes, countStyle: .file)
        let formattedCleanable = ByteCountFormatter.string(fromByteCount: scanner.totalCleanableBytes, countStyle: .file)
        let formattedSelected = ByteCountFormatter.string(fromByteCount: selected.bytes, countStyle: .file)

        HStack(spacing: CrucialSpacing.xl) {
            CrucialProgressRing(
                progress: scanner.usedDiskPercent,
                color: scanner.usedDiskPercent > 0.85 ? CrucialTheme.vitalCrimson : CrucialTheme.accent,
                lineWidth: 11,
                size: 104,
                centerTitle: "\(Int((scanner.usedDiskPercent * 100).rounded()))%",
                centerSubtitle: "Used"
            )

            VStack(alignment: .leading, spacing: CrucialSpacing.sm) {
                HStack(spacing: CrucialSpacing.sm) {
                    Text(scanner.hardwareInfo.volumeName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(CrucialTheme.textPrimary)

                    CrucialTag(scanner.hardwareInfo.fileSystem, color: CrucialTheme.textSecondary)

                    CrucialTag(scanner.hardwareInfo.smartStatus, color: CrucialTheme.accentInk)
                }

                Text("\(formattedFree) free of \(formattedTotal)  |  \(formattedCleanable) reclaimable found")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(CrucialTheme.textSecondary)

                if scanner.isScanning {
                    HStack(spacing: CrucialSpacing.sm) {
                        ProgressView()
                            .controlSize(.small)
                        Text(scanner.scanProgressMessage)
                            .font(.caption)
                            .foregroundStyle(CrucialTheme.accentInk)
                    }
                    .padding(.top, CrucialSpacing.xs)
                } else {
                    HStack(spacing: CrucialSpacing.md) {
                        Button(action: onRescan) {
                            Label("Scan Storage", systemImage: "arrow.clockwise")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, CrucialSpacing.md)
                                .padding(.vertical, CrucialSpacing.sm)
                                .background(CrucialTheme.cardRaised, in: .rect(cornerRadius: 7, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .strokeBorder(CrucialTheme.border, lineWidth: 1)
                                }
                                .foregroundStyle(CrucialTheme.textPrimary)
                        }
                        .buttonStyle(PressableButtonStyle())

                        if selected.count > 0 {
                            Button(action: onRequestClean) {
                                Label("Clean \(selected.count) Safe Items (\(formattedSelected))", systemImage: "trash")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, CrucialSpacing.lg)
                                    .padding(.vertical, CrucialSpacing.sm)
                                    .background(Self.primaryButtonFill, in: .rect(cornerRadius: 7, style: .continuous))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                    .padding(.top, CrucialSpacing.xs)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(CrucialSpacing.xl)
        .background(CrucialTheme.card, in: .rect(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(CrucialTheme.border, lineWidth: 1)
        }
    }
}

private struct CleanResultNotice: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: CrucialSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(CrucialTheme.accentInk)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(CrucialTheme.textPrimary)

            Spacer()

            Button("Dismiss", action: onDismiss)
                .buttonStyle(.borderless)
                .foregroundStyle(CrucialTheme.textSecondary)
        }
        .padding(CrucialSpacing.md)
        .background(CrucialTheme.card, in: .rect(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(CrucialTheme.border, lineWidth: 1)
        }
    }
}
