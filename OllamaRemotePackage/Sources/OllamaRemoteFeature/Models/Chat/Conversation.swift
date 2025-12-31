import Foundation
import SwiftData

@Model
public final class Conversation {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var providerTypeRaw: String
    public var providerId: UUID?
    public var selectedModel: String?

    @Relationship(deleteRule: .cascade)
    public var messages: [Message] = []

    public var providerType: ProviderType {
        get { ProviderType(rawValue: providerTypeRaw) ?? .localOllama }
        set { providerTypeRaw = newValue.rawValue }
    }

    public var sortedMessages: [Message] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }

    public init(
        title: String = "New Conversation",
        providerType: ProviderType = .localOllama
    ) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.providerTypeRaw = providerType.rawValue
    }
}
