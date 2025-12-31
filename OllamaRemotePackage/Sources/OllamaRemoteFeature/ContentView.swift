import SwiftUI
import SwiftData

public struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var appState = AppState()
    @State private var showSplash = true
    @State private var iPhonePath = NavigationPath()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

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
        @Bindable var state = appState
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ConversationListView()
        } detail: {
            if let conversation = appState.selectedConversation {
                ChatView(conversation: conversation)
                    .inspector(isPresented: $state.showInspector) {
                        InspectorView(conversation: conversation)
                            .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
                    }
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
        NavigationStack(path: $iPhonePath) {
            ConversationListView()
        }
        .onChange(of: appState.selectedConversation) { oldValue, newValue in
            // Auto-navigate to new conversation on iPhone
            if let conversation = newValue, oldValue?.id != conversation.id {
                // Clear existing path and navigate to new conversation
                iPhonePath = NavigationPath()
                iPhonePath.append(conversation)
            }
        }
    }
}
