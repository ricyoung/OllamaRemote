import SwiftUI
import SwiftData

public struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var appState = AppState()

    public init() {}

    public var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .environment(appState)
    }

    @ViewBuilder
    private var iPadLayout: some View {
        NavigationSplitView {
            ConversationListView()
        } detail: {
            if let conversation = appState.selectedConversation {
                ChatView(conversation: conversation)
            } else {
                ContentUnavailableView(
                    "No Conversation Selected",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Select a conversation or create a new one")
                )
            }
        }
    }

    @ViewBuilder
    private var iPhoneLayout: some View {
        NavigationStack {
            ConversationListView()
        }
    }
}
