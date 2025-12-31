import SwiftUI
import SwiftData

public struct ChatView: View {
    @Bindable var conversation: Conversation
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var chatService = ChatService()
    @State private var inputText = ""

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
                onSend: sendMessage,
                onCancel: cancelStream
            )
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await appState.loadModels()
        }
        .onChange(of: appState.activeProvider?.id) { _, _ in
            Task { await appState.loadModels() }
        }
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
