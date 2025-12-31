import SwiftUI

public struct MessageView: View {
    let message: Message
    @Environment(AppState.self) private var appState
    @State private var showCopied = false
    @State private var showSaved = false
    @State private var showShareSheet = false
    @State private var appeared = false
    @State private var buttonPressed: String? = nil

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
                        TypingIndicatorView()
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
            // Entrance animation
            .opacity(appeared ? 1 : 0)
            .offset(x: appeared ? 0 : (message.role == .user ? 20 : -20))

            // Action buttons below the message for assistant
            if message.role == .assistant && !message.isStreaming && !message.content.isEmpty {
                HStack(spacing: 16) {
                    ActionButton(
                        icon: showCopied ? "checkmark" : "doc.on.doc",
                        text: showCopied ? "Copied!" : "Copy",
                        isActive: showCopied,
                        isPressed: buttonPressed == "copy"
                    ) {
                        copyToClipboard()
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in buttonPressed = "copy" }
                            .onEnded { _ in buttonPressed = nil }
                    )

                    ActionButton(
                        icon: showSaved ? "checkmark" : "note.text",
                        text: showSaved ? "Saved!" : "Notes",
                        isActive: showSaved,
                        isPressed: buttonPressed == "notes"
                    ) {
                        saveToNotes()
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in buttonPressed = "notes" }
                            .onEnded { _ in buttonPressed = nil }
                    )
                }
                .padding(.leading, 44)
                .opacity(appeared ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [message.content])
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = message.content

        if appState.hapticsEnabled {
            HapticService.shared.success()
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopied = false
            }
        }
    }

    private func saveToNotes() {
        if appState.hapticsEnabled {
            HapticService.shared.success()
        }

        showShareSheet = true

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
        BlinkingCursor()
    }
}

// MARK: - Action Button

private struct ActionButton: View {
    let icon: String
    let text: String
    let isActive: Bool
    let isPressed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .contentTransition(.symbolEffect(.replace))
                Text(text)
                    .font(.caption)
            }
            .foregroundStyle(isActive ? .green : .secondary)
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Blinking Cursor

private struct BlinkingCursor: View {
    @State private var isVisible = true

    var body: some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(width: 2, height: 16)
            .opacity(isVisible ? 0.8 : 0.2)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isVisible.toggle()
                }
            }
    }
}

// MARK: - Typing Indicator

public struct TypingIndicatorView: View {
    @State private var animationPhase = 0

    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                    .opacity(animationPhase == index ? 1 : 0.5)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}
