import SwiftUI
import AppKit

public struct MainWindowView: View {
    @ObservedObject var windowManager = WindowManager.shared
    @ObservedObject var scanner = FileScannerService.shared
    @ObservedObject var trashService = SafetyTrashService.shared
    @ObservedObject var cpuMonitor = CPUMonitorService.shared
    @ObservedObject var localLLM = LocalLLMService.shared

    @State private var searchText: String = ""
    @State private var filterLevel: VitalityLevel? = nil
    @State private var showingTrashAlert: Bool = false
    @State private var statusAlertMessage: String? = nil

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // MARK: - 1. Left Retro Chassis Sidebar
            sidebarView
                .frame(width: 250)
                .background(RetroTheme.panel)

            Divider().background(RetroTheme.border)

            // MARK: - 2. Main Workstation Area
            Group {
                switch windowManager.selectedNav {
                case .dashboard:
                    dashboardView
                case .category(let category):
                    categoryDrilldownView(category: category)
                case .fileFinder:
                    FileFinderView()
                case .assistant:
                    CrucialAssistantView()
                case .settings:
                    SettingsView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RetroTheme.bg)
        }
        .frame(minWidth: 1080, minHeight: 700)
        .background(RetroTheme.bg)
        .onAppear {
            localLLM.checkModelStatus()
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
                title: Text("AUTHORIZE PURGE OPERATION"),
                message: Text("Crucial will stage \(info.count) files (\(ByteCountFormatter.string(fromByteCount: info.bytes, countStyle: .file))) into your macOS Trash. Zero destructive commands will be run; items remain restorable."),
                primaryButton: .destructive(Text("EXECUTE PURGE")) {
                    let result = scanner.cleanSelected()
                    statusAlertMessage = "Safely staged \(result.succeeded) items to Trash (\(ByteCountFormatter.string(fromByteCount: result.bytesFreed, countStyle: .file)) reclaimed)."
                },
                secondaryButton: .cancel(Text("CANCEL"))
            )
        }
    }

    private func autoSelectFirstItem() {
        if case .category(let cat) = windowManager.selectedNav {
            windowManager.selectedItem = scanner.itemsByCategory[cat]?.first
        } else {
            for cat in JunkCategory.allCases {
                if let first = scanner.itemsByCategory[cat]?.first {
                    windowManager.selectedItem = first
                    break
                }
            }
        }
    }

    // MARK: - Sidebar View (Industrial Chassis)
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Retro Chassis Brand Header
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(RetroTheme.panelRaised)
                            .frame(width: 26, height: 26)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(RetroTheme.borderLight, lineWidth: 1))

                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(RetroTheme.amber)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("CRUCIAL // SYS_RECLAIM")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(RetroTheme.textPrimary)
                        Text("TELEMETRY: VERIFIED // V1.0")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(RetroTheme.amber)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().background(RetroTheme.border)

            // Storage Gauge Block
            diskTelemetryBlock
                .padding(12)

            Divider().background(RetroTheme.border)

            // Navigation Sections
            ScrollView {
                VStack(spacing: 3) {
                    sidebarNavRow(
                        title: "DASHBOARD // OVERVIEW",
                        icon: "gauge.with.needle",
                        accentColor: RetroTheme.cyan,
                        isSelected: windowManager.selectedNav == .dashboard
                    ) {
                        windowManager.selectedNav = .dashboard
                    }

                    sidebarSectionTitle("DISPOSABLE SECTORS")

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

                    sidebarSectionTitle("INSTRUMENTATION & AI")

                    sidebarNavRow(
                        title: "CRUCIAL ASSISTANT [LLM]",
                        icon: "terminal.fill",
                        accentColor: RetroTheme.amber,
                        isSelected: windowManager.selectedNav == .assistant
                    ) {
                        windowManager.selectedNav = .assistant
                    }

                    sidebarNavRow(
                        title: "DEEP FILE FINDER",
                        icon: "magnifyingglass",
                        accentColor: RetroTheme.cyan,
                        isSelected: windowManager.selectedNav == .fileFinder
                    ) {
                        windowManager.selectedNav = .fileFinder
                    }

                    sidebarNavRow(
                        title: "SYSTEM SETTINGS",
                        icon: "gearshape.2.fill",
                        accentColor: RetroTheme.textMuted,
                        isSelected: windowManager.selectedNav == .settings
                    ) {
                        windowManager.selectedNav = .settings
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }

            Divider().background(RetroTheme.border)

            // Bottom Actions (Scan & Clean)
            VStack(spacing: 8) {
                if scanner.isScanning {
                    HStack(spacing: 6) {
                        Text(">")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(RetroTheme.amber)
                        Text(scanner.scanProgressMessage.uppercased())
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(RetroTheme.amber)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 6) {
                    Button {
                        Task {
                            await scanner.scanQuickCleanDashboard()
                            autoSelectFirstItem()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .bold))
                            Text(scanner.isScanning ? "SCANNING" : "RESCAN")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(RetroTheme.panelRaised)
                        .foregroundStyle(RetroTheme.textPrimary)
                        .cornerRadius(3)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(RetroTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(scanner.isScanning)

                    let info = scanner.getSelectedCountAndBytes()
                    Button {
                        showingTrashAlert = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(info.bytes > 0 ? "PURGE [\(ByteCountFormatter.string(fromByteCount: info.bytes, countStyle: .file))]" : "PURGE")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(info.bytes > 0 ? RetroTheme.amber : RetroTheme.panelRaised)
                        .foregroundStyle(info.bytes > 0 ? Color.black : RetroTheme.textDim)
                        .cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                    .disabled(info.bytes == 0 || scanner.isScanning)
                }
            }
            .padding(10)
            .background(RetroTheme.panel)
        }
    }

    private func sidebarSectionTitle(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(RetroTheme.textDim)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
    }

    private func sidebarNavRow(
        title: String,
        icon: String,
        accentColor: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .monospaced))
                    .foregroundStyle(isSelected ? RetroTheme.textPrimary : RetroTheme.textMuted)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? RetroTheme.panelRaised : Color.clear)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? RetroTheme.borderLight : Color.clear, lineWidth: 1)
            )
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
            HStack(spacing: 8) {
                Rectangle()
                    .fill(category.color)
                    .frame(width: 3, height: 14)

                Text(category.rawValue.uppercased())
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .monospaced))
                    .foregroundStyle(isSelected ? RetroTheme.textPrimary : RetroTheme.textMuted)
                    .lineLimit(1)

                Spacer()

                if totalSize > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(isSelected ? RetroTheme.amber : RetroTheme.textMuted)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isSelected ? RetroTheme.panelRaised : Color.clear)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? RetroTheme.borderLight : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var diskTelemetryBlock: some View {
        VStack(spacing: 6) {
            HStack {
                Text("APFS ROOT DISK")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroTheme.textDim)
                Spacer()
                Text("\(Int(scanner.usedDiskPercent * 100))% ALLOCATED")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(scanner.usedDiskPercent > 0.85 ? RetroTheme.crimson : RetroTheme.cyan)
            }

            // Segmented hardware-style meter
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(RetroTheme.panelRaised)
                        .frame(height: 5)

                    Rectangle()
                        .fill(scanner.usedDiskPercent > 0.85 ? RetroTheme.crimson : RetroTheme.cyan)
                        .frame(width: max(4, geo.size.width * CGFloat(scanner.usedDiskPercent)), height: 5)
                }
            }
            .frame(height: 5)

            HStack {
                Text("FREE: \(ByteCountFormatter.string(fromByteCount: scanner.diskFreeBytes, countStyle: .file))")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(RetroTheme.textMuted)
                Spacer()
                Text("RECLAIM: \(ByteCountFormatter.string(fromByteCount: scanner.totalCleanableBytes, countStyle: .file))")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroTheme.emerald)
            }

            // Real-time CPU Duty Cycle
            HStack(spacing: 6) {
                Text("CPU:")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroTheme.textDim)

                Text(String(format: "%.1f%%", cpuMonitor.cpuPercent))
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(cpuMonitor.cpuPercent > 15 ? RetroTheme.amber : RetroTheme.emerald)

                Spacer()

                Text(scanner.pacingMode == .pacedBurst ? "[PACED 10%]" : "[TURBO 97%]")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroTheme.textMuted)
            }
            .padding(.top, 2)
        }
        .padding(8)
        .background(RetroTheme.bg)
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(RetroTheme.border, lineWidth: 1))
    }

    // MARK: - Dashboard View
    private var dashboardView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Retro Header Readout
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("SYSTEM TELEMETRY & STORAGE AUDIT")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(RetroTheme.textPrimary)
                        Text("Deterministic heuristic categorization paired with local LLM deep diagnostics.")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(RetroTheme.textMuted)
                    }
                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(ByteCountFormatter.string(fromByteCount: scanner.totalCleanableBytes, countStyle: .file))
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundStyle(RetroTheme.amber)
                        Text("RECLAIMABLE JUNK")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(RetroTheme.textDim)
                    }
                    .padding(10)
                    .background(RetroTheme.panel)
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(RetroTheme.border, lineWidth: 1))
                }

                Divider().background(RetroTheme.border)

                // 4 Category Cards
                Text("SECTOR INVENTORY // SELECT CATEGORY TO DRILL DOWN:")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroTheme.textDim)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(JunkCategory.allCases.filter { $0 != .custom }) { cat in
                        let items = scanner.itemsByCategory[cat] ?? []
                        let size = items.reduce(0) { $0 + $1.size }

                        Button {
                            windowManager.selectedNav = .category(cat)
                            if let first = items.first {
                                windowManager.selectedItem = first
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Rectangle()
                                    .fill(cat.color)
                                    .frame(width: 4, height: 38)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(cat.rawValue.uppercased())
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(RetroTheme.textPrimary)
                                        Spacer()
                                        Text("\(items.count) FILES")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(RetroTheme.textDim)
                                    }

                                    Text(cat.description)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(RetroTheme.textMuted)
                                        .lineLimit(1)

                                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                        .font(.system(size: 12, weight: .black, design: .monospaced))
                                        .foregroundStyle(size > 0 ? RetroTheme.amber : RetroTheme.textMuted)
                                        .padding(.top, 1)
                                }
                            }
                            .padding(10)
                            .background(RetroTheme.panel)
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(RetroTheme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Recent Trash Staging Log
                if !trashService.history.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("RECYCLE STAGING HISTORY")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(RetroTheme.textDim)
                            Spacer()
                            Button("[OPEN MACOS TRASH]") {
                                trashService.openTrash()
                            }
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(RetroTheme.cyan)
                            .buttonStyle(.plain)
                        }

                        VStack(spacing: 4) {
                            ForEach(trashService.history.prefix(5)) { record in
                                HStack {
                                    Text("STAGED:")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(RetroTheme.emerald)
                                    Text(record.name)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(RetroTheme.textPrimary)
                                    Spacer()
                                    Text(ByteCountFormatter.string(fromByteCount: record.size, countStyle: .file))
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(RetroTheme.textMuted)
                                }
                                .padding(6)
                                .background(RetroTheme.panel)
                                .cornerRadius(3)
                                .overlay(RoundedRectangle(cornerRadius: 3).stroke(RetroTheme.border, lineWidth: 1))
                            }
                        }
                    }
                    .padding(.top, 8)
                }

                Spacer()
            }
            .padding(20)
        }
    }

    // MARK: - Category Drilldown (Center File List + Right Diagnostic Sheet)
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
                // Header Bar
                categoryHeaderBanner(category: category, items: allItems)
                    .padding(14)
                    .background(RetroTheme.panel)

                Divider().background(RetroTheme.border)

                // Search & Filter Bar
                filterControlsBar(category: category, allItems: allItems)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RetroTheme.bg)

                Divider().background(RetroTheme.border)

                // File Inventory List
                if filteredItems.isEmpty {
                    VStack(spacing: 8) {
                        Text("[SECTOR STATUS: CLEAN]")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(RetroTheme.emerald)
                        Text("No disposable assets detected in this category.")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(RetroTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: Binding(
                        get: { windowManager.selectedItem },
                        set: { newItem in
                            windowManager.selectedItem = newItem
                        }
                    )) {
                        ForEach(filteredItems) { item in
                            fileRow(item: item, in: category)
                                .tag(item)
                                .contextMenu {
                                    Button("Reveal in Finder") {
                                        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                                    }
                                    Button("Ask Crucial Assistant") {
                                        CrucialChatService.shared.askAbout(item: item)
                                        windowManager.selectedNav = .assistant
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
            .frame(minWidth: 420, maxWidth: .infinity)

            // MARK: Right Pane - Exhaustive Technical Profile Sheet
            VStack(spacing: 0) {
                if let item = windowManager.selectedItem {
                    exhaustiveTechnicalSheet(item: item)
                } else {
                    emptyInspectorPlaceholder
                }
            }
            .frame(minWidth: 400, maxWidth: 520)
            .background(RetroTheme.panel)
        }
    }

    private func categoryHeaderBanner(category: JunkCategory, items: [FileItem]) -> some View {
        let totalBytes = items.reduce(0) { $0 + $1.size }
        let selected = items.filter { $0.isSelected }
        let selectedBytes = selected.reduce(0) { $0 + $1.size }

        return HStack(spacing: 12) {
            Rectangle()
                .fill(category.color)
                .frame(width: 4, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(category.rawValue.uppercased())
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroTheme.textPrimary)

                    Text("[\(items.count) ASSETS]")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroTheme.textMuted)
                }

                Text(category.description)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(RetroTheme.textDim)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(RetroTheme.amber)

                if selected.count > 0 {
                    Text("\(selected.count) SELECTED (\(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file)))")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroTheme.cyan)
                }
            }
        }
    }

    private func filterControlsBar(category: JunkCategory, allItems: [FileItem]) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text(">")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroTheme.cyan)

                TextField("FILTER IN \(category.rawValue.uppercased())...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(RetroTheme.textPrimary)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Text("[CLEAR]")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(RetroTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(RetroTheme.panel)
            .cornerRadius(3)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(RetroTheme.border, lineWidth: 1))

            HStack(spacing: 6) {
                retroFilterPill(title: "ALL", count: allItems.count, isSelected: filterLevel == nil) {
                    filterLevel = nil
                }

                let safeCount = allItems.filter { $0.assessment.level == .safeToDelete }.count
                if safeCount > 0 {
                    retroFilterPill(title: "SAFE", count: safeCount, isSelected: filterLevel == .safeToDelete) {
                        filterLevel = .safeToDelete
                    }
                }

                let cautionCount = allItems.filter { $0.assessment.level == .caution }.count
                if cautionCount > 0 {
                    retroFilterPill(title: "REVIEW", count: cautionCount, isSelected: filterLevel == .caution) {
                        filterLevel = .caution
                    }
                }

                Spacer()

                Button("[SELECT SAFE]") {
                    scanner.selectSafeOnly(in: category)
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .buttonStyle(.plain)
                .foregroundStyle(RetroTheme.emerald)

                Button("[SELECT ALL]") {
                    scanner.selectAll(in: category, selected: true)
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .buttonStyle(.plain)
                .foregroundStyle(RetroTheme.textMuted)

                Button("[NONE]") {
                    scanner.selectAll(in: category, selected: false)
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .buttonStyle(.plain)
                .foregroundStyle(RetroTheme.textDim)
            }
        }
    }

    private func retroFilterPill(title: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("[\(title): \(count)]")
                .font(.system(size: 9, weight: isSelected ? .black : .bold, design: .monospaced))
                .foregroundStyle(isSelected ? RetroTheme.amber : RetroTheme.textMuted)
        }
        .buttonStyle(.plain)
    }

    private func fileRow(item: FileItem, in category: JunkCategory) -> some View {
        HStack(spacing: 8) {
            // Retro Checkbox toggle
            Button {
                scanner.toggleSelection(for: item.id, in: category)
            } label: {
                Text(item.isSelected ? "[X]" : "[ ]")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(item.isSelected ? RetroTheme.amber : RetroTheme.borderLight)
            }
            .buttonStyle(.plain)
            .disabled(item.assessment.level == .vital)

            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroTheme.textPrimary)
                        .lineLimit(1)

                    Text("[\(item.assessment.level.rawValue.uppercased())]")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(item.assessment.level == .safeToDelete ? RetroTheme.emerald : (item.assessment.level == .caution ? RetroTheme.amber : RetroTheme.crimson))
                }

                Text(item.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(RetroTheme.textDim)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(item.formattedSize)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(item.isSelected ? RetroTheme.amber : RetroTheme.textPrimary)

                if item.daysSinceLastAccess > 0 {
                    Text("\(item.daysSinceLastAccess)D IDLE")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(RetroTheme.textDim)
                }
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - Exhaustive Technical Profile Sheet (Right Column)
    private func exhaustiveTechnicalSheet(item: FileItem) -> some View {
        let profile = FileDiagnosticEngine.shared.profile(item: item)

        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Header Title
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("[TELEMETRY AUDIT: \(profile.name)]")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(RetroTheme.textPrimary)
                        Spacer()
                        Text(profile.formattedSize)
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(RetroTheme.amber)
                    }

                    Text("CANONICAL: \(profile.path)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(RetroTheme.textDim)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
                .padding(10)
                .background(RetroTheme.panelRaised)
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(RetroTheme.border, lineWidth: 1))

                // Purge Feasibility Verdict Box
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("PURGE VERDICT:")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(RetroTheme.textDim)
                        Spacer()
                        Text(profile.deletionVerdict)
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(profile.canBeDeleted ? RetroTheme.emerald : RetroTheme.crimson)
                    }
                }
                .padding(8)
                .background(RetroTheme.panelRaised)
                .cornerRadius(3)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(profile.canBeDeleted ? RetroTheme.emerald.opacity(0.4) : RetroTheme.crimson.opacity(0.4), lineWidth: 1))

                // Section 1: Provenance & Identity
                retroSectionHeader("1. IDENTITY & PROVENANCE")
                VStack(alignment: .leading, spacing: 4) {
                    telemetryRow(label: "ORIGINATING APP", value: profile.createdByApp)
                    telemetryRow(label: "SUBSYSTEM DOMAIN", value: profile.subsystemOrigin)
                    telemetryRow(label: "CLASSIFICATION", value: profile.fileClassification)
                    telemetryRow(label: "EXACT MAGNITUDE", value: "\(profile.exactBytes) bytes across \(profile.fileCount) inodes")
                    telemetryRow(label: "LAST MODIFIED", value: profile.lastModified)
                    telemetryRow(label: "DORMANT DURATION", value: "\(profile.daysIdle) days unaccessed")
                }
                .padding(8)
                .background(RetroTheme.panelRaised)
                .cornerRadius(3)

                // Section 2: Functional Purpose
                retroSectionHeader("2. FUNCTIONAL ROLE (WHY DOES THIS EXIST?)")
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.functionalPurpose)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(RetroTheme.textPrimary)
                        .lineSpacing(3)

                    Text("RATIONALE: \(profile.whyItExists)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(RetroTheme.textMuted)
                        .padding(.top, 2)
                }
                .padding(8)
                .background(RetroTheme.panelRaised)
                .cornerRadius(3)

                // Section 3: Process Dependency
                retroSectionHeader("3. PROCESS & APPLICATION DEPENDENCY")
                VStack(alignment: .leading, spacing: 4) {
                    telemetryRow(label: "OWNING PROCESS", value: profile.activeProcessDependency)
                    HStack {
                        Text("PROCESS STATUS:")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(RetroTheme.textDim)
                        Spacer()
                        Text(profile.isProcessRunning ? "⚠️ ACTIVE IN PROCESS TABLE" : "✅ DORMANT / CLOSED")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(profile.isProcessRunning ? RetroTheme.amber : RetroTheme.emerald)
                    }
                }
                .padding(8)
                .background(RetroTheme.panelRaised)
                .cornerRadius(3)

                // Section 4: Deletion Consequences
                retroSectionHeader("4. DELETION DYNAMICS & RECOVERY PROTOCOL")
                VStack(alignment: .leading, spacing: 4) {
                    telemetryRow(label: "IMMEDIATE EFFECT", value: profile.immediateImpact)
                    telemetryRow(label: "RELAUNCH BEHAVIOR", value: profile.appRelaunchImpact)

                    if let cmd = profile.rebuildCommand {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("REBUILD COMMAND:")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(RetroTheme.textDim)
                            Text(cmd)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(RetroTheme.cyan)
                                .padding(4)
                                .background(RetroTheme.bg)
                                .cornerRadius(2)
                        }
                    }
                }
                .padding(8)
                .background(RetroTheme.panelRaised)
                .cornerRadius(3)

                // Section 5: Telemetry Scores
                retroSectionHeader("5. CRUCIAL TELEMETRY SCORES")
                HStack(spacing: 8) {
                    scoreCard(title: "VITALITY RISK", score: profile.vitalityRiskScore, color: profile.vitalityRiskScore > 50 ? RetroTheme.crimson : RetroTheme.emerald)
                    scoreCard(title: "BLOAT SEVERITY", score: profile.bloatSeverityScore, color: RetroTheme.amber)
                    scoreCard(title: "RECOVERY COST", score: profile.recoveryDifficultyScore, color: RetroTheme.cyan)
                }

                // Interactive Buttons
                VStack(spacing: 6) {
                    Button {
                        CrucialChatService.shared.askAbout(item: item)
                        windowManager.selectedNav = .assistant
                    } label: {
                        HStack(spacing: 6) {
                            Text(">")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(RetroTheme.amber)
                            Text("[RUN LOCAL LLM ANALYSIS IN CONSOLE]")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(RetroTheme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(RetroTheme.panelRaised)
                        .cornerRadius(3)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(RetroTheme.amber, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 6) {
                        Button {
                            NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                        } label: {
                            Text("[REVEAL IN FINDER]")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(RetroTheme.panelRaised)
                                .foregroundStyle(RetroTheme.textMuted)
                                .cornerRadius(3)
                                .overlay(RoundedRectangle(cornerRadius: 3).stroke(RetroTheme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Button {
                            trashIndividualItem(item)
                        } label: {
                            Text("[STAGE TO TRASH]")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(item.assessment.level == .vital ? RetroTheme.panelRaised : RetroTheme.crimson.opacity(0.8))
                                .foregroundStyle(item.assessment.level == .vital ? RetroTheme.textDim : Color.white)
                                .cornerRadius(3)
                        }
                        .buttonStyle(.plain)
                        .disabled(item.assessment.level == .vital)
                    }
                }
                .padding(.top, 6)
            }
            .padding(12)
        }
    }

    private func retroSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .foregroundStyle(RetroTheme.textDim)
            .padding(.top, 4)
    }

    private func telemetryRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(RetroTheme.textDim)
            Text(value)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(RetroTheme.textPrimary)
        }
    }

    private func scoreCard(title: String, score: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(RetroTheme.textDim)
            Text("\(score)")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(color)
            Text("/ 100")
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(RetroTheme.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RetroTheme.bg)
        .cornerRadius(3)
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(RetroTheme.border, lineWidth: 1))
    }

    private var emptyInspectorPlaceholder: some View {
        VStack(spacing: 8) {
            Text("[NO ASSET SELECTED]")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(RetroTheme.textDim)
            Text("Select an asset in the inventory table to view full telemetry.")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(RetroTheme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func trashIndividualItem(_ item: FileItem) {
        do {
            try trashService.trash(item: item)
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
