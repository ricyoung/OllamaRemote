import Foundation

public struct OpenRouterConfig: ProviderConfiguration, Codable {
    public let id: UUID
    public var type: ProviderType { .openRouter }
    public var displayName: String
    public var isEnabled: Bool
    public var preferFreeModels: Bool
    public var siteURL: String?
    public var siteName: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case isEnabled
        case preferFreeModels
        case siteURL
        case siteName
        // intentionally omit `type` so it is not decoded/encoded and always defaults to `.openRouter`
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        self.preferFreeModels = try container.decode(Bool.self, forKey: .preferFreeModels)
        self.siteURL = try container.decodeIfPresent(String.self, forKey: .siteURL)
        self.siteName = try container.decodeIfPresent(String.self, forKey: .siteName)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(preferFreeModels, forKey: .preferFreeModels)
        try container.encodeIfPresent(siteURL, forKey: .siteURL)
        try container.encodeIfPresent(siteName, forKey: .siteName)
        // `type` is not encoded; it's derived.
    }

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
