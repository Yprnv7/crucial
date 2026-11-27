import SwiftUI

/// Compact pill badge used to indicate safety posture, status, or file metadata.
public struct CrucialTag: View {
    public let text: String
    public let color: Color

    public init(_ text: String, color: Color = CrucialTheme.textSecondary) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, CrucialSpacing.sm)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: .capsule)
            .overlay {
                Capsule()
                    .strokeBorder(color.opacity(0.32), lineWidth: 1)
            }
            .lineLimit(1)
    }
}
