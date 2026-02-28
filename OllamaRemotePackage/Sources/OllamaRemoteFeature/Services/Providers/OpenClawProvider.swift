import Foundation

public enum OpenClawTransportMode: String, Sendable {
    case unknown = "Unknown"
    case http = "HTTP"
    case websocketFallback = "WebSocket Fallback"
    case websocketDirect = "WebSocket Direct"
}

public struct OpenClawDiagnosticsSnapshot: Sendable {
    public let resolvedHTTPBaseURL: String
    public let resolvedGatewayWebSocketURL: String
    public let configuredMode: String
    public let lastActiveMode: OpenClawTransportMode
    public let lastTransportDetail: String?
}

public struct OpenClawGatewayProbeResult: Sendable {
    public let sessionKey: String
    public let responseText: String
}

public actor OpenClawProvider: LLMProvider {
    public let configuration: AnyProviderConfiguration
    private let httpClient: HTTPClient
    private let keychainService: KeychainService
    private let diagnosticsStore: DiagnosticsStore
    private var currentTask: Task<Void, Never>?
    private var lastActiveMode: OpenClawTransportMode = .unknown
    private var lastTransportDetail: String?
    private let httpStreamRequestTimeout: TimeInterval = 20
    private let httpStreamMaxAttempts = 2
    private let httpStreamRetryDelayNanoseconds: UInt64 = 500_000_000

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
        keychainService: KeychainService = .shared,
        diagnosticsStore: DiagnosticsStore = .shared
    ) {
        self.configuration = .openClaw(configuration)
        self.httpClient = httpClient
        self.keychainService = keychainService
        self.diagnosticsStore = diagnosticsStore
    }

    private func apiKey() async throws -> String {
        guard let key = try await keychainService.retrieve(key: try config.apiKeyReference) else {
            throw ProviderError.missingAPIKey
        }
        return key
    }

    private func authHeaders() async throws -> [String: String] {
        let key = try await apiKey()
        return [
            "Authorization": "Bearer \(key)",
            "Content-Type": "application/json"
        ]
    }

    private var usesGatewayRPCDirectly: Bool {
        guard let cfg = try? config else { return false }
        let host = cfg.host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return host.hasPrefix("ws://") || host.hasPrefix("wss://")
    }

    private func shouldAttemptGatewayFallback(for error: Error) -> Bool {
        if let net = error as? NetworkError {
            switch net {
            case .httpError(let statusCode, _):
                return statusCode == 404 || statusCode == 405
            case .invalidResponse, .decodingError, .connectionFailed:
                return true
            default:
                return false
            }
        }

        if error is DecodingError {
            return true
        }

        if case ProviderError.serverError(let message) = error {
            let lowered = message.lowercased()
            return lowered.contains("http streaming")
                || lowered.contains("chat endpoint is unavailable")
        }

        return false
    }

    public func diagnosticsSnapshot() -> OpenClawDiagnosticsSnapshot {
        let resolvedHTTPBaseURL = (try? config.baseURL.absoluteString) ?? "Invalid configuration"
        let resolvedGatewayWebSocketURL = (try? config.gatewayWebSocketURL().absoluteString) ?? "Invalid configuration"
        let configuredMode = usesGatewayRPCDirectly
            ? OpenClawTransportMode.websocketDirect.rawValue
            : "HTTP Primary + WebSocket Fallback"

        return OpenClawDiagnosticsSnapshot(
            resolvedHTTPBaseURL: resolvedHTTPBaseURL,
            resolvedGatewayWebSocketURL: resolvedGatewayWebSocketURL,
            configuredMode: configuredMode,
            lastActiveMode: lastActiveMode,
            lastTransportDetail: lastTransportDetail
        )
    }

    public func probeGateway(message: String = "ping") async throws -> OpenClawGatewayProbeResult {
        let probeText = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !probeText.isEmpty else {
            throw ProviderError.serverError(message: "Probe message cannot be empty")
        }

        let sessionKey = "main"
        await logDiagnostics(
            level: .info,
            message: "Starting gateway probe",
            metadata: ["sessionKey": sessionKey]
        )

        do {
            let finalResponse = try await withGatewayConnection { socket in
                try await gatewayConnect(socket)

                let sendRequestID = UUID().uuidString
                let sendParams = JSONValue.object([
                    "sessionKey": .string(sessionKey),
                    "message": .string(probeText),
                    "deliver": .bool(false),
                    "idempotencyKey": .string(UUID().uuidString)
                ])
                try await socket.send(
                    GatewayRequestEnvelope(
                        id: sendRequestID,
                        method: "chat.send",
                        params: sendParams
                    )
                )

                var runID: String?

                while true {
                    try Task.checkCancellation()
                    let envelope = try await socket.receive()

                    if envelope.type == "res", envelope.id == sendRequestID {
                        if envelope.ok == true {
                            runID = envelope.payload?.objectValue?["runId"]?.stringValue
                            continue
                        }

                        throw ProviderError.serverError(
                            message: gatewayErrorMessage(envelope.error, fallback: "chat.send failed")
                        )
                    }

                    guard envelope.type == "event", envelope.event == "chat" else { continue }
                    guard let payload = envelope.payload?.objectValue else { continue }
                    guard payload["sessionKey"]?.stringValue == sessionKey else { continue }

                    if let eventRunID = payload["runId"]?.stringValue,
                       let runID,
                       !runID.isEmpty,
                       !eventRunID.isEmpty,
                       runID != eventRunID {
                        continue
                    }

                    let state = payload["state"]?.stringValue ?? ""
                    switch state {
                    case "final":
                        return extractGatewayMessageText(payload["message"]) ?? ""
                    case "aborted":
                        throw ProviderError.cancelled
                    case "error":
                        let errorCode = payload["errorCode"]?.stringValue
                        let errorMessage = payload["errorMessage"]?.stringValue
                            ?? extractGatewayMessageText(payload["message"])
                            ?? "chat error"
                        if let errorCode {
                            throw ProviderError.serverError(message: "[\(errorCode)] \(errorMessage)")
                        }
                        throw ProviderError.serverError(message: errorMessage)
                    default:
                        continue
                    }
                }
            }

            updateActiveMode(
                usesGatewayRPCDirectly ? .websocketDirect : .websocketFallback,
                detail: "Gateway probe succeeded"
            )
            await logDiagnostics(
                level: .info,
                message: "Gateway probe succeeded",
                metadata: ["responseLength": "\(finalResponse.count)"]
            )
            return OpenClawGatewayProbeResult(sessionKey: sessionKey, responseText: finalResponse)
        } catch {
            updateActiveMode(.unknown, detail: "Gateway probe failed: \(errorSummary(error))")
            await logDiagnostics(
                level: .error,
                message: "Gateway probe failed",
                metadata: ["error": errorSummary(error)]
            )
            throw error
        }
    }

    private func updateActiveMode(_ mode: OpenClawTransportMode, detail: String? = nil) {
        lastActiveMode = mode
        if let detail {
            lastTransportDetail = detail
        }
    }

    private func logDiagnostics(
        level: DiagnosticsLevel,
        message: String,
        metadata: [String: String] = [:]
    ) async {
        var fullMetadata = metadata
        fullMetadata["providerId"] = configuration.id.uuidString
        await diagnosticsStore.record(
            category: "OpenClaw",
            level: level,
            message: message,
            metadata: fullMetadata
        )
    }

    private func errorSummary(_ error: Error) -> String {
        if let net = error as? NetworkError {
            switch net {
            case .httpError(let statusCode, let message):
                return message.map { "HTTP \(statusCode): \($0)" } ?? "HTTP \(statusCode)"
            default:
                return net.localizedDescription
            }
        }
        return error.localizedDescription
    }

    private func shouldRetryHTTPStream(after error: Error) -> Bool {
        if let net = error as? NetworkError {
            switch net {
            case .invalidResponse, .connectionFailed, .decodingError:
                return true
            case .httpError(let statusCode, _):
                return statusCode == 408 || statusCode == 429 || (500...599).contains(statusCode)
            default:
                return false
            }
        }
        return error is DecodingError
    }

    private func fallbackFailure(context: String, primary: Error, fallback: Error) -> ProviderError {
        ProviderError.serverError(
            message: "HTTP \(context) failed (\(errorSummary(primary))). Attempted gateway WebSocket fallback, but it also failed (\(errorSummary(fallback)))."
        )
    }

    public func testConnection() async throws -> Bool {
        if usesGatewayRPCDirectly {
            try await testGatewayConnection()
            updateActiveMode(.websocketDirect, detail: "Gateway-only connection test succeeded")
            await logDiagnostics(level: .info, message: "Connection test succeeded via gateway WebSocket")
            return true
        }

        let headers = try await authHeaders()
        let modelsURL = try config.baseURL.appending(path: "models")

        do {
            let _: OpenAIModelsResponse = try await httpClient.get(url: modelsURL, headers: headers)
            updateActiveMode(.http, detail: "HTTP /models succeeded")
            await logDiagnostics(level: .info, message: "Connection test succeeded via HTTP /models")
            return true
        } catch NetworkError.httpError(let statusCode, _) where statusCode == 401 || statusCode == 403 {
            throw ProviderError.missingAPIKey
        } catch NetworkError.httpError(let statusCode, _) where statusCode == 429 {
            throw ProviderError.rateLimited(retryAfter: nil)
        } catch NetworkError.httpError(let statusCode, _) where statusCode == 404 {
            // `/v1/models` may be unavailable on OpenClaw; probe chat completions directly.
            let chatURL = try config.baseURL.appending(path: "chat/completions")
            let probeBody = OpenAIChatRequest(
                model: "openclaw:main",
                messages: [ChatRequest.ChatMessage(role: "user", content: "connection test")],
                stream: false,
                temperature: nil,
                maxTokens: 1
            )

            do {
                let _: OpenAIChatResponse = try await httpClient.post(
                    url: chatURL,
                    body: probeBody,
                    headers: headers
                )
                updateActiveMode(.http, detail: "HTTP /chat/completions probe succeeded")
                await logDiagnostics(level: .info, message: "Connection test succeeded via HTTP chat/completions probe")
                return true
            } catch NetworkError.httpError(let code, _) where code == 401 || code == 403 {
                throw ProviderError.missingAPIKey
            } catch NetworkError.httpError(let code, _) where code == 429 {
                throw ProviderError.rateLimited(retryAfter: nil)
            } catch NetworkError.httpError(let code, _) where code == 404 {
                throw ProviderError.serverError(
                    message: "OpenClaw chat endpoint is unavailable. Enable gateway.http.endpoints.chatCompletions.enabled"
                )
            } catch NetworkError.httpError(let code, _) where code == 400 {
                // A 400 from chat/completions still proves host/auth/routing are reachable.
                updateActiveMode(.http, detail: "HTTP endpoint reachable (400 response)")
                await logDiagnostics(level: .warning, message: "Connection test received HTTP 400 from chat/completions; treating as reachable")
                return true
            }
        } catch {
            if shouldAttemptGatewayFallback(for: error) {
                await logDiagnostics(
                    level: .warning,
                    message: "HTTP connection test failed; trying gateway fallback",
                    metadata: ["error": errorSummary(error)]
                )
                do {
                    try await testGatewayConnection()
                    updateActiveMode(.websocketFallback, detail: "Gateway fallback connection test succeeded")
                    await logDiagnostics(level: .info, message: "Gateway fallback connection test succeeded")
                    return true
                } catch let fallbackError {
                    updateActiveMode(.unknown, detail: "Connection test fallback failed")
                    throw fallbackFailure(context: "connection test", primary: error, fallback: fallbackError)
                }
            }
            throw error
        }
    }

    public func fetchModels() async throws -> [LLMModel] {
        if usesGatewayRPCDirectly {
            let models = try await fetchModelsViaGateway()
            updateActiveMode(.websocketDirect, detail: "Fetched models via gateway")
            await logDiagnostics(level: .info, message: "Fetched models via gateway", metadata: ["count": "\(models.count)"])
            return models
        }

        let url = try config.baseURL.appending(path: "models")
        let headers = try await authHeaders()

        do {
            let response: OpenAIModelsResponse = try await httpClient.get(url: url, headers: headers)
            let models = response.data.map { model in
                LLMModel(
                    id: model.id,
                    name: model.id,
                    provider: .openClaw,
                    contextLength: nil,
                    isFree: false
                )
            }
            updateActiveMode(.http, detail: "Fetched models via HTTP")
            await logDiagnostics(level: .info, message: "Fetched models via HTTP", metadata: ["count": "\(models.count)"])
            return models
        } catch NetworkError.httpError(let statusCode, _) where statusCode == 401 || statusCode == 403 {
            throw ProviderError.missingAPIKey
        } catch NetworkError.httpError(let statusCode, _) where statusCode == 429 {
            throw ProviderError.rateLimited(retryAfter: nil)
        } catch NetworkError.httpError(let statusCode, _) where statusCode == 404 {
            updateActiveMode(.http, detail: "HTTP /models returned 404")
            return []
        } catch {
            if shouldAttemptGatewayFallback(for: error) {
                await logDiagnostics(
                    level: .warning,
                    message: "HTTP model fetch failed; trying gateway fallback",
                    metadata: ["error": errorSummary(error)]
                )
                do {
                    let models = try await fetchModelsViaGateway()
                    updateActiveMode(.websocketFallback, detail: "Fetched models via gateway fallback")
                    await logDiagnostics(level: .info, message: "Fetched models via gateway fallback", metadata: ["count": "\(models.count)"])
                    return models
                } catch let fallbackError {
                    updateActiveMode(.unknown, detail: "Model fetch fallback failed")
                    throw fallbackFailure(context: "model fetch", primary: error, fallback: fallbackError)
                }
            }
            throw error
        }
    }

    public func chat(request: ChatRequest) async throws -> ChatResponse {
        if usesGatewayRPCDirectly {
            let response = try await chatViaGateway(request: request)
            updateActiveMode(.websocketDirect, detail: "Chat completed via gateway")
            await logDiagnostics(level: .info, message: "Chat completed via gateway")
            return response
        }

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

            updateActiveMode(.http, detail: "Chat completed via HTTP")
            await logDiagnostics(level: .info, message: "Chat completed via HTTP")
            return ChatResponse(content: content, finishReason: .stop, usage: usage)
        } catch NetworkError.httpError(let statusCode, _) where statusCode == 401 || statusCode == 403 {
            throw ProviderError.missingAPIKey
        } catch NetworkError.httpError(let statusCode, _) where statusCode == 429 {
            throw ProviderError.rateLimited(retryAfter: nil)
        } catch NetworkError.httpError(let statusCode, _) where statusCode == 404 {
            throw ProviderError.serverError(
                message: "OpenClaw chat endpoint is unavailable. Enable gateway.http.endpoints.chatCompletions.enabled"
            )
        } catch {
            if shouldAttemptGatewayFallback(for: error) {
                await logDiagnostics(
                    level: .warning,
                    message: "HTTP chat failed; trying gateway fallback",
                    metadata: ["error": errorSummary(error)]
                )
                do {
                    let response = try await chatViaGateway(request: request)
                    updateActiveMode(.websocketFallback, detail: "Chat completed via gateway fallback")
                    await logDiagnostics(level: .info, message: "Chat completed via gateway fallback")
                    return response
                } catch let fallbackError {
                    updateActiveMode(.unknown, detail: "Chat fallback failed")
                    throw fallbackFailure(context: "chat request", primary: error, fallback: fallbackError)
                }
            }
            throw error
        }
    }

    public func chatStream(request: ChatRequest) -> AsyncThrowingStream<StreamChunk, Error> {
        if usesGatewayRPCDirectly {
            updateActiveMode(.websocketDirect, detail: "Streaming via gateway")
            return gatewayChatStream(request: request)
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    do {
                        try await streamViaHTTPWithRetry(request: request, continuation: continuation)
                        updateActiveMode(.http, detail: "Streaming completed via HTTP")
                        await logDiagnostics(level: .info, message: "Streaming completed via HTTP")
                    } catch {
                        if shouldAttemptGatewayFallback(for: error) {
                            await logDiagnostics(
                                level: .warning,
                                message: "HTTP stream failed; switching to gateway fallback",
                                metadata: ["error": errorSummary(error)]
                            )
                            do {
                                try await streamViaGateway(request: request, continuation: continuation)
                                updateActiveMode(.websocketFallback, detail: "Streaming completed via gateway fallback")
                                await logDiagnostics(level: .info, message: "Streaming completed via gateway fallback")
                            } catch let fallbackError {
                                updateActiveMode(.unknown, detail: "Streaming fallback failed")
                                throw fallbackFailure(context: "streaming chat", primary: error, fallback: fallbackError)
                            }
                        } else {
                            throw error
                        }
                    }
                } catch let error as NetworkError {
                    switch error {
                    case .httpError(let statusCode, _) where statusCode == 401 || statusCode == 403:
                        continuation.finish(throwing: ProviderError.missingAPIKey)
                    case .httpError(let statusCode, _) where statusCode == 429:
                        continuation.finish(throwing: ProviderError.rateLimited(retryAfter: nil))
                    case .httpError(let statusCode, _) where statusCode == 404:
                        continuation.finish(
                            throwing: ProviderError.serverError(
                                message: "OpenClaw chat endpoint is unavailable. Enable gateway.http.endpoints.chatCompletions.enabled"
                            )
                        )
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

    // MARK: - HTTP streaming

    private func streamViaHTTPWithRetry(
        request: ChatRequest,
        continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation
    ) async throws {
        var attempt = 1

        while attempt <= httpStreamMaxAttempts {
            do {
                try await streamViaHTTP(request: request, continuation: continuation)
                return
            } catch {
                let isRetryable = shouldRetryHTTPStream(after: error) && attempt < httpStreamMaxAttempts
                await logDiagnostics(
                    level: isRetryable ? .warning : .error,
                    message: "HTTP streaming attempt failed",
                    metadata: [
                        "attempt": "\(attempt)",
                        "maxAttempts": "\(httpStreamMaxAttempts)",
                        "retryable": isRetryable ? "true" : "false",
                        "error": errorSummary(error)
                    ]
                )

                if isRetryable {
                    attempt += 1
                    try? await Task.sleep(nanoseconds: httpStreamRetryDelayNanoseconds)
                    continue
                }
                throw error
            }
        }
    }

    private func streamViaHTTP(
        request: ChatRequest,
        continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation
    ) async throws {
        let url = try config.baseURL.appending(path: "chat/completions")
        let headers = try await authHeaders()

        let body = OpenAIChatRequest(
            model: request.model,
            messages: request.messages,
            stream: true,
            temperature: request.temperature,
            maxTokens: request.maxTokens
        )

        var sawDataFrame = false

        for try await line in await httpClient.streamSSE(
            url: url,
            body: body,
            headers: headers,
            requestTimeout: httpStreamRequestTimeout
        ) {
            guard line.hasPrefix("data: ") else { continue }
            sawDataFrame = true

            let jsonString = String(line.dropFirst(6))
            if jsonString == "[DONE]" {
                continuation.yield(StreamChunk(delta: "", isFinished: true, usage: nil))
                continuation.finish()
                return
            }

            guard let data = jsonString.data(using: .utf8) else { continue }
            let chunk = try JSONDecoder().decode(OpenAIStreamChunk.self, from: data)

            if let delta = chunk.choices.first?.delta.content {
                continuation.yield(StreamChunk(delta: delta, isFinished: false, usage: nil))
            }

            if chunk.choices.first?.finish_reason != nil {
                continuation.yield(StreamChunk(delta: "", isFinished: true, usage: nil))
                continuation.finish()
                return
            }
        }

        // Non-SSE or truncated SSE responses can happen when the gateway serves UI HTML.
        if !sawDataFrame {
            throw ProviderError.serverError(
                message: "OpenClaw HTTP streaming did not return SSE data. HTTP endpoint may be disabled; gateway WebSocket fallback is available."
            )
        }
    }

    // MARK: - Gateway WebSocket RPC

    private func gatewaySessionKey(for request: ChatRequest) -> String {
        // OpenClaw gateway tracks context by session key.
        // Keep a stable default here since provider API does not expose conversation IDs.
        _ = request
        return "main"
    }

    private func gatewayChatInput(from request: ChatRequest) -> String {
        request.messages.last(where: { $0.role == "user" })?.content
            ?? request.messages.last?.content
            ?? ""
    }

    private func gatewayWebSocketURL() throws -> URL {
        do {
            return try config.gatewayWebSocketURL()
        } catch {
            throw ProviderError.invalidConfiguration
        }
    }

    private func testGatewayConnection() async throws {
        _ = try await withGatewayConnection { socket in
            try await gatewayConnect(socket)
            return try await gatewayRequest(socket, method: "health", params: .object([:]))
        }
    }

    private func fetchModelsViaGateway() async throws -> [LLMModel] {
        try await withGatewayConnection { socket in
            try await gatewayConnect(socket)
            let payload = try await gatewayRequest(socket, method: "models.list", params: .object([:]))

            guard let models = payload?.objectValue?["models"]?.arrayValue else {
                return []
            }

            return models.compactMap { modelValue in
                if let id = modelIdentifier(from: modelValue) {
                    return LLMModel(
                        id: id,
                        name: modelDisplayName(from: modelValue) ?? id,
                        provider: .openClaw,
                        contextLength: nil,
                        isFree: false
                    )
                }
                return nil
            }
        }
    }

    private func chatViaGateway(request: ChatRequest) async throws -> ChatResponse {
        var fullContent = ""
        var usage: StreamChunk.TokenUsage?

        for try await chunk in gatewayChatStream(request: request) {
            fullContent += chunk.delta
            if chunk.isFinished {
                usage = chunk.usage
                break
            }
        }

        return ChatResponse(content: fullContent, finishReason: .stop, usage: usage)
    }

    private func gatewayChatStream(request: ChatRequest) -> AsyncThrowingStream<StreamChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await streamViaGateway(request: request, continuation: continuation)
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

    private func streamViaGateway(
        request: ChatRequest,
        continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation
    ) async throws {
        try await withGatewayConnection { socket in
            try await gatewayConnect(socket)

            let sessionKey = gatewaySessionKey(for: request)
            let message = gatewayChatInput(from: request).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !message.isEmpty else {
                throw ProviderError.serverError(message: "Cannot send an empty message")
            }

            let sendRequestID = UUID().uuidString
            let sendParams = JSONValue.object([
                "sessionKey": .string(sessionKey),
                "message": .string(message),
                "deliver": .bool(false),
                "idempotencyKey": .string(UUID().uuidString)
            ])
            try await socket.send(
                GatewayRequestEnvelope(
                    id: sendRequestID,
                    method: "chat.send",
                    params: sendParams
                )
            )

            var sendAckReceived = false
            var runID: String?
            var accumulated = ""

            while true {
                try Task.checkCancellation()
                let envelope = try await socket.receive()

                if envelope.type == "res", envelope.id == sendRequestID {
                    if envelope.ok == true {
                        sendAckReceived = true
                        runID = envelope.payload?.objectValue?["runId"]?.stringValue
                        continue
                    }

                    let message = gatewayErrorMessage(envelope.error, fallback: "chat.send failed")
                    throw ProviderError.serverError(message: message)
                }

                guard envelope.type == "event", envelope.event == "chat" else { continue }
                guard let payload = envelope.payload?.objectValue else { continue }
                guard payload["sessionKey"]?.stringValue == sessionKey else { continue }

                if let eventRunID = payload["runId"]?.stringValue,
                   let runID,
                   !runID.isEmpty,
                   !eventRunID.isEmpty,
                   runID != eventRunID {
                    continue
                }

                let state = payload["state"]?.stringValue ?? ""
                switch state {
                case "delta":
                    guard sendAckReceived else { continue }
                    let currentText = extractGatewayMessageText(payload["message"]) ?? ""
                    if currentText.isEmpty { continue }

                    if currentText.hasPrefix(accumulated) {
                        let delta = String(currentText.dropFirst(accumulated.count))
                        if !delta.isEmpty {
                            accumulated = currentText
                            continuation.yield(StreamChunk(delta: delta, isFinished: false, usage: nil))
                        }
                    } else {
                        accumulated = currentText
                        continuation.yield(StreamChunk(delta: currentText, isFinished: false, usage: nil))
                    }

                case "final":
                    let finalText = extractGatewayMessageText(payload["message"]) ?? ""
                    if !finalText.isEmpty {
                        if finalText.hasPrefix(accumulated) {
                            let remainder = String(finalText.dropFirst(accumulated.count))
                            if !remainder.isEmpty {
                                continuation.yield(StreamChunk(delta: remainder, isFinished: false, usage: nil))
                            }
                        } else if finalText != accumulated {
                            continuation.yield(StreamChunk(delta: finalText, isFinished: false, usage: nil))
                        }
                    }

                    continuation.yield(StreamChunk(delta: "", isFinished: true, usage: nil))
                    continuation.finish()
                    return

                case "aborted":
                    throw ProviderError.cancelled

                case "error":
                    let errorCode = payload["errorCode"]?.stringValue
                    let errorMessage = payload["errorMessage"]?.stringValue
                        ?? extractGatewayMessageText(payload["message"])
                        ?? "chat error"
                    if let errorCode, !errorCode.isEmpty {
                        throw ProviderError.serverError(message: "[\(errorCode)] \(errorMessage)")
                    }
                    throw ProviderError.serverError(message: errorMessage)

                default:
                    continue
                }
            }
        }
    }

    private func modelIdentifier(from value: JSONValue) -> String? {
        if let string = value.stringValue, !string.isEmpty {
            return string
        }

        guard let object = value.objectValue else { return nil }

        if let id = object["id"]?.stringValue, !id.isEmpty {
            return id
        }

        if let model = object["model"]?.stringValue, !model.isEmpty {
            if let provider = object["provider"]?.stringValue, !provider.isEmpty {
                return "\(provider)/\(model)"
            }
            return model
        }

        return nil
    }

    private func modelDisplayName(from value: JSONValue) -> String? {
        guard let object = value.objectValue else {
            return value.stringValue
        }

        if let displayName = object["displayName"]?.stringValue, !displayName.isEmpty {
            return displayName
        }

        if let name = object["name"]?.stringValue, !name.isEmpty {
            return name
        }

        return modelIdentifier(from: value)
    }

    private func extractGatewayMessageText(_ value: JSONValue?) -> String? {
        guard let value else { return nil }

        if let text = value.stringValue {
            return text
        }

        guard let object = value.objectValue else { return nil }

        if let text = object["text"]?.stringValue, !text.isEmpty {
            return text
        }

        if let contentString = object["content"]?.stringValue, !contentString.isEmpty {
            return contentString
        }

        if let contentArray = object["content"]?.arrayValue {
            let segments = contentArray.compactMap { item -> String? in
                if let text = item.objectValue?["text"]?.stringValue, !text.isEmpty {
                    return text
                }
                if let text = item.stringValue, !text.isEmpty {
                    return text
                }
                return nil
            }

            if !segments.isEmpty {
                return segments.joined(separator: "\n")
            }
        }

        return nil
    }

    private func gatewayErrorMessage(_ error: GatewayErrorEnvelope?, fallback: String) -> String {
        guard let error else {
            return fallback
        }

        var parts: [String] = []
        if let code = error.code, !code.isEmpty {
            parts.append("[\(code)]")
        }
        if let message = error.message, !message.isEmpty {
            parts.append(message)
        } else {
            parts.append(fallback)
        }

        if let details = error.details?.stringValue, !details.isEmpty {
            parts.append(details)
        }

        return parts.joined(separator: " ")
    }

    private func gatewayConnect(_ socket: GatewaySocket) async throws {
        let token = try await apiKey()

        let params = GatewayConnectParams(
            minProtocol: 3,
            maxProtocol: 3,
            client: GatewayConnectClient(
                id: "gateway-client",
                version: "dev",
                platform: "ios",
                mode: "ui",
                instanceId: UUID().uuidString
            ),
            role: "operator",
            scopes: ["operator.read", "operator.write"],
            caps: [],
            commands: [],
            permissions: [:],
            auth: GatewayConnectAuth(token: token, password: nil),
            userAgent: "OllamaRemote/iOS",
            locale: Locale.current.identifier
        )

        let payload = try jsonValue(from: params)
        _ = try await gatewayRequest(socket, method: "connect", params: payload)
    }

    private func gatewayRequest(
        _ socket: GatewaySocket,
        method: String,
        params: JSONValue
    ) async throws -> JSONValue? {
        let requestID = UUID().uuidString
        try await socket.send(
            GatewayRequestEnvelope(
                id: requestID,
                method: method,
                params: params
            )
        )

        while true {
            let envelope = try await socket.receive()

            guard envelope.type == "res", envelope.id == requestID else {
                continue
            }

            if envelope.ok == true {
                return envelope.payload
            }

            let message = gatewayErrorMessage(envelope.error, fallback: "gateway request failed")
            throw ProviderError.serverError(message: message)
        }
    }

    private func withGatewayConnection<T>(
        _ body: (GatewaySocket) async throws -> T
    ) async throws -> T {
        let url = try gatewayWebSocketURL()
        let socket = GatewaySocket(url: url)
        await socket.connect()

        do {
            let value = try await body(socket)
            await socket.close()
            return value
        } catch {
            await socket.close()
            throw error
        }
    }

    private func jsonValue<E: Encodable>(from value: E) throws -> JSONValue {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }
}

// MARK: - Gateway Wire Types

private struct GatewayRequestEnvelope: Encodable {
    let type: String = "req"
    let id: String
    let method: String
    let params: JSONValue
}

private struct GatewayResponseEnvelope: Decodable {
    let type: String
    let id: String?
    let ok: Bool?
    let payload: JSONValue?
    let error: GatewayErrorEnvelope?
    let event: String?
    let seq: Int?
}

private struct GatewayErrorEnvelope: Decodable {
    let code: String?
    let message: String?
    let details: JSONValue?
}

private struct GatewayConnectParams: Encodable {
    let minProtocol: Int
    let maxProtocol: Int
    let client: GatewayConnectClient
    let role: String
    let scopes: [String]
    let caps: [String]
    let commands: [String]
    let permissions: [String: Bool]
    let auth: GatewayConnectAuth
    let userAgent: String
    let locale: String
}

private struct GatewayConnectClient: Encodable {
    let id: String
    let version: String
    let platform: String
    let mode: String
    let instanceId: String
}

private struct GatewayConnectAuth: Encodable {
    let token: String?
    let password: String?
}

private actor GatewaySocket {
    private let task: URLSessionWebSocketTask
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(url: URL, session: URLSession = .shared) {
        self.task = session.webSocketTask(with: url)
    }

    func connect() {
        task.resume()
    }

    func close() {
        task.cancel(with: .normalClosure, reason: nil)
    }

    func send(_ envelope: GatewayRequestEnvelope) async throws {
        let data = try encoder.encode(envelope)
        guard let text = String(data: data, encoding: .utf8) else {
            throw ProviderError.serverError(message: "Failed to encode gateway request")
        }
        try await task.send(.string(text))
    }

    func receive() async throws -> GatewayResponseEnvelope {
        let message = try await task.receive()

        let data: Data
        switch message {
        case .string(let text):
            guard let encoded = text.data(using: .utf8) else {
                throw ProviderError.serverError(message: "Invalid gateway response")
            }
            data = encoded
        case .data(let binary):
            data = binary
        @unknown default:
            throw ProviderError.serverError(message: "Unsupported gateway message type")
        }

        return try decoder.decode(GatewayResponseEnvelope.self, from: data)
    }
}

private enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }
}
