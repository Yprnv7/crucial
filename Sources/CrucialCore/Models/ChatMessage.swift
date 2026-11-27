import Foundation

public struct ChatMessage: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let sender: MessageSender
    public var text: String
    public let timestamp: Date
    public let contextItem: FileItem?
    public var matchedFiles: [FileItem]
    public var suggestedAction: ChatAction?
    public var isActionExecuted: Bool

    public init(
        id: UUID = UUID(),
        sender: MessageSender,
        text: String,
        timestamp: Date = .now,
        contextItem: FileItem? = nil,
        matchedFiles: [FileItem] = [],
        suggestedAction: ChatAction? = nil,
        isActionExecuted: Bool = false
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.contextItem = contextItem
        self.matchedFiles = matchedFiles
        self.suggestedAction = suggestedAction
        self.isActionExecuted = isActionExecuted
    }
}
