import Foundation

public enum ProviderType: String, Codable, CaseIterable, Identifiable, Sendable {
    case localOllama = "local"
    case ollamaCloud = "cloud"
    case openRouter = "openrouter"
    case openClaw = "openclaw"
    case onDevice = "ondevice"
    case appleIntelligence = "apple_intelligence"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .localOllama: "Local Ollama"
        case .ollamaCloud: "Ollama Cloud"
        case .openRouter: "OpenRouter"
        case .openClaw: "OpenClaw"
        case .onDevice: "On-Device (MLX)"
        case .appleIntelligence: "Apple Intelligence"
        }
    }

    public var requiresAPIKey: Bool {
        switch self {
        case .localOllama, .onDevice, .appleIntelligence: false
        case .ollamaCloud, .openRouter, .openClaw: true
        }
    }

    public var iconName: String {
        switch self {
        case .localOllama: "server.rack"
        case .ollamaCloud: "cloud"
        case .openRouter: "network"
        case .openClaw: "pawprint"
        case .onDevice: "cpu"
        case .appleIntelligence: "apple.intelligence"
        }
    }
}
