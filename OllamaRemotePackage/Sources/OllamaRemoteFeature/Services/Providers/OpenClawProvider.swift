import Foundation

public actor OpenClawProvider: LLMProvider {
    public let configuration: AnyProviderConfiguration
    private let httpClient: HTTPClient
    private let keychainService: KeychainService
    private var currentTask: Task<Void, Never>?

    private var config: OpenClawConfig {
        get throws {
            guard case .openClaw(let cfg) = configuration else {
                throw ProviderError.invalidConfiguration
            }
            return cfg
        }
    }

    public init(
        configuration: OpenClawConfig,
        httpClient: HTTPClient = .shared,
        keychainService: KeychainService = .shared
    ) {
        self.configuration = .openClaw(configuration)
        self.httpClient = httpClient
        self.keychainService = keychainService
    }

    private func authHeaders() async throws -> [String: String] {
        guard let apiKey = try await keychainService.retrieve(key: try config.apiKeyReference) else {
            throw ProviderError.missingAPIKey
        }

        return [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
    }

    public func testConnection() async throws -> Bool {
        let url = try config.baseURL.appending(path: "models")
        let headers = try await authHeaders()

        do {
            let _: OpenAIModelsResponse = try await httpClient.get(url: url, headers: headers)
            return true
        } catch NetworkError.httpError(let statusCode, _) where statusCode == 401 || statusCode == 403 {
            throw ProviderError.missingAPIKey
        } catch NetworkError.httpError(let statusCode, _) where statusCode == 429 {
            throw ProviderError.rateLimited(retryAfter: nil)
        } catch NetworkError.httpError(let statusCode, _) where statusCode == 404 {
            return true
        }
    }

    public func fetchModels() async throws -> [LLMModel] {
        let url = try config.baseURL.appending(path: "models")
        let headers = try await authHeaders()

        do {
            let response: OpenAIModelsResponse = try await httpClient.get(url: url, headers: headers)
            return response.data.map { model in
                LLMModel(
                    id: model.id,
                    name: model.id,
                    provider: .openClaw,
                    contextLength: nil,
                    isFree: false
                )
            }
        } catch NetworkError.httpError(let statusCode, _) where statusCode == 401 || statusCode == 403 {
            throw ProviderError.missingAPIKey
        } catch NetworkError.httpError(let statusCode, _) where statusCode == 429 {
            throw ProviderError.rateLimited(retryAfter: nil)
        } catch NetworkError.httpError(let statusCode, _) where statusCode == 404 {
            return []
        }
    }

    public func chat(request: ChatRequest) async throws -> ChatResponse {
        let url = try config.baseURL.appending(path: "chat/completions")
        let headers = try await authHeaders()

        let body = OpenAIChatRequest(
            model: request.model,
            messages: request.messages,
            stream: false,
            temperature: request.temperature,
            maxTokens: request.maxTokens
        )

        do {
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
        } catch NetworkError.httpError(let statusCode, _) where statusCode == 401 || statusCode == 403 {
            throw ProviderError.missingAPIKey
        } catch NetworkError.httpError(let statusCode, _) where statusCode == 429 {
            throw ProviderError.rateLimited(retryAfter: nil)
        }
    }

    public func chatStream(request: ChatRequest) -> AsyncThrowingStream<StreamChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = try config.baseURL.appending(path: "chat/completions")
                    let headers = try await authHeaders()

                    let body = OpenAIChatRequest(
                        model: request.model,
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
                            continuation.yield(StreamChunk(delta: delta, isFinished: false, usage: nil))
                        }

                        if chunk.choices.first?.finish_reason != nil {
                            continuation.yield(StreamChunk(delta: "", isFinished: true, usage: nil))
                            continuation.finish()
                        }
                    }
                } catch let error as NetworkError {
                    switch error {
                    case .httpError(let statusCode, _) where statusCode == 401 || statusCode == 403:
                        continuation.finish(throwing: ProviderError.missingAPIKey)
                    case .httpError(let statusCode, _) where statusCode == 429:
                        continuation.finish(throwing: ProviderError.rateLimited(retryAfter: nil))
                    default:
                        continuation.finish(throwing: error)
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
