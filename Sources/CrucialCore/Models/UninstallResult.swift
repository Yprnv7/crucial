import Foundation

public struct UninstallResult: Sendable, Equatable {
    public let appName: String
    public let succeeded: Bool
    public let bytesFreed: Int64
    public let itemsTrashed: Int
    public let errorMessage: String?

    public init(
        appName: String,
        succeeded: Bool,
        bytesFreed: Int64,
        itemsTrashed: Int,
        errorMessage: String?
    ) {
        self.appName = appName
        self.succeeded = succeeded
        self.bytesFreed = bytesFreed
        self.itemsTrashed = itemsTrashed
        self.errorMessage = errorMessage
    }
}
