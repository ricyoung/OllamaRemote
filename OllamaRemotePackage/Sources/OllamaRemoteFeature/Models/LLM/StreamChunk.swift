import Foundation

public struct StreamChunk: Sendable {
    public let delta: String
    public let isFinished: Bool
    public let usage: TokenUsage?

    public struct TokenUsage: Sendable {
        public let promptTokens: Int
        public let completionTokens: Int
        public let totalTokens: Int

        public init(promptTokens: Int, completionTokens: Int, totalTokens: Int) {
            self.promptTokens = promptTokens
            self.completionTokens = completionTokens
            self.totalTokens = totalTokens
        }
    }

    public init(
        delta: String,
        isFinished: Bool,
        usage: TokenUsage? = nil
    ) {
        self.delta = delta
        self.isFinished = isFinished
        self.usage = usage
    }
}
