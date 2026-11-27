import SwiftUI

/// Renders an original-plus-copies duplicate set verified by identical SHA-256 digests.
public struct DuplicateGroupRow: View {
    public let group: DuplicateGroup
    public let onTrashCopy: (FileItem) -> Void

    public init(group: DuplicateGroup, onTrashCopy: @escaping (FileItem) -> Void) {
        self.group = group
        self.onTrashCopy = onTrashCopy
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CrucialSpacing.md) {
            HStack {
                FileIconImage(path: group.original.path, size: 28)

                VStack(alignment: .leading, spacing: CrucialSpacing.xxs) {
                    Text(group.original.name)
                        .font(.headline)
                        .foregroundStyle(CrucialTheme.textPrimary)

                    Text("SHA-256 \(group.hash.prefix(12))...  |  \(group.duplicates.count) extra copies")
                        .font(.caption.monospaced())
                        .foregroundStyle(CrucialTheme.textSecondary)
                }

                Spacer()

                CrucialTag("\(group.formattedWastedSize) wasted", color: CrucialTheme.starOchre)
            }

            Divider()

            duplicateEntry(item: group.original, isOriginal: true)

            ForEach(group.duplicates) { copy in
                duplicateEntry(item: copy, isOriginal: false)
            }
        }
        .padding(CrucialSpacing.lg)
        .background(CrucialTheme.card, in: .rect(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(CrucialTheme.border, lineWidth: 1)
        }
    }

    private func duplicateEntry(item: FileItem, isOriginal: Bool) -> some View {
        HStack(spacing: CrucialSpacing.md) {
            CrucialTag(
                isOriginal ? "Original Kept" : "Duplicate Copy",
                color: isOriginal ? CrucialTheme.accentInk : CrucialTheme.textSecondary
            )

            Text(item.displayPath)
                .font(.caption)
                .foregroundStyle(CrucialTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(item.formattedSize)
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(CrucialTheme.textSecondary)

            Button {
                FinderOpener.reveal(path: item.path)
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)
            .accessibilityLabel("Reveal \(item.name) in Finder")

            if !isOriginal {
                Button("Trash") {
                    onTrashCopy(item)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}
