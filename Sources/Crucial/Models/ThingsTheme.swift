import SwiftUI
import AppKit

public enum ThingsTheme {
    // MARK: - Bespoke Color Palette (Nordic Alpine Emerald & Honey Ochre)
    // Primary Signature Accent: Alpine Emerald (Clean, Reclaimed Storage)
    public static let accent = Color(red: 0.05, green: 0.65, blue: 0.53)        // #0DA687
    public static let accentLight = Color(red: 0.10, green: 0.74, blue: 0.61)   // #1ABCA0
    public static let accentDark = Color(red: 0.04, green: 0.52, blue: 0.42)    // #0A856B

    // Secondary Accent: Honey Ochre / Warm Amber (Things "Today" Star & Warnings)
    public static let starOchre = Color(red: 0.96, green: 0.62, blue: 0.10)     // #F59E1A
    public static let warning = Color(red: 0.96, green: 0.55, blue: 0.12)       // #F58C1F

    // Semantic Accents
    public static let vitalCrimson = Color(red: 0.94, green: 0.28, blue: 0.28)  // #EF4747
    public static let infoIndigo = Color(red: 0.39, green: 0.42, blue: 0.95)    // #636BF2
    public static let glacierCyan = Color(red: 0.04, green: 0.72, blue: 0.84)   // #0AB8D6
    public static let purple = Color(red: 0.64, green: 0.36, blue: 0.95)        // #A35CF2

    // MARK: - Native macOS Things 3 Surfaces (Adaptive Dark & Light)
    public static var canvas: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.094, green: 0.098, blue: 0.106, alpha: 1.0) // #18191B
                : NSColor(red: 0.984, green: 0.984, blue: 0.988, alpha: 1.0) // #FBFBFC
        }))
    }

    public static var sidebar: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.075, green: 0.078, blue: 0.086, alpha: 1.0) // #131416
                : NSColor(red: 0.957, green: 0.961, blue: 0.969, alpha: 1.0) // #F4F5F7
        }))
    }

    public static var card: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.125, green: 0.133, blue: 0.149, alpha: 1.0) // #202226
                : NSColor.white
        }))
    }

    public static var cardRaised: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.157, green: 0.165, blue: 0.184, alpha: 1.0) // #282A2F
                : NSColor(red: 0.941, green: 0.945, blue: 0.957, alpha: 1.0) // #F0F1F4
        }))
    }

    public static var cardHover: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.165, green: 0.173, blue: 0.196, alpha: 1.0) // #2A2C32
                : NSColor(red: 0.925, green: 0.933, blue: 0.949, alpha: 1.0) // #ECEEF2
        }))
    }

    public static var border: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.173, green: 0.180, blue: 0.204, alpha: 1.0) // #2C2E34
                : NSColor(red: 0.898, green: 0.906, blue: 0.922, alpha: 1.0) // #E5E7EB
        }))
    }

    public static var borderSubtle: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.145, green: 0.153, blue: 0.169, alpha: 0.6)
                : NSColor(red: 0.920, green: 0.925, blue: 0.935, alpha: 0.8)
        }))
    }

    // MARK: - Typography Colors
    public static var textPrimary: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.976, green: 0.980, blue: 0.984, alpha: 1.0) // #F9FAFB
                : NSColor(red: 0.110, green: 0.114, blue: 0.122, alpha: 1.0) // #1C1D1F
        }))
    }

    public static var textSecondary: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.612, green: 0.639, blue: 0.686, alpha: 1.0) // #9CA3AF
                : NSColor(red: 0.420, green: 0.447, blue: 0.502, alpha: 1.0) // #6B7280
        }))
    }

    public static var textTertiary: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.420, green: 0.447, blue: 0.502, alpha: 1.0) // #6B7280
                : NSColor(red: 0.612, green: 0.639, blue: 0.686, alpha: 1.0) // #9CA3AF
        }))
    }

    public static var textQuaternary: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.294, green: 0.333, blue: 0.388, alpha: 1.0) // #4B5563
                : NSColor(red: 0.820, green: 0.835, blue: 0.859, alpha: 1.0) // #D1D5DB
        }))
    }
}

// MARK: - Backward Compatibility Alias
public typealias RetroTheme = ThingsCompatTheme

public enum ThingsCompatTheme {
    public static var bg: Color { ThingsTheme.canvas }
    public static var panel: Color { ThingsTheme.sidebar }
    public static var panelRaised: Color { ThingsTheme.card }
    public static var border: Color { ThingsTheme.border }
    public static var borderLight: Color { ThingsTheme.cardRaised }

    public static var textPrimary: Color { ThingsTheme.textPrimary }
    public static var textMuted: Color { ThingsTheme.textSecondary }
    public static var textDim: Color { ThingsTheme.textTertiary }

    public static var amber: Color { ThingsTheme.starOchre }
    public static var cyan: Color { ThingsTheme.glacierCyan }
    public static var emerald: Color { ThingsTheme.accent }
    public static var crimson: Color { ThingsTheme.vitalCrimson }
    public static var violet: Color { ThingsTheme.infoIndigo }
}

// MARK: - Things 3 UI Design Components

/// Things 3 Signature Circular Checkbox
public struct ThingsCheckbox: View {
    public let isChecked: Bool
    public let tintColor: Color
    public let action: () -> Void

    public init(isChecked: Bool, tintColor: Color = ThingsTheme.accent, action: @escaping () -> Void) {
        self.isChecked = isChecked
        self.tintColor = tintColor
        self.action = action
    }

    public var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) {
                action()
            }
        }) {
            ZStack {
                Circle()
                    .strokeBorder(isChecked ? tintColor : ThingsTheme.border, lineWidth: 1.5)
                    .background(Circle().fill(isChecked ? tintColor : Color.clear))
                    .frame(width: 17, height: 17)

                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(isChecked ? 1.06 : 1.0)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

/// Things 3 Signature Progress Ring (e.g. for projects, categories, storage)
public struct ThingsProgressRing: View {
    public let progress: Double // 0.0 to 1.0
    public let size: CGFloat
    public let strokeWidth: CGFloat
    public let tintColor: Color
    public let backgroundColor: Color

    public init(
        progress: Double,
        size: CGFloat = 20,
        strokeWidth: CGFloat = 2.5,
        tintColor: Color = ThingsTheme.accent,
        backgroundColor: Color = ThingsTheme.border
    ) {
        self.progress = min(max(progress, 0.0), 1.0)
        self.size = size
        self.strokeWidth = strokeWidth
        self.tintColor = tintColor
        self.backgroundColor = backgroundColor
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(backgroundColor, lineWidth: strokeWidth)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0.0, to: CGFloat(progress))
                .stroke(tintColor, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
        }
    }
}

/// Things 3 Capsule Tag
public struct ThingsTag: View {
    public let title: String
    public let icon: String?
    public let color: Color

    public init(_ title: String, icon: String? = nil, color: Color = ThingsTheme.accent) {
        self.title = title
        self.icon = icon
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 3) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 9.5, weight: .semibold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(color.opacity(0.12))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}
