import SwiftUI

/// Sidebar-style application list row displaying icon, version, and total reclaimable footprint.
public struct AppRowView: View {
    public let app: InstalledAppInfo

    public init(app: InstalledAppInfo) {
        self.app = app
    }

    public var body: some View {
        HStack(spacing: CrucialSpacing.md) {
            FileIconImage(path: app.bundleURL.path, size: 30)

            VStack(alignment: .leading, spacing: CrucialSpacing.xxs) {
                HStack(spacing: CrucialSpacing.xs) {
                    Text(app.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(CrucialTheme.textPrimary)
                        .lineLimit(1)

                    if app.isSystemProtected {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(CrucialTheme.vitalCrimson)
                            .accessibilityLabel("System protected")
                    }
                }

                Text("v\(app.version)  |  \(app.residueItems.count) residue items")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(CrucialTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: CrucialSpacing.xs)

            Text(app.formattedTotalSize)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(CrucialTheme.textPrimary)
        }
        .padding(.vertical, CrucialSpacing.xs)
    }
}
