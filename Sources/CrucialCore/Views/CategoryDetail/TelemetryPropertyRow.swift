import SwiftUI

/// Key-value metadata row inside the forensic inspector panel.
public struct TelemetryPropertyRow: View {
    public let label: String
    public let value: String
    public let isMonospaced: Bool

    public init(label: String, value: String, isMonospaced: Bool = false) {
        self.label = label
        self.value = value
        self.isMonospaced = isMonospaced
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CrucialSpacing.xxs) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(CrucialTheme.textTertiary)

            Text(value)
                .font(isMonospaced ? .caption.monospaced() : .caption)
                .foregroundStyle(CrucialTheme.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, CrucialSpacing.xxs)
    }
}
