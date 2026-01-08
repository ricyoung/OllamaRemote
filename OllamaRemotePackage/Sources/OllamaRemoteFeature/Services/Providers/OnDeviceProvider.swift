import Foundation
import MLXLLM
import MLXLMCommon
import MLX

public actor OnDeviceProvider: LLMProvider {
    public let configuration: AnyProviderConfiguration

    private var loadedModelContainer: ModelContainer?
    private var loadedModelId: String?
    private var currentTask: Task<Void, Never>?

    public init(configuration: AnyProviderConfiguration = .onDevice(OnDeviceConfig())) {
        self.configuration = configuration
    }

    public func testConnection() async throws -> Bool {
        let hasModels = await MainActor.run {
            !LocalModelManager.shared.downloadedModels.isEmpty
        }
        return hasModels
    }

    public func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
    }

    public func fetchModels() async throws -> [LLMModel] {
        let downloadedIds = await MainActor.run {
            LocalModelManager.shared.downloadedModels
        }

        return LocalModel.availableModels
            .filter { downloadedIds.contains($0.id) }
            .map { model in
                LLMModel(
                    id: model.id,
                    name: model.displayName,
                    provider: .onDevice,
                    contextLength: 2048,
                    isFree: true
                )
            }
    }

    public func chat(request: ChatRequest) async throws -> ChatResponse {
        var fullContent = ""
        var usage: StreamChunk.TokenUsage?

        for try await chunk in chatStream(request: request) {
            fullContent += chunk.delta
            if chunk.isFinished {
                usage = chunk.usage
            }
        }

        return ChatResponse(
            content: fullContent,
            finishReason: .stop,
            usage: usage
        )
    }

    public func chatStream(request: ChatRequest) -> AsyncThrowingStream<StreamChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let localModel = LocalModel.availableModels.first(where: { $0.id == request.model }) else {
                        throw OnDeviceError.modelNotFound(request.model)
                    }

                    guard localModel.format == .mlx else {
                        throw OnDeviceError.formatNotSupported("Only MLX format is supported")
                    }

                    guard let huggingFaceId = localModel.huggingFaceId else {
                        throw OnDeviceError.modelNotFound("Missing HuggingFace ID for \(localModel.displayName)")
                    }

                    try await self.runMLXInference(
                        huggingFaceId: huggingFaceId,
                        modelId: localModel.id,
                        request: request,
                        continuation: continuation
                    )
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

    private func runMLXInference(
        huggingFaceId: String,
        modelId: String,
        request: ChatRequest,
        continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation
    ) async throws {
        // Load model if not already loaded or if different model
        if loadedModelId != modelId || loadedModelContainer == nil {
            // Clear previous model
            loadedModelContainer = nil
            loadedModelId = nil

            // Load new model from HuggingFace using the simplified API
            loadedModelContainer = try await loadModelContainer(id: huggingFaceId)
            loadedModelId = modelId
        }

        guard let modelContainer = loadedModelContainer else {
            throw OnDeviceError.modelLoadFailed
        }

        // Build prompt from messages
        let prompt = buildPrompt(from: request.messages)

        // Create a ChatSession with the model
        let generateParams = GenerateParameters(
            maxTokens: request.maxTokens ?? 512,
            temperature: Float(request.temperature ?? 0.7),
            topP: 0.9
        )

        let session = ChatSession(
            modelContainer,
            instructions: request.systemPrompt,
            generateParameters: generateParams
        )

        var tokenCount = 0

        // Stream the response
        for try await text in session.streamResponse(to: prompt) {
            try Task.checkCancellation()

            tokenCount += 1
            let chunk = StreamChunk(
                delta: text,
                isFinished: false,
                usage: nil
            )
            continuation.yield(chunk)
        }

        // Send final chunk with usage info
        let finalChunk = StreamChunk(
            delta: "",
            isFinished: true,
            usage: StreamChunk.TokenUsage(
                promptTokens: 0, // We don't track prompt tokens in this API
                completionTokens: tokenCount,
                totalTokens: tokenCount
            )
        )
        continuation.yield(finalChunk)
        continuation.finish()
    }

    private func buildPrompt(from messages: [ChatRequest.ChatMessage]) -> String {
        // Get the last user message for the chat
        messages.last(where: { $0.role == "user" })?.content ?? ""
    }
}

public enum OnDeviceError: LocalizedError {
    case modelNotFound(String)
    case modelNotDownloaded(String)
    case modelLoadFailed
    case formatNotSupported(String)
    case inferenceError(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let name):
            return "Model not found: \(name)"
        case .modelNotDownloaded(let name):
            return "Model not downloaded: \(name). Please download it first."
        case .modelLoadFailed:
            return "Failed to load the model"
        case .formatNotSupported(let reason):
            return "Format not supported: \(reason)"
        case .inferenceError(let reason):
            return "Inference error: \(reason)"
        }
    }
}
