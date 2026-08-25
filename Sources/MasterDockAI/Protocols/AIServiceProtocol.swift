import Foundation

public enum AIProvider: String, Codable, CaseIterable, Sendable {
    case appleIntelligence = "Apple Intelligence (Foundation Model)"
    case openAI = "OpenAI (GPT-4o)"
    case gemini = "Google Gemini"
    case ollama = "Local Ollama"
    case mock = "Instant Preview (Mock)"
}

public struct AIMessage: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let role: Role
    public var content: String
    public let timestamp: Date
    
    public enum Role: String, Codable, Sendable {
        case user
        case assistant
        case system
    }
    
    public init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

public protocol AIServiceProtocol: AnyObject, Sendable {
    var provider: AIProvider { get }
    func sendMessageStream(prompt: String, conversationHistory: [AIMessage]) -> AsyncThrowingStream<String, Error>
}
