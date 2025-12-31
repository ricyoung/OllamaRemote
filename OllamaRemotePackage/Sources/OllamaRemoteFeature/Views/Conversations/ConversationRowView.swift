import SwiftUI

public struct ConversationRowView: View {
    let conversation: Conversation
    @State private var appeared = false

    public init(conversation: Conversation) {
        self.conversation = conversation
    }

    public var body: some View {
        HStack(spacing: 14) {
            // Provider icon with glass background
            providerIcon

            VStack(alignment: .leading, spacing: 6) {
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

                    // Message count badge with glass effect
                    if conversation.messages.count > 0 {
                        Text("\(conversation.messages.count)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double.random(in: 0...0.1))) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private var providerIcon: some View {
        ZStack {
            // Glass background
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 44, height: 44)

            // Gradient overlay
            Circle()
                .fill(providerGradient)
                .frame(width: 44, height: 44)
                .opacity(0.9)

            // Icon
            Image(systemName: conversation.providerType.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
        }
        .shadow(color: providerColor.opacity(0.3), radius: 8, y: 4)
    }

    private var providerGradient: LinearGradient {
        LinearGradient(
            colors: [providerColor, providerColor.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
