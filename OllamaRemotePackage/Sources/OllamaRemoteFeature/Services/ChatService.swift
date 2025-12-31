import Foundation
import SwiftData

@Observable
@MainActor
public final class ChatService {
    public private(set) var isStreaming = false
    public private(set) var error: Error?

    private let providerFactory: ProviderFactory
    private var currentStreamTask: Task<Void, Never>?

    public init(providerFactory: ProviderFactory = .shared) {
        self.providerFactory = providerFactory
    }

    public func sendMessage(
        content: String,
        in conversation: Conversation,
        using configuration: AnyProviderConfiguration,
        model: String,
        onChunk: @escaping (String) -> Void
    ) async {
        isStreaming = true
        error = nil

        let userMessage = Message(content: content, role: .user, conversation: conversation)
        conversation.messages.append(userMessage)
        conversation.updatedAt = Date()

        let assistantMessage = Message(content: "", role: .assistant, conversation: conversation)
        assistantMessage.isStreaming = true
        assistantMessage.modelUsed = model
        conversation.messages.append(assistantMessage)

        let provider = providerFactory.provider(for: configuration)

        let chatMessages = conversation.sortedMessages
            .filter { $0.id != assistantMessage.id }
            .map { ChatRequest.ChatMessage(role: $0.role.rawValue, content: $0.content) }

        let request = ChatRequest(
            model: model,
            messages: chatMessages,
            stream: true,
            temperature: nil,
            maxTokens: nil,
            systemPrompt: nil
        )

        currentStreamTask = Task {
            do {
                var fullContent = ""
                for try await chunk in await provider.chatStream(request: request) {
                    fullContent += chunk.delta
                    assistantMessage.content = fullContent
                    onChunk(chunk.delta)

                    if chunk.isFinished {
                        if let usage = chunk.usage {
                            assistantMessage.tokenCount = usage.completionTokens
                        }
                    }
                }
                assistantMessage.isStreaming = false
            } catch {
                assistantMessage.isStreaming = false
                if !Task.isCancelled {
                    assistantMessage.content = "Error: \(error.localizedDescription)"
                    self.error = error
                }
            }

            isStreaming = false
        }
    }

    public func cancelStream() {
        currentStreamTask?.cancel()
        currentStreamTask = nil
        isStreaming = false
    }
}
