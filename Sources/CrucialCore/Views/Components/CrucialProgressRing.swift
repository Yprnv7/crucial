import SwiftUI

/// Circular gauge displaying a bounded percentage with optional center caption.
public struct CrucialProgressRing: View {
    public let progress: Double
    public let color: Color
    public let lineWidth: CGFloat
    public let size: CGFloat
    public let centerTitle: String?
    public let centerSubtitle: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        progress: Double,
        color: Color = CrucialTheme.accent,
        lineWidth: CGFloat = 10,
        size: CGFloat = 96,
        centerTitle: String? = nil,
        centerSubtitle: String? = nil
    ) {
        self.progress = min(max(progress, 0), 1)
        self.color = color
        self.lineWidth = lineWidth
        self.size = size
        self.centerTitle = centerTitle
        self.centerSubtitle = centerSubtitle
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(CrucialTheme.borderSubtle, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : CrucialMotion.navigation, value: progress)

            if centerTitle != nil || centerSubtitle != nil {
                VStack(spacing: CrucialSpacing.xxs) {
                    if let centerTitle {
                        Text(centerTitle)
                            .font(.system(size: size * 0.23, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(CrucialTheme.textPrimary)
                    }
                    if let centerSubtitle {
                        Text(centerSubtitle)
                            .font(.system(size: max(11, size * 0.12), weight: .medium))
                            .foregroundStyle(CrucialTheme.textSecondary)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(centerSubtitle ?? "Progress")
        .accessibilityValue("\(Int((progress * 100).rounded())) percent")
    }
}
