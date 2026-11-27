import SwiftUI

/// Standard macOS Preferences / Settings window opened via Cmd-Comma.
public struct CrucialSettingsView: View {
    @Environment(PermissionsService.self) private var permissions
    @Environment(LocalLLMService.self) private var llm
    @Environment(SafetyTrashService.self) private var trashService

    public init() {}

    public var body: some View {
        TabView {
            Form {
                Section("Permissions") {
                    LabeledContent("Full Disk Access") {
                        HStack(spacing: CrucialSpacing.sm) {
                            Text(permissions.hasFullDiskAccess ? "Granted" : "Not Granted")
                                .foregroundStyle(permissions.hasFullDiskAccess ? CrucialTheme.accentInk : CrucialTheme.starOchre)
                            Button("Open System Settings") {
                                permissions.openFullDiskAccessSettings()
                            }
                            Button("Recheck") {
                                permissions.checkPermissions()
                            }
                        }
                    }

                    LabeledContent("Authorized Folders") {
                        VStack(alignment: .trailing, spacing: CrucialSpacing.xs) {
                            Text("\(permissions.userAuthorizedFolders.count) custom folder(s)")
                                .foregroundStyle(CrucialTheme.textSecondary)
                            Button("Authorize Folder...") {
                                _ = permissions.requestFolderAccess()
                            }
                        }
                    }
                }

                Section("Safety Guarantees") {
                    LabeledContent("Deletion Mode") {
                        Text("macOS Trash (Recoverable)")
                            .foregroundStyle(CrucialTheme.accentInk)
                    }
                    LabeledContent("Protected Symlinks") {
                        Text("Always Blocked")
                            .foregroundStyle(CrucialTheme.textSecondary)
                    }
                    LabeledContent("Session Trash Log") {
                        Text("\(trashService.history.count) recorded moves")
                            .monospacedDigit()
                            .foregroundStyle(CrucialTheme.textSecondary)
                    }
                    Button("Open Trash in Finder") {
                        trashService.openTrash()
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            Form {
                Section("Offline Model Runtime") {
                    LabeledContent("Status") {
                        Text(llm.isModelReady ? "Ready (Offline)" : "Using Deterministic Rule Engine")
                            .foregroundStyle(llm.isModelReady ? CrucialTheme.accentInk : CrucialTheme.textSecondary)
                    }
                    LabeledContent("llama-cli Binary") {
                        Text(llm.binPath.isEmpty ? "Not bundled or found in Application Support" : llm.binPath)
                            .font(.caption.monospaced())
                            .lineLimit(2)
                    }
                    LabeledContent("GGUF Weights") {
                        Text(llm.modelPath.isEmpty ? "Not installed" : llm.modelPath)
                            .font(.caption.monospaced())
                            .lineLimit(2)
                    }
                    HStack {
                        Button("Recheck Model Paths") {
                            llm.checkModelStatus()
                        }
                        Button("Clear Conversation Memory") {
                            llm.clearConversationHistory()
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Assistant", systemImage: "cpu")
            }
        }
        .frame(width: 520, height: 340)
        .onAppear {
            permissions.checkPermissions()
            llm.checkModelStatus()
        }
    }
}
