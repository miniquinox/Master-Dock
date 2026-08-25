import Foundation

public final class OpenAIService: AIServiceProtocol, @unchecked Sendable {
    public let provider: AIProvider = .openAI
    private let apiKey: String
    private let model: String
    
    public init(apiKey: String, model: String = "gpt-4o") {
        self.apiKey = apiKey
        self.model = model
    }
    
    public func sendMessageStream(prompt: String, conversationHistory: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
                    continuation.finish(throwing: URLError(.badURL))
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                var messagesArray: [[String: String]] = [
                    ["role": "system", "content": "You are Master Dock AI, an intelligent, concise, and helpful macOS desktop assistant."]
                ]
                
                for msg in conversationHistory {
                    messagesArray.append(["role": msg.role.rawValue, "content": msg.content])
                }
                messagesArray.append(["role": "user", "content": prompt])
                
                let body: [String: Any] = [
                    "model": model,
                    "messages": messagesArray,
                    "stream": true,
                    "temperature": 0.7
                ]
                
                guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
                    continuation.finish(throwing: URLError(.cannotDecodeContentData))
                    return
                }
                request.httpBody = httpBody
                
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        continuation.yield("⚠️ OpenAI API Error: Please check your API key.")
                        continuation.finish()
                        return
                    }
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                            if jsonString == "[DONE]" { break }
                            
                            if let data = jsonString.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let choices = json["choices"] as? [[String: Any]],
                               let delta = choices.first?["delta"] as? [String: Any],
                               let content = delta["content"] as? String {
                                continuation.yield(content)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
