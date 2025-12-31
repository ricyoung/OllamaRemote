import Foundation

public actor OllamaCloudProvider: LLMProvider {
    public let configuration: AnyProviderConfiguration
    private let httpClient: HTTPClient
    private let keychainService: KeychainService
    private var currentTask: Task<Void, Never>?

    private var config: OllamaCloudConfig {
        guard case .cloud(let cfg) = configuration else {
            fatalError("OllamaCloudProvider requires OllamaCloudConfig")
        }
        return cfg
    }

    public init(
        configuration: OllamaCloudConfig,
        httpClient: HTTPClient = .shared,
        keychainService: KeychainService = .shared
    ) {
        self.configuration = .cloud(configuration)
        self.httpClient = httpClient
        self.keychainService = keychainService
    }

    private func authHeaders() async throws -> [String: String] {
        guard let apiKey = try await keychainService.retrieve(key: config.apiKeyReference) else {
            throw ProviderError.missingAPIKey
        }
        return ["Authorization": "Bearer \(apiKey)"]
    }

    public func testConnection() async throws -> Bool {
        let url = config.baseURL.appendingPathComponent("api/tags")
        let headers = try await authHeaders()
        let _: OllamaModelsResponse = try await httpClient.get(url: url, headers: headers)
        return true
    }

    public func fetchModels() async throws -> [LLMModel] {
        let url = config.baseURL.appendingPathComponent("api/tags")
        let headers = try await authHeaders()
        let response: OllamaModelsResponse = try await httpClient.get(url: url, headers: headers)
        return response.models.map { model in
            LLMModel(
                id: model.name,
                name: model.name,
                provider: .ollamaCloud,
                contextLength: nil,
                isFree: false
            )
        }
    }

    public func chat(request: ChatRequest) async throws -> ChatResponse {
        let url = config.baseURL.appendingPathComponent("api/chat")
        let headers = try await authHeaders()
        let body = OllamaChatRequest(
            model: request.model,
            messages: request.messages,
            stream: false,
            temperature: request.temperature,
            maxTokens: request.maxTokens
        )
        let response: OllamaChatResponse = try await httpClient.post(url: url, body: body, headers: headers)
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
                    let headers = try await authHeaders()
                    let body = OllamaChatRequest(
                        model: request.model,
                        messages: request.messages,
                        stream: true,
                        temperature: request.temperature,
                        maxTokens: request.maxTokens
                    )

                    for try await data in await httpClient.streamNDJSON(url: url, body: body, headers: headers) {
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
