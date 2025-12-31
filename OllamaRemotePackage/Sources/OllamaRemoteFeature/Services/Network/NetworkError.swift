import Foundation

public enum NetworkError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case connectionFailed(Error)
    case invalidURL

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid server response"
        case .httpError(let code, let message):
            if let message {
                "HTTP \(code): \(message)"
            } else {
                "HTTP error: \(code)"
            }
        case .decodingError(let error):
            "Failed to decode: \(error.localizedDescription)"
        case .connectionFailed(let error):
            "Connection failed: \(error.localizedDescription)"
        case .invalidURL:
            "Invalid URL"
        }
    }
}

public enum ProviderError: LocalizedError {
    case missingAPIKey
    case invalidConfiguration
    case connectionFailed(underlying: Error)
    case modelNotFound(String)
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(message: String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "API key is required for this provider"
        case .invalidConfiguration:
            "Provider configuration is invalid"
        case .connectionFailed(let error):
            "Connection failed: \(error.localizedDescription)"
        case .modelNotFound(let model):
            "Model '\(model)' not found"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                "Rate limited. Retry in \(Int(seconds)) seconds"
            } else {
                "Rate limited. Please try again later"
            }
        case .serverError(let message):
            "Server error: \(message)"
        case .cancelled:
            "Request was cancelled"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .missingAPIKey:
            "Add your API key in Settings"
        case .connectionFailed:
            "Check your network connection and provider address"
        case .rateLimited:
            "Wait a moment before sending another message"
        default:
            nil
        }
    }
}
