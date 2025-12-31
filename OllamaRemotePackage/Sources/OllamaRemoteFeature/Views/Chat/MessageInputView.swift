import SwiftUI

public struct MessageInputView: View {
    @Binding var text: String
    let isStreaming: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void
    let onCancel: () -> Void

    @State private var isPressed = false
    @State private var showMicHint = false
    @State private var rainbowPhase: CGFloat = 0

    public init(
        text: Binding<String>,
        isStreaming: Bool,
        isFocused: FocusState<Bool>.Binding,
        onSend: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._text = text
        self.isStreaming = isStreaming
        self.isFocused = isFocused
        self.onSend = onSend
        self.onCancel = onCancel
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Microphone button
            Button {
                isFocused.wrappedValue = true
                showMicHint = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showMicHint = false
                }
            } label: {
                Image(systemName: "mic.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .disabled(isStreaming)

            // Text input
            TextField("Message", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .focused(isFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            isFocused.wrappedValue ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.1),
                            lineWidth: isFocused.wrappedValue ? 1.5 : 0.5
                        )
                        .animation(.easeInOut(duration: 0.2), value: isFocused.wrappedValue)
                }
                .overlay(alignment: .trailing) {
                    if showMicHint {
                        Text("Tap 🎤 on keyboard")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 12)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .onSubmit {
                    if canSend {
                        onSend()
                    }
                }

            // Send/Cancel button with animation
            Button {
                if isStreaming {
                    onCancel()
                } else if canSend {
                    onSend()
                }
            } label: {
                ZStack {
                    // Stop icon
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.red.gradient, in: Circle())
                        .opacity(isStreaming ? 1 : 0)
                        .scaleEffect(isStreaming ? 1 : 0.5)

                    // Send icon
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            (canSend ? Color.accentColor : Color.gray).gradient,
                            in: Circle()
                        )
                        .opacity(isStreaming ? 0 : 1)
                        .scaleEffect(isStreaming ? 0.5 : 1)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isStreaming)
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
            }
            .disabled(!isStreaming && !canSend)
            .buttonStyle(.plain)
            .hoverEffect(.lift)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .bottom) {
            // Subtle rainbow animation at the bottom
            RainbowGradient(phase: rainbowPhase)
                .frame(height: 2)
                .opacity(0.6)
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rainbowPhase = 1
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showMicHint)
    }
}

// MARK: - Rainbow Gradient

private struct RainbowGradient: View {
    let phase: CGFloat

    private var colors: [Color] {
        [
            .red.opacity(0.8),
            .orange.opacity(0.8),
            .yellow.opacity(0.8),
            .green.opacity(0.8),
            .cyan.opacity(0.8),
            .blue.opacity(0.8),
            .purple.opacity(0.8),
            .red.opacity(0.8)
        ]
    }

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: UnitPoint(x: -0.5 + phase, y: 0.5),
            endPoint: UnitPoint(x: 0.5 + phase, y: 0.5)
        )
        .blur(radius: 1)
    }
}
