import Foundation

public struct InstalledAppInfo: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let bundleURL: URL
    public let bundleIdentifier: String
    public let version: String
    public let appSize: Int64
    public var residueItems: [AppResidueItem]
    public var isBundleSelected: Bool
    public let isSystemProtected: Bool
    public let protectionReason: String?
    public var isRunning: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        bundleURL: URL,
        bundleIdentifier: String,
        version: String,
        appSize: Int64,
        residueItems: [AppResidueItem],
        isBundleSelected: Bool = true,
        isSystemProtected: Bool = false,
        protectionReason: String? = nil,
        isRunning: Bool = false
    ) {
        self.id = id
        self.name = name
        self.bundleURL = bundleURL
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.appSize = appSize
        self.residueItems = residueItems
        self.isBundleSelected = isBundleSelected
        self.isSystemProtected = isSystemProtected
        self.protectionReason = protectionReason
        self.isRunning = isRunning
    }

    public var checkedResidueCount: Int {
        residueItems.count(where: { $0.isChecked })
    }

    public var checkedResidueBytes: Int64 {
        residueItems.filter(\.isChecked).reduce(0) { $0 + $1.size }
    }

    public var reclaimableBytes: Int64 {
        let bundleCost = (isBundleSelected && !isSystemProtected) ? appSize : 0
        return bundleCost + checkedResidueBytes
    }

    public var totalFootprint: Int64 {
        appSize + residueItems.reduce(0) { $0 + $1.size }
    }

    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalFootprint, countStyle: .file)
    }

    public var formattedReclaimableSize: String {
        ByteCountFormatter.string(fromByteCount: reclaimableBytes, countStyle: .file)
    }
}
