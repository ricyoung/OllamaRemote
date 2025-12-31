import Foundation

public struct LLMModel: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let provider: ProviderType
    public let contextLength: Int?
    public let isFree: Bool

    public var displayId: String {
        isFree ? "\(id):free" : id
    }

    public init(
        id: String,
        name: String,
        provider: ProviderType,
        contextLength: Int? = nil,
        isFree: Bool = false
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.contextLength = contextLength
        self.isFree = isFree
    }
}
