import Foundation

public struct ChatResponse: Sendable {
    public let content: String
    public let finishReason: FinishReason?
    public let usage: StreamChunk.TokenUsage?

    public enum FinishReason: String, Sendable {
        case stop
        case length
        case error
    }

    public init(
        content: String,
        finishReason: FinishReason? = nil,
        usage: StreamChunk.TokenUsage? = nil
    ) {
        self.content = content
        self.finishReason = finishReason
        self.usage = usage
    }
}
