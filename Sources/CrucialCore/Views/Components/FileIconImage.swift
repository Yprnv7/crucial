import AppKit
import SwiftUI

/// Displays the native Finder file or folder icon at crisp resolution without blocking layout.
public struct FileIconImage: View {
    public let path: String
    public let size: CGFloat

    public init(path: String, size: CGFloat = 24) {
        self.path = path
        self.size = size
    }

    public var body: some View {
        Image(nsImage: iconForPath(path))
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private func iconForPath(_ path: String) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: size * 2, height: size * 2)
        return icon
    }
}
