import SwiftUI

public struct MessageInputView: View {
    @Binding var text: String
    let isStreaming: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void
    let onCancel: () -> Void

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

    public var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Message", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .focused(isFocused)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                }
                .onSubmit {
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSend()
                    }
                }

            Button {
                if isStreaming {
                    onCancel()
                } else {
                    onSend()
                }
            } label: {
                Image(systemName: isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(isStreaming ? .red : .accentColor)
                    .symbolRenderingMode(.hierarchical)
            }
            .disabled(!isStreaming && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding()
        .background(.bar)
    }
}
