import SwiftUI
import AppKit

public struct FileFinderView: View {
    @ObservedObject var scanner = FileScannerService.shared
    @ObservedObject var trashService = SafetyTrashService.shared
    @ObservedObject var searchService = SystemFileSearchService.shared
    @ObservedObject var windowManager = WindowManager.shared

    @State private var searchText: String = ""
    @State private var selectedFileType: FileTypeCategory? = nil
    @State private var selectedItem: FileItem? = nil
    @State private var selectedItemIDs: Set<UUID> = []
    @State private var isAiExplaining: Bool = false
    @State private var statusMessage: String?
    @State private var searchDebounceTask: Task<Void, Never>? = nil

    public init() {}

    private var isSearchMode: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var allScannedItems: [FileItem] {
        var list: [FileItem] = []
        for (_, items) in scanner.itemsByCategory {
            list.append(contentsOf: items)
        }
        return list
    }

    private var currentDataset: [FileItem] {
        if isSearchMode {
            return searchService.searchResults
        } else {
            return allScannedItems
        }
    }

    private var filteredItems: [FileItem] {
        var items = currentDataset

        if let selectedFileType, selectedFileType != .all {
            items = items.filter { $0.fileTypeCategory == selectedFileType }
        }

        return items
    }

    private var selectedItemsList: [FileItem] {
        currentDataset.filter { selectedItemIDs.contains($0.id) }
    }

    private var selectedTotalBytes: Int64 {
        selectedItemsList.reduce(0) { $0 + $1.size }
    }

    public var body: some View {
        HSplitView {
            // Left Pane: Search, Category Bar & File List
            VStack(spacing: 0) {
                searchHeader
                    .padding(12)

                Divider().background(ThingsTheme.borderSubtle)

                categoryFilterBar
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                Divider().background(ThingsTheme.borderSubtle)

                if searchService.isSearching && filteredItems.isEmpty {
                    searchingState
                } else if isSearchMode && filteredItems.isEmpty && !searchService.isSearching {
                    emptySearchState
                } else {
                    fileList
                }

                // Multi-select batch action footer (when 1 or more items selected)
                if !selectedItemIDs.isEmpty {
                    multiSelectActionBar
                }
            }
            .frame(minWidth: 440, maxWidth: 560)

            // Right Pane: Automatic Crucial Vitality Card
            VStack(spacing: 0) {
                if let selectedItem {
                    vitalityDetailPane(item: selectedItem)
                } else {
                    emptySelectionState
                }
            }
            .frame(minWidth: 360, maxWidth: .infinity)
            .background(ThingsTheme.canvas)
        }
        .frame(minWidth: 800, minHeight: 520)
        .onAppear {
            if !windowManager.activeSearchQuery.isEmpty {
                searchText = windowManager.activeSearchQuery
                performSearchImmediate(query: searchText)
            } else if selectedItem == nil, let first = filteredItems.first {
                selectItemAndExplain(first)
            }
        }
        .onChange(of: searchText) { _, newValue in
            performSearchDebounced(query: newValue)
        }
        .onChange(of: windowManager.activeSearchQuery) { _, newQ in
            if !newQ.isEmpty && newQ != searchText {
                searchText = newQ
                performSearchImmediate(query: newQ)
            }
        }
    }

    // MARK: - Search Header
    private var searchHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(isSearchMode ? ThingsTheme.accent : ThingsTheme.textTertiary)

            TextField("Search entire Mac (all docs, jpg, pdf, zip, code, files)...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit {
                    performSearchImmediate(query: searchText)
                }

            if searchService.isSearching {
                ProgressView()
                    .scaleEffect(0.65)
                    .frame(width: 16, height: 16)
            } else if isSearchMode {
                Button {
                    searchText = ""
                    windowManager.activeSearchQuery = ""
                    searchDebounceTask?.cancel()
                    searchService.searchResults = []
                    selectedItemIDs.removeAll()
                    selectedItem = allScannedItems.first
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ThingsTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            Button {
                if isSearchMode {
                    performSearchImmediate(query: searchText)
                } else {
                    Task {
                        await scanner.scanQuickCleanDashboard()
                    }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help(isSearchMode ? "Refresh System Search" : "Rescan Detected Files")
        }
        .padding(8)
        .background(ThingsTheme.cardRaised)
        .cornerRadius(8)
    }

    // MARK: - Category Filter Bar (All File Types)
    private var categoryFilterBar: some View {
        VStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    filterPill(title: "All (\(currentDataset.count))", isSelected: selectedFileType == nil || selectedFileType == .all) {
                        selectedFileType = .all
                    }

                    ForEach(FileTypeCategory.allCases.filter { $0 != .all }) { cat in
                        let count = currentDataset.filter { $0.fileTypeCategory == cat }.count
                        if count > 0 {
                            filterPill(title: "\(cat.rawValue) (\(count))", isSelected: selectedFileType == cat) {
                                selectedFileType = cat
                            }
                        }
                    }
                }
            }

            HStack {
                let allFiltered = filteredItems
                let isAllSelected = !allFiltered.isEmpty && allFiltered.allSatisfy { selectedItemIDs.contains($0.id) }

                Button {
                    if isAllSelected {
                        selectedItemIDs.removeAll()
                    } else {
                        for item in allFiltered {
                            selectedItemIDs.insert(item.id)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isAllSelected ? "checkmark.square.fill" : "square")
                            .font(.system(size: 11))
                            .foregroundStyle(isAllSelected ? ThingsTheme.accent : ThingsTheme.textTertiary)
                        Text(isAllSelected ? "Deselect All" : "Select All (\(allFiltered.count))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ThingsTheme.textSecondary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                if !selectedItemIDs.isEmpty {
                    Text("\(selectedItemIDs.count) selected · \(ByteCountFormatter.string(fromByteCount: selectedTotalBytes, countStyle: .file))")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ThingsTheme.accent)
                }
            }
            .padding(.top, 2)
        }
    }

    private func filterPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? ThingsTheme.accent : ThingsTheme.cardRaised)
                .foregroundStyle(isSelected ? Color.white : ThingsTheme.textPrimary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - File List
    private var fileList: some View {
        List(selection: Binding(
            get: { selectedItem },
            set: { newItem in
                if let newItem {
                    selectItemAndExplain(newItem)
                }
            }
        )) {
            ForEach(filteredItems) { item in
                fileRow(item: item)
                    .tag(item)
            }
        }
        .listStyle(.inset)
    }

    private func fileRow(item: FileItem) -> some View {
        HStack(spacing: 10) {
            // Multi-select Checkbox
            Button {
                if selectedItemIDs.contains(item.id) {
                    selectedItemIDs.remove(item.id)
                } else {
                    selectedItemIDs.insert(item.id)
                }
            } label: {
                Image(systemName: selectedItemIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(selectedItemIDs.contains(item.id) ? ThingsTheme.accent : ThingsTheme.textTertiary)
            }
            .buttonStyle(.plain)

            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ThingsTheme.textPrimary)
                        .lineLimit(1)

                    // File Format Badge (DOCX, PDF, JPG, etc.)
                    Text(item.fileExtension)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(item.fileTypeCategory.color.opacity(0.15))
                        .foregroundStyle(item.fileTypeCategory.color)
                        .clipShape(RoundedRectangle(cornerRadius: 3))

                    vitalityBadge(item.assessment.level)
                }

                Text(item.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                    .font(.system(size: 11))
                    .foregroundStyle(ThingsTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(item.formattedSize)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(ThingsTheme.textSecondary)
        }
        .padding(.vertical, 4)
    }

    private func vitalityBadge(_ level: VitalityLevel) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(level.badgeColor)
                .frame(width: 6, height: 6)
            Text(level.rawValue)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(level.badgeColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(level.badgeColor.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Multi-Select Action Bar (Bottom)
    private var multiSelectActionBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(selectedItemIDs.count) items selected")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ThingsTheme.textPrimary)

                Text(ByteCountFormatter.string(fromByteCount: selectedTotalBytes, countStyle: .file))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(ThingsTheme.textSecondary)
            }

            Spacer()

            Button {
                let paths = selectedItemsList.map { $0.path }
                FinderOpener.revealMultiple(paths: paths)
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)

            Button {
                trashSelectedItems()
            } label: {
                Label("Move to Trash", systemImage: "trash.fill")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(12)
        .background(ThingsTheme.cardRaised)
        .overlay(Divider().background(ThingsTheme.borderSubtle), alignment: .top)
    }

    // MARK: - Search State Views
    private var searchingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Searching entire Mac across all directories...")
                .font(.system(size: 12))
                .foregroundStyle(ThingsTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptySearchState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(ThingsTheme.textTertiary)

            Text("No files found matching \"\(searchText)\"")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ThingsTheme.textPrimary)

            Text("Try searching for file extensions (.pdf, .jpg, .zip, .docx), names, or project directories.")
                .font(.system(size: 11))
                .foregroundStyle(ThingsTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Vitality Inspector Card (Right Pane)
    private func vitalityDetailPane(item: FileItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Top Item Header
                HStack(spacing: 14) {
                    Image(nsImage: item.icon)
                        .resizable()
                        .frame(width: 52, height: 52)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(item.name)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(ThingsTheme.textPrimary)

                            Text(item.fileExtension)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(item.fileTypeCategory.color.opacity(0.15))
                                .foregroundStyle(item.fileTypeCategory.color)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }

                        Text(item.path)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(ThingsTheme.textTertiary)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                }
                .padding(.bottom, 6)

                Divider().background(ThingsTheme.borderSubtle)

                // Crucial Risk Assessment Bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(item.assessment.level.rawValue, systemImage: item.assessment.level.iconName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(item.assessment.level.badgeColor)

                        Spacer()

                        Text("Risk Score: \(item.assessment.riskScore)/100")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(ThingsTheme.textSecondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(ThingsTheme.borderSubtle)
                                .frame(height: 8)

                            Capsule()
                                .fill(item.assessment.level.badgeColor)
                                .frame(width: max(8, geo.size.width * CGFloat(Double(item.assessment.riskScore) / 100.0)), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(14)
                .background(item.assessment.level.badgeColor.opacity(0.08))
                .cornerRadius(10)

                // File Format Documentation Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("FILE FORMAT DOCUMENTATION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ThingsTheme.textTertiary)
                        .tracking(0.5)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.formatDescription)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ThingsTheme.textPrimary)

                            Text("Classification: \(item.fileTypeCategory.rawValue)")
                                .font(.system(size: 11))
                                .foregroundStyle(ThingsTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(ThingsTheme.cardRaised)
                    .cornerRadius(8)
                }

                // AI & Heuristic Explanation
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Why is this file here?")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(ThingsTheme.textPrimary)

                        Spacer()

                        if isAiExplaining {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else if item.assessment.aiGenerated {
                            Label("AI Verified", systemImage: "sparkles")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.purple)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    Text(item.assessment.summary)
                        .font(.system(size: 13))
                        .foregroundStyle(ThingsTheme.textPrimary)

                    Text(item.assessment.impact)
                        .font(.system(size: 12))
                        .foregroundStyle(ThingsTheme.textSecondary)
                        .padding(10)
                        .background(ThingsTheme.cardRaised)
                        .cornerRadius(8)
                }

                // Rebuild Command Box (if applicable)
                if let rebuildCmd = item.assessment.rebuildCommand {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("How to Recreate (if ever needed):")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ThingsTheme.textTertiary)

                        HStack {
                            Text(rebuildCmd)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(ThingsTheme.textPrimary)
                            Spacer()
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(rebuildCmd, forType: .string)
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.plain)
                            .help("Copy Rebuild Command")
                        }
                        .padding(8)
                        .background(ThingsTheme.cardRaised)
                        .cornerRadius(6)
                    }
                }

                // File Metadata Grid
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text("Size:").font(.system(size: 12, weight: .medium)).foregroundStyle(ThingsTheme.textSecondary)
                        Text(item.formattedSize).font(.system(size: 12, design: .monospaced)).foregroundStyle(ThingsTheme.textPrimary)
                    }
                    GridRow {
                        Text("Format:").font(.system(size: 12, weight: .medium)).foregroundStyle(ThingsTheme.textSecondary)
                        Text(item.fileExtension).font(.system(size: 12)).foregroundStyle(ThingsTheme.textPrimary)
                    }
                    GridRow {
                        Text("Category:").font(.system(size: 12, weight: .medium)).foregroundStyle(ThingsTheme.textSecondary)
                        Text(item.fileTypeCategory.rawValue).font(.system(size: 12)).foregroundStyle(ThingsTheme.textPrimary)
                    }
                    if item.daysSinceLastAccess > 0 {
                        GridRow {
                            Text("Last Opened:").font(.system(size: 12, weight: .medium)).foregroundStyle(ThingsTheme.textSecondary)
                            Text("\(item.daysSinceLastAccess) days ago").font(.system(size: 12)).foregroundStyle(ThingsTheme.textPrimary)
                        }
                    }
                }
                .padding(.top, 4)

                Spacer()

                Divider().background(ThingsTheme.borderSubtle)

                // Actions Bar
                HStack(spacing: 10) {
                    Button {
                        FinderOpener.reveal(path: item.path)
                    } label: {
                        Label("Reveal in Finder", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button {
                        trashItem(item)
                    } label: {
                        Label("Move to Trash", systemImage: "trash.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(item.assessment.level == .vital)
                    .help(item.assessment.level == .vital ? "Crucial Safety Lock protects vital files from deletion" : "Safely moves this item to macOS Trash")
                }
            }
            .padding(20)
        }
    }

    private var emptySelectionState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(ThingsTheme.textTertiary)

            Text("Select a file to inspect its vitality & format")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ThingsTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func selectItemAndExplain(_ item: FileItem) {
        self.selectedItem = item
    }

    private func performSearchDebounced(query: String) {
        searchDebounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchService.searchResults = []
            selectedItemIDs.removeAll()
            if selectedItem == nil || !allScannedItems.contains(where: { $0.id == selectedItem?.id }) {
                selectedItem = allScannedItems.first
            }
            return
        }

        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 120_000_000) // 120ms debounce
            if !Task.isCancelled {
                let results = await searchService.search(query: trimmed)
                if !Task.isCancelled {
                    if let first = results.first {
                        selectedItem = first
                    }
                }
            }
        }
    }

    private func performSearchImmediate(query: String) {
        searchDebounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            let results = await searchService.search(query: trimmed)
            if let first = results.first {
                selectedItem = first
            }
        }
    }

    private func trashItem(_ item: FileItem) {
        do {
            try trashService.trash(item: item)
            searchService.searchResults.removeAll { $0.url == item.url }
            selectedItemIDs.remove(item.id)
            if selectedItem?.url == item.url {
                selectedItem = filteredItems.first
            }
            Task {
                await scanner.scanQuickCleanDashboard()
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func trashSelectedItems() {
        let toTrash = selectedItemsList.filter { $0.assessment.level != .vital }
        for item in toTrash {
            try? trashService.trash(item: item)
            searchService.searchResults.removeAll { $0.url == item.url }
            selectedItemIDs.remove(item.id)
        }
        selectedItem = filteredItems.first
        Task {
            await scanner.scanQuickCleanDashboard()
        }
    }
}
