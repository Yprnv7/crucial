import SwiftUI

/// Compact numeric ring card for inspector risk, bloat, and confidence scores.
public struct ScoreRingCard: View {
    public let title: String
    public let score: Int
    public let color: Color

    public init(title: String, score: Int, color: Color) {
        self.title = title
        self.score = score
        self.color = color
    }

    public var body: some View {
        VStack(spacing: CrucialSpacing.xs) {
            CrucialProgressRing(
                progress: Double(min(max(score, 0), 100)) / 100.0,
                color: color,
                lineWidth: 5,
                size: 52,
                centerTitle: "\(score)"
            )

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(CrucialTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CrucialSpacing.sm)
        .background(CrucialTheme.cardRaised, in: .rect(cornerRadius: 8, style: .continuous))
    }
}
