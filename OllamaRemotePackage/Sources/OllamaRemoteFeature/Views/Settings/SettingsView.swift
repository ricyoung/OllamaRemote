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
            Section {
                NavigationLink {
                    StatsView()
                } label: {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .font(.title2)
                            .foregroundStyle(.orange.gradient)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your Stats")
                                .font(.headline)
                            Text("\(StatsService.shared.currentStreak) day streak")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                    }
                    .padding(.vertical, 4)
                }
            }

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

                HStack {
                    Text("Auto-Delete After")
                    Spacer()
                    Menu {
                        Button("Never") { appState.setAutoDeleteDays(0) }
                        Button("7 Days") { appState.setAutoDeleteDays(7) }
                        Button("14 Days") { appState.setAutoDeleteDays(14) }
                        Button("30 Days") { appState.setAutoDeleteDays(30) }
                        Button("60 Days") { appState.setAutoDeleteDays(60) }
                        Button("90 Days") { appState.setAutoDeleteDays(90) }
                    } label: {
                        HStack(spacing: 4) {
                            Text(autoDeleteLabel)
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Chat History")
            } footer: {
                Text(autoDeleteFooter)
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

                Toggle("Show Follow-Up Questions", isOn: Binding(
                    get: { appState.showFollowUpQuestions },
                    set: { appState.setShowFollowUpQuestions($0) }
                ))
            } header: {
                Text("Feedback")
            } footer: {
                Text("Haptics provide tactile feedback. Follow-up questions suggest related queries after each response.")
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
                    Text("1.4.0")
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

                Link(destination: URL(string: "https://deepneuro.ai/richard")!) {
                    HStack {
                        Text("Developed by Richard Young")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                acknowledgementLink(
                    name: "Ollama",
                    description: "Local LLM inference engine",
                    url: "https://ollama.com"
                )

                acknowledgementLink(
                    name: "OpenRouter",
                    description: "Unified API for LLMs",
                    url: "https://openrouter.ai"
                )

                acknowledgementLink(
                    name: "MarkdownView",
                    description: "Markdown rendering for SwiftUI",
                    url: "https://github.com/LiYanan2004/MarkdownView"
                )

                acknowledgementLink(
                    name: "Highlightr",
                    description: "Code syntax highlighting",
                    url: "https://github.com/raspu/Highlightr"
                )

                acknowledgementLink(
                    name: "swift-markdown",
                    description: "Apple's Markdown parser",
                    url: "https://github.com/apple/swift-markdown"
                )
            } header: {
                Text("Acknowledgements")
            } footer: {
                Text("OllamaRemote is built with amazing open source software. Thank you to all contributors!")
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

    private var autoDeleteLabel: String {
        switch appState.autoDeleteDays {
        case 0: return "Never"
        case 1: return "1 Day"
        default: return "\(appState.autoDeleteDays) Days"
        }
    }

    private var autoDeleteFooter: String {
        if appState.autoDeleteDays == 0 {
            return "Conversations will be kept indefinitely."
        } else {
            return "Conversations older than \(appState.autoDeleteDays) days will be automatically deleted."
        }
    }

    @ViewBuilder
    private func acknowledgementLink(name: String, description: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
