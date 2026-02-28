import Foundation

public struct LocalOllamaConfig: ProviderConfiguration, Codable {
    public let id: UUID
    public var type: ProviderType { .localOllama }
    public var displayName: String
    public var isEnabled: Bool
    public var host: String
    public var port: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case isEnabled
        case host
        case port
    }

    public var baseURL: URL {
        let parsedHost = parseHostInput(host)

        var components = URLComponents()
        components.scheme = parsedHost?.scheme ?? "http"
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

        // Fail loudly instead of silently falling back to localhost.
        return components.url ?? URL(string: "invalid://configuration-error")!
    }

    public func validated() throws -> LocalOllamaConfig {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedHost.isEmpty || parseHostInput(trimmedHost) == nil {
            throw ConfigValidationError.invalidHost(host)
        }

        let resolvedPort = parseHostInput(trimmedHost)?.port ?? port
        guard (1...65535).contains(resolvedPort) else {
            throw ConfigValidationError.invalidPort(resolvedPort)
        }

        _ = baseURL
        return self
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

        return ParsedHostInput(
            scheme: includesScheme ? components.scheme : nil,
            host: parsedHost,
            port: components.port
        )
    }

    private struct ParsedHostInput {
        let scheme: String?
        let host: String
        let port: Int?
    }

    public init(
        id: UUID = UUID(),
        displayName: String = "Local Ollama",
        host: String = "localhost",
        port: Int = 11434,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.host = host
        self.port = port
        self.isEnabled = isEnabled
    }
}
