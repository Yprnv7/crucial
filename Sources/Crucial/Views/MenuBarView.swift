import SwiftUI
import AppKit

public struct MenuBarView: View {
    @ObservedObject var scanner = FileScannerService.shared
    @ObservedObject var trashService = SafetyTrashService.shared
    @State private var showingFinder = false
    @State private var showingSettings = false
    @State private var showingCleanAlert = false
    @State private var cleanResultAlert: String?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerSection
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

            Divider()

            // Disk Usage Gauge
            diskGaugeSection
                .padding(14)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))

            Divider()

            // Category Overview
            if scanner.isScanning {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.9)
                    Text(scanner.scanProgressMessage)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 30)
            } else {
                categoriesSection
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }

            Divider()

            // Bottom Action Bar
            actionFooter
                .padding(12)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 360, height: 480)
        .onAppear {
            if scanner.totalCleanableBytes == 0 && !scanner.isScanning {
                Task {
                    await scanner.scanQuickCleanDashboard()
                }
            }
        }
        .alert(isPresented: $showingCleanAlert) {
            Alert(
                title: Text("Clean Safe Files?"),
                message: Text("Crucial will safely move the selected items to your macOS Trash. You can restore them anytime."),
                primaryButton: .destructive(Text("Move to Trash")) {
                    cleanSelectedItems()
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.shield.fill")
                .font(.system(size: 20))
                .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Crucial")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("v1.0")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(4)
                }
                Text("Mac Junk Cleaner & File Finder")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await scanner.scanQuickCleanDashboard()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("Rescan Mac")

            Button {
                WindowManager.shared.openSettingsWindow()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("Crucial Settings")
        }
    }

    private var diskGaugeSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Macintosh HD")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(Int(scanner.usedDiskPercent * 100))% Used")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(scanner.usedDiskPercent > 0.85 ? .red : .secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 7)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: scanner.usedDiskPercent > 0.85 ? [.orange, .red] : [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(scanner.usedDiskPercent), height: 7)
                }
            }
            .frame(height: 7)

            HStack {
                Text("Free: \(ByteCountFormatter.string(fromByteCount: scanner.diskFreeBytes, countStyle: .file))")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    Text("\(ByteCountFormatter.string(fromByteCount: scanner.totalCleanableBytes, countStyle: .file)) Cleanable")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                }
            }
        }
    }

    private var categoriesSection: some View {
        ScrollView {
            VStack(spacing: 6) {
                categoryCard(
                    category: .devArtifacts,
                    title: "Developer Caches",
                    subtitle: "node_modules, DerivedData, .venv",
                    items: scanner.itemsByCategory[.devArtifacts] ?? []
                )

                categoryCard(
                    category: .systemCache,
                    title: "System & User Caches",
                    subtitle: "~/Library/Caches & logs",
                    items: scanner.itemsByCategory[.systemCache] ?? []
                )

                categoryCard(
                    category: .largeUnused,
                    title: "Large Idle Downloads",
                    subtitle: "DMGs, PKGs > 200MB",
                    items: scanner.itemsByCategory[.largeUnused] ?? []
                )

                categoryCard(
                    category: .appResidue,
                    title: "Leftover App Residue",
                    subtitle: "Uninstalled application folders",
                    items: scanner.itemsByCategory[.appResidue] ?? []
                )
            }
        }
    }

    private func categoryCard(category: JunkCategory, title: String, subtitle: String, items: [FileItem]) -> some View {
        let totalSize = items.reduce(0) { $0 + $1.size }
        let formatted = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)

        return HStack(spacing: 10) {
            Image(systemName: category.iconName)
                .font(.system(size: 14))
                .foregroundStyle(category.color)
                .frame(width: 26, height: 26)
                .background(category.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatted)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(totalSize > 0 ? .primary : .secondary)

                Text("\(items.count) items")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(8)
    }

    private var actionFooter: some View {
        HStack(spacing: 8) {
            Button {
                showingCleanAlert = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                    Text("Clean Safe (\(ByteCountFormatter.string(fromByteCount: scanner.totalCleanableBytes, countStyle: .file)))")
                        .fontWeight(.semibold)
                }
                .font(.system(size: 12))
                .frame(maxWidth: .infinity)
                .frame(height: 32)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(scanner.totalCleanableBytes == 0 || scanner.isScanning)

            Button {
                WindowManager.shared.openFinderWindow()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                    Text("Finder")
                }
                .font(.system(size: 12, weight: .medium))
                .frame(height: 32)
                .padding(.horizontal, 12)
            }
            .buttonStyle(.bordered)
            .help("Pop out deep File Finder and AI Vitality Inspector")
        }
    }

    private func cleanSelectedItems() {
        var itemsToTrash: [FileItem] = []
        for (_, items) in scanner.itemsByCategory {
            for item in items where item.assessment.level == .safeToDelete {
                itemsToTrash.append(item)
            }
        }

        let result = trashService.trashBatch(items: itemsToTrash)
        scanner.totalCleanableBytes = 0
        cleanResultAlert = "Moved \(result.succeeded) items (\(ByteCountFormatter.string(fromByteCount: result.bytesFreed, countStyle: .file))) to Trash."

        // Rescan after cleaning
        Task {
            await scanner.scanQuickCleanDashboard()
        }
    }
}
