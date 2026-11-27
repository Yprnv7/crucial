import SwiftUI

/// Single file or directory row in a category cleanup list.
public struct CategoryItemRow: View {
    public let item: FileItem
    public let onToggleSelection: () -> Void

    public init(item: FileItem, onToggleSelection: @escaping () -> Void) {
        self.item = item
        self.onToggleSelection = onToggleSelection
    }

    public var body: some View {
        HStack(spacing: CrucialSpacing.md) {
            if item.assessment.level == .vital {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(CrucialTheme.vitalCrimson)
                    .frame(width: 24, height: 24)
                    .accessibilityLabel("Protected system item")
            } else {
                CrucialCheckbox(
                    isSelected: item.isSelected,
                    label: "Select \(item.name)",
                    action: onToggleSelection
                )
            }

            FileIconImage(path: item.path, size: 28)

            VStack(alignment: .leading, spacing: CrucialSpacing.xxs) {
                HStack(spacing: CrucialSpacing.sm) {
                    Text(item.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(CrucialTheme.textPrimary)
                        .lineLimit(1)

                    CrucialTag(item.assessment.level.rawValue, color: item.assessment.level.badgeColor)
                }

                Text(item.displayPath)
                    .font(.caption)
                    .foregroundStyle(CrucialTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: CrucialSpacing.sm)

            Text(item.formattedSize)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(CrucialTheme.textPrimary)
        }
        .padding(.vertical, CrucialSpacing.xs)
        .contextMenu {
            Button("Reveal in Finder") {
                FinderOpener.reveal(path: item.path)
            }
            if item.assessment.level != .vital {
                Button(item.isSelected ? "Deselect Item" : "Select Item", action: onToggleSelection)
            }
        }
    }
}
