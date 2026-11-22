import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var permissions = PermissionsService.shared
    @ObservedObject var trashService = SafetyTrashService.shared
    @ObservedObject var scanner = FileScannerService.shared
    @ObservedObject var cpuMonitor = CPUMonitorService.shared
    @State private var apiKeyInput: String = ""
    @State private var isSavedMessageShowing: Bool = false
    @State private var isTestingConnection: Bool = false
    @State private var connectionStatus: (success: Bool, message: String)? = nil

    public init() {}

    public var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: permissions.hasFullDiskAccess ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                            .foregroundStyle(permissions.hasFullDiskAccess ? .green : .orange)
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
                        .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("Live Process CPU Usage:")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Circle()
                            .fill(cpuMonitor.cpuPercent > 50 ? Color.red : (cpuMonitor.cpuPercent > 15 ? Color.orange : Color.green))
                            .frame(width: 6, height: 6)
                        Text(String(format: "%.1f%%", cpuMonitor.cpuPercent))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Scanner CPU & Performance")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Crucial uses Gemini to automatically analyze unknown files, explaining what created them and if deleting them is safe.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    HStack {
                        SecureField("AI API Key", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))

                        Button("Save") {
                            GeminiExplainerService.shared.setApiKey(apiKeyInput)
                            isSavedMessageShowing = true
                            runConnectionTest()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isSavedMessageShowing = false
                            }
                        }
                        .disabled(apiKeyInput.isEmpty)

                        Button {
                            runConnectionTest()
                        } label: {
                            if isTestingConnection {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                            } else {
                                Text("Test")
                            }
                        }
                        .disabled(apiKeyInput.isEmpty || isTestingConnection)
                    }

                    if let status = connectionStatus {
                        HStack(spacing: 5) {
                            Image(systemName: status.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundStyle(status.success ? .green : .red)
                            Text(status.message)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(status.success ? .green : .red)
                        }
                        .padding(.top, 2)
                    } else if isSavedMessageShowing {
                        Text("API Key saved!")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("AI File Reasoning (Gemini)")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Total Cleaned this session:")
                            .font(.system(size: 12))
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: trashService.lastFreedBytes, countStyle: .file))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
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
        .frame(width: 480, height: 360)
        .onAppear {
            apiKeyInput = GeminiExplainerService.shared.apiKey ?? ""
            permissions.checkPermissions()
            if !apiKeyInput.isEmpty {
                runConnectionTest()
            }
        }
    }

    private func runConnectionTest() {
        Task {
            isTestingConnection = true
            let result = await GeminiExplainerService.shared.testConnection()
            await MainActor.run {
                self.connectionStatus = result
                self.isTestingConnection = false
            }
        }
    }
}
