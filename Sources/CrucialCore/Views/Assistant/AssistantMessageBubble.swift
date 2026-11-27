import SwiftUI

/// Single assistant or user message bubble with matched-file previews and executable actions.
public struct AssistantMessageBubble: View {
    public let message: ChatMessage

    @Environment(CrucialChatService.self) private var chat

    public init(message: ChatMessage) {
        self.message = message
    }

    public var body: some View {
        HStack {
            if message.sender == .user {
                Spacer(minLength: 80)
            }

            VStack(alignment: .leading, spacing: CrucialSpacing.sm) {
                Text(message.sender == .user ? "You" : "Crucial Assistant")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(message.sender == .user ? CrucialTheme.textSecondary : CrucialTheme.accentInk)

                Text(message.text)
                    .font(.body)
                    .foregroundStyle(CrucialTheme.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                if !message.matchedFiles.isEmpty {
                    VStack(spacing: CrucialSpacing.xs) {
                        ForEach(message.matchedFiles) { file in
                            HStack(spacing: CrucialSpacing.sm) {
                                FileIconImage(path: file.path, size: 20)
                                Text(file.name)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(CrucialTheme.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text(file.formattedSize)
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(CrucialTheme.textSecondary)
                                Button {
                                    FinderOpener.reveal(path: file.path)
                                } label: {
                                    Image(systemName: "folder")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .labelStyle(.iconOnly)
                                .accessibilityLabel("Reveal \(file.name) in Finder")
                            }
                            .padding(.horizontal, CrucialSpacing.sm)
                            .padding(.vertical, CrucialSpacing.xs)
                            .background(CrucialTheme.cardRaised, in: .rect(cornerRadius: 6, style: .continuous))
                        }
                    }
                }

                if let action = message.suggestedAction {
                    Button {
                        chat.executeAction(action, for: message.id)
                    } label: {
                        Label(
                            message.isActionExecuted ? "Completed: \(action.title)" : action.title,
                            systemImage: message.isActionExecuted ? "checkmark.circle.fill" : action.iconName
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(message.isActionExecuted ? CrucialTheme.textSecondary : CrucialTheme.accentInk)
                    .disabled(message.isActionExecuted)
                }
            }
            .padding(CrucialSpacing.md)
            .background(
                message.sender == .user ? CrucialTheme.cardRaised : CrucialTheme.card,
                in: .rect(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(CrucialTheme.border, lineWidth: 1)
            }

            if message.sender == .assistant {
                Spacer(minLength: 80)
            }
        }
    }
}
