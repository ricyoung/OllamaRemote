import SwiftUI

public struct MessageView: View {
    let message: Message
    @Environment(AppState.self) private var appState
    @State private var showCopied = false
    @State private var showSaved = false
    @State private var showShareSheet = false

    public init(message: Message) {
        self.message = message
    }

    public var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                if message.role == .assistant {
                    Image(systemName: "cpu")
                        .font(.title2)
                        .foregroundStyle(.tint)
                        .symbolRenderingMode(.hierarchical)
                }

                VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                    if message.isStreaming && message.content.isEmpty {
                        ProgressView()
                            .padding(8)
                    } else if message.isStreaming {
                        HStack(alignment: .bottom, spacing: 2) {
                            MarkdownTextView(content: message.content)
                            streamingCursor
                        }
                    } else {
                        MarkdownTextView(content: message.content)
                    }

                    if let model = message.modelUsed, !message.isStreaming {
                        Text(model)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(message.role == .user ? AnyShapeStyle(Color.accentColor.opacity(0.12)) : AnyShapeStyle(Material.ultraThinMaterial))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            message.role == .user
                                ? Color.accentColor.opacity(0.3)
                                : Color.primary.opacity(0.08),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

                if message.role == .user {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                        .symbolRenderingMode(.hierarchical)
                }
            }

            // Action buttons below the message for assistant
            if message.role == .assistant && !message.isStreaming && !message.content.isEmpty {
                HStack(spacing: 16) {
                    Button {
                        copyToClipboard()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                            Text(showCopied ? "Copied!" : "Copy")
                                .font(.caption)
                        }
                        .foregroundStyle(showCopied ? .green : .secondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        saveToNotes()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showSaved ? "checkmark" : "note.text")
                                .font(.caption)
                            Text(showSaved ? "Saved!" : "Notes")
                                .font(.caption)
                        }
                        .foregroundStyle(showSaved ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 44) // Align with message content (icon width + spacing)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [message.content])
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = message.content

        // Haptic feedback
        if appState.hapticsEnabled {
            HapticService.shared.success()
        }

        withAnimation {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopied = false
            }
        }
    }

    private func saveToNotes() {
        // Haptic feedback
        if appState.hapticsEnabled {
            HapticService.shared.success()
        }

        // Open share sheet which includes Notes as an option
        showShareSheet = true

        withAnimation {
            showSaved = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showSaved = false
            }
        }
    }

    @ViewBuilder
    private var streamingCursor: some View {
        Rectangle()
            .fill(Color.primary)
            .frame(width: 2, height: 16)
            .opacity(0.7)
    }
}
