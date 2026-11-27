import Foundation

public enum TrashError: LocalizedError, Equatable, Sendable {
    case protectedItem(String)
    case symlinkTargetProtected(String)
    case recycleFailed(String, String)

    public var errorDescription: String? {
        switch self {
        case .protectedItem(let path):
            "Crucial Safety Lock: '\(path)' is marked as Protected and cannot be removed."
        case .symlinkTargetProtected(let path):
            "Crucial Safety Lock: '\(path)' resolves to a protected system location."
        case .recycleFailed(let path, let reason):
            "Could not move '\(path)' to macOS Trash: \(reason)"
        }
    }
}
