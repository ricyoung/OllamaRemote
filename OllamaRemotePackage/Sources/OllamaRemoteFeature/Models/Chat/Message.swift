import Foundation
import SwiftData

@Model
public final class Message {
    @Attribute(.unique) public var id: UUID
    public var content: String
    public var role: MessageRole
    public var timestamp: Date
    public var isStreaming: Bool
    public var tokenCount: Int?
    public var modelUsed: String?

    @Relationship(inverse: \Conversation.messages)
    public var conversation: Conversation?

    public init(
        content: String,
        role: MessageRole,
        conversation: Conversation? = nil
    ) {
        self.id = UUID()
        self.content = content
        self.role = role
        self.timestamp = Date()
        self.isStreaming = false
        self.conversation = conversation
    }
}
