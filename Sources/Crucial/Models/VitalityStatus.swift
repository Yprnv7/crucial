import Foundation
import SwiftUI

public enum VitalityLevel: String, Codable, CaseIterable, Sendable {
    case safeToDelete = "Safe to Delete"
    case caution = "Needs Review"
    case vital = "Protected / Vital"

    public var badgeColor: Color {
        switch self {
        case .safeToDelete:
            return .green
        case .caution:
            return .orange
        case .vital:
            return .red
        }
    }

    public var iconName: String {
        switch self {
        case .safeToDelete:
            return "checkmark.circle.fill"
        case .caution:
            return "exclamationmark.triangle.fill"
        case .vital:
            return "shield.fill"
        }
    }
}

public enum JunkCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case devArtifacts = "Developer Caches"
    case systemCache = "System & User Caches"
    case appResidue = "Orphaned App Residue"
    case largeUnused = "Large Unused Files"
    case duplicates = "Duplicate Files"
    case custom = "User Items"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .devArtifacts:
            return "hammer.fill"
        case .systemCache:
            return "gearshape.2.fill"
        case .appResidue:
            return "trash.circle.fill"
        case .largeUnused:
            return "chart.pie.fill"
        case .duplicates:
            return "doc.on.doc.fill"
        case .custom:
            return "folder.fill"
        }
    }

    public var color: Color {
        switch self {
        case .devArtifacts:
            return .blue
        case .systemCache:
            return .purple
        case .appResidue:
            return .orange
        case .largeUnused:
            return .teal
        case .duplicates:
            return .pink
        case .custom:
            return .gray
        }
    }

    public var description: String {
        switch self {
        case .devArtifacts:
            return "node_modules, Xcode DerivedData, target, .venv, build caches"
        case .systemCache:
            return "~/Library/Caches, browser caches, old system logs"
        case .appResidue:
            return "Leftover Application Support files from uninstalled apps"
        case .largeUnused:
            return "Files larger than 200MB unaccessed in the last 60 days"
        case .duplicates:
            return "Identical duplicate files occupying unnecessary disk space"
        case .custom:
            return "User-selected directories and search results"
        }
    }
}

public struct VitalityAssessment: Codable, Equatable, Sendable {
    public let level: VitalityLevel
    public let riskScore: Int // 0 (100% disposable) to 100 (critical system file)
    public let category: JunkCategory
    public let summary: String
    public let impact: String
    public let canBeRebuilt: Bool
    public let rebuildCommand: String?
    public let aiGenerated: Bool

    public static let standardSafe = VitalityAssessment(
        level: .safeToDelete,
        riskScore: 0,
        category: .devArtifacts,
        summary: "Build artifact from an idle project.",
        impact: "Deleting this frees up space immediately. It can be recreated whenever needed.",
        canBeRebuilt: true,
        rebuildCommand: "npm install / cargo build",
        aiGenerated: false
    )

    public static let protectedSystem = VitalityAssessment(
        level: .vital,
        riskScore: 98,
        category: .custom,
        summary: "Crucial System or User Data.",
        impact: "Deleting this item could disrupt system operations, active projects, or personal files.",
        canBeRebuilt: false,
        rebuildCommand: nil,
        aiGenerated: false
    )
}
