import Foundation

public enum ChatAction: Sendable, Equatable {
    case cleanAllSafe(size: Int64)
    case cleanCategory(JunkCategory, size: Int64)
    case trashItem(url: URL, name: String, size: Int64)
    case navigateCategory(JunkCategory)
    case rescan
    case revealInFinder(path: String)
    case inspectInFileFinder(name: String)

    public var title: String {
        switch self {
        case .cleanAllSafe(let size):
            "Clean All Safe Items (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)))"
        case .cleanCategory(let cat, let size):
            "Clean \(cat.rawValue) (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)))"
        case .trashItem(_, let name, let size):
            "Move '\(name)' (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))) to Trash"
        case .navigateCategory(let cat):
            "View \(cat.rawValue)"
        case .rescan:
            "Rescan Mac Storage"
        case .revealInFinder:
            "Reveal in Finder"
        case .inspectInFileFinder(let name):
            "Open '\(name)' in Deep File Finder"
        }
    }

    public var iconName: String {
        switch self {
        case .cleanAllSafe, .cleanCategory, .trashItem: "trash"
        case .navigateCategory, .inspectInFileFinder: "arrow.right.circle"
        case .rescan: "arrow.clockwise"
        case .revealInFinder: "folder"
        }
    }
}
