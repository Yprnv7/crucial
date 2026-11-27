import SwiftUI

/// Interactive row representing a storage sector with percentage share and drill-down action.
public struct DiskSectorRowView: View {
    public let sector: DiskSectorItem
    public let isSelected: Bool
    public let action: () -> Void

    public init(sector: DiskSectorItem, isSelected: Bool, action: @escaping () -> Void) {
        self.sector = sector
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: CrucialSpacing.md) {
                Circle()
                    .fill(sector.color)
                    .frame(width: 10, height: 10)

                Image(systemName: sector.iconName)
                    .foregroundStyle(sector.color)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: CrucialSpacing.xxs) {
                    Text(sector.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(CrucialTheme.textPrimary)

                    Text(sector.description)
                        .font(.caption)
                        .foregroundStyle(CrucialTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: CrucialSpacing.xxs) {
                    Text(ByteCountFormatter.string(fromByteCount: sector.size, countStyle: .file))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(CrucialTheme.textPrimary)

                    Text("\(sector.percentage.formatted(.number.precision(.fractionLength(1))))%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(CrucialTheme.textSecondary)
                }

                if sector.targetNav != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(CrucialTheme.textTertiary)
                }
            }
            .padding(CrucialSpacing.md)
            .background(CrucialTheme.card, in: .rect(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? CrucialTheme.accent : CrucialTheme.border, lineWidth: 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.99))
    }
}
