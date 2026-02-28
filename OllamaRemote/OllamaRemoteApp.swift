import SwiftUI
import SwiftData
import OllamaRemoteFeature

@main
struct OllamaRemoteApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let sharedModelContainer: ModelContainer? = {
        let schema = Schema([Conversation.self, Message.self])
        let persistentConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [persistentConfiguration])
        } catch {
            print("Failed to create persistent model container: \(error)")
        }

        // Fallback to in-memory storage to avoid hard-crashing on launch.
        let inMemoryConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        do {
            return try ModelContainer(for: schema, configurations: [inMemoryConfiguration])
        } catch {
            print("Failed to create in-memory model container fallback: \(error)")
            return nil
        }
    }()

    var body: some Scene {
        WindowGroup {
            if let sharedModelContainer {
                ContentView()
                    .modelContainer(sharedModelContainer)
            } else {
                StorageRecoveryView()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                clearConversationsIfNeeded()
            }
        }
    }

    private func clearConversationsIfNeeded() {
        guard let sharedModelContainer else {
            return
        }

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

private struct StorageRecoveryView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Storage Initialization Failed")
                .font(.headline)
            Text("Ollama Remote couldn't open local storage. Restart the app. If this keeps happening, reinstall the app.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
        }
        .padding()
    }
}
