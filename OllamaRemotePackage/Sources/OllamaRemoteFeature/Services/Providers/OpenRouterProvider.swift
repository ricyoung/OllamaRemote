import Foundation

public actor OpenRouterProvider: LLMProvider {
    public let configuration: AnyProviderConfiguration
    private let httpClient: HTTPClient
    private let keychainService: KeychainService
    private var currentTask: Task<Void, Never>?

    private var config: OpenRouterConfig {
        guard case .openRouter(let cfg) = configuration else {
            fatalError("OpenRouterProvider requires OpenRouterConfig")
        }
        return cfg
    }

    public init(
        configuration: OpenRouterConfig,
        httpClient: HTTPClient = .shared,
        keychainService: KeychainService = .shared
    ) {
        self.configuration = .openRouter(configuration)
        self.httpClient = httpClient
        self.keychainService = keychainService
    }

    private func authHeaders() async throws -> [String: String] {
        guard let apiKey = try await keychainService.retrieve(key: config.apiKeyReference) else {
            throw ProviderError.missingAPIKey
        }
        var headers = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
        if let siteURL = config.siteURL {
            headers["HTTP-Referer"] = siteURL
        }
        if let siteName = config.siteName {
            headers["X-Title"] = siteName
        }
        return headers
    }

    public func testConnection() async throws -> Bool {
        let url = config.baseURL.appendingPathComponent("models")
        let headers = try await authHeaders()
        let _: OpenRouterModelsResponse = try await httpClient.get(url: url, headers: headers)
        return true
    }

    public func fetchModels() async throws -> [LLMModel] {
        let url = config.baseURL.appendingPathComponent("models")
        let headers = try await authHeaders()
        let response: OpenRouterModelsResponse = try await httpClient.get(url: url, headers: headers)
        return response.data.map { model in
            LLMModel(
                id: model.id,
                name: model.name ?? model.id,
                provider: .openRouter,
                contextLength: model.context_length,
                isFree: model.id.hasSuffix(":free")
            )
        }
    }

    public func chat(request: ChatRequest) async throws -> ChatResponse {
        let url = config.baseURL.appendingPathComponent("chat/completions")
        let headers = try await authHeaders()

        var modelId = request.model
        if config.preferFreeModels && !modelId.hasSuffix(":free") {
            modelId += ":free"
        }

        let body = OpenAIChatRequest(
            model: modelId,
            messages: request.messages,
            stream: false,
            temperature: request.temperature,
            maxTokens: request.maxTokens
        )

        let response: OpenAIChatResponse = try await httpClient.post(url: url, body: body, headers: headers)
        let content = response.choices.first?.message.content ?? ""
        let usage = response.usage.map {
            StreamChunk.TokenUsage(
                promptTokens: $0.prompt_tokens,
                completionTokens: $0.completion_tokens,
                totalTokens: $0.total_tokens
            )
        }

        return ChatResponse(content: content, finishReason: .stop, usage: usage)
    }

    public func chatStream(request: ChatRequest) -> AsyncThrowingStream<StreamChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = config.baseURL.appendingPathComponent("chat/completions")
                    let headers = try await authHeaders()

                    var modelId = request.model
                    if config.preferFreeModels && !modelId.hasSuffix(":free") {
                        modelId += ":free"
                    }

                    let body = OpenAIChatRequest(
                        model: modelId,
                        messages: request.messages,
                        stream: true,
                        temperature: request.temperature,
                        maxTokens: request.maxTokens
                    )

                    for try await line in await httpClient.streamSSE(url: url, body: body, headers: headers) {
                        guard line.hasPrefix("data: ") else { continue }

                        let jsonString = String(line.dropFirst(6))
                        if jsonString == "[DONE]" {
                            continuation.yield(StreamChunk(delta: "", isFinished: true, usage: nil))
                            continuation.finish()
                            break
                        }

                        guard let data = jsonString.data(using: .utf8) else { continue }
                        let chunk = try JSONDecoder().decode(OpenAIStreamChunk.self, from: data)

                        if let delta = chunk.choices.first?.delta.content {
                            continuation.yield(StreamChunk(
                                delta: delta,
                                isFinished: false,
                                usage: nil
                            ))
                        }

                        if chunk.choices.first?.finish_reason != nil {
                            continuation.yield(StreamChunk(delta: "", isFinished: true, usage: nil))
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
