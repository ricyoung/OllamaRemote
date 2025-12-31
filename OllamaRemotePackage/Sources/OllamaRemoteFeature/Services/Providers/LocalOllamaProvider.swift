import Foundation

public actor LocalOllamaProvider: LLMProvider {
    public let configuration: AnyProviderConfiguration
    private let httpClient: HTTPClient
    private var currentTask: Task<Void, Never>?

    private var config: LocalOllamaConfig {
        guard case .local(let cfg) = configuration else {
            fatalError("LocalOllamaProvider requires LocalOllamaConfig")
        }
        return cfg
    }

    public init(configuration: LocalOllamaConfig, httpClient: HTTPClient = .shared) {
        self.configuration = .local(configuration)
        self.httpClient = httpClient
    }

    public func testConnection() async throws -> Bool {
        let url = config.baseURL.appendingPathComponent("api/tags")
        let _: OllamaModelsResponse = try await httpClient.get(url: url)
        return true
    }

    public func fetchModels() async throws -> [LLMModel] {
        let url = config.baseURL.appendingPathComponent("api/tags")
        let response: OllamaModelsResponse = try await httpClient.get(url: url)
        return response.models.map { model in
            LLMModel(
                id: model.name,
                name: model.name,
                provider: .localOllama,
                contextLength: nil,
                isFree: true
            )
        }
    }

    public func chat(request: ChatRequest) async throws -> ChatResponse {
        let url = config.baseURL.appendingPathComponent("api/chat")
        let body = OllamaChatRequest(
            model: request.model,
            messages: request.messages,
            stream: false,
            temperature: request.temperature,
            maxTokens: request.maxTokens
        )
        let response: OllamaChatResponse = try await httpClient.post(url: url, body: body)
        return ChatResponse(
            content: response.message.content,
            finishReason: .stop,
            usage: nil
        )
    }

    public func chatStream(request: ChatRequest) -> AsyncThrowingStream<StreamChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = config.baseURL.appendingPathComponent("api/chat")
                    let body = OllamaChatRequest(
                        model: request.model,
                        messages: request.messages,
                        stream: true,
                        temperature: request.temperature,
                        maxTokens: request.maxTokens
                    )

                    for try await data in await httpClient.streamNDJSON(url: url, body: body) {
                        let decoded = try JSONDecoder().decode(OllamaStreamChunk.self, from: data)
                        continuation.yield(StreamChunk(
                            delta: decoded.message.content,
                            isFinished: decoded.done,
                            usage: nil
                        ))
                        if decoded.done {
                            continuation.finish()
                        }
                    }
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
}
