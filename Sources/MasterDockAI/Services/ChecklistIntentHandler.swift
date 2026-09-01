import Foundation

@MainActor
public final class ChecklistIntentHandler {
    public static let shared = ChecklistIntentHandler()
    
    private init() {}
    
    public func handleIntent(prompt: String, conversationHistory: [AIMessage] = [], checklistService: ChecklistService) -> ChecklistActionResult? {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()
        
        // 0. Contextual Follow-up Check: e.g. "and also chocolate milk", "and buy bread", "also coffee", "plus eggs"
        let lastAssistantMessage = conversationHistory.last(where: { $0.role == .assistant })?.content.lowercased() ?? ""
        let isFollowUpChecklistContext = lastAssistantMessage.contains("checklist") || lastAssistantMessage.contains("task")
        
        if isFollowUpChecklistContext && (lower.hasPrefix("and also ") || lower.hasPrefix("also ") || lower.hasPrefix("and ") || lower.hasPrefix("plus ") || lower.hasPrefix("as well as ")) {
            var taskPayload = trimmed
            for prefix in ["and also ", "as well as ", "also ", "and ", "plus "] {
                if taskPayload.lowercased().hasPrefix(prefix) {
                    taskPayload = String(taskPayload.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
            let cleaned = cleanTaskTitle(taskPayload)
            if !cleaned.isEmpty {
                checklistService.addItem(title: cleaned)
                return ChecklistActionResult(
                    message: "✨ Added new task to your Daily Checklist:\n\n• **\(cleaned)**",
                    didPerformAction: true
                )
            }
        }
        
        // 1. Clear Completed Tasks
        if isClearCompletedIntent(lower) {
            let beforeCount = checklistService.completedCount
            checklistService.clearCompleted()
            if beforeCount > 0 {
                return ChecklistActionResult(
                    message: "🗑️ **Cleared \(beforeCount) completed task\(beforeCount == 1 ? "" : "s")** from your Daily Checklist.",
                    didPerformAction: true
                )
            } else {
                return ChecklistActionResult(
                    message: "ℹ️ You don't have any completed tasks to clear on your Daily Checklist.",
                    didPerformAction: true
                )
            }
        }
        
        // 2. Complete / Mark Done
        if let target = extractCompleteTaskTarget(from: trimmed) {
            if let matchedItem = findMatchingItem(target: target, in: checklistService.items) {
                if !matchedItem.isCompleted {
                    checklistService.toggleItem(matchedItem)
                }
                return ChecklistActionResult(
                    message: "✅ Marked **\"\(matchedItem.title)\"** as completed on your Daily Checklist! 🎉",
                    didPerformAction: true
                )
            } else {
                return ChecklistActionResult(
                    message: "⚠️ Could not find a task matching *\"\(target)\"* on your Daily Checklist.",
                    didPerformAction: true
                )
            }
        }
        
        // 3. Remove / Delete Task
        if let target = extractDeleteTaskTarget(from: trimmed) {
            if let matchedItem = findMatchingItem(target: target, in: checklistService.items) {
                checklistService.removeItem(matchedItem)
                return ChecklistActionResult(
                    message: "🗑️ Removed **\"\(matchedItem.title)\"** from your Daily Checklist.",
                    didPerformAction: true
                )
            } else {
                return ChecklistActionResult(
                    message: "⚠️ Could not find a task matching *\"\(target)\"* on your Daily Checklist.",
                    didPerformAction: true
                )
            }
        }
        
        // 4. Add Tasks
        if let newTasks = extractAddTasks(from: trimmed), !newTasks.isEmpty {
            for task in newTasks {
                checklistService.addItem(title: task)
            }
            
            if newTasks.count == 1 {
                return ChecklistActionResult(
                    message: "✨ Added new task to your Daily Checklist:\n\n• **\(newTasks[0])**",
                    didPerformAction: true
                )
            } else {
                let formattedList = newTasks.map { "• **\($0)**" }.joined(separator: "\n")
                return ChecklistActionResult(
                    message: "✨ Added \(newTasks.count) tasks to your Daily Checklist:\n\n\(formattedList)",
                    didPerformAction: true
                )
            }
        }
        
        // 5. Show / List Checklist
        if isListChecklistIntent(lower) {
            let items = checklistService.items
            if items.isEmpty {
                return ChecklistActionResult(
                    message: "📋 Your Daily Checklist is currently empty. Ask me to add some tasks!",
                    didPerformAction: true
                )
            } else {
                let progress = checklistService.completedCount
                let total = items.count
                var lines = ["📋 **Daily Checklist** (\(progress)/\(total) completed):\n"]
                for (index, item) in items.enumerated() {
                    let status = item.isCompleted ? "✅ ~~" : "⬜ "
                    let suffix = item.isCompleted ? "~~" : ""
                    lines.append("\(index + 1). \(status)\(item.title)\(suffix)")
                }
                return ChecklistActionResult(
                    message: lines.joined(separator: "\n"),
                    didPerformAction: true
                )
            }
        }
        
        return nil
    }
    
    // MARK: - Pattern Matchers
    
    private func isClearCompletedIntent(_ lower: String) -> Bool {
        return lower.contains("clear completed") ||
               lower.contains("clear done") ||
               lower.contains("remove completed") ||
               lower.contains("delete completed") ||
               lower == "clear checklist" ||
               lower == "clear checklist done"
    }
    
    private func isListChecklistIntent(_ lower: String) -> Bool {
        return (lower.contains("checklist") || lower.contains("todo") || lower.contains("tasks")) &&
               (lower.contains("show") || lower.contains("what") || lower.contains("list") || lower.contains("view") || lower.contains("see") || lower.contains("check"))
    }
    
    private func extractCompleteTaskTarget(from original: String) -> String? {
        var str = original.trimmingCharacters(in: .whitespacesAndNewlines)
        var didMatchCompletionKeyword = false
        
        // Strip trailing completion keywords
        let completionSuffixes = [
            " as completed", " as complete", " as done", " as finished", " is done", " is complete", " is completed"
        ]
        for suffix in completionSuffixes {
            if str.lowercased().hasSuffix(suffix) {
                str = String(str.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                didMatchCompletionKeyword = true
                break
            }
        }
        
        // Regex to strip conversational preamble
        let pattern = #"^(can\s+you|could\s+you|would\s+you|please|let's|lets)?\s*(also)?\s*(please)?\s*(mark|check\s+off|complete|finish|cross\s+out|done)\s*(task|the\s+task|item|the\s+item)?\s*[:\-]?"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(str.startIndex..<str.endIndex, in: str)
            if let match = regex.firstMatch(in: str, options: [], range: range) {
                if let swiftRange = Range(match.range, in: str) {
                    str = String(str[swiftRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    didMatchCompletionKeyword = true
                }
            }
        }
        
        guard didMatchCompletionKeyword else { return nil }
        str = stripPunctuationAndKeywords(str)
        return str.isEmpty ? nil : str
    }
    
    private func extractDeleteTaskTarget(from original: String) -> String? {
        var str = original.trimmingCharacters(in: .whitespacesAndNewlines)
        var didMatchDeleteKeyword = false
        
        // Strip trailing source phrases
        let listSuffixes = [
            " from my daily checklist", " from the daily checklist", " from my checklist", " from the checklist", " from checklist",
            " from my todo list", " from my to do list", " from the todo list", " from todo list",
            " from my task list", " from the task list", " from my tasks", " from the tasks", " from tasks",
            " from my list", " from the list", " from list"
        ]
        for suffix in listSuffixes {
            if str.lowercased().hasSuffix(suffix) {
                str = String(str.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Regex to strip conversational preamble
        let pattern = #"^(can\s+you|could\s+you|would\s+you|please|let's|lets)?\s*(also)?\s*(please)?\s*(delete|remove|clear|drop)\s*(task|the\s+task|item|the\s+item)?\s*[:\-]?"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(str.startIndex..<str.endIndex, in: str)
            if let match = regex.firstMatch(in: str, options: [], range: range) {
                if let swiftRange = Range(match.range, in: str) {
                    str = String(str[swiftRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    didMatchDeleteKeyword = true
                }
            }
        }
        
        guard didMatchDeleteKeyword else { return nil }
        str = stripPunctuationAndKeywords(str)
        return str.isEmpty ? nil : str
    }
    
    private func extractAddTasks(from original: String) -> [String]? {
        var payload = original.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = payload.lowercased()
        
        let isAddRelated = lower.contains("add") ||
                           lower.contains("task") ||
                           lower.contains("remind me") ||
                           lower.contains("put ") ||
                           lower.contains("insert") ||
                           lower.contains("include")
        guard isAddRelated else { return nil }
        
        // Suffix list keywords to strip first (from longest to shortest)
        let suffixes = [
            "to my daily checklist", "to the daily checklist", "to my checklist", "to the checklist", "to checklist",
            "to my todo list", "to my to do list", "to the todo list", "to todo list", "to the to do list",
            "to my task list", "to the task list", "to my tasks", "to the tasks", "to tasks",
            "to my list", "to the list", "to list",
            "on my daily checklist", "on the daily checklist", "on my checklist", "on the checklist", "on checklist",
            "on my todo list", "on my to do list", "on the todo list", "on todo list",
            "on my task list", "on the task list", "on my tasks", "on the tasks", "on tasks",
            "on my list", "on the list", "on list",
            "in my checklist", "in the checklist", "in checklist",
            "in my todo list", "in my to do list", "in my list", "in the list", "in list", "in tasks"
        ]
        
        for suffix in suffixes {
            let lowerPayload = payload.lowercased()
            if lowerPayload.hasSuffix(" \(suffix)") {
                let range = lowerPayload.range(of: " \(suffix)", options: .backwards)!
                payload = String(payload[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        
        // Comprehensive Regex to match ANY conversational preamble
        // Handles: "can you also add", "could you please add", "i need to add", "please also add", "also add", "remind me to", etc.
        let pattern = #"^(can\s+you|could\s+you|would\s+you|will\s+you|please|let's|lets|i\s+need\s+to|i\s+want\s+to|don't\s+forget\s+to|dont\s+forget\s+to|remember\s+to|and)?\s*(also)?\s*(please)?\s*(add|put|insert|include|create|remind\s+me\s+to)\s*(a\s+new\s+task|new\s+tasks|a\s+task|tasks|task|to\s+my\s+list|to\s+the\s+list|to\s+my\s+checklist|to\s+the\s+checklist|to\s+checklist|to\s+list|on\s+my\s+list|on\s+the\s+list|on\s+my\s+checklist|on\s+the\s+checklist)?\s*[:\-]?"#
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(payload.startIndex..<payload.endIndex, in: payload)
            if let match = regex.firstMatch(in: payload, options: [], range: range) {
                if let swiftRange = Range(match.range, in: payload) {
                    payload = String(payload[swiftRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        // Strip any residual prefix colon, quotes, or dashes
        payload = payload.trimmingCharacters(in: CharacterSet(charactersIn: ": \n\r\t\"'"))
        guard !payload.isEmpty else { return nil }
        
        // Check if there are multiple numbered or bulleted items
        var tasks: [String] = []
        let rawLines = payload.components(separatedBy: .newlines)
        
        if rawLines.count > 1 {
            for rawLine in rawLines {
                var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                    line = String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if let dotIndex = line.firstIndex(of: ".") {
                    let prefix = line[..<dotIndex]
                    if Int(prefix) != nil {
                        line = String(line[line.index(after: dotIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                let cleaned = cleanTaskTitle(line)
                if !cleaned.isEmpty {
                    tasks.append(cleaned)
                }
            }
        } else {
            // Comma separated if not a URL or code
            if payload.contains(",") && !payload.contains("http") && !payload.contains("{") {
                let parts = payload.components(separatedBy: ",")
                for part in parts {
                    let cleaned = cleanTaskTitle(part)
                    if !cleaned.isEmpty {
                        tasks.append(cleaned)
                    }
                }
            } else {
                let cleaned = cleanTaskTitle(payload)
                if !cleaned.isEmpty {
                    tasks.append(cleaned)
                }
            }
        }
        
        return tasks.isEmpty ? nil : tasks
    }
    
    private func cleanTaskTitle(_ input: String) -> String {
        var str = input.trimmingCharacters(in: CharacterSet(charactersIn: " -*•1234567890.:\"'"))
        if str.lowercased().hasPrefix("and ") {
            str = String(str.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        str = str.trimmingCharacters(in: CharacterSet(charactersIn: " :\"'"))
        guard !str.isEmpty else { return "" }
        return str.prefix(1).uppercased() + str.dropFirst()
    }
    
    private func stripPunctuationAndKeywords(_ input: String) -> String {
        var str = input.trimmingCharacters(in: CharacterSet(charactersIn: " :\"'#"))
        if str.lowercased().hasPrefix("task ") {
            str = String(str.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return str.trimmingCharacters(in: CharacterSet(charactersIn: " :\"'#"))
    }
    
    private func findMatchingItem(target: String, in items: [ChecklistItem]) -> ChecklistItem? {
        let cleanedTarget = target.trimmingCharacters(in: CharacterSet(charactersIn: " #\"'")).lowercased()
        
        // Check if numeric index (e.g. "task 1", "2")
        if let num = Int(cleanedTarget), num > 0, num <= items.count {
            return items[num - 1]
        }
        
        // Exact match
        if let exact = items.first(where: { $0.title.lowercased() == cleanedTarget }) {
            return exact
        }
        
        // Prefix or substring match
        if let substring = items.first(where: { $0.title.lowercased().contains(cleanedTarget) || cleanedTarget.contains($0.title.lowercased()) }) {
            return substring
        }
        
        return nil
    }
}

public struct ChecklistActionResult: Sendable {
    public let message: String
    public let didPerformAction: Bool
    
    public init(message: String, didPerformAction: Bool) {
        self.message = message
        self.didPerformAction = didPerformAction
    }
}
