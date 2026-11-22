import SwiftUI
import AppKit

public struct MainWindowView: View {
    @ObservedObject var windowManager = WindowManager.shared
    @ObservedObject var scanner = FileScannerService.shared
    @ObservedObject var trashService = SafetyTrashService.shared
    @ObservedObject var cpuMonitor = CPUMonitorService.shared

    @State private var searchText: String = ""
    @State private var filterLevel: VitalityLevel? = nil
    @State private var showingTrashAlert: Bool = false
    @State private var isAiAnalyzing: Bool = false
    @State private var statusAlertMessage: String? = nil

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // MARK: - 1. Left Sidebar
            sidebarView
                .frame(width: 260)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.85))

            Divider()

            // MARK: - 2. Content Area (Center + Right or Full Pane)
            Group {
                switch windowManager.selectedNav {
                case .dashboard:
                    dashboardView
                case .category(let category):
                    categoryDrilldownView(category: category)
                case .fileFinder:
                    FileFinderView()
                case .settings:
                    SettingsView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1040, minHeight: 680)
        .onAppear {
            if scanner.itemsByCategory.isEmpty && !scanner.isScanning {
                Task {
                    await scanner.scanQuickCleanDashboard()
                    autoSelectFirstItem()
                }
            } else if windowManager.selectedItem == nil {
                autoSelectFirstItem()
            }
        }
        .alert(isPresented: $showingTrashAlert) {
            let info = scanner.getSelectedCountAndBytes()
            return Alert(
                title: Text("Move Selected Items to Trash?"),
                message: Text("Crucial will safely move \(info.count) files (\(ByteCountFormatter.string(fromByteCount: info.bytes, countStyle: .file))) to your macOS Trash. You can restore them anytime."),
                primaryButton: .destructive(Text("Move to Trash")) {
                    let result = scanner.cleanSelected()
                    statusAlertMessage = "Safely moved \(result.succeeded) items to Trash (\(ByteCountFormatter.string(fromByteCount: result.bytesFreed, countStyle: .file)) freed)."
                },
                secondaryButton: .cancel()
            )
        }
    }

    // MARK: - Auto-select helper
    private func autoSelectFirstItem() {
        if case .category(let cat) = windowManager.selectedNav {
            windowManager.selectedItem = scanner.itemsByCategory[cat]?.first
        } else {
            // First item from any category
            for cat in JunkCategory.allCases {
                if let first = scanner.itemsByCategory[cat]?.first {
                    windowManager.selectedItem = first
                    break
                }
            }
        }
    }

    // MARK: - Sidebar View
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // App Branding Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .shadow(color: .purple.opacity(0.4), radius: 6, x: 0, y: 2)

                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Crucial")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text("v1.0")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(4)
                    }
                    Text("Mac Junk Cleaner & Vitality")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            // Storage Gauge Card
            diskGaugeCard
                .padding(14)

            Divider()

            // Navigation Menu
            ScrollView {
                VStack(spacing: 4) {
                    sidebarNavRow(
                        title: "Dashboard",
                        icon: "gauge.with.needle.fill",
                        color: .blue,
                        isSelected: windowManager.selectedNav == .dashboard
                    ) {
                        windowManager.selectedNav = .dashboard
                    }

                    sidebarSectionTitle("CLEANABLE CATEGORIES")
                        .padding(.top, 8)

                    ForEach(JunkCategory.allCases.filter { $0 != .custom }) { cat in
                        let items = scanner.itemsByCategory[cat] ?? []
                        let size = items.reduce(0) { $0 + $1.size }
                        let isSelected = windowManager.selectedNav == .category(cat)

                        sidebarCategoryRow(
                            category: cat,
                            itemsCount: items.count,
                            totalSize: size,
                            isSelected: isSelected
                        ) {
                            windowManager.selectedNav = .category(cat)
                            if let first = items.first {
                                windowManager.selectedItem = first
                            }
                        }
                    }

                    sidebarSectionTitle("TOOLS & SETTINGS")
                        .padding(.top, 8)

                    sidebarNavRow(
                        title: "Deep File Finder",
                        icon: "magnifyingglass",
                        color: .green,
                        isSelected: windowManager.selectedNav == .fileFinder
                    ) {
                        windowManager.selectedNav = .fileFinder
                    }

                    sidebarNavRow(
                        title: "Settings & AI",
                        icon: "gearshape.fill",
                        color: .gray,
                        isSelected: windowManager.selectedNav == .settings
                    ) {
                        windowManager.selectedNav = .settings
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }

            Divider()

            // Bottom Actions (Scan & Clean)
            VStack(spacing: 10) {
                if scanner.isScanning {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(scanner.scanProgressMessage)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 8) {
                    Button {
                        Task {
                            await scanner.scanQuickCleanDashboard()
                            autoSelectFirstItem()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .bold))
                            Text(scanner.isScanning ? "Scanning..." : "Rescan")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.bordered)
                    .disabled(scanner.isScanning)

                    let info = scanner.getSelectedCountAndBytes()
                    Button {
                        showingTrashAlert = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 10))
                            Text(info.bytes > 0 ? ByteCountFormatter.string(fromByteCount: info.bytes, countStyle: .file) : "Clean")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(info.bytes == 0 || scanner.isScanning)
                }
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        }
    }

    private func sidebarSectionTitle(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
    }

    private func sidebarNavRow(
        title: String,
        icon: String,
        color: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 22, height: 22)

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private func sidebarCategoryRow(
        category: JunkCategory,
        itemsCount: Int,
        totalSize: Int64,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: category.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(category.color)
                    .frame(width: 22, height: 22)

                Text(category.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .lineLimit(1)

                Spacer()

                if totalSize > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.12))
                        .cornerRadius(5)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private var diskGaugeCard: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Macintosh HD")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text("\(Int(scanner.usedDiskPercent * 100))% Used")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(scanner.usedDiskPercent > 0.85 ? .red : .secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.18))
                        .frame(height: 6)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: scanner.usedDiskPercent > 0.85 ? [.orange, .red] : [.cyan, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, geo.size.width * CGFloat(scanner.usedDiskPercent)), height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text("Free: \(ByteCountFormatter.string(fromByteCount: scanner.diskFreeBytes, countStyle: .file))")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("✨ \(ByteCountFormatter.string(fromByteCount: scanner.totalCleanableBytes, countStyle: .file)) Cleanable")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.green)
            }

            Divider()
                .padding(.vertical, 2)

            // Real-Time CPU & Pacing Controller
            HStack(spacing: 6) {
                Circle()
                    .fill(cpuMonitor.cpuPercent > 50 ? Color.red : (cpuMonitor.cpuPercent > 15 ? Color.orange : Color.green))
                    .frame(width: 6, height: 6)

                Text(String(format: "CPU: %.1f%%", cpuMonitor.cpuPercent))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(cpuMonitor.cpuPercent > 50 ? Color.red : Color.primary)

                Spacer()

                Menu {
                    Button {
                        scanner.pacingMode = .pacedBurst
                    } label: {
                        Label("🟢 Paced Bursts (~10% CPU)", systemImage: scanner.pacingMode == .pacedBurst ? "checkmark" : "")
                    }

                    Button {
                        scanner.pacingMode = .turbo
                    } label: {
                        Label("🚀 Turbo Full Speed (97% CPU)", systemImage: scanner.pacingMode == .turbo ? "checkmark" : "")
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(scanner.pacingMode == .pacedBurst ? "Paced (10%)" : "Turbo (97%)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(4)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    // MARK: - Dashboard View
    private var dashboardView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Header Welcome Banner
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mac Storage & Vitality Center")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("Crucial isolates disposable build caches, application residue, and large files while safeguarding your critical system files.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    let total = scanner.totalCleanableBytes
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing))
                        Text("Ready to Safely Reclaim")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.bottom, 4)

                // 4 Category Quick-Drilldown Cards
                Text("Junk Categories (Click to inspect individual files)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(JunkCategory.allCases.filter { $0 != .custom }) { cat in
                        let items = scanner.itemsByCategory[cat] ?? []
                        let size = items.reduce(0) { $0 + $1.size }

                        Button {
                            windowManager.selectedNav = .category(cat)
                            if let first = items.first {
                                windowManager.selectedItem = first
                            }
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(cat.color.opacity(0.15))
                                        .frame(width: 48, height: 48)

                                    Image(systemName: cat.iconName)
                                        .font(.system(size: 22))
                                        .foregroundStyle(cat.color)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(cat.rawValue)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(Color.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(cat.description)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)

                                    HStack(spacing: 8) {
                                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundStyle(size > 0 ? cat.color : .secondary)

                                        Text("• \(items.count) files")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.top, 2)
                                }
                            }
                            .padding(14)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Recent Trash History & Undo
                if !trashService.history.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Recently Trashed Items")
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
                            Button("Open macOS Trash") {
                                trashService.openTrash()
                            }
                            .font(.system(size: 11))
                        }

                        VStack(spacing: 6) {
                            ForEach(trashService.history.prefix(5)) { record in
                                HStack {
                                    Image(systemName: "trash.circle")
                                        .foregroundStyle(.secondary)
                                    Text(record.name)
                                        .font(.system(size: 12, weight: .medium))
                                    Spacer()
                                    Text(ByteCountFormatter.string(fromByteCount: record.size, countStyle: .file))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(8)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                                .cornerRadius(6)
                            }
                        }
                    }
                    .padding(.top, 8)
                }

                Spacer()
            }
            .padding(26)
        }
    }

    // MARK: - Category Drilldown (Center File List + Right Vitality Inspector)
    private func categoryDrilldownView(category: JunkCategory) -> some View {
        let allItems = scanner.itemsByCategory[category] ?? []

        let filteredItems = allItems.filter { item in
            let matchesSearch = searchText.isEmpty ||
                item.name.lowercased().contains(searchText.lowercased()) ||
                item.path.lowercased().contains(searchText.lowercased())

            let matchesLevel = filterLevel == nil || item.assessment.level == filterLevel
            return matchesSearch && matchesLevel
        }

        return HSplitView {
            // MARK: Center Pane - Files List
            VStack(spacing: 0) {
                // Category Header Banner
                categoryHeaderBanner(category: category, items: allItems)
                    .padding(16)

                Divider()

                // Filter & Search Controls
                filterControlsBar(category: category, allItems: allItems)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)

                Divider()

                // File List
                if filteredItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 32))
                            .foregroundStyle(.green)
                        Text("No items found in \(category.rawValue)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: Binding(
                        get: { windowManager.selectedItem },
                        set: { newItem in
                            if let newItem {
                                selectItemAndExplain(newItem)
                            }
                        }
                    )) {
                        ForEach(filteredItems) { item in
                            fileRow(item: item, in: category)
                                .tag(item)
                                .contextMenu {
                                    Button("Reveal in Finder") {
                                        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                                    }
                                    Button("Copy Full Path") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(item.path, forType: .string)
                                    }
                                    Divider()
                                    Button("Move to Trash") {
                                        trashIndividualItem(item)
                                    }
                                    .disabled(item.assessment.level == .vital)
                                }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 440, maxWidth: .infinity)

            // MARK: Right Pane - Vitality & AI Inspector
            VStack(spacing: 0) {
                if let item = windowManager.selectedItem {
                    vitalityDetailPane(item: item)
                } else {
                    emptyInspectorPlaceholder
                }
            }
            .frame(minWidth: 360, maxWidth: 460)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }

    // MARK: - Category Header Banner
    private func categoryHeaderBanner(category: JunkCategory, items: [FileItem]) -> some View {
        let totalBytes = items.reduce(0) { $0 + $1.size }
        let selected = items.filter { $0.isSelected }
        let selectedBytes = selected.reduce(0) { $0 + $1.size }

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(category.color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: category.iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(category.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(category.rawValue)
                        .font(.system(size: 17, weight: .bold))
                    Text("\(items.count) files")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(6)
                }

                Text(category.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(category.color)

                if selected.count > 0 {
                    Text("\(selected.count) selected (\(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file)))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.purple)
                }
            }
        }
    }

    // MARK: - Filter & Selection Controls
    private func filterControlsBar(category: JunkCategory, allItems: [FileItem]) -> some View {
        VStack(spacing: 8) {
            // Search Input Field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))

                TextField("Filter files in \(category.rawValue)...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(7)

            // Filter Pills & Batch Selection
            HStack(spacing: 6) {
                // Filter level chips
                filterPill(title: "All", count: allItems.count, isSelected: filterLevel == nil) {
                    filterLevel = nil
                }

                let safeCount = allItems.filter { $0.assessment.level == .safeToDelete }.count
                if safeCount > 0 {
                    filterPill(title: "🟢 Safe", count: safeCount, isSelected: filterLevel == .safeToDelete) {
                        filterLevel = .safeToDelete
                    }
                }

                let cautionCount = allItems.filter { $0.assessment.level == .caution }.count
                if cautionCount > 0 {
                    filterPill(title: "🟡 Review", count: cautionCount, isSelected: filterLevel == .caution) {
                        filterLevel = .caution
                    }
                }

                Spacer()

                // Batch Selection Buttons
                Button("Select Safe") {
                    scanner.selectSafeOnly(in: category)
                }
                .font(.system(size: 10, weight: .semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Select All") {
                    scanner.selectAll(in: category, selected: true)
                }
                .font(.system(size: 10, weight: .semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Deselect All") {
                    scanner.selectAll(in: category, selected: false)
                }
                .font(.system(size: 10, weight: .semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func filterPill(title: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                Text("(\(count))")
                    .font(.system(size: 9, design: .monospaced))
                    .opacity(0.8)
            }
            .font(.system(size: 11, weight: isSelected ? .bold : .regular))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - File Row Component
    private func fileRow(item: FileItem, in category: JunkCategory) -> some View {
        HStack(spacing: 10) {
            // Checkbox for Individual Selection
            Button {
                scanner.toggleSelection(for: item.id, in: category)
            } label: {
                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(item.isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(item.assessment.level == .vital)

            // System Icon
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 24, height: 24)

            // File Name & Path Snippet
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)

                    vitalityBadge(item.assessment.level)
                }

                Text(item.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Metadata Badges (Idle Age + Size)
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.formattedSize)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(item.isSelected ? Color.primary : Color.secondary)

                if item.daysSinceLastAccess > 0 {
                    Text("\(item.daysSinceLastAccess)d idle")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func vitalityBadge(_ level: VitalityLevel) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(level.badgeColor)
                .frame(width: 5, height: 5)
            Text(level.rawValue)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(level.badgeColor)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(level.badgeColor.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Vitality Detail Inspector (Right Column)
    private func vitalityDetailPane(item: FileItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Top Header (Large Icon + Name + Category)
                HStack(spacing: 12) {
                    Image(nsImage: item.icon)
                        .resizable()
                        .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(2)

                        HStack(spacing: 6) {
                            Text(item.category.rawValue)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(item.category.color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(item.category.color.opacity(0.12))
                                .cornerRadius(5)

                            Text(item.formattedSize)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 8)

                Divider()

                // Path with Copy and Reveal
                VStack(alignment: .leading, spacing: 6) {
                    Text("FULL LOCATION")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)

                    HStack {
                        Text(item.path)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .textSelection(.enabled)

                        Spacer()

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(item.path, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .help("Copy Full Path")
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                }

                // Crucial Vitality Score Card & Risk Meter
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(item.assessment.level.rawValue, systemImage: item.assessment.level.iconName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(item.assessment.level.badgeColor)

                        Spacer()

                        Text("Risk Score: \(item.assessment.riskScore)/100")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 7)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.green, .orange, .red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(7, geo.size.width * CGFloat(Double(item.assessment.riskScore) / 100.0)), height: 7)
                        }
                    }
                    .frame(height: 7)
                }
                .padding(12)
                .background(item.assessment.level.badgeColor.opacity(0.08))
                .cornerRadius(10)

                // Explanation: Why is this file here?
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Why is this file here?")
                            .font(.system(size: 12, weight: .bold))

                        Spacer()

                        if isAiAnalyzing {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else if item.assessment.aiGenerated {
                            Label("AI Verified", systemImage: "sparkles")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.purple)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.15))
                                .cornerRadius(5)
                        }
                    }

                    Text(item.assessment.summary)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)

                    Text(item.assessment.impact)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(9)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                }

                // Rebuild Command Snippet
                if let rebuildCmd = item.assessment.rebuildCommand {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Rebuild Command (if needed):")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)

                        HStack {
                            Text(rebuildCmd)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.primary)
                            Spacer()
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(rebuildCmd, forType: .string)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .help("Copy Rebuild Command")
                        }
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                }

                // AI Deep Analysis Button
                if !item.assessment.aiGenerated {
                    Button {
                        triggerDeepAiAnalysis(item: item)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("Deep AI Explanation (Gemini)")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Divider()

                // Actions (Reveal & Trash)
                HStack(spacing: 10) {
                    Button {
                        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                    } label: {
                        Label("Reveal in Finder", systemImage: "folder")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button {
                        trashIndividualItem(item)
                    } label: {
                        Label("Move to Trash", systemImage: "trash.fill")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(item.assessment.level == .vital)
                    .help(item.assessment.level == .vital ? "Vital system files are protected from deletion" : "Safely moves this file to macOS Trash")
                }
            }
            .padding(16)
        }
    }

    private var emptyInspectorPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("Select an individual file")
                .font(.system(size: 14, weight: .semibold))

            Text("Inspect its Crucial Vitality Score, AI explanation, and safely delete it.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions & Helpers
    private func selectItemAndExplain(_ item: FileItem) {
        windowManager.selectedItem = item

        // Automatic Gemini AI explanation if API key is set and item not yet verified
        if GeminiExplainerService.shared.apiKey != nil && !item.assessment.aiGenerated {
            triggerDeepAiAnalysis(item: item)
        }
    }

    private func triggerDeepAiAnalysis(item: FileItem) {
        Task {
            await MainActor.run { isAiAnalyzing = true }
            let updatedAssessment = await GeminiExplainerService.shared.explain(item: item)
            await MainActor.run {
                if windowManager.selectedItem?.id == item.id {
                    windowManager.selectedItem?.assessment = updatedAssessment
                }
                isAiAnalyzing = false
            }
        }
    }

    private func trashIndividualItem(_ item: FileItem) {
        do {
            try trashService.trash(item: item)
            // Remove from scanner list
            for cat in scanner.itemsByCategory.keys {
                scanner.itemsByCategory[cat]?.removeAll { $0.id == item.id }
            }
            scanner.recalculateCleanableBytes()
            scanner.refreshDiskSpace()
            autoSelectFirstItem()
        } catch {
            statusAlertMessage = error.localizedDescription
        }
    }
}
