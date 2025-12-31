import Foundation

public struct LocalOllamaConfig: ProviderConfiguration {
    public let id: UUID
    public let type: ProviderType = .localOllama
    public var displayName: String
    public var isEnabled: Bool
    public var host: String
    public var port: Int

    public var baseURL: URL {
        URL(string: "http://\(host):\(port)")!
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
