import Foundation

public struct VitalityAssessment: Codable, Equatable, Hashable, Sendable {
    public let level: VitalityLevel
    public let riskScore: Int
    public let category: JunkCategory
    public let summary: String
    public let impact: String
    public let canBeRebuilt: Bool
    public let rebuildCommand: String?
    public let aiGenerated: Bool

    public init(
        level: VitalityLevel,
        riskScore: Int,
        category: JunkCategory,
        summary: String,
        impact: String,
        canBeRebuilt: Bool,
        rebuildCommand: String?,
        aiGenerated: Bool
    ) {
        self.level = level
        self.riskScore = riskScore
        self.category = category
        self.summary = summary
        self.impact = impact
        self.canBeRebuilt = canBeRebuilt
        self.rebuildCommand = rebuildCommand
        self.aiGenerated = aiGenerated
    }

    public static let standardSafe = VitalityAssessment(
        level: .safeToDelete,
        riskScore: 0,
        category: .devArtifacts,
        summary: "Build artifact from an idle project.",
        impact: "Moving this to Trash reclaims disk space immediately and can be regenerated with your package manager.",
        canBeRebuilt: true,
        rebuildCommand: "npm install / cargo build",
        aiGenerated: false
    )

    public static let protectedSystem = VitalityAssessment(
        level: .vital,
        riskScore: 98,
        category: .custom,
        summary: "Protected Operating System or Personal Data.",
        impact: "Removing this item can disrupt macOS stability, active repositories, or personal documents.",
        canBeRebuilt: false,
        rebuildCommand: nil,
        aiGenerated: false
    )
}
