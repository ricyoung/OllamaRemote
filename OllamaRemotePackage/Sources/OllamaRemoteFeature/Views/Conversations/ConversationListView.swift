import SwiftUI
import SwiftData

public struct ConversationListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]

    public init() {}

    public var body: some View {
        List {
            ForEach(conversations) { conversation in
                NavigationLink(value: conversation) {
                    ConversationRowView(conversation: conversation)
                }
            }
            .onDelete(perform: deleteConversations)
        }
        .navigationDestination(for: Conversation.self) { conversation in
            ChatView(conversation: conversation)
        }
        .navigationTitle("Conversations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    createNewConversation()
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gear")
                }
            }
        }
        .overlay {
            if conversations.isEmpty {
                ContentUnavailableView {
                    Label("No Conversations", systemImage: "bubble.left.and.bubble.right")
                } description: {
                    Text("Tap + to start a new conversation")
                } actions: {
                    Button("New Conversation") {
                        createNewConversation()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
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
            let conversation = conversations[index]
            if appState.selectedConversation?.id == conversation.id {
                appState.selectedConversation = nil
            }
            modelContext.delete(conversation)
        }
    }
}
