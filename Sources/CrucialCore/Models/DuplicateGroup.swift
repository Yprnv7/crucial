import Foundation

public struct DuplicateGroup: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let hash: String
    public let size: Int64
    public let original: FileItem
    public var duplicates: [FileItem]

    public init(
        id: UUID = UUID(),
        hash: String,
        size: Int64,
        original: FileItem,
        duplicates: [FileItem]
    ) {
        self.id = id
        self.hash = hash
        self.size = size
        self.original = original
        self.duplicates = duplicates
    }

    public var totalWastedBytes: Int64 {
        Int64(duplicates.count) * size
    }

    public var formattedWastedSize: String {
        ByteCountFormatter.string(fromByteCount: totalWastedBytes, countStyle: .file)
    }
}
