import SwiftUI

/// Forensic right-hand inspector presenting asynchronous file telemetry, risk scoring, and safe actions.
public struct FileDiagnosticInspectorView: View {
    public let item: FileItem

    @Environment(CrucialChatService.self) private var chatService
    @Environment(NavigationStore.self) private var navigation
    @Environment(FileScannerService.self) private var scanner

    @State private var profile: DetailedFileProfile?
    @State private var showTrashConfirmation = false
    @State private var actionFeedback: String?

    public init(item: FileItem) {
        self.item = item
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CrucialSpacing.lg) {
                headerSection

                Divider()

                actionBar

                if let actionFeedback {
                    Text(actionFeedback)
                        .font(.caption)
                        .foregroundStyle(CrucialTheme.accentInk)
                }

                if let profile {
                    metricsStrip(profile: profile)
                    verdictSection(profile: profile)
                    telemetrySection(profile: profile)
                } else {
                    HStack(spacing: CrucialSpacing.sm) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Inspecting file origin and active processes...")
                            .font(.caption)
                            .foregroundStyle(CrucialTheme.textSecondary)
                    }
                    .padding(.vertical, CrucialSpacing.lg)
                }
            }
            .padding(CrucialSpacing.lg)
        }
        .background(CrucialTheme.card)
        .task(id: item.id) {
            actionFeedback = nil
            profile = nil
            profile = await FileDiagnosticEngine.shared.profile(item: item)
        }
        .confirmationDialog(
            "Move '\(item.name)' to Trash?",
            isPresented: $showTrashConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move to Trash (\(item.formattedSize))", role: .destructive) {
                do {
                    try SafetyTrashService.shared.trash(item: item)
                    scanner.refreshDiskSpace()
                    actionFeedback = "Moved to Trash."
                } catch {
                    actionFeedback = error.localizedDescription
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(item.displayPath)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: CrucialSpacing.sm) {
            HStack(spacing: CrucialSpacing.md) {
                FileIconImage(path: item.path, size: 38)

                VStack(alignment: .leading, spacing: CrucialSpacing.xxs) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundStyle(CrucialTheme.textPrimary)
                        .lineLimit(2)

                    Text(item.formattedSize)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(CrucialTheme.accentInk)
                }
            }

            CrucialTag(item.assessment.level.rawValue, color: item.assessment.level.badgeColor)
        }
    }

    private var actionBar: some View {
        HStack(spacing: CrucialSpacing.sm) {
            Button {
                FinderOpener.reveal(path: item.path)
            } label: {
                Label("Finder", systemImage: "folder")
            }
            .buttonStyle(.bordered)

            Button {
                navigation.navigate(to: .assistant, item: item)
                chatService.askAbout(item: item)
            } label: {
                Label("Ask Assistant", systemImage: "cpu")
            }
            .buttonStyle(.bordered)

            Spacer()

            Button(role: .destructive) {
                showTrashConfirmation = true
            } label: {
                Label("Trash", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(item.assessment.level == .vital)
        }
    }

    @ViewBuilder
    private func metricsStrip(profile: DetailedFileProfile) -> some View {
        HStack(spacing: CrucialSpacing.sm) {
            ScoreRingCard(
                title: "Risk",
                score: profile.vitalityRiskScore,
                color: item.assessment.level.badgeColor
            )
            ScoreRingCard(
                title: "Bloat",
                score: profile.bloatSeverityScore,
                color: CrucialTheme.starOchre
            )
            ScoreRingCard(
                title: "Safety",
                score: profile.safetyConfidencePercent,
                color: CrucialTheme.accentInk
            )
        }
    }

    @ViewBuilder
    private func verdictSection(profile: DetailedFileProfile) -> some View {
        VStack(alignment: .leading, spacing: CrucialSpacing.sm) {
            Text(profile.deletionVerdict)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CrucialTheme.textPrimary)

            Text(profile.functionalPurpose)
                .font(.caption)
                .foregroundStyle(CrucialTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(profile.immediateImpact)
                .font(.caption)
                .foregroundStyle(CrucialTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(CrucialSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CrucialTheme.cardRaised, in: .rect(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func telemetrySection(profile: DetailedFileProfile) -> some View {
        VStack(alignment: .leading, spacing: CrucialSpacing.sm) {
            Text("Telemetry")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CrucialTheme.textPrimary)

            TelemetryPropertyRow(label: "Origin", value: profile.createdByApp)
            TelemetryPropertyRow(label: "Type", value: profile.fileClassification)
            TelemetryPropertyRow(label: "Subsystem", value: profile.subsystemOrigin)
            TelemetryPropertyRow(label: "Active Process", value: profile.activeProcessDependency)
            TelemetryPropertyRow(label: "Modified", value: profile.lastModified)
            TelemetryPropertyRow(label: "Idle Age", value: "\(profile.daysIdle) days")
            TelemetryPropertyRow(label: "Exact Bytes", value: "\(profile.exactBytes) B")
            TelemetryPropertyRow(label: "Location", value: profile.path)
            if let cmd = profile.rebuildCommand {
                TelemetryPropertyRow(label: "Rebuild", value: cmd, isMonospaced: true)
            }
        }
    }
}
