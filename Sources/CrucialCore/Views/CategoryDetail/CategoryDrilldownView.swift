import QuickLook
import SwiftUI

/// Detailed drilldown list and forensic inspector for a specific cleanup category.
public struct CategoryDrilldownView: View {
    public let category: JunkCategory

    @Environment(FileScannerService.self) private var scanner
    @Environment(NavigationStore.self) private var navigation

    @State private var selectedItemID: FileItem.ID?
    @State private var showCleanDialog = false
    @State private var filterText = ""

    public init(category: JunkCategory) {
        self.category = category
    }

    private var allCategoryItems: [FileItem] {
        scanner.itemsByCategory[category] ?? []
    }

    private var filteredItems: [FileItem] {
        let query = navigation.activeSearchQuery.isEmpty ? filterText : navigation.activeSearchQuery
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return allCategoryItems }
        return allCategoryItems.filter {
            $0.name.localizedStandardContains(trimmed) || $0.displayPath.localizedStandardContains(trimmed)
        }
    }

    private var selectedItem: FileItem? {
        guard let selectedItemID else { return nil }
        return allCategoryItems.first { $0.id == selectedItemID }
    }

    public var body: some View {
        VStack(spacing: 0) {
            CategoryToolbarHeader(
                category: category,
                items: allCategoryItems,
                filterText: $filterText,
                onSelectSafe: { scanner.selectSafeOnly(in: category) },
                onSelectAll: { scanner.selectAll(in: category, selected: true) },
                onDeselectAll: { scanner.selectAll(in: category, selected: false) },
                onRequestClean: { showCleanDialog = true }
            )

            Divider()

            if allCategoryItems.isEmpty {
                ContentUnavailableView {
                    Label("No Items in \(category.rawValue)", systemImage: category.iconName)
                } description: {
                    Text(category.description)
                } actions: {
                    Button("Scan Mac Storage") {
                        Task { await scanner.scanQuickCleanDashboard() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CrucialTheme.canvas)
            } else {
                HSplitView {
                    List(filteredItems, selection: $selectedItemID) { item in
                        CategoryItemRow(
                            item: item,
                            onToggleSelection: {
                                scanner.toggleSelection(for: item.id, in: category)
                            }
                        )
                        .tag(item.id)
                    }
                    .listStyle(.inset)
                    .frame(minWidth: 380, idealWidth: 520, maxWidth: .infinity)
                    .onKeyPress(.space) {
                        if let selectedItem {
                            navigation.preview(selectedItem.url)
                            return .handled
                        }
                        return .ignored
                    }

                    if let selectedItem {
                        FileDiagnosticInspectorView(item: selectedItem)
                            .frame(minWidth: 320, idealWidth: 360, maxWidth: 440)
                    } else {
                        ContentUnavailableView {
                            Label("Select an Item", systemImage: "sidebar.right")
                        } description: {
                            Text("Choose any file or directory from the list to inspect active process dependencies, safety rationale, and recovery options.")
                        }
                        .frame(minWidth: 300, idealWidth: 350, maxWidth: 420, maxHeight: .infinity)
                        .background(CrucialTheme.canvas)
                    }
                }
            }
        }
        .background(CrucialTheme.canvas)
        .onChange(of: category) { _, _ in
            selectedItemID = allCategoryItems.first?.id
        }
        .onAppear {
            if selectedItemID == nil {
                selectedItemID = allCategoryItems.first?.id
            }
        }
        .confirmationDialog(
            "Clean Selected \(category.rawValue)?",
            isPresented: $showCleanDialog,
            titleVisibility: .visible
        ) {
            let selection = scanner.getSelectedCountAndBytes(for: category)
            Button(
                "Move \(selection.count) Items (\(ByteCountFormatter.string(fromByteCount: selection.bytes, countStyle: .file))) to Trash",
                role: .destructive
            ) {
                _ = scanner.cleanSelected(in: category)
                if let currentID = selectedItemID,
                   !allCategoryItems.contains(where: { $0.id == currentID }) {
                    selectedItemID = allCategoryItems.first?.id
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Items are placed in macOS Trash rather than immediately unlinked.")
        }
    }
}

private struct CategoryToolbarHeader: View {
    let category: JunkCategory
    let items: [FileItem]
    @Binding var filterText: String
    let onSelectSafe: () -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onRequestClean: () -> Void

    private static let cleanButtonFill = Color(red: 0.031, green: 0.478, blue: 0.384)

    var body: some View {
        let selectedItems = items.filter(\.isSelected)
        let selectedBytes = selectedItems.reduce(0) { $0 + $1.size }
        let formattedSelected = ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file)

        HStack(spacing: CrucialSpacing.md) {
            Image(systemName: category.iconName)
                .font(.title2)
                .foregroundStyle(category.color)

            VStack(alignment: .leading, spacing: CrucialSpacing.xxs) {
                Text(category.rawValue)
                    .font(.headline)
                    .foregroundStyle(CrucialTheme.textPrimary)
                Text(category.description)
                    .font(.caption)
                    .foregroundStyle(CrucialTheme.textSecondary)
            }

            Spacer()

            if !items.isEmpty {
                TextField("Filter category", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)

                Menu("Select") {
                    Button("Safe Items Only", action: onSelectSafe)
                    Button("Select All Non-Protected", action: onSelectAll)
                    Button("Deselect All", action: onDeselectAll)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                if !selectedItems.isEmpty {
                    Button(action: onRequestClean) {
                        Label("Trash \(selectedItems.count) (\(formattedSelected))", systemImage: "trash")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, CrucialSpacing.md)
                            .padding(.vertical, 6)
                            .background(Self.cleanButtonFill, in: .rect(cornerRadius: 6, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
        .padding(.horizontal, CrucialSpacing.lg)
        .padding(.vertical, CrucialSpacing.md)
        .background(CrucialTheme.card)
    }
}
