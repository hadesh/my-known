import Foundation

public struct ChatMessage: Identifiable, Codable {
    public let id: UUID
    public let role: ChatRole
    public let content: String
    public let timestamp: Date
    public var isStreaming: Bool
    public var citations: [Citation]

    public init(id: UUID, role: ChatRole, content: String, timestamp: Date, isStreaming: Bool, citations: [Citation]) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.citations = citations
    }
}

public enum ChatRole: String, Codable {
    case user, assistant, system
}

public struct Citation: Codable {
    public let fileID: String
    public let title: String
    public let snippet: String
}