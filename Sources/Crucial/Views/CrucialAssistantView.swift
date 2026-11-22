import SwiftUI
import AppKit

public struct ActionConfirmationItem: Identifiable {
    public let id = UUID()
    public let action: ChatAction
    public let messageId: UUID

    public init(action: ChatAction, messageId: UUID) {
        self.action = action
        self.messageId = messageId
    }
}

public struct CrucialAssistantView: View {
    @ObservedObject var chatService = CrucialChatService.shared
    @ObservedObject var windowManager = WindowManager.shared
    @ObservedObject var localLLM = LocalLLMService.shared
    @State private var inputText: String = ""
    @State private var actionToConfirm: (action: ChatAction, messageId: UUID)? = nil

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Things 3 Native Header
            assistantHeader
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(ThingsTheme.canvas)

            Divider().background(ThingsTheme.borderSubtle)

            // MARK: - Things 3 Quick Tags / Prompts
            quickPromptBar
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(ThingsTheme.canvas)

            Divider().background(ThingsTheme.borderSubtle)

            // MARK: - Messages Stream
            messagesStream

            Divider().background(ThingsTheme.borderSubtle)

            // MARK: - Things 3 Floating Quick Entry Bar
            floatingInputBar
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(ThingsTheme.canvas)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThingsTheme.canvas)
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
                title: Text("Authorize Storage Action"),
                message: Text("Crucial will execute: \(item.action.title). Deletions are moved to macOS Trash safely."),
                primaryButton: .destructive(Text("Proceed")) {
                    chatService.executeAction(item.action, for: item.messageId)
                },
                secondaryButton: .cancel(Text("Cancel"))
            )
        }
    }

    // MARK: - Things 3 Header
    private var assistantHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(ThingsTheme.accent)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Crucial Assistant")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(ThingsTheme.textPrimary)

                    ThingsTag(
                        localLLM.isModelReady ? "Llama 3.2 · Metal GPU" : "Deterministic Core",
                        icon: "cpu",
                        color: ThingsTheme.accent
                    )
                }

                Text("On-device systems telemetry, provenance analysis & safe storage intelligence")
                    .font(.system(size: 11))
                    .foregroundStyle(ThingsTheme.textSecondary)
            }

            Spacer()

            Button {
                chatService.messages.removeAll()
                chatService.loadWelcomeMessage()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                    Text("Clear")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(ThingsTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(ThingsTheme.cardRaised)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Quick Prompt Tag Bar
    private var quickPromptBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                promptChip(title: "Disk Health", prompt: "Why is my disk full?", icon: "chart.pie.fill")
                promptChip(title: "DerivedData", prompt: "Explain Xcode DerivedData", icon: "hammer.fill")
                promptChip(title: "node_modules", prompt: "Explain node_modules", icon: "shippingbox.fill")
                promptChip(title: "System Caches", prompt: "Can I delete ~/Library/Caches?", icon: "internaldrive.fill")
                promptChip(title: "Clean Safe", prompt: "Clean safe files", icon: "sparkles")
                promptChip(title: "Safety Rules", prompt: "Will deleting files break my Mac?", icon: "shield.fill")
            }
        }
    }

    private func promptChip(title: String, prompt: String, icon: String) -> some View {
        Button {
            chatService.sendUserMessage(prompt)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ThingsTheme.accent)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ThingsTheme.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(ThingsTheme.card)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(ThingsTheme.border, lineWidth: 1)
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
                        thingsMessageRow(msg)
                            .id(msg.id)
                    }

                    if chatService.isTyping || localLLM.isGenerating {
                        HStack(spacing: 8) {
                            ThingsProgressRing(progress: 0.7, size: 14, strokeWidth: 2, tintColor: ThingsTheme.accent)
                            Text("Analyzing storage & synthesizing with local Llama 3.2...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(ThingsTheme.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
            }
            .onChange(of: chatService.messages.count) {
                if let last = chatService.messages.last {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func thingsMessageRow(_ msg: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if msg.sender == .user {
                Spacer(minLength: 40)
            } else {
                // Things 3 Circular Avatar
                ZStack {
                    Circle()
                        .fill(ThingsTheme.accent.opacity(0.12))
                        .frame(width: 28, height: 28)

                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ThingsTheme.accent)
                }
            }

            VStack(alignment: msg.sender == .user ? .trailing : .leading, spacing: 6) {
                // Author & Time
                HStack(spacing: 6) {
                    Text(msg.sender == .user ? "You" : "Crucial Intelligence")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ThingsTheme.textSecondary)

                    Text("·")
                        .foregroundStyle(ThingsTheme.textTertiary)

                    Text(DateFormatter.localizedString(from: msg.timestamp, dateStyle: .none, timeStyle: .short))
                        .font(.system(size: 10))
                        .foregroundStyle(ThingsTheme.textTertiary)
                }

                // Message Bubble / Card
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey(msg.text))
                        .font(.system(size: 12.5))
                        .lineSpacing(4)
                        .foregroundStyle(ThingsTheme.textPrimary)
                        .textSelection(.enabled)

                    // Suggested Actions
                    if let action = msg.suggestedAction, !msg.isActionExecuted {
                        Divider().background(ThingsTheme.borderSubtle)
                            .padding(.vertical, 2)

                        HStack(spacing: 8) {
                            Button {
                                actionToConfirm = (action: action, messageId: msg.id)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 11, weight: .bold))
                                    Text(action.title)
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(ThingsTheme.accent)
                                .foregroundStyle(Color.white)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Spacer()
                        }
                    } else if msg.isActionExecuted {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(ThingsTheme.accent)
                            Text("Action completed")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ThingsTheme.textSecondary)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(14)
                .background(msg.sender == .user ? ThingsTheme.cardRaised : ThingsTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(ThingsTheme.border, lineWidth: 1)
                )
            }

            if msg.sender == .user {
                // User Avatar
                ZStack {
                    Circle()
                        .fill(ThingsTheme.cardRaised)
                        .frame(width: 28, height: 28)

                    Image(systemName: "person.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(ThingsTheme.textSecondary)
                }
            } else {
                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Floating Things 3 Input Bar
    private var floatingInputBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(ThingsTheme.textTertiary)

            TextField("Ask anything about your disk, apps, or files...", text: $inputText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(ThingsTheme.textPrimary)
                .onSubmit {
                    submitInput()
                }

            if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    inputText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ThingsTheme.textTertiary)
                }
                .buttonStyle(.plain)

                Button {
                    submitInput()
                } label: {
                    ZStack {
                        Circle()
                            .fill(ThingsTheme.accent)
                            .frame(width: 28, height: 28)

                        Image(systemName: "arrow.up")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(ThingsTheme.card)
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(ThingsTheme.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }

    private func submitInput() {
        let clean = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        inputText = ""
        chatService.sendUserMessage(clean)
    }
}
