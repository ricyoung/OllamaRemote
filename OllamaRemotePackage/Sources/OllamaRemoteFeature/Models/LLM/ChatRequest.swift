import Foundation

public struct ChatRequest: Sendable {
    public let model: String
    public let messages: [ChatMessage]
    public let stream: Bool
    public let temperature: Double?
    public let maxTokens: Int?
    public let systemPrompt: String?

    public struct ChatMessage: Codable, Sendable {
        public let role: String
        public let content: String

        public init(role: String, content: String) {
            self.role = role
            self.content = content
        }
    }

    public init(
        model: String,
        messages: [ChatMessage],
        stream: Bool = true,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        systemPrompt: String? = nil
    ) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.systemPrompt = systemPrompt
    }
}
