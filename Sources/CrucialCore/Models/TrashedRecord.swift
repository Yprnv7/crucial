import Foundation

public struct TrashedRecord: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let originalURL: URL
    public let trashedAt: Date
    public let size: Int64
    public let name: String

    public init(
        id: UUID = UUID(),
        originalURL: URL,
        trashedAt: Date = .now,
        size: Int64,
        name: String
    ) {
        self.id = id
        self.originalURL = originalURL
        self.trashedAt = trashedAt
        self.size = size
        self.name = name
    }
}
