import SwiftUI
import SwiftData

public struct ChatView: View {
    @Bindable var conversation: Conversation
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var chatService = ChatService()
    @State private var inputText = ""
    @State private var showShareSheet = false
    @FocusState private var isInputFocused: Bool

    public init(conversation: Conversation) {
        self.conversation = conversation
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            messagesList

            Divider()

            MessageInputView(
                text: $inputText,
                isStreaming: chatService.isStreaming,
                isFocused: $isInputFocused,
                onSend: sendMessage,
                onCancel: cancelStream
            )
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(conversation.messages.isEmpty)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [exportConversation()])
        }
        .task {
            await appState.loadModels()
            await handlePendingMessage()
        }
        .onChange(of: appState.activeProvider?.id) { _, _ in
            Task { await appState.loadModels() }
        }
    }

    private func exportConversation() -> String {
        var export = "# \(conversation.title)\n"
        export += "Date: \(conversation.createdAt.formatted(date: .long, time: .shortened))\n"
        export += "Provider: \(conversation.providerType.displayName)\n\n"
        export += "---\n\n"

        for message in conversation.sortedMessages {
            let role = message.role == .user ? "**You**" : "**Assistant**"
            export += "\(role):\n\(message.content)\n\n"
        }

        return export
    }

    private func handlePendingMessage() async {
        guard let pending = appState.pendingMessage else { return }
        appState.pendingMessage = nil

        // Wait for models to load
        while appState.isLoadingModels {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        guard let config = appState.activeProvider,
              let modelId = appState.selectedModelId else { return }

        await chatService.sendMessage(
            content: pending,
            in: conversation,
            using: config,
            model: modelId
        ) { _ in }
    }

    @ViewBuilder
    private var headerBar: some View {
        HStack {
            ProviderDropdownView()

            Spacer()

            if appState.isLoadingModels {
                ProgressView()
                    .scaleEffect(0.8)
            } else if !appState.availableModels.isEmpty {
                @Bindable var state = appState
                Picker("Model", selection: $state.selectedModelId) {
                    ForEach(appState.availableModels) { model in
                        Text(model.name)
                            .tag(model.id as String?)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    @ViewBuilder
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(conversation.sortedMessages) { message in
                        MessageView(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: conversation.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = conversation.sortedMessages.last {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    private func sendMessage() {
        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty,
              let config = appState.activeProvider,
              let modelId = appState.selectedModelId else { return }

        inputText = ""

        // Haptic feedback
        if appState.hapticsEnabled {
            HapticService.shared.mediumTap()
        }

        // Auto-generate title from first message if still default
        if conversation.messages.isEmpty &&
           (conversation.title == "New Chat" || conversation.title == "New Conversation") {
            conversation.title = String(content.prefix(40))
        }

        Task {
            await chatService.sendMessage(
                content: content,
                in: conversation,
                using: config,
                model: modelId
            ) { _ in }
        }
    }

    private func cancelStream() {
        chatService.cancelStream()
    }
}
