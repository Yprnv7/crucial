import Charts
import SwiftUI

/// Interactive Storage Breakdown screen visualizing real volume capacity, APFS telemetry, and cleanup sectors.
public struct DiskSunburstView: View {
    @Environment(FileScannerService.self) private var scanner
    @Environment(NavigationStore.self) private var navigation

    @State private var mode: TreemapMode = .wholeVolume
    @State private var selectedSectorID: String?

    public init() {}

    private var sectors: [DiskSectorItem] {
        switch mode {
        case .wholeVolume:
            return buildWholeVolumeSectors()
        case .cleanableSectors:
            return buildCleanableSectors()
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CrucialSpacing.xl) {
                headerControls

                hardwareSummaryCard

                HStack(alignment: .top, spacing: CrucialSpacing.xl) {
                    chartPanel
                        .frame(width: 300)

                    sectorListPanel
                }
            }
            .padding(CrucialSpacing.xl)
        }
        .background(CrucialTheme.canvas)
    }

    private var headerControls: some View {
        HStack {
            VStack(alignment: .leading, spacing: CrucialSpacing.xxs) {
                Text("Storage Breakdown")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(CrucialTheme.textPrimary)

                Text("Live volume capacity and category footprint across \(scanner.hardwareInfo.volumeName).")
                    .font(.subheadline)
                    .foregroundStyle(CrucialTheme.textSecondary)
            }

            Spacer()

            Picker("View Mode", selection: $mode) {
                ForEach(TreemapMode.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
        }
    }

    private var hardwareSummaryCard: some View {
        let hw = scanner.hardwareInfo
        return HStack(spacing: CrucialSpacing.xl) {
            VitalStatColumn(title: "Volume", value: hw.volumeName, detail: hw.fileSystem)
            VitalStatColumn(title: "Media", value: hw.isSolidState ? "Solid State (SSD)" : "Rotational Drive", detail: "SMART: \(hw.smartStatus)")
            VitalStatColumn(title: "Applications", value: ByteCountFormatter.string(fromByteCount: hw.applicationsBytes, countStyle: .file), detail: "/Applications")
            VitalStatColumn(title: "Personal Media", value: ByteCountFormatter.string(fromByteCount: hw.userMediaBytes, countStyle: .file), detail: "Home folders")
            VitalStatColumn(title: "Available", value: ByteCountFormatter.string(fromByteCount: hw.freeBytes, countStyle: .file), detail: "Purgeable included")
        }
        .padding(CrucialSpacing.lg)
        .background(CrucialTheme.card, in: .rect(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(CrucialTheme.border, lineWidth: 1)
        }
    }

    private var chartPanel: some View {
        VStack(spacing: CrucialSpacing.md) {
            if sectors.isEmpty {
                ContentUnavailableView {
                    Label("No Measured Data", systemImage: "chart.pie")
                } description: {
                    Text("Run a storage scan to populate cleanable sector sizes.")
                }
                .frame(height: 260)
            } else {
                ZStack {
                    Chart(sectors) { sector in
                        SectorMark(
                            angle: .value("Size", max(1, sector.size)),
                            innerRadius: .ratio(0.58),
                            angularInset: 2
                        )
                        .foregroundStyle(sector.color)
                        .opacity(selectedSectorID == nil || selectedSectorID == sector.id ? 1.0 : 0.45)
                        .cornerRadius(4)
                    }
                    .frame(height: 260)

                    VStack(spacing: CrucialSpacing.xxs) {
                        Text(mode == .wholeVolume ? "Used Space" : "Reclaimable")
                            .font(.caption)
                            .foregroundStyle(CrucialTheme.textSecondary)

                        let centerBytes = mode == .wholeVolume
                            ? scanner.hardwareInfo.usedBytes
                            : scanner.totalCleanableBytes

                        Text(ByteCountFormatter.string(fromByteCount: centerBytes, countStyle: .file))
                            .font(.headline.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(CrucialTheme.textPrimary)
                    }
                }
            }
        }
        .padding(CrucialSpacing.lg)
        .background(CrucialTheme.card, in: .rect(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(CrucialTheme.border, lineWidth: 1)
        }
    }

    private var sectorListPanel: some View {
        VStack(alignment: .leading, spacing: CrucialSpacing.sm) {
            Text(mode == .wholeVolume ? "Volume Allocation" : "Reclaimable Sectors")
                .font(.headline)
                .foregroundStyle(CrucialTheme.textPrimary)

            if sectors.isEmpty {
                Text("No sectors recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(CrucialTheme.textSecondary)
            } else {
                ForEach(sectors) { sector in
                    DiskSectorRowView(
                        sector: sector,
                        isSelected: selectedSectorID == sector.id
                    ) {
                        selectedSectorID = sector.id
                        if let nav = sector.targetNav {
                            navigation.navigate(to: nav)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func buildWholeVolumeSectors() -> [DiskSectorItem] {
        let hw = scanner.hardwareInfo
        let total = max(Int64(1), hw.totalBytes)
        let dev = max(hw.developerCachesBytes, sumBytes(for: .devArtifacts))
        let caches = sumBytes(for: .systemCache)
        let apps = hw.applicationsBytes
        let media = hw.userMediaBytes
        let free = hw.freeBytes
        let accounted = apps + media + dev + caches + free
        let systemAndOther = max(Int64(0), total - accounted)

        let raw: [(String, Int64, Color, String, String, CrucialNavSection?)] = [
            ("Applications", apps, CrucialTheme.cobalt, "square.stack.3d.up", "Bundles in /Applications", .uninstaller),
            ("User Media & Documents", media, CrucialTheme.glacierCyan, "person.crop.rectangle", "Desktop, Documents, Downloads, Pictures, Movies", .fileFinder),
            ("Developer Build Caches", dev, CrucialTheme.accent, "hammer", "Xcode DerivedData, node_modules, target, and .venv", .category(.devArtifacts)),
            ("System & User Caches", caches, CrucialTheme.starOchre, "internaldrive", "Application caches and diagnostic logs", .category(.systemCache)),
            ("macOS System & Other Data", systemAndOther, CrucialTheme.slateBlue, "macstudio", "APFS system snapshot, frameworks, and container volumes", nil),
            ("Free Space", free, CrucialTheme.border, "checkmark.circle", "Immediately available capacity", nil)
        ]

        return raw.filter { $0.1 > 0 }.map { entry in
            DiskSectorItem(
                name: entry.0,
                size: entry.1,
                percentage: (Double(entry.1) / Double(total)) * 100.0,
                color: entry.2,
                iconName: entry.3,
                description: entry.4,
                targetNav: entry.5
            )
        }
    }

    private func buildCleanableSectors() -> [DiskSectorItem] {
        let categories: [JunkCategory] = [.devArtifacts, .systemCache, .appResidue, .largeUnused]
        let total = max(Int64(1), categories.reduce(0) { $0 + sumBytes(for: $1) })

        return categories.compactMap { category in
            let size = sumBytes(for: category)
            guard size > 0 else { return nil }
            return DiskSectorItem(
                name: category.rawValue,
                size: size,
                percentage: (Double(size) / Double(total)) * 100.0,
                color: category.color,
                iconName: category.iconName,
                description: category.description,
                targetNav: .category(category)
            )
        }
    }

    private func sumBytes(for category: JunkCategory) -> Int64 {
        (scanner.itemsByCategory[category] ?? []).reduce(0) { $0 + $1.size }
    }
}
