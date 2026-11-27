import SwiftUI

/// Offline forensic assistant backed by the Crucial rule engine and optional local GGUF inference.
public struct AssistantView: View {
    @Environment(CrucialChatService.self) private var chat
    @Environment(LocalLLMService.self) private var llm
    @Environment(NavigationStore.self) private var navigation

    @State private var draftMessage = ""

    private let suggestedPrompts = [
        "What is safe to clean right now?",
        "Show largest developer caches",
        "Inspect ~/Library residue"
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            statusHeader

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: CrucialSpacing.md) {
                        ForEach(chat.messages) { message in
                            AssistantMessageBubble(message: message)
                                .id(message.id)
                        }

                        if chat.isTyping {
                            HStack(spacing: CrucialSpacing.sm) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Evaluating local storage rules...")
                                    .font(.caption)
                                    .foregroundStyle(CrucialTheme.textSecondary)
                            }
                            .padding(.horizontal, CrucialSpacing.md)
                        }
                    }
                    .padding(CrucialSpacing.xl)
                }
                .background(CrucialTheme.canvas)
                .onChange(of: chat.messages.count) { _, _ in
                    if let lastID = chat.messages.last?.id {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }

            Divider()

            promptComposer
        }
        .task {
            llm.checkModelStatus()
            if chat.messages.isEmpty {
                chat.loadWelcomeMessage()
            }
        }
    }

    private var statusHeader: some View {
        HStack(spacing: CrucialSpacing.md) {
            Image(systemName: "cpu")
                .font(.title3)
                .foregroundStyle(CrucialTheme.accentInk)

            VStack(alignment: .leading, spacing: CrucialSpacing.xxs) {
                Text("Crucial Assistant")
                    .font(.headline)
                    .foregroundStyle(CrucialTheme.textPrimary)

                Text(
                    llm.isModelReady
                        ? "Offline mode active (Llama 3.2 1B Q4 + Vitality rule engine)"
                        : "Offline deterministic Vitality rule engine active"
                )
                .font(.caption)
                .foregroundStyle(CrucialTheme.textSecondary)
            }

            Spacer()

            Button("Reset Thread") {
                llm.clearConversationHistory()
                chat.loadWelcomeMessage()
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, CrucialSpacing.lg)
        .padding(.vertical, CrucialSpacing.md)
        .background(CrucialTheme.card)
    }

    private var promptComposer: some View {
        VStack(alignment: .leading, spacing: CrucialSpacing.sm) {
            ScrollView(.horizontal) {
                HStack(spacing: CrucialSpacing.sm) {
                    ForEach(suggestedPrompts, id: \.self) { prompt in
                        Button(prompt) {
                            chat.sendUserMessage(prompt, contextItem: navigation.selectedItem)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            HStack(spacing: CrucialSpacing.sm) {
                TextField("Ask about a cache, folder, or cleanup plan...", text: $draftMessage)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { submitDraft() }

                Button("Send", action: submitDraft)
                    .buttonStyle(.borderedProminent)
                    .tint(CrucialTheme.accentInk)
                    .disabled(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(CrucialSpacing.md)
        .background(CrucialTheme.card)
    }

    private func submitDraft() {
        let trimmed = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        draftMessage = ""
        chat.sendUserMessage(trimmed, contextItem: navigation.selectedItem)
    }
}
