import Foundation
import Combine

public struct PromptAction: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let iconSystemName: String
    public let promptTemplate: String
    public let category: String
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        iconSystemName: String,
        promptTemplate: String,
        category: String = "Productivity"
    ) {
        self.id = id
        self.title = title
        self.iconSystemName = iconSystemName
        self.promptTemplate = promptTemplate
        self.category = category
    }
}

public final class PromptLibraryService: ObservableObject {
    public static let shared = PromptLibraryService()
    
    @Published public private(set) var favoritePrompts: [PromptAction] = []
    private let storageKey = "favorite_prompts"
    
    public init() {
        loadPrompts()
    }
    
    public func resolvePrompt(_ action: PromptAction, clipboardContent: String) -> String {
        var result = action.promptTemplate
        if result.contains("{clipboard}") {
            result = result.replacingOccurrences(of: "{clipboard}", with: clipboardContent)
        } else if !clipboardContent.isEmpty {
            result = "\(result)\n\nContext / Content:\n\"\"\"\n\(clipboardContent)\n\"\"\""
        }
        return result
    }
    
    public func addCustomPrompt(title: String, icon: String, template: String) {
        let action = PromptAction(
            title: title,
            iconSystemName: icon,
            promptTemplate: template,
            category: "Custom"
        )
        favoritePrompts.append(action)
        persistPrompts()
    }
    
    public func removePrompt(_ action: PromptAction) {
        favoritePrompts.removeAll { $0.id == action.id }
        persistPrompts()
    }
    
    private func persistPrompts() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(favoritePrompts) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func loadPrompts() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([PromptAction].self, from: data), !saved.isEmpty {
            self.favoritePrompts = saved
        } else {
            // Default built-in AI prompt shortcuts
            self.favoritePrompts = [
                PromptAction(
                    id: "summarize",
                    title: "Summarize",
                    iconSystemName: "doc.plaintext.fill",
                    promptTemplate: "Provide a clean, bulleted executive summary of the following content:\n\n{clipboard}",
                    category: "Writing"
                ),
                PromptAction(
                    id: "fix-grammar",
                    title: "Fix Grammar",
                    iconSystemName: "pencil.and.outline",
                    promptTemplate: "Correct all grammar, typos, and improve clarity while keeping the exact meaning intact:\n\n{clipboard}",
                    category: "Writing"
                ),
                PromptAction(
                    id: "explain-code",
                    title: "Explain Code",
                    iconSystemName: "curlybraces",
                    promptTemplate: "Explain what this code snippet does, highlighting edge cases and potential improvements:\n\n{clipboard}",
                    category: "Coding"
                ),
                PromptAction(
                    id: "translate",
                    title: "Translate",
                    iconSystemName: "character.book.closed.fill",
                    promptTemplate: "Translate the following text into English and Spanish with natural phrasing:\n\n{clipboard}",
                    category: "Language"
                ),
                PromptAction(
                    id: "action-items",
                    title: "Action Items",
                    iconSystemName: "checklist",
                    promptTemplate: "Extract all clear, actionable tasks and next steps from this message:\n\n{clipboard}",
                    category: "Productivity"
                ),
                PromptAction(
                    id: "professional",
                    title: "Make Professional",
                    iconSystemName: "sparkles",
                    promptTemplate: "Rewrite this message into a polite, crisp, and professional tone for executive communication:\n\n{clipboard}",
                    category: "Writing"
                )
            ]
        }
    }
}
