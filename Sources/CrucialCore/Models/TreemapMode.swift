import Foundation

public enum TreemapMode: String, CaseIterable, Identifiable, Sendable {
    case wholeVolume = "Volume Capacity"
    case cleanableSectors = "Cleanable Sectors"

    public var id: String { rawValue }
}
