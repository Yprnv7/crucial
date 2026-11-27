import SwiftUI

public enum VitalityLevel: String, Codable, CaseIterable, Sendable, Equatable {
    case safeToDelete = "Safe to Delete"
    case caution = "Needs Review"
    case vital = "Protected"

    public var badgeColor: Color {
        switch self {
        case .safeToDelete: CrucialTheme.accentInk
        case .caution: CrucialTheme.starOchre
        case .vital: CrucialTheme.vitalCrimson
        }
    }

    public var iconName: String {
        switch self {
        case .safeToDelete: "checkmark.circle.fill"
        case .caution: "exclamationmark.triangle.fill"
        case .vital: "lock.shield.fill"
        }
    }
}
