import SwiftUI

public enum RetroTheme {
    // Canvas & Chassis
    public static let bg = Color(red: 0.07, green: 0.08, blue: 0.10)          // Deep industrial chassis (#121419)
    public static let panel = Color(red: 0.11, green: 0.13, blue: 0.16)       // Beveled module (#1C2129)
    public static let panelRaised = Color(red: 0.15, green: 0.17, blue: 0.22) // Active surface (#262C38)
    public static let border = Color(red: 0.22, green: 0.26, blue: 0.32)      // Machined edge line (#384252)
    public static let borderLight = Color(red: 0.30, green: 0.35, blue: 0.44) // Highlight rim (#4D5A70)

    // Typography
    public static let textPrimary = Color(red: 0.94, green: 0.96, blue: 0.98) // Crisp phosphor off-white (#F0F4F8)
    public static let textMuted = Color(red: 0.58, green: 0.64, blue: 0.72)   // Telemetry gray (#94A3B8)
    public static let textDim = Color(red: 0.40, green: 0.45, blue: 0.54)     // Sub-label dark (#66738A)

    // Retro-Fit Phosphor Accents
    public static let amber = Color(red: 0.96, green: 0.62, blue: 0.04)       // Vintage amber gauge (#F59E0B)
    public static let cyan = Color(red: 0.02, green: 0.71, blue: 0.83)        // CRT phosphor cyan (#06B6D4)
    public static let emerald = Color(red: 0.06, green: 0.73, blue: 0.51)     // Safe status green (#10B981)
    public static let crimson = Color(red: 0.94, green: 0.27, blue: 0.27)     // Vital system lock (#EF4444)
    public static let violet = Color(red: 0.60, green: 0.40, blue: 0.95)      // Diagnostics purple (#9966F2)
}
