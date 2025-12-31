import Foundation

public struct OnDeviceConfig: ProviderConfiguration, Sendable {
    public var id: UUID
    public var displayName: String
    public var isEnabled: Bool
    public let type: ProviderType = .onDevice

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
