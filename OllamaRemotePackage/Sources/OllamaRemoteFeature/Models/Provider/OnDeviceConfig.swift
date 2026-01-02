import Foundation

public struct OnDeviceConfig: ProviderConfiguration, Sendable, Codable {
    public var id: UUID
    public var displayName: String
    public var isEnabled: Bool
    public var type: ProviderType { .onDevice }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case isEnabled
    }

    public var baseURL: URL {
        // Local file URL - not used for network
        URL(fileURLWithPath: "/")
    }

    public init(
        id: UUID = UUID(),
        displayName: String = "On-Device",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.isEnabled = isEnabled
    }
}
