import Foundation
import CoreML

public actor OnDeviceProvider: LLMProvider {
    public let configuration: AnyProviderConfiguration

    private var loadedModel: MLModel?
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

                    let prompt = request.messages.last?.content ?? ""

                    if localModel.format == .coreML {
                        try await self.runCoreMLInference(
                            model: localModel,
                            prompt: prompt,
                            continuation: continuation
                        )
                    } else {
                        throw OnDeviceError.formatNotSupported("GGUF requires llama.cpp integration")
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            currentTask = task
        }
    }

    private func runCoreMLInference(
        model: LocalModel,
        prompt: String,
        continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation
    ) async throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelPath = documentsPath.appendingPathComponent("Models").appendingPathComponent(model.filename)

        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw OnDeviceError.modelNotDownloaded(model.displayName)
        }

        // Load model if not already loaded
        if loadedModelId != model.id {
            let config = MLModelConfiguration()
            config.computeUnits = .all // Use Neural Engine + GPU + CPU as needed

            // For .mlpackage, we need to compile it first
            let compiledURL = try await MLModel.compileModel(at: modelPath)
            loadedModel = try MLModel(contentsOf: compiledURL, configuration: config)
            loadedModelId = model.id
        }

        guard loadedModel != nil else {
            throw OnDeviceError.modelLoadFailed
        }

        // Placeholder response - real implementation needs tokenizer integration
        let response = "I'm running on-device using Core ML and the Neural Engine! Model: \(model.displayName). Your prompt was: \"\(prompt)\". Full inference requires tokenizer integration."

        // Stream the response word by word
        let words = response.split(separator: " ")
        for (index, word) in words.enumerated() {
            let isLast = index == words.count - 1
            let chunk = StreamChunk(
                delta: String(word) + " ",
                isFinished: isLast,
                usage: isLast ? StreamChunk.TokenUsage(
                    promptTokens: 10,
                    completionTokens: words.count,
                    totalTokens: 10 + words.count
                ) : nil
            )
            continuation.yield(chunk)
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
        }

        continuation.finish()
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
