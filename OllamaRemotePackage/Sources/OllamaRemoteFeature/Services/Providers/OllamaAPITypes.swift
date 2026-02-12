import Foundation

// MARK: - Ollama API Request/Response Types

struct OllamaChatRequest: Encodable {
    let model: String
    let messages: [OllamaMessage]
    let stream: Bool
    let options: OllamaOptions?

    struct OllamaMessage: Encodable {
        let role: String
        let content: String
    }

    struct OllamaOptions: Encodable {
        let temperature: Double?
        let num_predict: Int?
    }

    init(
        model: String,
        messages: [ChatRequest.ChatMessage],
        stream: Bool,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.model = model
        self.messages = messages.map { OllamaMessage(role: $0.role, content: $0.content) }
        self.stream = stream
        self.options = (temperature != nil || maxTokens != nil)
            ? OllamaOptions(temperature: temperature, num_predict: maxTokens)
            : nil
    }
}

struct OllamaChatResponse: Decodable {
    let model: String
    let message: OllamaResponseMessage
    let done: Bool
    let total_duration: Int?
    let eval_count: Int?

    struct OllamaResponseMessage: Decodable {
        let role: String
        let content: String
    }
}

struct OllamaStreamChunk: Decodable {
    let model: String
    let message: OllamaMessage
    let done: Bool
    let eval_count: Int?

    struct OllamaMessage: Decodable {
        let role: String
        let content: String
    }
}

struct OllamaModelsResponse: Decodable {
    let models: [OllamaModelInfo]

    struct OllamaModelInfo: Decodable {
        let name: String
        let modified_at: String?
        let size: Int?
    }
}

// MARK: - OpenRouter/OpenAI API Types

struct OpenAIChatRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let stream: Bool
    let temperature: Double?
    let max_tokens: Int?

    struct OpenAIMessage: Encodable {
        let role: String
        let content: String
    }

    init(
        model: String,
        messages: [ChatRequest.ChatMessage],
        stream: Bool,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.model = model
        self.messages = messages.map { OpenAIMessage(role: $0.role, content: $0.content) }
        self.stream = stream
        self.temperature = temperature
        self.max_tokens = maxTokens
    }
}

struct OpenAIChatResponse: Decodable {
    let id: String
    let choices: [Choice]
    let usage: Usage?

    struct Choice: Decodable {
        let message: Message
        let finish_reason: String?

        struct Message: Decodable {
            let role: String
            let content: String
        }
    }

    struct Usage: Decodable {
        let prompt_tokens: Int
        let completion_tokens: Int
        let total_tokens: Int
    }
}

struct OpenAIStreamChunk: Decodable {
    let id: String
    let choices: [Choice]

    struct Choice: Decodable {
        let delta: Delta
        let finish_reason: String?

        struct Delta: Decodable {
            let content: String?
        }
    }
}

struct OpenAIModelsResponse: Decodable {
    let data: [OpenAIModel]

    struct OpenAIModel: Decodable {
        let id: String
    }
}

struct OpenRouterModelsResponse: Decodable {
    let data: [OpenRouterModel]

    struct OpenRouterModel: Decodable {
        let id: String
        let name: String?
        let context_length: Int?
        let pricing: Pricing?

        struct Pricing: Decodable {
            let prompt: String?
            let completion: String?
        }

        var isFree: Bool {
            guard let pricing = pricing else { return false }
            let promptCost = Double(pricing.prompt ?? "1") ?? 1
            let completionCost = Double(pricing.completion ?? "1") ?? 1
            return promptCost == 0 && completionCost == 0
        }
    }
}
