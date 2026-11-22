import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var permissions = PermissionsService.shared
    @ObservedObject var trashService = SafetyTrashService.shared
    @State private var apiKeyInput: String = ""
    @State private var isSavedMessageShowing: Bool = false

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
                    Text("Crucial uses Gemini to automatically analyze unknown files, explaining what created them and if deleting them is safe.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    HStack {
                        SecureField("AI API Key (optional)", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))

                        Button("Save") {
                            GeminiExplainerService.shared.setApiKey(apiKeyInput)
                            isSavedMessageShowing = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isSavedMessageShowing = false
                            }
                        }
                        .disabled(apiKeyInput.isEmpty)
                    }

                    if isSavedMessageShowing {
                        Text("API Key saved successfully!")
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
        }
    }
}
