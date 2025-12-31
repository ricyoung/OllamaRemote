import Foundation

public struct OpenRouterConfig: ProviderConfiguration {
    public let id: UUID
    public let type: ProviderType = .openRouter
    public var displayName: String
    public var isEnabled: Bool
    public var preferFreeModels: Bool
    public var siteURL: String?
    public var siteName: String?

    public var baseURL: URL {
        URL(string: "https://openrouter.ai/api/v1")!
    }

    public var apiKeyReference: String {
        "openrouter_\(id.uuidString)"
    }

    public init(
        id: UUID = UUID(),
        displayName: String = "OpenRouter",
        isEnabled: Bool = true,
        preferFreeModels: Bool = true,
        siteURL: String? = nil,
        siteName: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.isEnabled = isEnabled
        self.preferFreeModels = preferFreeModels
        self.siteURL = siteURL
        self.siteName = siteName
    }
}
