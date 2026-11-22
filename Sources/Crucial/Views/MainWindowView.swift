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
            // MARK: - 1. Things 3 Left Sidebar
            sidebarView
                .frame(width: 250)
                .background(ThingsTheme.sidebar)

            Divider().background(ThingsTheme.borderSubtle)

            // MARK: - 2. Center & Right Content View
            Group {
                switch windowManager.selectedNav {
                case .dashboard:
                    dashboardView
                case .diskMap:
                    DiskSunburstView()
                case .duplicates:
                    DuplicatesView()
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
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: windowManager.selectedNav)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ThingsTheme.canvas)
        }
        .frame(minWidth: 1080, minHeight: 700)
        .background(ThingsTheme.canvas)
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
                title: Text("Authorize Safe Trash Operation"),
                message: Text("Crucial will stage \(info.count) items (\(ByteCountFormatter.string(fromByteCount: info.bytes, countStyle: .file))) into macOS Trash. No destructive rm -rf commands are used; items remain restorable."),
                primaryButton: .destructive(Text("Move to Trash")) {
                    let result = scanner.cleanSelected()
                    statusAlertMessage = "Safely moved \(result.succeeded) items to Trash (\(ByteCountFormatter.string(fromByteCount: result.bytesFreed, countStyle: .file)) reclaimed)."
                },
                secondaryButton: .cancel(Text("Cancel"))
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

    // MARK: - Things 3 Sidebar View
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // App Title & Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(ThingsTheme.accent.opacity(0.15))
                        .frame(width: 28, height: 28)

                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ThingsTheme.accent)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Crucial")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(ThingsTheme.textPrimary)

                    Text("Storage Intelligence")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ThingsTheme.textSecondary)
                }

                Spacer()

                if scanner.isScanning {
                    ProgressView()
                        .scaleEffect(0.65)
                } else {
                    Button {
                        Task {
                            await scanner.scanQuickCleanDashboard()
                            autoSelectFirstItem()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ThingsTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Rescan Mac storage")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Search Bar (Things 3 style)
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(ThingsTheme.textTertiary)

                TextField("Quick Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(ThingsTheme.textPrimary)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(ThingsTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(ThingsTheme.cardRaised)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            Divider().background(ThingsTheme.borderSubtle)

            // Core Navigation Lists
            ScrollView {
                VStack(spacing: 2) {
                    // 1. Dashboard (Today / Star style)
                    thingsNavRow(
                        title: "Clean Dashboard",
                        icon: "star.fill",
                        tintColor: ThingsTheme.starOchre,
                        badge: scanner.totalCleanableBytes > 0 ? ByteCountFormatter.string(fromByteCount: scanner.totalCleanableBytes, countStyle: .file) : nil,
                        isSelected: windowManager.selectedNav == .dashboard
                    ) {
                        windowManager.selectedNav = .dashboard
                    }

                    // 2. Visual Storage Treemap
                    thingsNavRow(
                        title: "Storage Treemap",
                        icon: "chart.pie.fill",
                        tintColor: ThingsTheme.accent,
                        badge: nil,
                        isSelected: windowManager.selectedNav == .diskMap
                    ) {
                        windowManager.selectedNav = .diskMap
                    }

                    // 3. Duplicate File Finder
                    thingsNavRow(
                        title: "Duplicate Finder",
                        icon: "doc.on.doc.fill",
                        tintColor: ThingsTheme.purple,
                        badge: DuplicateFinderService.shared.totalWastedBytes > 0 ? ByteCountFormatter.string(fromByteCount: DuplicateFinderService.shared.totalWastedBytes, countStyle: .file) : nil,
                        isSelected: windowManager.selectedNav == .duplicates
                    ) {
                        windowManager.selectedNav = .duplicates
                    }

                    // 4. Crucial Assistant (Conversational AI)
                    thingsNavRow(
                        title: "Crucial Assistant",
                        icon: "bubble.left.and.bubble.right.fill",
                        tintColor: ThingsTheme.infoIndigo,
                        badge: localLLM.isModelReady ? "Llama 3.2" : nil,
                        isSelected: windowManager.selectedNav == .assistant
                    ) {
                        windowManager.selectedNav = .assistant
                    }

                    // 5. Deep File Finder
                    thingsNavRow(
                        title: "Deep File Finder",
                        icon: "magnifyingglass",
                        tintColor: ThingsTheme.glacierCyan,
                        badge: nil,
                        isSelected: windowManager.selectedNav == .fileFinder
                    ) {
                        windowManager.selectedNav = .fileFinder
                    }

                    // Section: Areas & Sectors
                    thingsSectionHeader("AREAS & SECTORS")

                    ForEach(JunkCategory.allCases.filter { $0 != .custom }) { cat in
                        let items = scanner.itemsByCategory[cat] ?? []
                        let size = items.reduce(0) { $0 + $1.size }
                        let isSelected = windowManager.selectedNav == .category(cat)

                        thingsCategoryRow(
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

                    // Section: Configuration
                    thingsSectionHeader("PREFERENCES")

                    thingsNavRow(
                        title: "Settings & Safety Rules",
                        icon: "gearshape.fill",
                        tintColor: ThingsTheme.textTertiary,
                        badge: nil,
                        isSelected: windowManager.selectedNav == .settings
                    ) {
                        windowManager.selectedNav = .settings
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }

            Divider().background(ThingsTheme.borderSubtle)

            // Things 3 Disk Telemetry Ring Footer
            diskTelemetryRingFooter
                .padding(14)
        }
    }

    private func thingsSectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(ThingsTheme.textTertiary)
                .tracking(0.5)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    private func thingsNavRow(
        title: String,
        icon: String,
        tintColor: Color,
        badge: String?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? (Color.white) : tintColor)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : ThingsTheme.textPrimary)

                Spacer()

                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.9) : ThingsTheme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.2) : ThingsTheme.cardRaised)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isSelected ? ThingsTheme.accent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func thingsCategoryRow(
        category: JunkCategory,
        itemsCount: Int,
        totalSize: Int64,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: categoryIcon(for: category))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : categoryTint(for: category))
                    .frame(width: 18)

                Text(category.rawValue)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : ThingsTheme.textPrimary)
                    .lineLimit(1)

                Spacer()

                if totalSize > 0 {
                    HStack(spacing: 5) {
                        Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(isSelected ? Color.white.opacity(0.9) : ThingsTheme.textSecondary)

                        ThingsProgressRing(
                            progress: 1.0,
                            size: 11,
                            strokeWidth: 2,
                            tintColor: isSelected ? Color.white : categoryTint(for: category),
                            backgroundColor: isSelected ? Color.white.opacity(0.3) : ThingsTheme.border
                        )
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isSelected ? ThingsTheme.accent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func categoryIcon(for cat: JunkCategory) -> String {
        switch cat {
        case .devArtifacts: return "hammer.fill"
        case .systemCache: return "internaldrive.fill"
        case .appResidue: return "trash.slash.fill"
        case .largeUnused: return "arrow.down.doc.fill"
        case .duplicates: return "doc.on.doc.fill"
        case .custom: return "folder.fill"
        }
    }

    private func categoryTint(for cat: JunkCategory) -> Color {
        switch cat {
        case .devArtifacts: return ThingsTheme.infoIndigo
        case .systemCache: return ThingsTheme.glacierCyan
        case .appResidue: return ThingsTheme.starOchre
        case .largeUnused: return ThingsTheme.purple
        case .duplicates: return ThingsTheme.starOchre
        case .custom: return ThingsTheme.accent
        }
    }

    // MARK: - Things 3 Storage Progress Ring Footer
    private var diskTelemetryRingFooter: some View {
        HStack(spacing: 12) {
            ThingsProgressRing(
                progress: scanner.usedDiskPercent,
                size: 34,
                strokeWidth: 3.5,
                tintColor: scanner.usedDiskPercent > 0.85 ? ThingsTheme.vitalCrimson : ThingsTheme.accent,
                backgroundColor: ThingsTheme.border
            )
            .overlay(
                Text("\(Int(scanner.usedDiskPercent * 100))%")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(ThingsTheme.textPrimary)
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Macintosh HD")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ThingsTheme.textPrimary)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: scanner.diskFreeBytes, countStyle: .file) + " free")
                        .font(.system(size: 10))
                        .foregroundStyle(ThingsTheme.textSecondary)
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(cpuMonitor.cpuPercent > 20 ? ThingsTheme.starOchre : ThingsTheme.accent)
                        .frame(width: 5, height: 5)
                    Text("CPU: \(String(format: "%.0f%%", cpuMonitor.cpuPercent)) · \(scanner.pacingMode == .pacedBurst ? "Paced" : "Active")")
                        .font(.system(size: 9))
                        .foregroundStyle(ThingsTheme.textTertiary)
                }
            }
        }
    }

    // MARK: - Dashboard View (Things 3 Style)
    private var dashboardView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Grand Things 3 Header
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(ThingsTheme.starOchre.opacity(0.12))
                            .frame(width: 44, height: 44)

                        Image(systemName: "star.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(ThingsTheme.starOchre)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Clean Dashboard")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(ThingsTheme.textPrimary)

                        Text("Deterministic storage heuristics paired with on-device Llama 3.2 telemetry.")
                            .font(.system(size: 12))
                            .foregroundStyle(ThingsTheme.textSecondary)
                    }

                    Spacer()

                    // Quick Clean Action Card
                    if scanner.totalCleanableBytes > 0 {
                        Button {
                            for cat in JunkCategory.allCases {
                                scanner.selectAll(in: cat, selected: true)
                            }
                            showingTrashAlert = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .bold))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Clean All Safe")
                                        .font(.system(size: 12, weight: .bold))
                                    Text(ByteCountFormatter.string(fromByteCount: scanner.totalCleanableBytes, countStyle: .file))
                                        .font(.system(size: 10, weight: .medium))
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(ThingsTheme.accent)
                            .foregroundStyle(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: ThingsTheme.accent.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider().background(ThingsTheme.borderSubtle)

                // Areas Grid (Things 3 Cards)
                VStack(alignment: .leading, spacing: 12) {
                    Text("AREAS OVERVIEW")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ThingsTheme.textTertiary)
                        .tracking(0.5)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
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
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(categoryTint(for: cat).opacity(0.12))
                                            .frame(width: 40, height: 40)

                                        Image(systemName: categoryIcon(for: cat))
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(categoryTint(for: cat))
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(cat.rawValue)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(ThingsTheme.textPrimary)

                                        Text("\(items.count) items · \(cat.description)")
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(ThingsTheme.textSecondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(ThingsTheme.textPrimary)

                                        ThingsProgressRing(
                                            progress: items.isEmpty ? 0.0 : 1.0,
                                            size: 14,
                                            strokeWidth: 2,
                                            tintColor: categoryTint(for: cat),
                                            backgroundColor: ThingsTheme.border
                                        )
                                    }
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

                // Recent Safety Trash Staging Log
                if !trashService.history.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("RECENT TRASH STAGING LOG")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ThingsTheme.textTertiary)
                            .tracking(0.5)

                        ForEach(trashService.history.prefix(5)) { record in
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(ThingsTheme.accent)

                                Text(record.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(ThingsTheme.textPrimary)

                                Spacer()

                                Text(ByteCountFormatter.string(fromByteCount: record.size, countStyle: .file))
                                    .font(.system(size: 11))
                                    .foregroundStyle(ThingsTheme.textSecondary)
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
                }

                Spacer()
            }
            .padding(28)
        }
    }

    // MARK: - Category Drilldown (Center Task List + Right Task Sheet)
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
            // MARK: Center Pane - Things 3 Task List
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // Header Bar (Things 3 grand title)
                    categoryGrandHeader(category: category, items: allItems)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 12)

                    // Capsule Filter Bar
                    categoryFilterCapsuleBar(category: category, allItems: allItems)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)

                    Divider().background(ThingsTheme.borderSubtle)

                    // File Inventory List (Things 3 To-Dos)
                    if filteredItems.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 38))
                                .foregroundStyle(ThingsTheme.accent)

                            Text("All Clean")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(ThingsTheme.textPrimary)

                            Text("No disposable cache or idle artifacts in this sector.")
                                .font(.system(size: 12))
                                .foregroundStyle(ThingsTheme.textSecondary)
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
                                thingsTaskRow(item: item, in: category)
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

                // MARK: Things 3 "Magic Plus" / Floating Action Button
                floatingCleanButton(in: category)
                    .padding(24)
            }

            // MARK: Right Pane - Things 3 Task Sheet / Inspector
            VStack(spacing: 0) {
                if let item = windowManager.selectedItem {
                    thingsTaskInspectorSheet(item: item)
                } else {
                    emptyInspectorPlaceholder
                }
            }
            .frame(minWidth: 380, maxWidth: 520)
            .background(ThingsTheme.sidebar)
        }
    }

    private func categoryGrandHeader(category: JunkCategory, items: [FileItem]) -> some View {
        let totalBytes = items.reduce(0) { $0 + $1.size }

        return HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(categoryTint(for: category).opacity(0.12))
                    .frame(width: 38, height: 38)

                Image(systemName: categoryIcon(for: category))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(categoryTint(for: category))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(ThingsTheme.textPrimary)

                Text("\(items.count) items · \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)) reclaimable")
                    .font(.system(size: 11.5))
                    .foregroundStyle(ThingsTheme.textSecondary)
            }

            Spacer()
        }
    }

    private func categoryFilterCapsuleBar(category: JunkCategory, allItems: [FileItem]) -> some View {
        HStack(spacing: 8) {
            thingsFilterCapsule(title: "All", count: allItems.count, isSelected: filterLevel == nil) {
                filterLevel = nil
            }

            let safeCount = allItems.filter { $0.assessment.level == .safeToDelete }.count
            if safeCount > 0 {
                thingsFilterCapsule(title: "Safe", count: safeCount, isSelected: filterLevel == .safeToDelete) {
                    filterLevel = .safeToDelete
                }
            }

            let cautionCount = allItems.filter { $0.assessment.level == .caution }.count
            if cautionCount > 0 {
                thingsFilterCapsule(title: "Review", count: cautionCount, isSelected: filterLevel == .caution) {
                    filterLevel = .caution
                }
            }

            Spacer()

            Button("Select Safe") {
                scanner.selectSafeOnly(in: category)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(ThingsTheme.accent)
            .buttonStyle(.plain)

            Text("·").foregroundStyle(ThingsTheme.textTertiary)

            Button("All") {
                scanner.selectAll(in: category, selected: true)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(ThingsTheme.textSecondary)
            .buttonStyle(.plain)

            Text("·").foregroundStyle(ThingsTheme.textTertiary)

            Button("None") {
                scanner.selectAll(in: category, selected: false)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(ThingsTheme.textTertiary)
            .buttonStyle(.plain)
        }
    }

    private func thingsFilterCapsule(title: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
                    .opacity(isSelected ? 0.9 : 0.6)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(isSelected ? ThingsTheme.accent : ThingsTheme.cardRaised)
            .foregroundStyle(isSelected ? Color.white : ThingsTheme.textPrimary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Things 3 Task Row
    private func thingsTaskRow(item: FileItem, in category: JunkCategory) -> some View {
        HStack(spacing: 12) {
            // Circular Things 3 Checkbox
            ThingsCheckbox(isChecked: item.isSelected) {
                scanner.toggleSelection(for: item.id, in: category)
            }
            .disabled(item.assessment.level == .vital)

            // Native Icon
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 20, height: 20)

            // Item Details
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ThingsTheme.textPrimary)
                        .lineLimit(1)

                    if item.assessment.level == .safeToDelete {
                        ThingsTag("100% Safe", color: ThingsTheme.accent)
                    } else if item.assessment.level == .caution {
                        ThingsTag("Caution", color: ThingsTheme.starOchre)
                    } else {
                        ThingsTag("Vital Lock", color: ThingsTheme.vitalCrimson)
                    }
                }

                Text(item.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(ThingsTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.formattedSize)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(item.isSelected ? ThingsTheme.accent : ThingsTheme.textPrimary)

                if item.daysSinceLastAccess > 0 {
                    Text("\(item.daysSinceLastAccess)d idle")
                        .font(.system(size: 10))
                        .foregroundStyle(ThingsTheme.textTertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Things 3 "Magic Plus" / Floating Clean Button
    private func floatingCleanButton(in category: JunkCategory) -> some View {
        let items = scanner.itemsByCategory[category] ?? []
        let selected = items.filter { $0.isSelected }
        let selectedBytes = selected.reduce(0) { $0 + $1.size }

        return Group {
            if selectedBytes > 0 {
                Button {
                    showingTrashAlert = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Clean \(selected.count) Selected (\(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file)))")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(ThingsTheme.accent)
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Things 3 Task Sheet / Inspector (Right Column)
    private func thingsTaskInspectorSheet(item: FileItem) -> some View {
        let profile = FileDiagnosticEngine.shared.profile(item: item)

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header (Task Title & Checkbox)
                HStack(alignment: .top, spacing: 10) {
                    ThingsCheckbox(isChecked: item.isSelected) {
                        scanner.toggleSelection(for: item.id, in: item.category)
                    }
                    .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(profile.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(ThingsTheme.textPrimary)

                        HStack(spacing: 6) {
                            Text(profile.formattedSize)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(ThingsTheme.accent)

                            Text("·")
                                .foregroundStyle(ThingsTheme.textTertiary)

                            Text("\(profile.fileCount) inodes")
                                .font(.system(size: 11))
                                .foregroundStyle(ThingsTheme.textSecondary)
                        }
                    }

                    Spacer()

                    Button {
                        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 14))
                            .foregroundStyle(ThingsTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")
                }

                // Canonical Path Card
                HStack {
                    Text(profile.path)
                        .font(.system(size: 10.5))
                        .foregroundStyle(ThingsTheme.textSecondary)
                        .lineLimit(2)
                        .textSelection(.enabled)

                    Spacer()

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(profile.path, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundStyle(ThingsTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy Path")
                }
                .padding(8)
                .background(ThingsTheme.cardRaised)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // Purge Feasibility Banner
                HStack(spacing: 8) {
                    Image(systemName: profile.canBeDeleted ? "checkmark.circle.fill" : "lock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(profile.canBeDeleted ? ThingsTheme.accent : ThingsTheme.vitalCrimson)

                    Text(profile.deletionVerdict)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(profile.canBeDeleted ? ThingsTheme.accent : ThingsTheme.vitalCrimson)

                    Spacer()
                }
                .padding(10)
                .background(profile.canBeDeleted ? ThingsTheme.accent.opacity(0.1) : ThingsTheme.vitalCrimson.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Section 1: Notes (Functional Role & System Rationale)
                VStack(alignment: .leading, spacing: 6) {
                    Text("FUNCTIONAL ROLE & RATIONALE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ThingsTheme.textTertiary)
                        .tracking(0.5)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(profile.functionalPurpose)
                            .font(.system(size: 11.5))
                            .lineSpacing(3)
                            .foregroundStyle(ThingsTheme.textPrimary)

                        Text("Why it exists: \(profile.whyItExists)")
                            .font(.system(size: 11))
                            .foregroundStyle(ThingsTheme.textSecondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ThingsTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ThingsTheme.border, lineWidth: 1))
                }

                // Section 2: Property Checklist
                VStack(alignment: .leading, spacing: 6) {
                    Text("TELEMETRY PROPERTIES")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ThingsTheme.textTertiary)
                        .tracking(0.5)

                    VStack(spacing: 8) {
                        thingsPropertyRow(label: "Originating App", value: profile.createdByApp)
                        thingsPropertyRow(label: "Subsystem Domain", value: profile.subsystemOrigin)
                        thingsPropertyRow(label: "Classification", value: profile.fileClassification)
                        thingsPropertyRow(label: "Exact Size", value: "\(profile.exactBytes) bytes")
                        thingsPropertyRow(label: "Process Status", value: profile.isProcessRunning ? "⚠️ Active in Process Table" : "Closed / Dormant", highlight: profile.isProcessRunning ? ThingsTheme.starOchre : ThingsTheme.accent)
                        thingsPropertyRow(label: "Last Modified", value: profile.lastModified)
                        thingsPropertyRow(label: "Dormant Duration", value: "\(profile.daysIdle) days idle")
                    }
                    .padding(12)
                    .background(ThingsTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ThingsTheme.border, lineWidth: 1))
                }

                // Section 3: Deletion Dynamics & Rebuild
                VStack(alignment: .leading, spacing: 6) {
                    Text("DELETION IMPACT & RECOVERY")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ThingsTheme.textTertiary)
                        .tracking(0.5)

                    VStack(alignment: .leading, spacing: 8) {
                        thingsPropertyRow(label: "Immediate Impact", value: profile.immediateImpact)
                        thingsPropertyRow(label: "Relaunch Behavior", value: profile.appRelaunchImpact)

                        if let cmd = profile.rebuildCommand {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Rebuild Protocol")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(ThingsTheme.textSecondary)

                                HStack {
                                    Text(cmd)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(ThingsTheme.textPrimary)
                                    Spacer()
                                    Button {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(cmd, forType: .string)
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 10))
                                            .foregroundStyle(ThingsTheme.textTertiary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(8)
                                .background(ThingsTheme.cardRaised)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .padding(12)
                    .background(ThingsTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ThingsTheme.border, lineWidth: 1))
                }

                // Section 4: Things 3 Score Progress Rings
                VStack(alignment: .leading, spacing: 6) {
                    Text("TELEMETRY SCORE GAUGES")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ThingsTheme.textTertiary)
                        .tracking(0.5)

                    HStack(spacing: 12) {
                        thingsScoreRingCard(title: "Vitality Risk", score: profile.vitalityRiskScore, color: profile.vitalityRiskScore > 50 ? ThingsTheme.vitalCrimson : ThingsTheme.accent)
                        thingsScoreRingCard(title: "Bloat Severity", score: profile.bloatSeverityScore, color: ThingsTheme.starOchre)
                        thingsScoreRingCard(title: "Recovery Cost", score: profile.recoveryDifficultyScore, color: ThingsTheme.infoIndigo)
                    }
                }

                // Action Buttons
                VStack(spacing: 8) {
                    Button {
                        CrucialChatService.shared.askAbout(item: item)
                        windowManager.selectedNav = .assistant
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Run Local Llama 3.2 Deep Diagnosis")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(ThingsTheme.card)
                        .foregroundStyle(ThingsTheme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ThingsTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 8) {
                        Button {
                            NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                        } label: {
                            Text("Reveal in Finder")
                                .font(.system(size: 11, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(ThingsTheme.card)
                                .foregroundStyle(ThingsTheme.textSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ThingsTheme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Button {
                            trashIndividualItem(item)
                        } label: {
                            Text("Stage to Trash")
                                .font(.system(size: 11, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(profile.canBeDeleted ? ThingsTheme.accent : ThingsTheme.cardRaised)
                                .foregroundStyle(profile.canBeDeleted ? Color.white : ThingsTheme.textTertiary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(!profile.canBeDeleted)
                    }
                }
                .padding(.top, 4)
            }
            .padding(18)
        }
    }

    private func thingsPropertyRow(label: String, value: String, highlight: Color? = nil) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(ThingsTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(highlight ?? ThingsTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func thingsScoreRingCard(title: String, score: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            ThingsProgressRing(
                progress: Double(score) / 100.0,
                size: 38,
                strokeWidth: 3.5,
                tintColor: color,
                backgroundColor: ThingsTheme.border
            )
            .overlay(
                Text("\(score)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ThingsTheme.textPrimary)
            )

            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(ThingsTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(ThingsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ThingsTheme.border, lineWidth: 1))
    }

    private var emptyInspectorPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 32))
                .foregroundStyle(ThingsTheme.textTertiary)

            Text("Select an Item")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ThingsTheme.textPrimary)

            Text("View 12-point technical telemetry, process dependencies, and deletion consequences.")
                .font(.system(size: 11))
                .foregroundStyle(ThingsTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func trashIndividualItem(_ item: FileItem) {
        do {
            try trashService.trash(item: item)
            for cat in JunkCategory.allCases {
                scanner.itemsByCategory[cat]?.removeAll { $0.id == item.id }
            }
            scanner.recalculateCleanableBytes()
            scanner.refreshDiskSpace()
            windowManager.selectedItem = nil
            autoSelectFirstItem()
        } catch {
            statusAlertMessage = "Could not move to Trash: \(error.localizedDescription)"
        }
    }
}
