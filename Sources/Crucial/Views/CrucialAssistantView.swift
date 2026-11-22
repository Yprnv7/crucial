import SwiftUI
import AppKit

public struct CrucialAssistantView: View {
    @ObservedObject var chatService = CrucialChatService.shared
    @ObservedObject var windowManager = WindowManager.shared
    @ObservedObject var localLLM = LocalLLMService.shared
    @State private var inputText: String = ""
    @State private var actionToConfirm: (action: ChatAction, messageId: UUID)? = nil

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Retro Diagnostic Terminal Header
            terminalHeader
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(RetroTheme.panel)

            Divider().background(RetroTheme.border)

            // Diagnostic Command Shortcuts
            commandBar
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(RetroTheme.bg.opacity(0.8))

            Divider().background(RetroTheme.border)

            // Message Stream
            messagesStream

            Divider().background(RetroTheme.border)

            // Retro Command Console Input
            consoleInputBar
                .padding(12)
                .background(RetroTheme.panel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RetroTheme.bg)
        .alert(item: Binding<ActionConfirmationItem?>(
            get: {
                if let a = actionToConfirm {
                    return ActionConfirmationItem(action: a.action, messageId: a.messageId)
                }
                return nil
            },
            set: { _ in actionToConfirm = nil }
        )) { item in
            Alert(
                title: Text("AUTHORIZE DISK OPERATION"),
                message: Text("Crucial will execute: \(item.action.title). All deletions are staged in your macOS Trash."),
                primaryButton: .destructive(Text("CONFIRM")) {
                    chatService.executeAction(item.action, for: item.messageId)
                },
                secondaryButton: .cancel(Text("ABORT"))
            )
        }
    }

    // MARK: - Terminal Header
    private var terminalHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Circle().fill(Color.red.opacity(0.8)).frame(width: 8, height: 8)
                Circle().fill(Color.yellow.opacity(0.8)).frame(width: 8, height: 8)
                Circle().fill(Color.green.opacity(0.8)).frame(width: 8, height: 8)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("CRUCIAL DIAGNOSTIC CONSOLE")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroTheme.textPrimary)

                    Text(localLLM.isModelReady ? "ENGINE: LLAMA-3.2-METAL [ONLINE]" : "ENGINE: DEEP DIAGNOSTIC [ONLINE]")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroTheme.amber)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(RetroTheme.panelRaised)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(RetroTheme.amber.opacity(0.4), lineWidth: 1))
                }

                Text("SUBSYSTEM: APFS_AUDITOR // DISK_INODE_TELEMETRY // ZERO_DATA_LOSS_INTERLOCK")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(RetroTheme.textDim)
            }

            Spacer()

            Button {
                chatService.messages.removeAll()
                chatService.loadWelcomeMessage()
            } label: {
                Text("[CLEAR CONSOLE]")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroTheme.textMuted)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Command Bar
    private var commandBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                terminalPromptChip("DIAGNOSE_STORAGE", prompt: "Why is my disk full?")
                terminalPromptChip("AUDIT_DERIVEDDATA", prompt: "Explain Xcode DerivedData")
                terminalPromptChip("AUDIT_NODE_MODULES", prompt: "Explain node_modules")
                terminalPromptChip("AUDIT_USER_CACHES", prompt: "Can I delete ~/Library/Caches?")
                terminalPromptChip("STAGE_SAFE_CLEAN", prompt: "Clean safe files")
                terminalPromptChip("VERIFY_SAFETY_LOCK", prompt: "Will deleting files break my Mac?")
            }
        }
    }

    private func terminalPromptChip(_ title: String, prompt: String) -> some View {
        Button {
            chatService.sendUserMessage(prompt)
        } label: {
            HStack(spacing: 4) {
                Text(">")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroTheme.cyan)
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroTheme.textPrimary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RetroTheme.panel)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(RetroTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Messages Stream
    private var messagesStream: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(chatService.messages) { msg in
                        terminalMessageRow(msg)
                            .id(msg.id)
                    }

                    if chatService.isTyping || localLLM.isGenerating {
                        HStack(spacing: 8) {
                            Text(">")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(RetroTheme.amber)
                            Text("EXECUTING DIAGNOSTIC TELEMETRY ANALYSIS...")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(RetroTheme.amber)
                            Spacer()
                        }
                        .padding(.horizontal, 18)
                    }
                }
                .padding(18)
            }
            .onChange(of: chatService.messages.count) {
                if let last = chatService.messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func terminalMessageRow(_ msg: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header bar of message
            HStack(spacing: 6) {
                Text(msg.sender == .user ? "[OPERATOR // QUERY]" : "[CRUCIAL TELEMETRY // REPORT]")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(msg.sender == .user ? RetroTheme.cyan : RetroTheme.amber)

                Spacer()

                Text(DateFormatter.localizedString(from: msg.timestamp, dateStyle: .none, timeStyle: .medium))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(RetroTheme.textDim)
            }

            // Message Body
            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey(msg.text))
                    .font(.system(size: 11, design: .monospaced))
                    .lineSpacing(4)
                    .foregroundStyle(RetroTheme.textPrimary)
                    .textSelection(.enabled)

                // If Action Attached
                if let action = msg.suggestedAction {
                    Divider().background(RetroTheme.border)
                        .padding(.vertical, 4)

                    if msg.isActionExecuted {
                        HStack(spacing: 6) {
                            Text("[STATUS: EXECUTED]")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(RetroTheme.emerald)
                        }
                        .padding(6)
                        .background(RetroTheme.emerald.opacity(0.1))
                        .cornerRadius(4)
                    } else {
                        HStack {
                            Text("ACTION REQUIRED:")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(RetroTheme.amber)

                            Spacer()

                            Button {
                                actionToConfirm = (action: action, messageId: msg.id)
                            } label: {
                                HStack(spacing: 6) {
                                    Text("[")
                                    Image(systemName: action.iconName)
                                        .font(.system(size: 10))
                                    Text(action.title.uppercased())
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    Text("]")
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(RetroTheme.panelRaised)
                                .foregroundStyle(RetroTheme.amber)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(RetroTheme.amber, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(12)
            .background(msg.sender == .user ? RetroTheme.panel : RetroTheme.panelRaised)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(msg.sender == .user ? RetroTheme.border : RetroTheme.borderLight, lineWidth: 1)
            )
        }
    }

    // MARK: - Command Console Input
    private var consoleInputBar: some View {
        VStack(spacing: 6) {
            // Target file badge if inspecting
            if let selected = windowManager.selectedItem {
                HStack(spacing: 6) {
                    Text("ACTIVE_TARGET:")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroTheme.amber)

                    Text(selected.path)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(RetroTheme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        chatService.askAbout(item: selected)
                    } label: {
                        Text("[RUN FULL DIAGNOSTIC]")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(RetroTheme.cyan)
                    }
                    .buttonStyle(.plain)
                }
                .padding(6)
                .background(RetroTheme.panelRaised)
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(RetroTheme.border, lineWidth: 1))
            }

            HStack(spacing: 8) {
                Text(">")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(RetroTheme.cyan)

                TextField("ENTER FILE PATH OR QUERY (e.g. 'Why is my disk full?')...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(RetroTheme.textPrimary)
                    .onSubmit {
                        submitText()
                    }

                Button {
                    submitText()
                } label: {
                    Text("[EXECUTE]")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? RetroTheme.textDim : RetroTheme.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RetroTheme.panelRaised)
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(RetroTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(10)
            .background(RetroTheme.bg)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(RetroTheme.border, lineWidth: 1))
        }
    }

    private func submitText() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        chatService.sendUserMessage(text)
    }
}

private struct ActionConfirmationItem: Identifiable {
    let id = UUID()
    let action: ChatAction
    let messageId: UUID
}
