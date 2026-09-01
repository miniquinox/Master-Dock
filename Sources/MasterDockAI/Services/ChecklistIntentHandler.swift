import Foundation

@MainActor
public final class ChecklistIntentHandler {
    public static let shared = ChecklistIntentHandler()
    
    private init() {}
    
    public func handleIntent(prompt: String, checklistService: ChecklistService) -> ChecklistActionResult? {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        
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
        if let target = extractCompleteTaskTarget(from: trimmed, lower: lower) {
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
        if let target = extractDeleteTaskTarget(from: trimmed, lower: lower) {
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
        if let newTasks = extractAddTasks(from: trimmed, lower: lower), !newTasks.isEmpty {
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
               lower == "clear checklist done"
    }
    
    private func isListChecklistIntent(_ lower: String) -> Bool {
        return (lower.contains("checklist") || lower.contains("todo") || lower.contains("tasks")) &&
               (lower.contains("show") || lower.contains("what") || lower.contains("list") || lower.contains("view") || lower.contains("see") || lower.contains("check"))
    }
    
    private func extractCompleteTaskTarget(from original: String, lower: String) -> String? {
        let patterns = [
            "mark task as completed", "mark task as complete", "mark as completed", "mark as complete",
            "mark task as done", "mark as done", "complete task", "finish task", "check off task",
            "check off", "complete", "finish", "done"
        ]
        
        for pattern in patterns {
            if lower.hasPrefix(pattern) {
                var remainder = String(original.dropFirst(pattern.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                remainder = stripPunctuationAndKeywords(remainder)
                if !remainder.isEmpty { return remainder }
            }
        }
        
        // Regex / middle patterns: e.g. "mark 'task 1' as done"
        if lower.contains("mark ") && (lower.contains(" as done") || lower.contains(" as complete") || lower.contains(" as completed")) {
            var extracted = original
            if let markRange = lower.range(of: "mark ") {
                extracted = String(extracted[markRange.upperBound...])
            }
            if let doneRange = extracted.lowercased().range(of: " as done") ?? extracted.lowercased().range(of: " as complete") ?? extracted.lowercased().range(of: " as completed") {
                extracted = String(extracted[..<doneRange.lowerBound])
            }
            extracted = stripPunctuationAndKeywords(extracted)
            if !extracted.isEmpty { return extracted }
        }
        
        return nil
    }
    
    private func extractDeleteTaskTarget(from original: String, lower: String) -> String? {
        let patterns = [
            "remove task", "delete task", "remove", "delete"
        ]
        
        for pattern in patterns {
            if lower.hasPrefix(pattern) {
                var remainder = String(original.dropFirst(pattern.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if remainder.lowercased().hasSuffix("from checklist") || remainder.lowercased().hasSuffix("from my checklist") || remainder.lowercased().hasSuffix("from tasks") {
                    if let fromRange = remainder.lowercased().range(of: " from ") {
                        remainder = String(remainder[..<fromRange.lowerBound])
                    }
                }
                remainder = stripPunctuationAndKeywords(remainder)
                if !remainder.isEmpty { return remainder }
            }
        }
        
        return nil
    }
    
    private func extractAddTasks(from original: String, lower: String) -> [String]? {
        let isAddRelated = lower.contains("add ") || lower.contains("new task") || lower.contains("create task") || lower.contains("remind me to ") || lower.contains("put on my checklist")
        guard isAddRelated else { return nil }
        
        var payload = original
        
        // Strip common prefix triggers
        let prefixes = [
            "add to my checklist:", "add to checklist:", "add to my checklist", "add to checklist",
            "add to my tasks:", "add to tasks:", "add to my tasks", "add to tasks",
            "add to my to do list:", "add to my todo list:", "add to todo list:", "add to todo:",
            "add to my to do list", "add to my todo list", "add to todo list", "add to todo",
            "add new task:", "add new tasks:", "add new task", "add new tasks",
            "add tasks:", "add task:", "add tasks", "add task",
            "create new task:", "create task:", "create tasks:", "create task", "create tasks",
            "remind me to ", "put on my checklist:", "put on my checklist "
        ]
        
        for prefix in prefixes {
            if payload.lowercased().hasPrefix(prefix) {
                payload = String(payload.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        
        // Strip suffix triggers (e.g. "... to my checklist", "... to tasks")
        let suffixes = [
            "to my daily checklist", "to the daily checklist", "to my checklist", "to the checklist", "to checklist",
            "to my todo list", "to my to do list", "to my tasks", "to tasks"
        ]
        for suffix in suffixes {
            if payload.lowercased().hasSuffix(suffix) {
                if let suffixRange = payload.lowercased().range(of: " \(suffix)") {
                    payload = String(payload[..<suffixRange.lowerBound])
                }
            }
        }
        
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
                if !line.isEmpty {
                    tasks.append(cleanTaskTitle(line))
                }
            }
        } else {
            // Check for comma or semicolon separation if multiple items
            if payload.contains(",") && !payload.contains("http") {
                let parts = payload.components(separatedBy: ",")
                for part in parts {
                    let cleaned = cleanTaskTitle(part)
                    if !cleaned.isEmpty {
                        tasks.append(cleaned)
                    }
                }
            } else {
                tasks.append(cleanTaskTitle(payload))
            }
        }
        
        return tasks.isEmpty ? nil : tasks
    }
    
    private func cleanTaskTitle(_ input: String) -> String {
        var str = input.trimmingCharacters(in: CharacterSet(charactersIn: " -*•1234567890.:\"'"))
        if str.lowercased().hasPrefix("and ") {
            str = String(str.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return str
    }
    
    private func stripPunctuationAndKeywords(_ input: String) -> String {
        var str = input.trimmingCharacters(in: CharacterSet(charactersIn: " :\"'#"))
        if str.lowercased().hasPrefix("task ") {
            str = String(str.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return str
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

public struct ChecklistActionResult {
    public let message: String
    public let didPerformAction: Bool
    
    public init(message: String, didPerformAction: Bool) {
        self.message = message
        self.didPerformAction = didPerformAction
    }
}
