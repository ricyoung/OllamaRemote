import Foundation

public enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}
