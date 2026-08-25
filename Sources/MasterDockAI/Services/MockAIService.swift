import Foundation

public final class MockAIService: AIServiceProtocol, @unchecked Sendable {
    public let provider: AIProvider = .mock
    
    public init() {}
    
    public func sendMessageStream(prompt: String, conversationHistory: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let response = self.generateMockResponse(for: prompt)
                let words = response.components(separatedBy: " ")
                
                for word in words {
                    try? await Task.sleep(nanoseconds: 35_000_000) // 35ms per word
                    continuation.yield(word + " ")
                }
                continuation.finish()
            }
        }
    }
    
    private func generateMockResponse(for prompt: String) -> String {
        let lower = prompt.lowercased()
        
        if lower.contains("summarize") || lower.contains("summary") {
            return "Here is a structured summary of your input:\n\n• **Core Theme:** High-velocity productivity enhancement\n• **Key Takeaway:** Liquid glass interface with trackpad edge gestures\n• **Action Items:** Instant access to clipboard, calendar, audio player, and quick AI prompts."
        } else if lower.contains("grammar") || lower.contains("fix") {
            return "Here is the refined and grammatically polished version:\n\n> \"I have reviewed the proposal and confirmed that all project deliverables are on track for today's milestone.\""
        } else if lower.contains("code") || lower.contains("swift") {
            return "Here is the optimized Swift implementation using modern concurrency:\n\n```swift\n@MainActor\nfunc executeAction() async throws -> String {\n    let result = try await Task.detached(priority: .userInitiated) {\n        return \"Task Completed Successfully\"\n    }.value\n    return result\n}\n```"
        } else if lower.contains("translate") {
            return "Here is the translated text:\n\n*English:* Master Dock brings Apple-grade productivity right to your fingertips.\n*Spanish:* Master Dock pone la productividad de nivel Apple al alcance de tus dedos.\n*French:* Master Dock met la productivité de qualité Apple au bout de vos doigts."
        } else {
            return "Master Dock AI is active and ready. I can assist you with quick research, contextual text transformations, drafting emails, analyzing code, or controlling your workspace. How can I assist your workflow right now?"
        }
    }
}
