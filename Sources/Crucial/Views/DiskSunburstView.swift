import SwiftUI
import AppKit

public struct DiskSunburstView: View {
    @ObservedObject var scanner = FileScannerService.shared
    @ObservedObject var windowManager = WindowManager.shared
    @State private var hoveredCategory: JunkCategory? = nil

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(ThingsTheme.accent.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ThingsTheme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Visual Storage Treemap")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(ThingsTheme.textPrimary)

                    Text("Proportional hierarchical visualization of cleanable sectors and storage bloat.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(ThingsTheme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(ByteCountFormatter.string(fromByteCount: scanner.totalCleanableBytes, countStyle: .file))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(ThingsTheme.accent)
                    Text("Cleanable Capacity")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ThingsTheme.textTertiary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(ThingsTheme.canvas)

            Divider().background(ThingsTheme.borderSubtle)

            // Main Interactive Treemap View
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Sunburst Overview Ring & Summary Card
                    HStack(spacing: 24) {
                        // Things 3 Multi-Segment Ring
                        ZStack {
                            Circle()
                                .stroke(ThingsTheme.border, lineWidth: 16)
                                .frame(width: 130, height: 130)

                            let total = Double(max(scanner.totalCleanableBytes, 1))
                            let devBytes = Double((scanner.itemsByCategory[.devArtifacts] ?? []).reduce(0) { $0 + $1.size })
                            let cacheBytes = Double((scanner.itemsByCategory[.systemCache] ?? []).reduce(0) { $0 + $1.size })
                            let residueBytes = Double((scanner.itemsByCategory[.appResidue] ?? []).reduce(0) { $0 + $1.size })
                            let largeBytes = Double((scanner.itemsByCategory[.largeUnused] ?? []).reduce(0) { $0 + $1.size })

                            // Segment 1: Dev
                            Circle()
                                .trim(from: 0.0, to: CGFloat(devBytes / total))
                                .stroke(ThingsTheme.infoIndigo, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 130, height: 130)

                            // Segment 2: Caches
                            Circle()
                                .trim(from: CGFloat(devBytes / total), to: CGFloat((devBytes + cacheBytes) / total))
                                .stroke(ThingsTheme.glacierCyan, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 130, height: 130)

                            // Segment 3: Residue
                            Circle()
                                .trim(from: CGFloat((devBytes + cacheBytes) / total), to: CGFloat((devBytes + cacheBytes + residueBytes) / total))
                                .stroke(ThingsTheme.starOchre, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 130, height: 130)

                            // Segment 4: Large Unused
                            Circle()
                                .trim(from: CGFloat((devBytes + cacheBytes + residueBytes) / total), to: CGFloat(min(1.0, (devBytes + cacheBytes + residueBytes + largeBytes) / total)))
                                .stroke(ThingsTheme.purple, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 130, height: 130)

                            VStack(spacing: 2) {
                                Text(ByteCountFormatter.string(fromByteCount: scanner.totalCleanableBytes, countStyle: .file))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(ThingsTheme.textPrimary)
                                Text("Reclaimable")
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundStyle(ThingsTheme.textSecondary)
                            }
                        }
                        .padding(.leading, 8)

                        // Segment Legend
                        VStack(alignment: .leading, spacing: 10) {
                            legendRow(category: .devArtifacts, color: ThingsTheme.infoIndigo)
                            legendRow(category: .systemCache, color: ThingsTheme.glacierCyan)
                            legendRow(category: .appResidue, color: ThingsTheme.starOchre)
                            legendRow(category: .largeUnused, color: ThingsTheme.purple)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(20)
                    .background(ThingsTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ThingsTheme.border, lineWidth: 1))

                    // Proportional Treemap Tiles
                    VStack(alignment: .leading, spacing: 10) {
                        Text("PROPORTIONAL SECTOR BLOCKS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ThingsTheme.textTertiary)
                            .tracking(0.5)

                        ForEach(JunkCategory.allCases.filter { $0 != .custom }) { cat in
                            let items = scanner.itemsByCategory[cat] ?? []
                            let size = items.reduce(0) { $0 + $1.size }
                            let percent = scanner.totalCleanableBytes > 0 ? (Double(size) / Double(scanner.totalCleanableBytes)) : 0.0

                            Button {
                                windowManager.selectedNav = .category(cat)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(categoryColor(cat))
                                                .frame(width: 8, height: 8)

                                            Text(cat.rawValue)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(ThingsTheme.textPrimary)
                                        }

                                        Spacer()

                                        Text(String(format: "%.1f%%", percent * 100))
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(ThingsTheme.textSecondary)

                                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(ThingsTheme.textPrimary)
                                    }

                                    // Proportional Bar
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(ThingsTheme.borderSubtle)
                                                .frame(height: 8)

                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(categoryColor(cat))
                                                .frame(width: max(4, geo.size.width * CGFloat(percent)), height: 8)
                                        }
                                    }
                                    .frame(height: 8)
                                }
                                .padding(14)
                                .background(ThingsTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(ThingsTheme.border, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThingsTheme.canvas)
    }

    private func legendRow(category: JunkCategory, color: Color) -> some View {
        let items = scanner.itemsByCategory[category] ?? []
        let size = items.reduce(0) { $0 + $1.size }
        let percent = scanner.totalCleanableBytes > 0 ? (Double(size) / Double(scanner.totalCleanableBytes)) * 100 : 0

        return HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(category.rawValue)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ThingsTheme.textPrimary)

            Spacer()

            Text("\(Int(percent))%")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ThingsTheme.textSecondary)

            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(ThingsTheme.textPrimary)
        }
    }

    private func categoryColor(_ cat: JunkCategory) -> Color {
        switch cat {
        case .devArtifacts: return ThingsTheme.infoIndigo
        case .systemCache: return ThingsTheme.glacierCyan
        case .appResidue: return ThingsTheme.starOchre
        case .largeUnused: return ThingsTheme.purple
        case .duplicates: return ThingsTheme.accent
        case .custom: return ThingsTheme.accent
        }
    }
}
