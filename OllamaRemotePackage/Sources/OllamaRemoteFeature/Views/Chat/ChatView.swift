import SwiftUI
import SwiftData

public struct ChatView: View {
    @Bindable var conversation: Conversation
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var chatService = ChatService()
    @State private var inputText = ""
    @State private var showShareSheet = false
    @State private var followUpQuestions: [String] = []
    @State private var isGeneratingFollowUps = false
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
                Menu {
                    ForEach(appState.availableModels) { model in
                        Button {
                            state.selectedModelId = model.id
                        } label: {
                            if model.id == state.selectedModelId {
                                Label(model.name, systemImage: "checkmark")
                            } else {
                                Text(model.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "cube.fill")
                            .font(.caption)
                        Text(appState.availableModels.first { $0.id == state.selectedModelId }?.name ?? "Select Model")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay {
                    LinearGradient(
                        colors: [.clear, .accentColor.opacity(0.03)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
        }
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

                    // Follow-up questions
                    if appState.showFollowUpQuestions && !followUpQuestions.isEmpty && !chatService.isStreaming {
                        followUpQuestionsView
                            .id("followups")
                    }
                }
                .padding()
            }
            .onChange(of: conversation.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: followUpQuestions) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    @ViewBuilder
    private var followUpQuestionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Follow-up questions")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            FlowLayout(spacing: 8) {
                ForEach(followUpQuestions, id: \.self) { question in
                    Button {
                        inputText = question
                        followUpQuestions = []
                        isInputFocused = true
                    } label: {
                        Text(question)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 8)
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
        followUpQuestions = [] // Clear previous follow-ups

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

            // Generate follow-up questions after response completes
            if appState.showFollowUpQuestions {
                await generateFollowUpQuestions(config: config, modelId: modelId)
            }
        }
    }

    private func generateFollowUpQuestions(config: AnyProviderConfiguration, modelId: String) async {
        guard let lastAssistantMessage = conversation.sortedMessages.last,
              lastAssistantMessage.role == .assistant,
              !lastAssistantMessage.content.isEmpty else { return }

        isGeneratingFollowUps = true

        // Build a prompt to generate follow-up questions
        let followUpPrompt = """
        Based on this conversation, suggest exactly 3 brief follow-up questions the user might ask next.
        Return ONLY the 3 questions, one per line, without numbering or bullets.
        Keep each question under 50 characters.
        """

        var contextMessages = conversation.sortedMessages.suffix(4).map { msg in
            ChatRequest.ChatMessage(role: msg.role.rawValue, content: msg.content)
        }
        contextMessages.append(ChatRequest.ChatMessage(role: "user", content: followUpPrompt))

        let request = ChatRequest(
            model: modelId,
            messages: contextMessages,
            stream: false
        )

        let provider = ProviderFactory.shared.provider(for: config)

        do {
            let response = try await provider.chat(request: request)
            let questions = response.content
                .components(separatedBy: CharacterSet.newlines)
                .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0.count < 100 }
                .prefix(3)

            await MainActor.run {
                followUpQuestions = Array(questions)
            }
        } catch {
            // Silently fail - follow-ups are optional
        }

        isGeneratingFollowUps = false
    }

    private func cancelStream() {
        chatService.cancelStream()
    }
}
