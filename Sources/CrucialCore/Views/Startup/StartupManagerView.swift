import SwiftUI

/// Inspects LaunchAgents and LaunchDaemons, surfacing orphaned plists and enable/disable controls.
public struct StartupManagerView: View {
    @Environment(StartupManagerService.self) private var startup

    @State private var itemPendingTrash: StartupItemInfo?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: CrucialSpacing.xxs) {
                    Text("Startup Agents & Daemons")
                        .font(.headline)
                        .foregroundStyle(CrucialTheme.textPrimary)

                    Text("Review user LaunchAgents and read-only system daemons configured to start automatically.")
                        .font(.caption)
                        .foregroundStyle(CrucialTheme.textSecondary)
                }

                Spacer()

                Button("Rescan") {
                    Task { await startup.scanStartupItems() }
                }
                .buttonStyle(.bordered)
                .disabled(startup.isScanning)
            }
            .padding(.horizontal, CrucialSpacing.lg)
            .padding(.vertical, CrucialSpacing.md)
            .background(CrucialTheme.card)

            Divider()

            if let errorMessage = startup.lastErrorMessage {
                HStack(spacing: CrucialSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(CrucialTheme.starOchre)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(CrucialTheme.textPrimary)
                    Spacer()
                }
                .padding(CrucialSpacing.md)
                .background(CrucialTheme.card)
                Divider()
            }

            if startup.isScanning && startup.items.isEmpty {
                ProgressView("Scanning LaunchAgents...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(CrucialTheme.canvas)
            } else if startup.items.isEmpty {
                ContentUnavailableView {
                    Label("No Startup Agents Found", systemImage: "bolt.circle")
                } description: {
                    Text("No user or third-party LaunchAgent property lists were detected.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CrucialTheme.canvas)
            } else {
                ScrollView {
                    LazyVStack(spacing: CrucialSpacing.sm) {
                        ForEach(startup.items) { item in
                            StartupAgentRow(
                                item: item,
                                onToggle: { startup.toggleItem(item) },
                                onRequestTrash: { itemPendingTrash = item }
                            )
                        }
                    }
                    .padding(CrucialSpacing.xl)
                }
                .background(CrucialTheme.canvas)
            }
        }
        .task {
            if startup.items.isEmpty && !startup.isScanning {
                await startup.scanStartupItems()
            }
        }
        .confirmationDialog(
            "Trash LaunchAgent?",
            isPresented: Binding(
                get: { itemPendingTrash != nil },
                set: { if !$0 { itemPendingTrash = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let target = itemPendingTrash {
                Button("Move \(target.label).plist to Trash", role: .destructive) {
                    startup.trashItem(target)
                    itemPendingTrash = nil
                }
            }
            Button("Cancel", role: .cancel) {
                itemPendingTrash = nil
            }
        } message: {
            Text("Removing the LaunchAgent plist prevents it from launching on future logins.")
        }
    }
}

private struct StartupAgentRow: View {
    let item: StartupItemInfo
    let onToggle: () -> Void
    let onRequestTrash: () -> Void

    var body: some View {
        HStack(spacing: CrucialSpacing.md) {
            VStack(alignment: .leading, spacing: CrucialSpacing.xxs) {
                HStack(spacing: CrucialSpacing.sm) {
                    Text(item.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(CrucialTheme.textPrimary)

                    if item.isOrphaned {
                        CrucialTag("Orphaned", color: CrucialTheme.starOchre)
                    }

                    if item.isSystemLevel {
                        CrucialTag("System Read-Only", color: CrucialTheme.textSecondary)
                    } else {
                        CrucialTag(
                            item.isEnabled ? "Enabled" : "Disabled",
                            color: item.isEnabled ? CrucialTheme.accentInk : CrucialTheme.textSecondary
                        )
                    }
                }

                Text(item.label)
                    .font(.caption.monospaced())
                    .foregroundStyle(CrucialTheme.textSecondary)

                if let execPath = item.displayExecutablePath {
                    Text(execPath)
                        .font(.caption)
                        .foregroundStyle(CrucialTheme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            Button {
                FinderOpener.reveal(path: item.plistURL.path)
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .accessibilityLabel("Reveal \(item.label) in Finder")

            if !item.isSystemLevel {
                Button(item.isEnabled ? "Disable" : "Enable", action: onToggle)
                    .buttonStyle(.bordered)

                Button(role: .destructive, action: onRequestTrash) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .labelStyle(.iconOnly)
                .accessibilityLabel("Move \(item.label) to Trash")
            }
        }
        .padding(CrucialSpacing.md)
        .background(CrucialTheme.card, in: .rect(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(CrucialTheme.border, lineWidth: 1)
        }
    }
}
