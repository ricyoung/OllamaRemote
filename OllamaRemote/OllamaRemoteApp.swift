import SwiftUI
import SwiftData
import OllamaRemoteFeature

@main
struct OllamaRemoteApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Conversation.self, Message.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                clearConversationsIfNeeded()
            }
        }
    }

    private func clearConversationsIfNeeded() {
        let autoSave = SettingsStore.shared.loadAutoSaveChats()
        guard !autoSave else { return }

        let context = sharedModelContainer.mainContext
        do {
            let conversations = try context.fetch(FetchDescriptor<Conversation>())
            for conversation in conversations {
                context.delete(conversation)
            }
            try context.save()
        } catch {
            print("Failed to clear conversations: \(error)")
        }
    }
}
