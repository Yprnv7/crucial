import SwiftUI

/// Single Library residue row with selection checkbox and Finder reveal context action.
public struct AppResidueRowView: View {
    public let appID: UUID
    public let residue: AppResidueItem

    @Environment(AppUninstallerService.self) private var uninstaller

    public init(appID: UUID, residue: AppResidueItem) {
        self.appID = appID
        self.residue = residue
    }

    public var body: some View {
        HStack(spacing: CrucialSpacing.md) {
            CrucialCheckbox(
                isSelected: residue.isChecked,
                label: "Select \(residue.name)"
            ) {
                uninstaller.toggleResidueItem(appID: appID, residueID: residue.id)
            }

            VStack(alignment: .leading, spacing: CrucialSpacing.xxs) {
                HStack(spacing: CrucialSpacing.sm) {
                    Text(residue.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(CrucialTheme.textPrimary)
                        .lineLimit(1)

                    CrucialTag(residue.categoryName, color: CrucialTheme.textSecondary)
                }

                Text(residue.displayPath)
                    .font(.caption)
                    .foregroundStyle(CrucialTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: CrucialSpacing.sm)

            Text(residue.formattedSize)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(CrucialTheme.textPrimary)

            Button {
                FinderOpener.reveal(path: residue.path)
            } label: {
                Image(systemName: "folder")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)
            .accessibilityLabel("Reveal \(residue.name) in Finder")
        }
        .padding(.horizontal, CrucialSpacing.md)
        .padding(.vertical, CrucialSpacing.sm)
        .background(CrucialTheme.card, in: .rect(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(CrucialTheme.borderSubtle, lineWidth: 1)
        }
    }
}
