import SwiftUI

/// Accessible toggle control with animated state indicator and crisp keyboard/mouse hit target.
public struct CrucialCheckbox: View {
    public let isSelected: Bool
    public let label: String
    public let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let activeFill = Color(red: 0.031, green: 0.478, blue: 0.384) // #087A62 (5.5:1 vs white)

    public init(isSelected: Bool, label: String = "Select item", action: @escaping () -> Void) {
        self.isSelected = isSelected
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isSelected ? Self.activeFill : CrucialTheme.cardRaised)
                    .frame(width: 18, height: 18)

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(
                        isSelected ? Self.activeFill : CrucialTheme.border,
                        lineWidth: 1.25
                    )
                    .frame(width: 18, height: 18)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.75).combined(with: .opacity))
                }
            }
            .frame(width: 24, height: 24)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isSelected ? "Selected" : "Unselected")
        .accessibilityAddTraits(.isButton)
        .animation(reduceMotion ? nil : CrucialMotion.control, value: isSelected)
    }
}
