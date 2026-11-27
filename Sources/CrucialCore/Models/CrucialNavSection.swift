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

    public var id: String {
        switch self {
        case .dashboard: "dashboard"
        case .category(let cat): "category_\(cat.rawValue)"
        case .uninstaller: "uninstaller"
        case .diskMap: "diskMap"
        case .duplicates: "duplicates"
        case .maintenance: "maintenance"
        case .startup: "startup"
        case .fileFinder: "fileFinder"
        case .assistant: "assistant"
        }
    }

    public var title: String {
        switch self {
        case .dashboard: "Clean Dashboard"
        case .category(let cat): cat.rawValue
        case .uninstaller: "App Uninstaller"
        case .diskMap: "Storage Breakdown"
        case .duplicates: "Duplicate Finder"
        case .maintenance: "System Maintenance"
        case .startup: "Startup Agents"
        case .fileFinder: "Deep File Finder"
        case .assistant: "Crucial Assistant"
        }
    }

    public var iconName: String {
        switch self {
        case .dashboard: "gauge.with.dots.needle.bottom.50percent"
        case .category(let cat): cat.iconName
        case .uninstaller: "trash.square"
        case .diskMap: "chart.pie"
        case .duplicates: "doc.on.doc"
        case .maintenance: "wrench.and.screwdriver"
        case .startup: "bolt.circle"
        case .fileFinder: "doc.text.magnifyingglass"
        case .assistant: "cpu"
        }
    }

    public var accentColor: Color {
        switch self {
        case .dashboard: CrucialTheme.accentInk
        case .category(let cat): cat.color
        case .uninstaller: CrucialTheme.accentInk
        case .diskMap: CrucialTheme.accentInk
        case .duplicates: CrucialTheme.glacierCyan
        case .maintenance: CrucialTheme.cobalt
        case .startup: CrucialTheme.starOchre
        case .fileFinder: CrucialTheme.cobalt
        case .assistant: CrucialTheme.accentInk
        }
    }
}
