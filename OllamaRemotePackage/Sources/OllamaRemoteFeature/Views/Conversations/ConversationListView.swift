import SwiftUI
import SwiftData

public struct ConversationListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @State private var editMode: EditMode = .inactive
    @State private var quickMessage = ""
    @State private var navigationPath = NavigationPath()
    @State private var searchText = ""
    @State private var conversationToRename: Conversation?
    @State private var renameText = ""
    @FocusState private var isQuickInputFocused: Bool

    private var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return conversations
        }
        return conversations.filter { conversation in
            conversation.title.localizedCaseInsensitiveContains(searchText) ||
            conversation.messages.contains { message in
                message.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(filteredConversations) { conversation in
                    NavigationLink(value: conversation) {
                        ConversationRowView(conversation: conversation)
                    }
                    .contextMenu {
                        Button {
                            renameText = conversation.title
                            conversationToRename = conversation
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            deleteConversation(conversation)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: deleteConversations)
            }
            .overlay {
                if conversations.isEmpty && quickMessage.isEmpty {
                    ContentUnavailableView {
                        Label("No Conversations", systemImage: "bubble.left.and.bubble.right")
                    } description: {
                        Text("Type below to start chatting")
                    }
                } else if filteredConversations.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }

            Divider()

            quickStartInput
        }
        .navigationDestination(for: Conversation.self) { conversation in
            ChatView(conversation: conversation)
        }
        .navigationTitle("Conversations")
        .searchable(text: $searchText, prompt: "Search conversations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    createNewConversation()
                } label: {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gear")
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            ToolbarItem(placement: .topBarTrailing) {
                if !conversations.isEmpty {
                    EditButton()
                }
            }
        }
        .environment(\.editMode, $editMode)
        .onAppear {
            cleanupOldConversations()
            StatsService.shared.recordActivity()
        }
        .alert("Rename Conversation", isPresented: .init(
            get: { conversationToRename != nil },
            set: { if !$0 { conversationToRename = nil } }
        )) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) {
                conversationToRename = nil
            }
            Button("Save") {
                if let conversation = conversationToRename {
                    conversation.title = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                conversationToRename = nil
            }
        }
    }

    @ViewBuilder
    private var quickStartInput: some View {
        HStack(spacing: 12) {
            TextField("Ask anything...", text: $quickMessage, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($isQuickInputFocused)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                }
                .onSubmit {
                    startQuickConversation()
                }

            Button {
                startQuickConversation()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
            }
            .disabled(quickMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(.bar)
    }

    private func startQuickConversation() {
        let content = quickMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        let providerType = appState.activeProvider?.type ?? .localOllama
        let conversation = Conversation(
            title: String(content.prefix(30)),
            providerType: providerType
        )
        modelContext.insert(conversation)
        appState.selectedConversation = conversation
        appState.pendingMessage = content
        quickMessage = ""
        isQuickInputFocused = false
    }

    private func createNewConversation() {
        let providerType = appState.activeProvider?.type ?? .localOllama
        let conversation = Conversation(
            title: "New Chat",
            providerType: providerType
        )
        modelContext.insert(conversation)
        appState.selectedConversation = conversation
    }

    private func deleteConversations(at offsets: IndexSet) {
        for index in offsets {
            let conversation = filteredConversations[index]
            deleteConversation(conversation)
        }
    }

    private func deleteConversation(_ conversation: Conversation) {
        if appState.selectedConversation?.id == conversation.id {
            appState.selectedConversation = nil
        }
        modelContext.delete(conversation)
    }

    private func cleanupOldConversations() {
        let days = appState.autoDeleteDays
        guard days > 0 else { return } // 0 means never delete

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        for conversation in conversations {
            if conversation.updatedAt < cutoffDate {
                deleteConversation(conversation)
            }
        }
    }
}
