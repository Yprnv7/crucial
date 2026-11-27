import Foundation

public struct AppResidueItem: Identifiable, Sendable, Hashable, Equatable {
    public let id: UUID
    public let path: String
    public let url: URL
    public let name: String
    public let size: Int64
    public let categoryName: String
    public var isChecked: Bool

    public init(
        id: UUID = UUID(),
        path: String,
        url: URL,
        name: String,
        size: Int64,
        categoryName: String,
        isChecked: Bool = true
    ) {
        self.id = id
        self.path = path
        self.url = url
        self.name = name
        self.size = size
        self.categoryName = categoryName
        self.isChecked = isChecked
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    public var displayPath: String {
        let home = URL.homeDirectory.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}
