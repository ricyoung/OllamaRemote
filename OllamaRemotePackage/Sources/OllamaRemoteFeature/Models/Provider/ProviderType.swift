import Foundation

public enum ProviderType: String, Codable, CaseIterable, Identifiable, Sendable {
    case localOllama = "local"
    case ollamaCloud = "cloud"
    case openRouter = "openrouter"
    case onDevice = "ondevice"
    case appleIntelligence = "apple_intelligence"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .localOllama: "Local Ollama"
        case .ollamaCloud: "Ollama Cloud"
        case .openRouter: "OpenRouter"
        case .onDevice: "On-Device (MLX)"
        case .appleIntelligence: "Apple Intelligence"
        }
    }

    public var requiresAPIKey: Bool {
        switch self {
        case .localOllama, .onDevice, .appleIntelligence: false
        case .ollamaCloud, .openRouter: true
        }
    }

    public var iconName: String {
        switch self {
        case .localOllama: "server.rack"
        case .ollamaCloud: "cloud"
        case .openRouter: "network"
        case .onDevice: "cpu"
        case .appleIntelligence: "apple.intelligence"
        }
    }
}
