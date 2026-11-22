import SwiftUI
import AppKit

public struct DuplicatesView: View {
    @ObservedObject var dupService = DuplicateFinderService.shared
    @ObservedObject var scanner = FileScannerService.shared
    @State private var showingTrashAllAlert = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar (Things 3 Grand Header)
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(ThingsTheme.purple.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ThingsTheme.purple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Duplicate File Finder")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(ThingsTheme.textPrimary)

                    if dupService.totalWastedBytes > 0 {
                        Text("\(dupService.duplicateGroups.count) duplicate clusters · \(ByteCountFormatter.string(fromByteCount: dupService.totalWastedBytes, countStyle: .file)) redundant waste")
                            .font(.system(size: 11.5))
                            .foregroundStyle(ThingsTheme.textSecondary)
                    } else {
                        Text("Cryptographic SHA-256 byte verification ensures 100% false-positive free matching.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(ThingsTheme.textSecondary)
                    }
                }

                Spacer()

                if dupService.isScanning {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7)
                        Text(dupService.progressMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(ThingsTheme.textSecondary)
                    }
                } else {
                    HStack(spacing: 8) {
                        Button {
                            Task {
                                var allItems: [FileItem] = []
                                for (_, items) in scanner.itemsByCategory {
                                    allItems.append(contentsOf: items)
                                }
                                await dupService.scanForDuplicates(in: allItems)
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11))
                                Text("Scan Duplicates")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(ThingsTheme.cardRaised)
                            .foregroundStyle(ThingsTheme.textPrimary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        if dupService.totalWastedBytes > 0 {
                            Button {
                                showingTrashAllAlert = true
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 11))
                                    Text("Purge Duplicates (\(ByteCountFormatter.string(fromByteCount: dupService.totalWastedBytes, countStyle: .file)))")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(ThingsTheme.accent)
                                .foregroundStyle(Color.white)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(ThingsTheme.canvas)

            Divider().background(ThingsTheme.borderSubtle)

            // Content List
            if dupService.duplicateGroups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(ThingsTheme.accent)

                    Text(dupService.isScanning ? "Scanning for Duplicates..." : "No Redundant Duplicates")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(ThingsTheme.textPrimary)

                    Text(dupService.isScanning ? "Comparing cryptographic hashes across files..." : "Click 'Scan Duplicates' to discover identical files across your folders.")
                        .font(.system(size: 12))
                        .foregroundStyle(ThingsTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(dupService.duplicateGroups) { group in
                            duplicateGroupCard(group)
                        }
                    }
                    .padding(24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThingsTheme.canvas)
        .onAppear {
            if dupService.duplicateGroups.isEmpty && !dupService.isScanning {
                Task {
                    var allItems: [FileItem] = []
                    for (_, items) in scanner.itemsByCategory {
                        allItems.append(contentsOf: items)
                    }
                    await dupService.scanForDuplicates(in: allItems)
                }
            }
        }
        .alert(isPresented: $showingTrashAllAlert) {
            Alert(
                title: Text("Purge All Duplicate Copies"),
                message: Text("Crucial will preserve all original files and safely stage \(ByteCountFormatter.string(fromByteCount: dupService.totalWastedBytes, countStyle: .file)) of redundant duplicates into macOS Trash."),
                primaryButton: .destructive(Text("Move to Trash")) {
                    dupService.trashAllDuplicates()
                },
                secondaryButton: .cancel(Text("Cancel"))
            )
        }
    }

    private func duplicateGroupCard(_ group: CryptoDuplicateGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Group Header
            HStack {
                HStack(spacing: 6) {
                    Image(nsImage: group.original.icon)
                        .resizable()
                        .frame(width: 18, height: 18)

                    Text(group.original.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ThingsTheme.textPrimary)
                }

                Spacer()

                ThingsTag("\(group.duplicates.count) Redundant Copies", color: ThingsTheme.purple)

                Text(group.formattedWastedSize + " wasted")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ThingsTheme.accent)
            }

            Divider().background(ThingsTheme.borderSubtle)

            // Original File Row
            HStack(spacing: 8) {
                ThingsTag("ORIGINAL", color: ThingsTheme.infoIndigo)

                Text(group.original.path)
                    .font(.system(size: 10.5))
                    .foregroundStyle(ThingsTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button {
                    NSWorkspace.shared.selectFile(group.original.path, inFileViewerRootedAtPath: "")
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                        .foregroundStyle(ThingsTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Reveal original in Finder")
            }
            .padding(8)
            .background(ThingsTheme.cardRaised)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Duplicate Copies Rows
            VStack(spacing: 6) {
                ForEach(group.duplicates) { dup in
                    HStack(spacing: 8) {
                        ThingsTag("DUPLICATE", color: ThingsTheme.starOchre)

                        Text(dup.path)
                            .font(.system(size: 10.5))
                            .foregroundStyle(ThingsTheme.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Button {
                            NSWorkspace.shared.selectFile(dup.path, inFileViewerRootedAtPath: "")
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 11))
                                .foregroundStyle(ThingsTheme.textTertiary)
                        }
                        .buttonStyle(.plain)

                        Button {
                            dupService.trashDuplicate(item: dup)
                        } label: {
                            Text("Trash Copy")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(ThingsTheme.vitalCrimson.opacity(0.12))
                                .foregroundStyle(ThingsTheme.vitalCrimson)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(ThingsTheme.canvas)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
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
}
