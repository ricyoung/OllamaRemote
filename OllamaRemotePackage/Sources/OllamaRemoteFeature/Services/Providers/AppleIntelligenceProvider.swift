import Foundation
import FoundationModels

public actor AppleIntelligenceProvider: LLMProvider {
    public let configuration: AnyProviderConfiguration
    private var session: LanguageModelSession?
    private var currentTask: Task<Void, Never>?

    public init(configuration: AppleIntelligenceConfig = AppleIntelligenceConfig()) {
        self.configuration = .appleIntelligence(configuration)
    }

    /// Check if Apple Intelligence is available on this device
    public static var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    /// Get the reason why Apple Intelligence is unavailable
    public static var unavailabilityReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(let reason):
            switch reason {
            case .appleIntelligenceNotEnabled:
                return "Apple Intelligence is not enabled. Enable it in Settings > Apple Intelligence & Siri."
            case .deviceNotEligible:
                return "This device does not support Apple Intelligence."
            case .modelNotReady:
                return "The Apple Intelligence model is still being prepared. Please try again later."
            @unknown default:
                return "Apple Intelligence is unavailable."
            }
        }
    }

    public func testConnection() async throws -> Bool {
        return Self.isAvailable
    }

    public func fetchModels() async throws -> [LLMModel] {
        guard Self.isAvailable else { return [] }

        return [
            LLMModel(
                id: "apple-intelligence",
                name: "Apple Intelligence",
                provider: .appleIntelligence,
                contextLength: 4096,
                isFree: true
            )
        ]
    }

    public func chat(request: ChatRequest) async throws -> ChatResponse {
        var fullContent = ""

        for try await chunk in chatStream(request: request) {
            fullContent += chunk.delta
        }

        return ChatResponse(
            content: fullContent,
            finishReason: .stop,
            usage: nil
        )
    }

    public func chatStream(request: ChatRequest) -> AsyncThrowingStream<StreamChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard Self.isAvailable else {
                        throw AppleIntelligenceError.notAvailable(Self.unavailabilityReason ?? "Unknown reason")
                    }

                    // Create session with system instructions if provided
                    let session: LanguageModelSession
                    if let systemPrompt = request.systemPrompt, !systemPrompt.isEmpty {
                        session = LanguageModelSession {
                            systemPrompt
                        }
                    } else {
                        session = LanguageModelSession()
                    }

                    // Build the prompt from messages
                    let prompt = buildPrompt(from: request.messages)

                    // Stream the response using snapshot-based streaming
                    // Each snapshot contains the full content so far, so we track previous
                    // content to calculate the delta for each chunk
                    let stream = session.streamResponse(to: prompt)
                    var previousContent = ""

                    for try await snapshot in stream {
                        try Task.checkCancellation()

                        let currentContent = snapshot.content

                        // Calculate delta: new characters since last snapshot
                        let delta: String
                        if currentContent.hasPrefix(previousContent) {
                            delta = String(currentContent.dropFirst(previousContent.count))
                        } else {
                            // Content was reset or changed unexpectedly
                            delta = currentContent
                        }

                        if !delta.isEmpty {
                            continuation.yield(StreamChunk(delta: delta, isFinished: false, usage: nil))
                        }

                        previousContent = currentContent
                    }

                    // Send final chunk
                    continuation.yield(StreamChunk(delta: "", isFinished: true, usage: nil))
                    continuation.finish()

                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            currentTask = task

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    public func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Private Methods

    private func buildPrompt(from messages: [ChatRequest.ChatMessage]) -> String {
        // Combine user and assistant messages into a conversation
        var prompt = ""

        for message in messages {
            if message.role == "user" {
                if !prompt.isEmpty {
                    prompt += "\n\n"
                }
                prompt += message.content
            } else if message.role == "assistant" {
                prompt += "\n\nAssistant: \(message.content)"
            }
        }

        return prompt
    }
}

// MARK: - Errors

public enum AppleIntelligenceError: LocalizedError {
    case notAvailable(String)
    case sessionFailed
    case generationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notAvailable(let reason):
            return "Apple Intelligence is not available: \(reason)"
        case .sessionFailed:
            return "Failed to create Apple Intelligence session"
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        }
    }
}
