import SwiftUI

/// Compact labeled statistic column used in the Storage Breakdown telemetry bar.
public struct VitalStatColumn: View {
    public let title: String
    public let value: String
    public let detail: String

    public init(title: String, value: String, detail: String) {
        self.title = title
        self.value = value
        self.detail = detail
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CrucialSpacing.xxs) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(CrucialTheme.textTertiary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(CrucialTheme.textPrimary)
                .lineLimit(1)

            Text(detail)
                .font(.caption)
                .foregroundStyle(CrucialTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
