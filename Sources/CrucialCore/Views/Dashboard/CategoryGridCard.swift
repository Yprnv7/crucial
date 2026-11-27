import SwiftUI

/// Interactive summary card representing a single scan category on the dashboard.
public struct CategoryGridCard: View {
    public let category: JunkCategory
    public let items: [FileItem]
    public let isScanning: Bool
    public let action: () -> Void

    public init(
        category: JunkCategory,
        items: [FileItem],
        isScanning: Bool,
        action: @escaping () -> Void
    ) {
        self.category = category
        self.items = items
        self.isScanning = isScanning
        self.action = action
    }

    private var totalBytes: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    private var selectedBytes: Int64 {
        items.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }

    private var safeCount: Int {
        items.count(where: { $0.assessment.level == .safeToDelete })
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: CrucialSpacing.md) {
                HStack(alignment: .top) {
                    Image(systemName: category.iconName)
                        .font(.title3)
                        .foregroundStyle(category.color)
                        .frame(width: 34, height: 34)
                        .background(category.color.opacity(0.12), in: .rect(cornerRadius: 8, style: .continuous))

                    Spacer()

                    Text(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(CrucialTheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: CrucialSpacing.xs) {
                    Text(category.rawValue)
                        .font(.headline)
                        .foregroundStyle(CrucialTheme.textPrimary)

                    Text(category.description)
                        .font(.caption)
                        .foregroundStyle(CrucialTheme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Divider()
                    .background(CrucialTheme.borderSubtle)

                HStack {
                    if isScanning && items.isEmpty {
                        Text("Scanning...")
                            .font(.caption)
                            .foregroundStyle(CrucialTheme.textSecondary)
                    } else {
                        Text("\(items.count) items (\(safeCount) safe)")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(CrucialTheme.textSecondary)
                    }

                    Spacer()

                    if selectedBytes > 0 {
                        CrucialTag(
                            "\(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file)) selected",
                            color: CrucialTheme.accentInk
                        )
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(CrucialTheme.textTertiary)
                    }
                }
            }
            .padding(CrucialSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CrucialTheme.card, in: .rect(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(CrucialTheme.border, lineWidth: 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.99))
        .accessibilityLabel("\(category.rawValue), \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)), \(items.count) items")
    }
}
