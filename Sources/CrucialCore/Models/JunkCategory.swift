import SwiftUI

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
        case .devArtifacts: "hammer"
        case .systemCache: "internaldrive"
        case .appResidue: "trash"
        case .largeUnused: "doc.badge.clock"
        case .duplicates: "doc.on.doc"
        case .custom: "folder"
        }
    }

    public var color: Color {
        switch self {
        case .devArtifacts: CrucialTheme.cobalt
        case .systemCache: CrucialTheme.glacierCyan
        case .appResidue: CrucialTheme.starOchre
        case .largeUnused: CrucialTheme.slateBlue
        case .duplicates: CrucialTheme.accentInk
        case .custom: CrucialTheme.textSecondary
        }
    }

    public var description: String {
        switch self {
        case .devArtifacts: "Xcode DerivedData, node_modules, target, and .venv build caches"
        case .systemCache: "Stale browser caches and historical logs in ~/Library"
        case .appResidue: "Leftover support files from uninstalled applications"
        case .largeUnused: "Files over 100 MB unaccessed for more than 30 days"
        case .duplicates: "Byte-identical files identified by SHA-256 verification"
        case .custom: "User-selected directories and search matches"
        }
    }
}
