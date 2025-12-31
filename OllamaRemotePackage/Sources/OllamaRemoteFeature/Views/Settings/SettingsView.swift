import SwiftUI
import SwiftData

public struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var conversations: [Conversation]
    @State private var showClearConfirmation = false

    public init() {}

    public var body: some View {
        @Bindable var state = appState

        List {
            Section("Providers") {
                ForEach(appState.providerConfigurations) { config in
                    NavigationLink {
                        ProviderSettingsView(configuration: config)
                    } label: {
                        HStack {
                            Image(systemName: config.type.iconName)
                                .foregroundStyle(config.isEnabled ? .primary : .secondary)
                            Text(config.displayName)
                            Spacer()
                            if !config.isEnabled {
                                Text("Disabled")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                Toggle("Auto-Save Conversations", isOn: Binding(
                    get: { appState.autoSaveChats },
                    set: { appState.setAutoSaveChats($0) }
                ))
            } header: {
                Text("Chat History")
            } footer: {
                Text("When disabled, conversations will not be saved after you close the app.")
            }

            Section {
                HStack {
                    Text("Text Size")
                    Spacer()
                    HStack(spacing: 0) {
                        ForEach(-2...2, id: \.self) { offset in
                            Button {
                                appState.setFontSizeOffset(offset)
                            } label: {
                                Text(offsetLabel(offset))
                                    .font(.system(size: 14, weight: offset == appState.fontSizeOffset ? .bold : .regular))
                                    .frame(width: 44, height: 36)
                                    .background(offset == appState.fontSizeOffset ? Color.accentColor : Color.clear)
                                    .foregroundStyle(offset == appState.fontSizeOffset ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } header: {
                Text("Display")
            } footer: {
                Text("Adjusts the size of chat message text.")
            }

            Section {
                Toggle("Haptic Feedback", isOn: Binding(
                    get: { appState.hapticsEnabled },
                    set: { appState.setHapticsEnabled($0) }
                ))
            } header: {
                Text("Feedback")
            } footer: {
                Text("Provides tactile feedback for actions like sending messages and copying text.")
            }

            Section {
                Button(role: .destructive) {
                    showClearConfirmation = true
                } label: {
                    HStack {
                        Text("Clear All Conversations")
                        Spacer()
                        Text("\(conversations.count)")
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(conversations.isEmpty)
            }

            Section("On-Device") {
                NavigationLink {
                    LocalModelsView()
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(.tint)
                        Text("Download Local Models")
                        Spacer()
                        Text("\(LocalModelManager.shared.downloadedModels.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.3.3")
                        .foregroundStyle(.secondary)
                }

                Link(destination: URL(string: "https://github.com/ricyoung/OllamaRemote")!) {
                    HStack {
                        Text("Source Code")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }

                Link(destination: URL(string: "https://deepknow.ai/richard")!) {
                    HStack {
                        Text("Developed by Richard Young")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog(
            "Clear All Conversations",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) {
                clearAllConversations()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all \(conversations.count) conversations. This action cannot be undone.")
        }
    }

    private func clearAllConversations() {
        appState.selectedConversation = nil
        for conversation in conversations {
            modelContext.delete(conversation)
        }
    }

    private func offsetLabel(_ offset: Int) -> String {
        switch offset {
        case -2: return "A⁻²"
        case -1: return "A⁻¹"
        case 0: return "A"
        case 1: return "A⁺¹"
        case 2: return "A⁺²"
        default: return "A"
        }
    }
}
