import SwiftUI

/// Scans scanned categories and home media for exact SHA-256 duplicate files.
public struct DuplicateFinderView: View {
    @Environment(DuplicateFinderService.self) private var duplicates
    @Environment(FileScannerService.self) private var scanner

    @State private var showTrashAllConfirmation = false

    public init() {}

    private var candidateItems: [FileItem] {
        scanner.itemsByCategory.values.flatMap { $0 }
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            if let errorMessage = duplicates.lastErrorMessage {
                HStack(spacing: CrucialSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(CrucialTheme.starOchre)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(CrucialTheme.textPrimary)
                    Spacer()
                }
                .padding(CrucialSpacing.md)
                .background(CrucialTheme.card)
                Divider()
            }

            if duplicates.isScanning {
                VStack(spacing: CrucialSpacing.md) {
                    ProgressView()
                    Text(duplicates.progressMessage)
                        .font(.subheadline)
                        .foregroundStyle(CrucialTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CrucialTheme.canvas)
            } else if duplicates.duplicateGroups.isEmpty {
                ContentUnavailableView {
                    Label("No Duplicate Groups", systemImage: "doc.on.doc")
                } description: {
                    Text(duplicates.progressMessage)
                } actions: {
                    Button("Scan for Duplicates") {
                        Task { await duplicates.scanForDuplicates(in: candidateItems) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CrucialTheme.canvas)
            } else {
                ScrollView {
                    LazyVStack(spacing: CrucialSpacing.md) {
                        ForEach(duplicates.duplicateGroups) { group in
                            DuplicateGroupRow(group: group) { item in
                                duplicates.trashDuplicate(item: item)
                            }
                        }
                    }
                    .padding(CrucialSpacing.xl)
                }
                .background(CrucialTheme.canvas)
            }
        }
        .confirmationDialog(
            "Trash All Extra Duplicate Copies?",
            isPresented: $showTrashAllConfirmation,
            titleVisibility: .visible
        ) {
            let wasted = ByteCountFormatter.string(fromByteCount: duplicates.totalWastedBytes, countStyle: .file)
            Button("Trash Duplicates (\(wasted))", role: .destructive) {
                duplicates.trashAllDuplicates()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The primary original file in every group is kept intact; only extra copies are moved to Trash.")
        }
    }

    private var headerBar: some View {
        HStack(spacing: CrucialSpacing.md) {
            VStack(alignment: .leading, spacing: CrucialSpacing.xxs) {
                Text("Duplicate Finder")
                    .font(.headline)
                    .foregroundStyle(CrucialTheme.textPrimary)

                Text(
                    duplicates.totalWastedBytes > 0
                        ? "\(duplicates.duplicateGroups.count) groups wasting \(ByteCountFormatter.string(fromByteCount: duplicates.totalWastedBytes, countStyle: .file))"
                        : "Size, 4 KB boundary hash, and full SHA-256 verification"
                )
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(CrucialTheme.textSecondary)
            }

            Spacer()

            Button("Scan") {
                Task { await duplicates.scanForDuplicates(in: candidateItems) }
            }
            .buttonStyle(.bordered)
            .disabled(duplicates.isScanning)

            if !duplicates.duplicateGroups.isEmpty {
                Button("Trash All Extras", role: .destructive) {
                    showTrashAllConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .tint(CrucialTheme.vitalCrimson)
            }
        }
        .padding(.horizontal, CrucialSpacing.lg)
        .padding(.vertical, CrucialSpacing.md)
        .background(CrucialTheme.card)
    }
}
