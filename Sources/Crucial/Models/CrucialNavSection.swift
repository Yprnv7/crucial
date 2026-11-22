import Foundation
import SwiftUI

public enum CrucialNavSection: Hashable, Identifiable, Sendable {
    case dashboard
    case category(JunkCategory)
    case uninstaller
    case diskMap
    case duplicates
    case maintenance
    case startup
    case fileFinder
    case assistant
    case settings

    public var id: String {
        switch self {
        case .dashboard:
            return "dashboard"
        case .category(let cat):
            return "category_\(cat.rawValue)"
        case .uninstaller:
            return "uninstaller"
        case .diskMap:
            return "diskMap"
        case .duplicates:
            return "duplicates"
        case .maintenance:
            return "maintenance"
        case .startup:
            return "startup"
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
        case .uninstaller:
            return "App Uninstaller"
        case .diskMap:
            return "Storage Treemap"
        case .duplicates:
            return "Duplicate Finder"
        case .maintenance:
            return "System Maintenance"
        case .startup:
            return "Startup Daemons"
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
        case .uninstaller:
            return "trash.circle.fill"
        case .diskMap:
            return "chart.pie.fill"
        case .duplicates:
            return "doc.on.doc.fill"
        case .maintenance:
            return "wrench.and.screwdriver.fill"
        case .startup:
            return "bolt.fill"
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
        case .uninstaller:
            return ThingsTheme.accent
        case .diskMap:
            return ThingsTheme.accent
        case .duplicates:
            return ThingsTheme.purple
        case .maintenance:
            return ThingsTheme.glacierCyan
        case .startup:
            return ThingsTheme.starOchre
        case .fileFinder:
            return ThingsTheme.glacierCyan
        case .assistant:
            return ThingsTheme.infoIndigo
        case .settings:
            return ThingsTheme.textTertiary
        }
    }
}
