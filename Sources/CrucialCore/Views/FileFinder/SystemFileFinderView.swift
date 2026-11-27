import QuickLook
import SwiftUI

/// Deep Spotlight + user-directory search paired with the live forensic file inspector.
public struct SystemFileFinderView: View {
    @Environment(SystemFileSearchService.self) private var fileSearch
    @Environment(NavigationStore.self) private var navigation

    @State private var query = ""
    @State private var selectedType: FileTypeCategory = .all
    @State private var selectedItemID: FileItem.ID?

    public init() {}

    private var filteredResults: [FileItem] {
        guard selectedType != .all else { return fileSearch.searchResults }
        return fileSearch.searchResults.filter { $0.fileTypeCategory == selectedType }
    }

    private var selectedItem: FileItem? {
        guard let selectedItemID else { return nil }
        return filteredResults.first { $0.id == selectedItemID }
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchHeader

            Divider()

            if fileSearch.isSearching {
                VStack(spacing: CrucialSpacing.md) {
                    ProgressView()
                    Text("Querying Spotlight index and user directories...")
                        .font(.subheadline)
                        .foregroundStyle(CrucialTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CrucialTheme.canvas)
            } else if filteredResults.isEmpty {
                ContentUnavailableView {
                    Label("Deep File Finder", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text(
                        fileSearch.lastQuery.isEmpty
                            ? "Search by filename, extension, or keyword to inspect size, active processes, and safe removal posture."
                            : "No indexed files matched '\(fileSearch.lastQuery)' under \(selectedType.rawValue)."
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CrucialTheme.canvas)
            } else {
                HSplitView {
                    List(filteredResults, selection: $selectedItemID) { item in
                        CategoryItemRow(item: item) {}
                            .tag(item.id)
                    }
                    .listStyle(.inset)
                    .frame(minWidth: 380, maxWidth: .infinity)
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
                    }
                }
            }
        }
        .background(CrucialTheme.canvas)
        .onAppear {
            if query.isEmpty && !navigation.activeSearchQuery.isEmpty {
                query = navigation.activeSearchQuery
                Task { _ = await fileSearch.search(query: query) }
            }
        }
    }

    private var searchHeader: some View {
        HStack(spacing: CrucialSpacing.md) {
            TextField("Search filename or extension (for example deriveddata, dmg, mp4)", text: $query)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    Task {
                        _ = await fileSearch.search(query: query)
                        selectedItemID = filteredResults.first?.id
                    }
                }

            Picker("File Type", selection: $selectedType) {
                ForEach(FileTypeCategory.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .frame(width: 190)

            Button("Search") {
                Task {
                    _ = await fileSearch.search(query: query)
                    selectedItemID = filteredResults.first?.id
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(CrucialTheme.accentInk)
            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || fileSearch.isSearching)
        }
        .padding(.horizontal, CrucialSpacing.lg)
        .padding(.vertical, CrucialSpacing.md)
        .background(CrucialTheme.card)
    }
}
