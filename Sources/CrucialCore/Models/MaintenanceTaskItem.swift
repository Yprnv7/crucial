import Foundation

public struct MaintenanceTaskItem: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let subtitle: String
    public let iconName: String
    public var isExecuting: Bool
    public var isCompleted: Bool
    public var resultMessage: String?

    public init(
        id: UUID = UUID(),
        name: String,
        subtitle: String,
        iconName: String,
        isExecuting: Bool = false,
        isCompleted: Bool = false,
        resultMessage: String? = nil
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.iconName = iconName
        self.isExecuting = isExecuting
        self.isCompleted = isCompleted
        self.resultMessage = resultMessage
    }
}
