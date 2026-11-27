import SwiftUI

public struct DiskSectorItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let size: Int64
    public let percentage: Double
    public let color: Color
    public let iconName: String
    public let description: String
    public let targetNav: CrucialNavSection?

    public init(
        id: String? = nil,
        name: String,
        size: Int64,
        percentage: Double,
        color: Color,
        iconName: String,
        description: String,
        targetNav: CrucialNavSection?
    ) {
        self.id = id ?? name
        self.name = name
        self.size = size
        self.percentage = percentage
        self.color = color
        self.iconName = iconName
        self.description = description
        self.targetNav = targetNav
    }
}
