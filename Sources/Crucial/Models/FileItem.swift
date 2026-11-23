import Foundation
import AppKit

public struct FileItem: Identifiable, Hashable, Equatable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let path: String
    public let size: Int64
    public let isDirectory: Bool
    public let creationDate: Date?
    public let modificationDate: Date?
    public let lastAccessDate: Date?
    public var category: JunkCategory
    public var assessment: VitalityAssessment
    public var isSelected: Bool

    public init(
        id: UUID = UUID(),
        url: URL,
        name: String? = nil,
        size: Int64,
        isDirectory: Bool,
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        lastAccessDate: Date? = nil,
        category: JunkCategory = .custom,
        assessment: VitalityAssessment,
        isSelected: Bool = false
    ) {
        self.id = id
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.path = url.path
        self.size = size
        self.isDirectory = isDirectory
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.lastAccessDate = lastAccessDate
        self.category = category
        self.assessment = assessment
        self.isSelected = isSelected
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    public var fileTypeCategory: FileTypeCategory {
        FileTypeCategory.categorize(url: url)
    }

    public var fileExtension: String {
        let ext = url.pathExtension.uppercased()
        return ext.isEmpty ? (isDirectory ? "DIR" : "FILE") : ext
    }

    public var formatDescription: String {
        FileTypeCategory.formatDescription(for: url.pathExtension)
    }

    @MainActor
    public var icon: NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }

    public var daysSinceLastAccess: Int {
        guard let accessDate = lastAccessDate ?? modificationDate else { return 0 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: accessDate, to: Date())
        return max(0, components.day ?? 0)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(path)
        hasher.combine(size)
    }

    public static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.path == rhs.path && lhs.size == rhs.size
    }
}
