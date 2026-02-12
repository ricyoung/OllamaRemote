import SwiftUI

public struct InspectorView: View {
    let conversation: Conversation
    @Environment(AppState.self) private var appState

    public init(conversation: Conversation) {
        self.conversation = conversation
    }

    public var body: some View {
        List {
            Section("Conversation") {
                LabeledContent("Title", value: conversation.title)
                LabeledContent("Messages", value: "\(conversation.messages.count)")
                LabeledContent("Created", value: conversation.createdAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Updated", value: conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }

            Section("Provider") {
                HStack {
                    Image(systemName: conversation.providerType.iconName)
                        .foregroundStyle(providerColor)
                    Text(conversation.providerType.displayName)
                }

                if let model = appState.selectedModelId {
                    LabeledContent("Model", value: model)
                }

                if let provider = appState.activeProvider {
                    if provider.type == .appleIntelligence {
                        LabeledContent("Endpoint", value: "Apple Intelligence")
                    } else if provider.type == .localOllama {
                        LabeledContent("Endpoint", value: "Local")
                    } else if provider.type == .openRouter {
                        LabeledContent("Endpoint", value: "OpenRouter API")
                    } else if provider.type == .openClaw {
                        LabeledContent("Endpoint", value: "OpenClaw API")
                    } else if provider.type == .ollamaCloud {
                        LabeledContent("Endpoint", value: "Ollama Cloud")
                    } else if provider.type == .onDevice {
                        LabeledContent("Endpoint", value: "Neural Engine")
                    }
                }
            }

            Section("Statistics") {
                let wordCount = conversation.messages.reduce(0) { $0 + $1.content.split(separator: " ").count }
                let charCount = conversation.messages.reduce(0) { $0 + $1.content.count }
                let userMessages = conversation.messages.filter { $0.role == .user }.count
                let assistantMessages = conversation.messages.filter { $0.role == .assistant }.count

                LabeledContent("User Messages", value: "\(userMessages)")
                LabeledContent("Assistant Messages", value: "\(assistantMessages)")
                LabeledContent("Total Words", value: "\(wordCount)")
                LabeledContent("Total Characters", value: "\(charCount)")
            }

            if !conversation.messages.isEmpty {
                Section("Models Used") {
                    let modelsUsed = Set(conversation.messages.compactMap { $0.modelUsed })
                    if modelsUsed.isEmpty {
                        Text("No model info")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(modelsUsed).sorted(), id: \.self) { model in
                            HStack {
                                Image(systemName: "cube.fill")
                                    .foregroundStyle(.tint)
                                Text(model)
                                    .font(.footnote)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var providerColor: Color {
        switch conversation.providerType {
        case .appleIntelligence: return .indigo
        case .onDevice: return .purple
        case .localOllama: return .blue
        case .ollamaCloud: return .cyan
        case .openRouter: return .orange
        case .openClaw: return .mint
        }
    }
}
