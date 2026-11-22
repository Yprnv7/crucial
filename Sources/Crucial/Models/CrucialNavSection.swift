import Foundation
import SwiftUI

public enum CrucialNavSection: Hashable, Identifiable, Sendable {
    case dashboard
    case category(JunkCategory)
    case diskMap
    case duplicates
    case fileFinder
    case assistant
    case settings

    public var id: String {
        switch self {
        case .dashboard:
            return "dashboard"
        case .category(let cat):
            return "category_\(cat.rawValue)"
        case .diskMap:
            return "diskMap"
        case .duplicates:
            return "duplicates"
        case .fileFinder:
            return "fileFinder"
        case .assistant:
            return "assistant"
        case .settings:
            return "settings"
        }
    }

    public var title: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .category(let cat):
            return cat.rawValue
        case .diskMap:
            return "Storage Treemap"
        case .duplicates:
            return "Duplicate Finder"
        case .fileFinder:
            return "Deep File Finder"
        case .assistant:
            return "Crucial Assistant"
        case .settings:
            return "Settings & System"
        }
    }

    public var iconName: String {
        switch self {
        case .dashboard:
            return "star.fill"
        case .category(let cat):
            return cat.iconName
        case .diskMap:
            return "chart.pie.fill"
        case .duplicates:
            return "doc.on.doc.fill"
        case .fileFinder:
            return "magnifyingglass"
        case .assistant:
            return "bubble.left.and.bubble.right.fill"
        case .settings:
            return "gearshape.fill"
        }
    }

    public var accentColor: Color {
        switch self {
        case .dashboard:
            return ThingsTheme.starOchre
        case .category(let cat):
            return cat.color
        case .diskMap:
            return ThingsTheme.accent
        case .duplicates:
            return ThingsTheme.purple
        case .fileFinder:
            return ThingsTheme.glacierCyan
        case .assistant:
            return ThingsTheme.infoIndigo
        case .settings:
            return ThingsTheme.textTertiary
        }
    }
}
