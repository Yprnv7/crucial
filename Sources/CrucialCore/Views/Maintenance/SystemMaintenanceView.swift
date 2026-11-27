import SwiftUI

/// Executes native macOS maintenance routines including DNS cache flush, Time Machine thinning, and Spotlight re-indexing.
public struct SystemMaintenanceView: View {
    @Environment(SystemMaintenanceService.self) private var maintenance

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: CrucialSpacing.xxs) {
                    Text("System Maintenance")
                        .font(.headline)
                        .foregroundStyle(CrucialTheme.textPrimary)

                    Text("Run documented macOS utilities with administrator confirmation where required.")
                        .font(.caption)
                        .foregroundStyle(CrucialTheme.textSecondary)
                }

                Spacer()

                Button("Run All Tasks") {
                    Task { await maintenance.runAllTasks() }
                }
                .buttonStyle(.borderedProminent)
                .tint(CrucialTheme.accentInk)
                .disabled(maintenance.isRunningAll)
            }
            .padding(.horizontal, CrucialSpacing.lg)
            .padding(.vertical, CrucialSpacing.md)
            .background(CrucialTheme.card)

            Divider()

            ScrollView {
                LazyVStack(spacing: CrucialSpacing.md) {
                    ForEach(Array(maintenance.tasks.enumerated()), id: \.element.id) { index, task in
                        MaintenanceTaskRow(task: task) {
                            Task { await maintenance.executeTask(at: index) }
                        }
                    }
                }
                .padding(CrucialSpacing.xl)
            }
            .background(CrucialTheme.canvas)
        }
    }
}

private struct MaintenanceTaskRow: View {
    let task: MaintenanceTaskItem
    let onRun: () -> Void

    var body: some View {
        HStack(spacing: CrucialSpacing.md) {
            Image(systemName: task.iconName)
                .font(.title3)
                .foregroundStyle(CrucialTheme.cobalt)
                .frame(width: 34, height: 34)
                .background(CrucialTheme.cobalt.opacity(0.12), in: .rect(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: CrucialSpacing.xxs) {
                Text(task.name)
                    .font(.headline)
                    .foregroundStyle(CrucialTheme.textPrimary)

                Text(task.subtitle)
                    .font(.caption)
                    .foregroundStyle(CrucialTheme.textSecondary)

                if let resultMessage = task.resultMessage {
                    Text(resultMessage)
                        .font(.caption)
                        .foregroundStyle(task.isCompleted ? CrucialTheme.accentInk : CrucialTheme.starOchre)
                        .padding(.top, 2)
                }
            }

            Spacer()

            if task.isExecuting {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button(task.isCompleted ? "Run Again" : "Run", action: onRun)
                    .buttonStyle(.bordered)
            }
        }
        .padding(CrucialSpacing.lg)
        .background(CrucialTheme.card, in: .rect(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(CrucialTheme.border, lineWidth: 1)
        }
    }
}
