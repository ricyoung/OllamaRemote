import Foundation

public struct AppleIntelligenceConfig: ProviderConfiguration, Sendable, Codable {
    public var id: UUID
    public var displayName: String
    public var isEnabled: Bool
    public var type: ProviderType { .appleIntelligence }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case isEnabled
    }

    public var baseURL: URL {
        // Not used for Apple Intelligence - runs on-device
        URL(fileURLWithPath: "/")
    }

    public init(
        id: UUID = UUID(),
        displayName: String = "Apple Intelligence",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.isEnabled = isEnabled
    }
}
