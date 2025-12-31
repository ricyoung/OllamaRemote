import SwiftUI
import SwiftData

public struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var appState = AppState()
    @State private var showSplash = true

    public init() {}

    public var body: some View {
        ZStack {
            Group {
                if horizontalSizeClass == .regular {
                    iPadLayout
                } else {
                    iPhoneLayout
                }
            }
            .environment(appState)
            .opacity(showSplash ? 0 : 1)

            if showSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.4)) {
                    showSplash = false
                }
            }
        }
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
