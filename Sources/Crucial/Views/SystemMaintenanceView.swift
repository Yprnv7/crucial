import SwiftUI

public struct SystemMaintenanceView: View {
    @ObservedObject var maintenance = SystemMaintenanceService.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(ThingsTheme.accent.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ThingsTheme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("System Maintenance")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(ThingsTheme.textPrimary)

                    Text("Thin phantom APFS snapshots, clear stale DNS caches, and tune macOS performance.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(ThingsTheme.textSecondary)
                }

                Spacer()

                Button {
                    Task {
                        await maintenance.runAllTasks()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if maintenance.isRunningAll {
                            ProgressView().scaleEffect(0.65)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text(maintenance.isRunningAll ? "Running Tasks..." : "Run All Tasks")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(ThingsTheme.accent)
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(maintenance.isRunningAll)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(ThingsTheme.canvas)

            Divider().background(ThingsTheme.borderSubtle)

            // Tasks List
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(0..<maintenance.tasks.count, id: \.self) { idx in
                        maintenanceTaskCard(index: idx)
                    }
                }
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThingsTheme.canvas)
    }

    private func maintenanceTaskCard(index: Int) -> some View {
        let task = maintenance.tasks[index]

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(task.isCompleted ? ThingsTheme.accent.opacity(0.12) : ThingsTheme.cardRaised)
                    .frame(width: 42, height: 42)

                if task.isExecuting {
                    ProgressView().scaleEffect(0.7)
                } else if task.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(ThingsTheme.accent)
                } else {
                    Image(systemName: task.iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ThingsTheme.textPrimary)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(task.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ThingsTheme.textPrimary)

                Text(task.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(ThingsTheme.textSecondary)

                if let result = task.resultMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(ThingsTheme.accent)
                        Text(result)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ThingsTheme.accent)
                    }
                    .padding(.top, 2)
                }
            }

            Spacer()

            Button {
                Task {
                    await maintenance.executeTask(at: index)
                }
            } label: {
                Text(task.isCompleted ? "Run Again" : "Execute")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ThingsTheme.cardRaised)
                    .foregroundStyle(ThingsTheme.textPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(task.isExecuting || maintenance.isRunningAll)
        }
        .padding(14)
        .background(ThingsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(ThingsTheme.border, lineWidth: 1)
        )
    }
}
