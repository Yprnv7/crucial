import Foundation

/// Live volume telemetry measured directly from macOS storage and diskutil APIs.
public struct DiskHardwareInfo: Sendable, Equatable {
    public let volumeName: String
    public let fileSystem: String
    public let smartStatus: String
    public let isSolidState: Bool
    public let totalBytes: Int64
    public let freeBytes: Int64
    public let applicationsBytes: Int64
    public let userMediaBytes: Int64
    public let developerCachesBytes: Int64

    public var usedBytes: Int64 {
        max(0, totalBytes - freeBytes)
    }

    public init(
        volumeName: String = "Macintosh HD",
        fileSystem: String = "APFS",
        smartStatus: String = "Verified",
        isSolidState: Bool = true,
        totalBytes: Int64 = 0,
        freeBytes: Int64 = 0,
        applicationsBytes: Int64 = 0,
        userMediaBytes: Int64 = 0,
        developerCachesBytes: Int64 = 0
    ) {
        self.volumeName = volumeName
        self.fileSystem = fileSystem
        self.smartStatus = smartStatus
        self.isSolidState = isSolidState
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
        self.applicationsBytes = applicationsBytes
        self.userMediaBytes = userMediaBytes
        self.developerCachesBytes = developerCachesBytes
    }
}
