import Foundation
import Combine

public enum TaskPriority: String, Codable, Sendable {
    case low
    case medium
    case high
}

public struct ChecklistItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var isCompleted: Bool
    public let createdAt: Date
    public var priority: TaskPriority
    
    public init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        priority: TaskPriority = .medium
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.priority = priority
    }
}

public final class ChecklistService: ObservableObject, ChecklistServiceProtocol {
    public static let shared = ChecklistService()
    
    @Published public private(set) var items: [ChecklistItem] = []
    private let storageKey = "daily_checklist"
    
    public var completedCount: Int {
        items.filter { $0.isCompleted }.count
    }
    
    public var totalCount: Int {
        items.count
    }
    
    public var progressPercentage: Double {
        guard totalCount > 0 else { return 0.0 }
        return Double(completedCount) / Double(totalCount)
    }
    
    public init() {
        loadItems()
    }
    
    public func addItem(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let item = ChecklistItem(title: trimmed)
        items.insert(item, at: 0)
        persistItems()
    }
    
    public func toggleItem(_ item: ChecklistItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].isCompleted.toggle()
            persistItems()
        }
    }
    
    public func removeItem(_ item: ChecklistItem) {
        items.removeAll { $0.id == item.id }
        persistItems()
    }
    
    public func clearCompleted() {
        items.removeAll { $0.isCompleted }
        persistItems()
    }
    
    private func persistItems() {
        PersistenceController.shared.save(items, forKey: storageKey)
    }
    
    private func loadItems() {
        if let saved = PersistenceController.shared.load([ChecklistItem].self, forKey: storageKey) {
            self.items = saved
        } else {
            // Default sample tasks for brand new users on initial run
            self.items = [
                ChecklistItem(title: "Review daily priority tasks", isCompleted: true, priority: .high),
                ChecklistItem(title: "Check morning calendar and sync calls", isCompleted: false, priority: .medium),
                ChecklistItem(title: "Try 2-finger swipe on left trackpad edge", isCompleted: false, priority: .high),
                ChecklistItem(title: "Try voice mode (Option+Shift+Space or swipe > 50%)", isCompleted: false, priority: .low)
            ]
        }
    }
}
