import AppKit
import SwiftUI

/// MenuBarExtra popover showing real CPU load, resident memory, disk free space, and quick launch.
public struct CrucialMenuBarView: View {
    @Environment(CPUMonitorService.self) private var monitor
    @Environment(FileScannerService.self) private var scanner
    @Environment(\.openWindow) private var openWindow

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: CrucialSpacing.md) {
            HStack {
                Text("Crucial Telemetry")
                    .font(.headline)
                    .foregroundStyle(CrucialTheme.textPrimary)

                Spacer()

                Text(scanner.hardwareInfo.smartStatus)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(CrucialTheme.accentInk)
            }

            Divider()

            metricRow(
                label: "CPU Load",
                value: "\(monitor.cpuPercent.formatted(.number.precision(.fractionLength(1))))%"
            )
            metricRow(
                label: "App Memory",
                value: "\(monitor.memoryMB.formatted(.number.precision(.fractionLength(0)))) MB"
            )
            metricRow(
                label: "Free Disk Space",
                value: ByteCountFormatter.string(fromByteCount: scanner.diskFreeBytes, countStyle: .file)
            )
            metricRow(
                label: "Cleanable Found",
                value: ByteCountFormatter.string(fromByteCount: scanner.totalCleanableBytes, countStyle: .file)
            )

            Divider()

            HStack(spacing: CrucialSpacing.sm) {
                Button("Open Crucial") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                }
                .buttonStyle(.borderedProminent)
                .tint(CrucialTheme.accentInk)

                Spacer()

                Button("Rescan") {
                    Task { await scanner.scanQuickCleanDashboard() }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(CrucialSpacing.md)
        .frame(width: 280)
        .onAppear {
            monitor.startMonitoring()
            scanner.refreshDiskSpace()
        }
        .onDisappear {
            monitor.stopMonitoring()
        }
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(CrucialTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(CrucialTheme.textPrimary)
        }
    }
}
