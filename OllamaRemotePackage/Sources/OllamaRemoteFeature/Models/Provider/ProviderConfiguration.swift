import Foundation

public protocol ProviderConfiguration: Codable, Identifiable, Sendable {
    var id: UUID { get }
    var type: ProviderType { get }
    var displayName: String { get set }
    var isEnabled: Bool { get set }
    var baseURL: URL { get }
}

public enum AnyProviderConfiguration: Codable, Identifiable, Sendable {
    case local(LocalOllamaConfig)
    case cloud(OllamaCloudConfig)
    case openRouter(OpenRouterConfig)
    case onDevice(OnDeviceConfig)
    case appleIntelligence(AppleIntelligenceConfig)

    public var id: UUID {
        switch self {
        case .local(let config): config.id
        case .cloud(let config): config.id
        case .openRouter(let config): config.id
        case .onDevice(let config): config.id
        case .appleIntelligence(let config): config.id
        }
    }

    public var type: ProviderType {
        switch self {
        case .local: .localOllama
        case .cloud: .ollamaCloud
        case .openRouter: .openRouter
        case .onDevice: .onDevice
        case .appleIntelligence: .appleIntelligence
        }
    }

    public var displayName: String {
        switch self {
        case .local(let config): config.displayName
        case .cloud(let config): config.displayName
        case .openRouter(let config): config.displayName
        case .onDevice(let config): config.displayName
        case .appleIntelligence(let config): config.displayName
        }
    }

    public var isEnabled: Bool {
        switch self {
        case .local(let config): config.isEnabled
        case .cloud(let config): config.isEnabled
        case .openRouter(let config): config.isEnabled
        case .onDevice(let config): config.isEnabled
        case .appleIntelligence(let config): config.isEnabled
        }
    }

    public var baseURL: URL {
        switch self {
        case .local(let config): config.baseURL
        case .cloud(let config): config.baseURL
        case .openRouter(let config): config.baseURL
        case .onDevice(let config): config.baseURL
        case .appleIntelligence(let config): config.baseURL
        }
    }

    public var apiKeyReference: String? {
        switch self {
        case .local, .onDevice, .appleIntelligence: nil
        case .cloud(let config): config.apiKeyReference
        case .openRouter(let config): config.apiKeyReference
        }
    }
}
