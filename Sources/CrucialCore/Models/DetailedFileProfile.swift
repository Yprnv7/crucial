import Foundation

public struct DetailedFileProfile: Sendable, Equatable {
    public let name: String
    public let path: String
    public let parentDirectory: String
    public let formattedSize: String
    public let exactBytes: Int64
    public let isDirectory: Bool
    public let fileCount: Int
    public let lastModified: String
    public let daysIdle: Int

    public let createdByApp: String
    public let fileClassification: String
    public let subsystemOrigin: String

    public let functionalPurpose: String
    public let whyItExists: String
    public let activeProcessDependency: String
    public let isProcessRunning: Bool

    public let canBeDeleted: Bool
    public let deletionVerdict: String
    public let immediateImpact: String
    public let appRelaunchImpact: String
    public let rebuildCommand: String?

    public let vitalityRiskScore: Int
    public let bloatSeverityScore: Int
    public let recoveryDifficultyScore: Int
    public let safetyConfidencePercent: Int

    public init(
        name: String,
        path: String,
        parentDirectory: String,
        formattedSize: String,
        exactBytes: Int64,
        isDirectory: Bool,
        fileCount: Int,
        lastModified: String,
        daysIdle: Int,
        createdByApp: String,
        fileClassification: String,
        subsystemOrigin: String,
        functionalPurpose: String,
        whyItExists: String,
        activeProcessDependency: String,
        isProcessRunning: Bool,
        canBeDeleted: Bool,
        deletionVerdict: String,
        immediateImpact: String,
        appRelaunchImpact: String,
        rebuildCommand: String?,
        vitalityRiskScore: Int,
        bloatSeverityScore: Int,
        recoveryDifficultyScore: Int,
        safetyConfidencePercent: Int
    ) {
        self.name = name
        self.path = path
        self.parentDirectory = parentDirectory
        self.formattedSize = formattedSize
        self.exactBytes = exactBytes
        self.isDirectory = isDirectory
        self.fileCount = fileCount
        self.lastModified = lastModified
        self.daysIdle = daysIdle
        self.createdByApp = createdByApp
        self.fileClassification = fileClassification
        self.subsystemOrigin = subsystemOrigin
        self.functionalPurpose = functionalPurpose
        self.whyItExists = whyItExists
        self.activeProcessDependency = activeProcessDependency
        self.isProcessRunning = isProcessRunning
        self.canBeDeleted = canBeDeleted
        self.deletionVerdict = deletionVerdict
        self.immediateImpact = immediateImpact
        self.appRelaunchImpact = appRelaunchImpact
        self.rebuildCommand = rebuildCommand
        self.vitalityRiskScore = vitalityRiskScore
        self.bloatSeverityScore = bloatSeverityScore
        self.recoveryDifficultyScore = recoveryDifficultyScore
        self.safetyConfidencePercent = safetyConfidencePercent
    }
}
