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
        let isAddRelated = lower.hasPrefix("add ") ||
                           lower.contains("add ") ||
                           lower.hasPrefix("new task") ||
                           lower.contains("new task") ||
                           lower.hasPrefix("create task") ||
                           lower.contains("create task") ||
                           lower.contains("remind me to ") ||
                           lower.contains("put ")
        guard isAddRelated else { return nil }
        
        var payload = original
        
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
                payload = String(payload[..<range.lowerBound])
                break
            }
        }
        
        // Prefix triggers to strip (from longest to shortest)
        let prefixes = [
            "add to my daily checklist:", "add to my daily checklist", "add to the daily checklist:", "add to the daily checklist",
            "add to my checklist:", "add to checklist:", "add to my checklist", "add to checklist",
            "add to my to do list:", "add to my todo list:", "add to todo list:", "add to todo:", "add to to-do:",
            "add to my to do list", "add to my todo list", "add to todo list", "add to todo", "add to to-do",
            "add to my task list:", "add to the task list:", "add to my task list", "add to the task list",
            "add to my tasks:", "add to tasks:", "add to my tasks", "add to tasks",
            "add to my list:", "add to the list:", "add to list:", "add to my list", "add to the list", "add to list",
            "put on my checklist:", "put on my checklist", "put on the checklist:", "put on the checklist",
            "put on my list:", "put on my list", "put on the list:", "put on the list",
            "put on my tasks:", "put on my tasks",
            "add new tasks:", "add new task:", "add new tasks", "add new task",
            "add tasks:", "add task:", "add tasks", "add task", "add a task:", "add a task",
            "create new task:", "create new tasks:", "create task:", "create tasks:", "create a task:", "create task", "create tasks", "create a task",
            "remind me to ", "please remind me to ", "please add ", "can you add ", "could you add ",
            "put ", "add "
        ]
        
        for prefix in prefixes {
            if payload.lowercased().hasPrefix(prefix) {
                payload = String(payload.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
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
                let cleaned = cleanTaskTitle(line)
                if !cleaned.isEmpty {
                    tasks.append(cleaned)
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
