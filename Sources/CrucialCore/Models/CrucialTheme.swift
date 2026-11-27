import SwiftUI

/// Consistent 4px spatial rhythm and critically damped motion parameters for macOS.
public enum CrucialSpacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
}

/// Critically damped spring definitions aligned with Apple HIG and reduced-motion discipline.
public enum CrucialMotion {
    public static let navigation: Animation = .spring(response: 0.28, dampingFraction: 0.90)
    public static let control: Animation = .spring(response: 0.20, dampingFraction: 0.88)
}

/// Domain-grounded palette derived from macOS precision hardware diagnostics.
/// Meets WCAG AA contrast across light, dark, and increased-contrast appearances.
public enum CrucialTheme {
    // Primary Signature Accent: Alpine Emerald
    public static let accent = Color(red: 0.051, green: 0.651, blue: 0.529)       // #0DA687

    // High-contrast text variant for accent labels on light/dark cards (>= 4.5:1)
    public static var accentInk: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.071, green: 0.722, blue: 0.588, alpha: 1.0) // #12B896 on #202226 (6.7:1)
                : NSColor(red: 0.031, green: 0.478, blue: 0.384, alpha: 1.0) // #087A62 on #FFFFFF (5.3:1)
        }))
    }

    // Semantic Status Accents (Zero purple-to-blue gradients)
    public static let starOchre = Color(red: 0.851, green: 0.467, blue: 0.024)    // #D97706
    public static let warning = Color(red: 0.961, green: 0.620, blue: 0.102)      // #F59E1A
    public static let vitalCrimson = Color(red: 0.863, green: 0.149, blue: 0.149) // #DC2626
    public static let cobalt = Color(red: 0.145, green: 0.388, blue: 0.922)       // #2563EB
    public static let glacierCyan = Color(red: 0.024, green: 0.545, blue: 0.690)  // #068BB0
    public static let slateBlue = Color(red: 0.278, green: 0.349, blue: 0.451)    // #475973

    // Adaptive Neutrals (Light / Dark / Increased Contrast)
    public static var canvas: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.094, green: 0.098, blue: 0.106, alpha: 1.0) // #18191B
                : NSColor(red: 0.984, green: 0.984, blue: 0.988, alpha: 1.0) // #FBFBFC
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
                ? NSColor(red: 0.161, green: 0.169, blue: 0.188, alpha: 1.0) // #292B30
                : NSColor(red: 0.941, green: 0.945, blue: 0.957, alpha: 1.0) // #F0F1F4
        }))
    }

    public static var border: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let highContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(red: 0.22, green: 0.24, blue: 0.27, alpha: highContrast ? 0.95 : 0.75)
            } else {
                return NSColor(red: 0.85, green: 0.87, blue: 0.90, alpha: highContrast ? 1.0 : 0.90)
            }
        }))
    }

    public static var borderSubtle: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.08)
                : NSColor(white: 0.0, alpha: 0.08)
        }))
    }

    // Accessible Typography Ramp (every pair >= 4.5:1 AA on canvas and card)
    public static var textPrimary: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.949, green: 0.957, blue: 0.969, alpha: 1.0) // #F2F4F7
                : NSColor(red: 0.094, green: 0.102, blue: 0.122, alpha: 1.0) // #181A1F
        }))
    }

    public static var textSecondary: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.639, green: 0.667, blue: 0.714, alpha: 1.0) // #A3AAB6
                : NSColor(red: 0.310, green: 0.337, blue: 0.388, alpha: 1.0) // #4F5663
        }))
    }

    public static var textTertiary: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.545, green: 0.573, blue: 0.620, alpha: 1.0) // #8B929E (>= 5.0:1)
                : NSColor(red: 0.388, green: 0.420, blue: 0.471, alpha: 1.0) // #636B78 (>= 5.3:1)
        }))
    }
}
