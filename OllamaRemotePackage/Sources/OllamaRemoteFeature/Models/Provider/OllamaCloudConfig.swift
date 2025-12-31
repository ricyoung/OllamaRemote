import Foundation

public struct OllamaCloudConfig: ProviderConfiguration {
    public let id: UUID
    public let type: ProviderType = .ollamaCloud
    public var displayName: String
    public var isEnabled: Bool

    public var baseURL: URL {
        URL(string: "https://ollama.com")!
    }

    public var apiKeyReference: String {
        "ollama_cloud_\(id.uuidString)"
    }

    public init(
        id: UUID = UUID(),
        displayName: String = "Ollama Cloud",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.isEnabled = isEnabled
    }
}
