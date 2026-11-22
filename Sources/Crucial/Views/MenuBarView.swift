import SwiftUI
import AppKit

public struct MenuBarView: View {
    @ObservedObject var scanner = FileScannerService.shared
    @ObservedObject var trashService = SafetyTrashService.shared
    @ObservedObject var cpuMonitor = CPUMonitorService.shared
    @ObservedObject var windowManager = WindowManager.shared
    @State private var showingCleanAlert = false
    @State private var cleanResultAlert: String?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Things 3 Mini Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(ThingsTheme.accent.opacity(0.15))
                        .frame(width: 26, height: 26)

                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ThingsTheme.accent)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Crucial")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ThingsTheme.textPrimary)

                    Text("Storage Intelligence")
                        .font(.system(size: 10))
                        .foregroundStyle(ThingsTheme.textSecondary)
                }

                Spacer()

                if scanner.isScanning {
                    ProgressView().scaleEffect(0.65)
                } else {
                    Button {
                        Task {
                            await scanner.scanQuickCleanDashboard()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ThingsTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Rescan Storage")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(ThingsTheme.sidebar)

            Divider().background(ThingsTheme.borderSubtle)

            // MARK: - Things 3 Circular Progress Gauge Card
            HStack(spacing: 14) {
                ThingsProgressRing(
                    progress: scanner.usedDiskPercent,
                    size: 46,
                    strokeWidth: 4,
                    tintColor: scanner.usedDiskPercent > 0.85 ? ThingsTheme.vitalCrimson : ThingsTheme.accent,
                    backgroundColor: ThingsTheme.border
                )
                .overlay(
                    Text("\(Int(scanner.usedDiskPercent * 100))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ThingsTheme.textPrimary)
                )

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Macintosh HD")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ThingsTheme.textPrimary)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: scanner.diskFreeBytes, countStyle: .file) + " free")
                            .font(.system(size: 11))
                            .foregroundStyle(ThingsTheme.textSecondary)
                    }

                    HStack(spacing: 6) {
                        Text(ByteCountFormatter.string(fromByteCount: scanner.totalCleanableBytes, countStyle: .file) + " cleanable")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ThingsTheme.accent)

                        Text("·")
                            .foregroundStyle(ThingsTheme.textTertiary)

                        Circle()
                            .fill(cpuMonitor.cpuPercent > 20 ? ThingsTheme.starOchre : ThingsTheme.accent)
                            .frame(width: 4, height: 4)

                        Text("CPU \(String(format: "%.0f%%", cpuMonitor.cpuPercent))")
                            .font(.system(size: 9.5))
                            .foregroundStyle(ThingsTheme.textTertiary)
                    }
                }
            }
            .padding(14)
            .background(ThingsTheme.card)

            Divider().background(ThingsTheme.borderSubtle)

            // MARK: - Categories Breakdown
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(JunkCategory.allCases.filter { $0 != .custom }) { cat in
                        let items = scanner.itemsByCategory[cat] ?? []
                        let size = items.reduce(0) { $0 + $1.size }

                        Button {
                            windowManager.selectedNav = .category(cat)
                            windowManager.openMainWindow()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: cat.iconName)
                                    .font(.system(size: 12))
                                    .foregroundStyle(cat.color)
                                    .frame(width: 16)

                                Text(cat.rawValue)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(ThingsTheme.textPrimary)

                                Spacer()

                                if size > 0 {
                                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(ThingsTheme.textSecondary)

                                    ThingsProgressRing(
                                        progress: 1.0,
                                        size: 10,
                                        strokeWidth: 2,
                                        tintColor: cat.color,
                                        backgroundColor: ThingsTheme.border
                                    )
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(ThingsTheme.cardRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
            }

            Divider().background(ThingsTheme.borderSubtle)

            // MARK: - Action Footer
            VStack(spacing: 8) {
                if scanner.totalCleanableBytes > 0 {
                    Button {
                        showingCleanAlert = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .bold))
                            Text("Clean Safe Junk (\(ByteCountFormatter.string(fromByteCount: scanner.totalCleanableBytes, countStyle: .file)))")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(ThingsTheme.accent)
                        .foregroundStyle(Color.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    Button {
                        windowManager.selectedNav = .assistant
                        windowManager.openMainWindow()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 10))
                            Text("Assistant")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(ThingsTheme.cardRaised)
                        .foregroundStyle(ThingsTheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)

                    Button {
                        windowManager.openMainWindow()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "macwindow")
                                .font(.system(size: 10))
                            Text("Open App")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(ThingsTheme.cardRaised)
                        .foregroundStyle(ThingsTheme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(ThingsTheme.sidebar)
        }
        .frame(width: 320, height: 420)
        .background(ThingsTheme.canvas)
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
                message: Text("Crucial will safely move disposable build artifacts and caches to macOS Trash."),
                primaryButton: .destructive(Text("Move to Trash")) {
                    for cat in JunkCategory.allCases {
                        scanner.selectSafeOnly(in: cat)
                    }
                    let res = scanner.cleanSelected()
                    cleanResultAlert = "Reclaimed \(ByteCountFormatter.string(fromByteCount: res.bytesFreed, countStyle: .file))."
                },
                secondaryButton: .cancel()
            )
        }
    }
}
