import SwiftUI
import AppKit

public struct FileFinderView: View {
    @ObservedObject var scanner = FileScannerService.shared
    @ObservedObject var trashService = SafetyTrashService.shared
    @State private var searchText: String = ""
    @State private var selectedCategory: JunkCategory? = nil
    @State private var selectedItem: FileItem? = nil
    @State private var isAiExplaining: Bool = false
    @State private var statusMessage: String?

    public init() {}

    private var allItems: [FileItem] {
        var list: [FileItem] = []
        for (_, items) in scanner.itemsByCategory {
            list.append(contentsOf: items)
        }
        return list
    }

    private var filteredItems: [FileItem] {
        var items = allItems

        if let selectedCategory {
            items = items.filter { $0.category == selectedCategory }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            items = items.filter {
                $0.name.lowercased().contains(query) ||
                $0.path.lowercased().contains(query) ||
                $0.category.rawValue.lowercased().contains(query)
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    public var body: some View {
        HSplitView {
            // Left Pane: Search & File List
            VStack(spacing: 0) {
                searchHeader
                    .padding(12)

                Divider()

                categoryFilterBar
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                Divider()

                fileList
            }
            .frame(minWidth: 420, maxWidth: 540)

            // Right Pane: Automatic Crucial Vitality Card
            VStack(spacing: 0) {
                if let selectedItem {
                    vitalityDetailPane(item: selectedItem)
                } else {
                    emptySelectionState
                }
            }
            .frame(minWidth: 360, maxWidth: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 800, minHeight: 520)
        .onAppear {
            if selectedItem == nil, let first = filteredItems.first {
                selectItemAndExplain(first)
            }
        }
    }

    // MARK: - Search Header
    private var searchHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search by name, path, extension, or keywords...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button {
                Task {
                    await scanner.scanQuickCleanDashboard()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Rescan Files")
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Category Filter Bar
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterPill(title: "All (\(allItems.count))", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }

                ForEach(JunkCategory.allCases.filter { $0 != .custom }) { cat in
                    let count = scanner.itemsByCategory[cat]?.count ?? 0
                    if count > 0 {
                        filterPill(title: "\(cat.rawValue) (\(count))", isSelected: selectedCategory == cat) {
                            selectedCategory = cat
                        }
                    }
                }
            }
        }
    }

    private func filterPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
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
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    vitalityBadge(item.assessment.level)
                }

                Text(item.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(item.formattedSize)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
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
                        Text(item.name)
                            .font(.system(size: 18, weight: .bold))

                        Text(item.path)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                }
                .padding(.bottom, 6)

                Divider()

                // Crucial Risk Assessment Bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(item.assessment.level.rawValue, systemImage: item.assessment.level.iconName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(item.assessment.level.badgeColor)

                        Spacer()

                        Text("Risk Score: \(item.assessment.riskScore)/100")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.15))
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

                // AI & Heuristic Explanation
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Why is this file here?")
                            .font(.system(size: 13, weight: .bold))

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
                        .foregroundStyle(.primary)

                    Text(item.assessment.impact)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                }

                // Rebuild Command Box (if applicable)
                if let rebuildCmd = item.assessment.rebuildCommand {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("How to Recreate (if ever needed):")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        HStack {
                            Text(rebuildCmd)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.primary)
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
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                }

                // File Metadata Grid
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text("Size:").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Text(item.formattedSize).font(.system(size: 12, design: .monospaced))
                    }
                    GridRow {
                        Text("Category:").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Text(item.category.rawValue).font(.system(size: 12))
                    }
                    if item.daysSinceLastAccess > 0 {
                        GridRow {
                            Text("Last Opened:").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                            Text("\(item.daysSinceLastAccess) days ago").font(.system(size: 12))
                        }
                    }
                }
                .padding(.top, 4)

                Spacer()

                Divider()

                // Actions Bar
                HStack(spacing: 10) {
                    Button {
                        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
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
                .foregroundStyle(.secondary)

            Text("Select a file to inspect its vitality")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func selectItemAndExplain(_ item: FileItem) {
        self.selectedItem = item

        // Automatic AI Explanation
        if GeminiExplainerService.shared.apiKey != nil {
            Task {
                await MainActor.run { isAiExplaining = true }
                let newAssessment = await GeminiExplainerService.shared.explain(item: item)
                await MainActor.run {
                    if self.selectedItem?.id == item.id {
                        self.selectedItem?.assessment = newAssessment
                    }
                    self.isAiExplaining = false
                }
            }
        }
    }

    private func trashItem(_ item: FileItem) {
        do {
            try trashService.trash(item: item)
            // Remove from list
            Task {
                await scanner.scanQuickCleanDashboard()
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
