import Foundation

public enum ConfigValidationError: LocalizedError, Equatable {
    case invalidHost(String)
    case invalidPort(Int)
    case invalidPathPrefix(String)

    public var errorDescription: String? {
        switch self {
        case .invalidHost(let host):
            "Invalid host: \(host)"
        case .invalidPort(let port):
            "Port must be between 1 and 65535 (got \(port))"
        case .invalidPathPrefix(let path):
            "Invalid path prefix: \(path)"
        }
    }
}

public struct OpenClawConfig: ProviderConfiguration, Codable {
    public let id: UUID
    public var type: ProviderType { .openClaw }
    public var displayName: String
    public var isEnabled: Bool
    public var host: String
    public var port: Int
    public var useTLS: Bool
    public var pathPrefix: String

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case isEnabled
        case host
        case port
        case useTLS
        case pathPrefix
    }

    public var baseURL: URL {
        var components = URLComponents()
        components.scheme = useTLS ? "https" : "http"
        components.host = host
        components.port = port
        components.path = normalizedPathPrefix
        // Fail loudly instead of silently falling back to localhost
        return components.url ?? URL(string: "invalid://configuration-error")!
    }

    public var apiKeyReference: String {
        "openclaw_\(id.uuidString)"
    }

    private var normalizedPathPrefix: String {
        let trimmed = pathPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "/v1" }
        return trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
    }

    public func validated() throws -> OpenClawConfig {
        let forbiddenHostChars = CharacterSet(charactersIn: "/@?#\r\n")
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedHost.isEmpty || trimmedHost.rangeOfCharacter(from: forbiddenHostChars) != nil {
            throw ConfigValidationError.invalidHost(host)
        }

        guard (1...65535).contains(port) else {
            throw ConfigValidationError.invalidPort(port)
        }

        let forbiddenPathChars = CharacterSet(charactersIn: "?#\r\n")
        let trimmedPath = pathPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPath.rangeOfCharacter(from: forbiddenPathChars) != nil || trimmedPath.contains("..") {
            throw ConfigValidationError.invalidPathPrefix(pathPrefix)
        }

        return self
    }

    public init(
        id: UUID = UUID(),
        displayName: String = "OpenClaw",
        isEnabled: Bool = true,
        host: String = "localhost",
        port: Int = 18789,
        useTLS: Bool = false,
        pathPrefix: String = "/v1"
    ) {
        self.id = id
        self.displayName = displayName
        self.isEnabled = isEnabled
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.pathPrefix = pathPrefix
    }
}
