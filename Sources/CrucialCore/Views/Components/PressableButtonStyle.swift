import SwiftUI

/// Button style providing crisp surface feedback and subtle tactile compression on press.
public struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let scale: CGFloat

    public init(scale: CGFloat = 0.97) {
        self.scale = scale
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1.0)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(reduceMotion ? nil : CrucialMotion.control, value: configuration.isPressed)
    }
}
