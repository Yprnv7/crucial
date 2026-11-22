import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var permissions = PermissionsService.shared
    @ObservedObject var trashService = SafetyTrashService.shared
    @ObservedObject var scanner = FileScannerService.shared
    @ObservedObject var cpuMonitor = CPUMonitorService.shared
    @ObservedObject var localLLM = LocalLLMService.shared

    public init() {}

    public var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: permissions.hasFullDiskAccess ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                            .foregroundStyle(permissions.hasFullDiskAccess ? ThingsTheme.accent : ThingsTheme.warning)
                            .font(.system(size: 16))

                        Text(permissions.hasFullDiskAccess ? "Full Disk Access Granted" : "Full Disk Access Recommended")
                            .font(.system(size: 13, weight: .semibold))

                        Spacer()

                        Button("System Settings...") {
                            permissions.openFullDiskAccessSettings()
                        }
                    }

                    Text("Full Disk Access allows Crucial to scan and clean system-level caches, Xcode DerivedData, and orphaned application residue.")
                        .font(.system(size: 11))
                        .foregroundStyle(ThingsTheme.textSecondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("macOS Permissions")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Scan Mode", selection: $scanner.pacingMode) {
                        ForEach(ScanPacingMode.allCases) { mode in
                            Text(mode == .pacedBurst ? "Paced (~10%)" : "Turbo (97%)").tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(scanner.pacingMode.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(ThingsTheme.textSecondary)

                    HStack {
                        Text("Live Process CPU Usage:")
                            .font(.system(size: 11))
                            .foregroundStyle(ThingsTheme.textSecondary)
                        Spacer()
                        Circle()
                            .fill(cpuMonitor.cpuPercent > 50 ? ThingsTheme.vitalCrimson : (cpuMonitor.cpuPercent > 15 ? ThingsTheme.starOchre : ThingsTheme.accent))
                            .frame(width: 6, height: 6)
                        Text(String(format: "%.1f%%", cpuMonitor.cpuPercent))
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Scanner CPU & Performance")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "cpu")
                            .font(.system(size: 14))
                            .foregroundStyle(ThingsTheme.accent)
                        Text("Llama 3.2 1B Instruct (Metal GPU)")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        ThingsTag("Active", color: ThingsTheme.accent)
                    }

                    Text("Crucial runs an on-device local Large Language Model via Apple Silicon Metal GPU acceleration. All file telemetry synthesis, reasoning, and risk analyses occur completely offline on your Mac with zero external cloud calls.")
                        .font(.system(size: 11))
                        .foregroundStyle(ThingsTheme.textSecondary)

                    Divider().background(ThingsTheme.borderSubtle)

                    HStack {
                        Text("Inference Engine:")
                            .font(.system(size: 11))
                            .foregroundStyle(ThingsTheme.textSecondary)
                        Spacer()
                        Text("llama.cpp · Apple Silicon Metal")
                            .font(.system(size: 11, weight: .medium))
                    }

                    HStack {
                        Text("Local Model Weights:")
                            .font(.system(size: 11))
                            .foregroundStyle(ThingsTheme.textSecondary)
                        Spacer()
                        Text("Llama-3.2-1B-Instruct-Q4_K_M.gguf")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("On-Device AI Engine")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Total Cleaned this session:")
                            .font(.system(size: 12))
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: trashService.lastFreedBytes, countStyle: .file))
                            .font(.system(size: 12, weight: .bold))
                    }

                    Button("Open macOS Trash Folder") {
                        trashService.openTrash()
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Trash & Recovery")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 420)
        .onAppear {
            permissions.checkPermissions()
            localLLM.checkModelStatus()
        }
    }
}
