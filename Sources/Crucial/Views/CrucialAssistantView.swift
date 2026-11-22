import SwiftUI
import AppKit

public struct CrucialAssistantView: View {
    @ObservedObject var chatService = CrucialChatService.shared
    @ObservedObject var windowManager = WindowManager.shared
    @State private var inputText: String = ""
    @State private var actionToConfirm: (action: ChatAction, messageId: UUID)? = nil

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerSection
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            // Quick Prompt Suggestions Carousel
            quickPromptsBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()

            // Chat Messages Stream
            messagesStream

            Divider()

            // Input Bar
            inputBarSection
                .padding(14)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
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
                title: Text("Execute Action?"),
                message: Text("Crucial will now execute: \(item.action.title). Deletions are safely staged in your macOS Trash."),
                primaryButton: .destructive(Text("Proceed")) {
                    chatService.executeAction(item.action, for: item.messageId)
                },
                secondaryButton: .cancel()
            )
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .indigo, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: "bubble.left.and.sparkles.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Crucial Assistant")
                        .font(.system(size: 15, weight: .bold))
                    Text("100% Offline AI")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(4)
                }
                Text("Built-in macOS expert knowledge for disk bloat, caches, and file vitality.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                chatService.messages.removeAll()
                chatService.loadWelcomeMessage()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Clear Chat History")
        }
    }

    // MARK: - Quick Prompt Suggestions
    private var quickPromptsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                promptChip("Why is my disk full?")
                promptChip("Explain DerivedData")
                promptChip("Explain node_modules")
                promptChip("Can I delete ~/Library/Caches?")
                promptChip("Clean safe files")
                promptChip("Will deleting files break my Mac?")
            }
        }
    }

    private func promptChip(_ text: String) -> some View {
        Button {
            chatService.sendUserMessage(text)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "sparkle")
                    .font(.system(size: 9))
                    .foregroundStyle(.purple)
                Text(text)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Messages Stream
    private var messagesStream: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(chatService.messages) { msg in
                        messageRow(msg)
                            .id(msg.id)
                    }

                    if chatService.isTyping {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("Crucial Assistant is thinking...")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(20)
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

    private func messageRow(_ msg: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if msg.sender == .assistant {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.purple)
                }
            } else {
                Spacer()
            }

            VStack(alignment: msg.sender == .user ? .trailing : .leading, spacing: 8) {
                // Message Bubble
                Text(LocalizedStringKey(msg.text))
                    .font(.system(size: 12))
                    .lineSpacing(3)
                    .padding(12)
                    .foregroundStyle(msg.sender == .user ? Color.white : Color.primary)
                    .background(
                        msg.sender == .user
                            ? Color.accentColor
                            : Color(NSColor.controlBackgroundColor).opacity(0.8)
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                    )

                // Context File Pill if attached
                if let item = msg.contextItem {
                    HStack(spacing: 6) {
                        Image(nsImage: item.icon)
                            .resizable()
                            .frame(width: 14, height: 14)
                        Text(item.name)
                            .font(.system(size: 10, weight: .semibold))
                        Text("(\(item.formattedSize))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                }

                // Suggested Action Card (Shown only after explanation!)
                if let action = msg.suggestedAction {
                    if msg.isActionExecuted {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Action Completed")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                    } else {
                        Button {
                            actionToConfirm = (action: action, messageId: msg.id)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: action.iconName)
                                    .font(.system(size: 11))
                                Text(action.title)
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.purple)
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                            .shadow(color: .purple.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if msg.sender == .user {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "person.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                }
            } else {
                Spacer()
            }
        }
    }

    // MARK: - Input Bar
    private var inputBarSection: some View {
        VStack(spacing: 6) {
            // Currently inspected item chip
            if let selected = windowManager.selectedItem {
                HStack(spacing: 6) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 10))
                        .foregroundStyle(.purple)
                    Text("Selected: \(selected.name)")
                        .font(.system(size: 10, weight: .semibold))
                    Spacer()
                    Button("Explain this file") {
                        chatService.askAbout(item: selected)
                    }
                    .font(.system(size: 9, weight: .bold))
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(5)
            }

            HStack(spacing: 8) {
                TextField("Ask anything about your files, caches, or disk space...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit {
                        submitText()
                    }

                Button {
                    submitText()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary.opacity(0.4) : Color.purple)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
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
