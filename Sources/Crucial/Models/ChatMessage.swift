import Foundation

public enum MessageSender: Sendable, Equatable {
    case user
    case assistant
}

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
            return "Clean All Safe Junk (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)))"
        case .cleanCategory(let cat, let size):
            return "Clean \(cat.rawValue) (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)))"
        case .trashItem(_, let name, let size):
            return "Move '\(name)' (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))) to Trash"
        case .navigateCategory(let cat):
            return "View \(cat.rawValue)"
        case .rescan:
            return "Rescan Mac Now"
        case .revealInFinder:
            return "Reveal in Finder"
        case .inspectInFileFinder(let name):
            return "Open '\(name)' in Deep File Finder"
        }
    }

    public var iconName: String {
        switch self {
        case .cleanAllSafe, .cleanCategory, .trashItem:
            return "trash.fill"
        case .navigateCategory, .inspectInFileFinder:
            return "arrow.right.circle.fill"
        case .rescan:
            return "arrow.clockwise"
        case .revealInFinder:
            return "folder.fill"
        }
    }
}

public struct ChatMessage: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let sender: MessageSender
    public var text: String
    public let timestamp: Date
    public let contextItem: FileItem?
    public var suggestedAction: ChatAction?
    public var isActionExecuted: Bool

    public init(
        id: UUID = UUID(),
        sender: MessageSender,
        text: String,
        timestamp: Date = Date(),
        contextItem: FileItem? = nil,
        suggestedAction: ChatAction? = nil,
        isActionExecuted: Bool = false
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.contextItem = contextItem
        self.suggestedAction = suggestedAction
        self.isActionExecuted = isActionExecuted
    }
}
