import SwiftUI
import AppKit

public struct StartupManagerView: View {
    @ObservedObject var startupService = StartupManagerService.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(ThingsTheme.starOchre.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ThingsTheme.starOchre)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Startup & LaunchAgents")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(ThingsTheme.textPrimary)

                    Text("Control background services, login daemons, and eliminate dead orphaned agents.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(ThingsTheme.textSecondary)
                }

                Spacer()

                Button {
                    Task {
                        await startupService.scanStartupItems()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                        Text("Rescan")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ThingsTheme.cardRaised)
                    .foregroundStyle(ThingsTheme.textPrimary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(ThingsTheme.canvas)

            Divider().background(ThingsTheme.borderSubtle)

            // Content List
            if startupService.isScanning {
                VStack(spacing: 12) {
                    ProgressView().scaleEffect(0.8)
                    Text("Scanning LaunchAgents and background daemons...")
                        .font(.system(size: 11))
                        .foregroundStyle(ThingsTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if startupService.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(ThingsTheme.accent)

                    Text("No Background LaunchAgents")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(ThingsTheme.textPrimary)

                    Text("Your Mac has zero third-party startup daemons registered.")
                        .font(.system(size: 12))
                        .foregroundStyle(ThingsTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(startupService.items) { item in
                            startupItemCard(item)
                        }
                    }
                    .padding(24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThingsTheme.canvas)
        .onAppear {
            if startupService.items.isEmpty && !startupService.isScanning {
                Task {
                    await startupService.scanStartupItems()
                }
            }
        }
    }

    private func startupItemCard(_ item: StartupItemInfo) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.isOrphaned ? ThingsTheme.starOchre.opacity(0.12) : ThingsTheme.cardRaised)
                    .frame(width: 36, height: 36)

                Image(systemName: item.isOrphaned ? "exclamationmark.triangle.fill" : "gearshape.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(item.isOrphaned ? ThingsTheme.starOchre : ThingsTheme.infoIndigo)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ThingsTheme.textPrimary)

                    if item.isOrphaned {
                        ThingsTag("Dead Orphan Daemon", color: ThingsTheme.starOchre)
                    } else if item.isEnabled {
                        ThingsTag("Active on Boot", color: ThingsTheme.accent)
                    } else {
                        ThingsTag("Disabled", color: ThingsTheme.textTertiary)
                    }

                    if item.isSystemLevel {
                        ThingsTag("System-wide", color: ThingsTheme.purple)
                    }
                }

                Text(item.label)
                    .font(.system(size: 11))
                    .foregroundStyle(ThingsTheme.textSecondary)

                if let exec = item.executablePath {
                    Text(exec.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                        .font(.system(size: 10))
                        .foregroundStyle(ThingsTheme.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    startupService.toggleItem(item)
                } label: {
                    Text(item.isEnabled ? "Disable" : "Enable")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(item.isEnabled ? ThingsTheme.cardRaised : ThingsTheme.accent.opacity(0.12))
                        .foregroundStyle(item.isEnabled ? ThingsTheme.textPrimary : ThingsTheme.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    startupService.trashItem(item)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(ThingsTheme.textTertiary)
                        .padding(6)
                        .background(ThingsTheme.cardRaised)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Move LaunchAgent to Trash")
            }
        }
        .padding(12)
        .background(ThingsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(ThingsTheme.border, lineWidth: 1)
        )
    }
}
