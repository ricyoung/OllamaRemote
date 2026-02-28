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
        let parsedHost = parseHostInput(host)

        var components = URLComponents()
        components.scheme = parsedHost?.scheme ?? (useTLS ? "https" : "http")
        components.host = parsedHost?.host ?? host.trimmingCharacters(in: .whitespacesAndNewlines)
        if let parsedHost {
            if parsedHost.scheme != nil {
                components.port = parsedHost.port
            } else {
                components.port = parsedHost.port ?? port
            }
        } else {
            components.port = port
        }
        components.path = parsedHost?.path ?? normalizedPathPrefix
        // Fail loudly instead of silently falling back to localhost
        return components.url ?? URL(string: "invalid://configuration-error")!
    }

    public var apiKeyReference: String {
        "openclaw_\(id.uuidString)"
    }

    public func gatewayWebSocketURL() throws -> URL {
        let raw = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            throw ConfigValidationError.invalidHost(host)
        }

        if raw.hasPrefix("ws://") || raw.hasPrefix("wss://") {
            guard let direct = URL(string: raw) else {
                throw ConfigValidationError.invalidHost(host)
            }
            return direct
        }

        if raw.contains("://"), let parsed = URLComponents(string: raw), let parsedHost = parsed.host {
            var components = URLComponents()
            switch (parsed.scheme ?? "").lowercased() {
            case "https", "wss":
                components.scheme = "wss"
                components.port = parsed.port
            case "http", "ws":
                components.scheme = "ws"
                components.port = parsed.port
            default:
                components.scheme = useTLS ? "wss" : "ws"
                components.port = parsed.port ?? port
            }
            components.host = parsedHost

            let parsedPath = parsed.path.trimmingCharacters(in: .whitespacesAndNewlines)
            if !parsedPath.isEmpty,
               parsedPath != "/",
               !parsedPath.lowercased().hasPrefix("/chat") {
                components.path = parsedPath.hasPrefix("/") ? parsedPath : "/\(parsedPath)"
            }

            guard let url = components.url else {
                throw ConfigValidationError.invalidHost(host)
            }
            return url
        }

        var components = URLComponents()
        components.scheme = useTLS ? "wss" : "ws"
        components.host = raw
        components.port = port
        guard let url = components.url else {
            throw ConfigValidationError.invalidHost(host)
        }
        return url
    }

    private var normalizedPathPrefix: String {
        let trimmed = pathPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "/v1" }
        return trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
    }

    private func parseHostInput(_ value: String) -> ParsedHostInput? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let includesScheme = trimmed.contains("://")
        let candidate = includesScheme ? trimmed : "http://\(trimmed)"

        guard let components = URLComponents(string: candidate),
              let parsedHost = components.host,
              !parsedHost.isEmpty else {
            return nil
        }

        let explicitPath: String?
        if components.path.isEmpty || components.path == "/" {
            explicitPath = nil
        } else if components.path.lowercased().hasPrefix("/chat") {
            // Shared Control UI links commonly include /chat?session=...
            // Keep API base URL path configurable via `pathPrefix` in that case.
            explicitPath = nil
        } else {
            explicitPath = components.path.hasPrefix("/") ? components.path : "/\(components.path)"
        }

        return ParsedHostInput(
            scheme: includesScheme ? components.scheme : nil,
            host: parsedHost,
            port: components.port,
            path: explicitPath
        )
    }

    private struct ParsedHostInput {
        let scheme: String?
        let host: String
        let port: Int?
        let path: String?
    }

    public func validated() throws -> OpenClawConfig {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedHost.isEmpty || parseHostInput(trimmedHost) == nil {
            throw ConfigValidationError.invalidHost(host)
        }

        let resolvedPort = parseHostInput(trimmedHost)?.port ?? port
        guard (1...65535).contains(resolvedPort) else {
            throw ConfigValidationError.invalidPort(resolvedPort)
        }

        let forbiddenPathChars = CharacterSet(charactersIn: "?#\r\n")
        let trimmedPath = pathPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPath.rangeOfCharacter(from: forbiddenPathChars) != nil || trimmedPath.contains("..") {
            throw ConfigValidationError.invalidPathPrefix(pathPrefix)
        }

        _ = try gatewayWebSocketURL()

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
