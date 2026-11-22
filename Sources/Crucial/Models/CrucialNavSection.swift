import Foundation
import SwiftUI

public enum CrucialNavSection: Hashable, Identifiable, Sendable {
    case dashboard
    case category(JunkCategory)
    case fileFinder
    case assistant
    case settings

    public var id: String {
        switch self {
        case .dashboard:
            return "dashboard"
        case .category(let cat):
            return "category_\(cat.rawValue)"
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
            return "gauge.with.needle.fill"
        case .category(let cat):
            return cat.iconName
        case .fileFinder:
            return "magnifyingglass"
        case .assistant:
            return "bubble.left.and.sparkles.fill"
        case .settings:
            return "gearshape.fill"
        }
    }

    public var accentColor: Color {
        switch self {
        case .dashboard:
            return .blue
        case .category(let cat):
            return cat.color
        case .fileFinder:
            return .green
        case .assistant:
            return .purple
        case .settings:
            return .gray
        }
    }
}
