import Foundation

public struct StartupItemInfo: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let label: String
    public let plistURL: URL
    public let executablePath: String?
    public let isOrphaned: Bool
    public var isEnabled: Bool
    public let isSystemLevel: Bool

    public init(
        id: UUID = UUID(),
        label: String,
        plistURL: URL,
        executablePath: String?,
        isOrphaned: Bool,
        isEnabled: Bool,
        isSystemLevel: Bool
    ) {
        self.id = id
        self.label = label
        self.plistURL = plistURL
        self.executablePath = executablePath
        self.isOrphaned = isOrphaned
        self.isEnabled = isEnabled
        self.isSystemLevel = isSystemLevel
    }

    public var displayName: String {
        let parts = label.components(separatedBy: ".")
        if let last = parts.last, last.count > 2 {
            return last.capitalized
        }
        return label
    }

    public var displayExecutablePath: String? {
        guard let executablePath else { return nil }
        let home = URL.homeDirectory.path
        return executablePath.hasPrefix(home) ? "~" + executablePath.dropFirst(home.count) : executablePath
    }
}
