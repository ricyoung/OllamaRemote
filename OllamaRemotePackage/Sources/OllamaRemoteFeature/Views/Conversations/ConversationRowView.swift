import SwiftUI

public struct ConversationRowView: View {
    let conversation: Conversation

    public init(conversation: Conversation) {
        self.conversation = conversation
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Provider icon with colored background
            providerIcon

            VStack(alignment: .leading, spacing: 4) {
                // Title and time row
                HStack {
                    Text(conversation.title)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    Text(relativeTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Preview and message count row
                HStack {
                    if let preview = lastMessagePreview {
                        Text(preview)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("No messages yet")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .italic()
                    }

                    Spacer()

                    // Message count badge
                    if conversation.messages.count > 0 {
                        Text("\(conversation.messages.count)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5), in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var providerIcon: some View {
        Image(systemName: conversation.providerType.iconName)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(providerColor, in: RoundedRectangle(cornerRadius: 8))
    }

    private var providerColor: Color {
        switch conversation.providerType {
        case .onDevice:
            return .purple
        case .localOllama:
            return .blue
        case .ollamaCloud:
            return .cyan
        case .openRouter:
            return .orange
        }
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: conversation.updatedAt, relativeTo: Date())
    }

    private var lastMessagePreview: String? {
        guard let lastMessage = conversation.sortedMessages.last else { return nil }
        let content = lastMessage.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = lastMessage.role == .user ? "You: " : ""
        let preview = content.replacingOccurrences(of: "\n", with: " ")
        return prefix + String(preview.prefix(60))
    }
}
