import Foundation
import EventKit
import Combine

public struct CalendarMeeting: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let location: String?
    public let joinURL: URL?
    public let isAllDay: Bool
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        joinURL: URL? = nil,
        isAllDay: Bool = false
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.joinURL = joinURL
        self.isAllDay = isAllDay
    }
    
    public var timeRangeString: String {
        if isAllDay { return "All Day" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }
    
    public var countdownStatus: String {
        let now = Date()
        if now >= startDate && now <= endDate {
            return "Happening Now"
        } else if startDate > now {
            let diffMinutes = Int(startDate.timeIntervalSince(now) / 60)
            if diffMinutes < 60 {
                return "in \(diffMinutes) min"
            } else {
                let hours = diffMinutes / 60
                let mins = diffMinutes % 60
                return "in \(hours)h \(mins)m"
            }
        } else {
            return "Completed"
        }
    }
}

public final class CalendarService: ObservableObject, CalendarServiceProtocol {
    public static let shared = CalendarService()
    
    @Published public private(set) var todayEvents: [CalendarMeeting] = []
    private let eventStore = EKEventStore()
    
    public init() {
        Task {
            await refreshEvents()
        }
    }
    
    @MainActor
    public func refreshEvents() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        
        let hasAccess: Bool
        if #available(macOS 14.0, *) {
            hasAccess = (status == .fullAccess || status == .writeOnly)
        } else {
            hasAccess = (status == .authorized)
        }
        
        guard hasAccess else {
            // Load demo / sample items if permission pending so user sees beautiful UI
            self.todayEvents = generateSampleEvents()
            return
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let rawEvents = eventStore.events(matching: predicate)
        
        self.todayEvents = rawEvents.map { ekEvent in
            let joinURL = extractMeetingURL(from: ekEvent.notes ?? "") ?? ekEvent.url
            return CalendarMeeting(
                id: ekEvent.eventIdentifier ?? UUID().uuidString,
                title: ekEvent.title ?? "Untitled Event",
                startDate: ekEvent.startDate,
                endDate: ekEvent.endDate,
                location: ekEvent.location,
                joinURL: joinURL,
                isAllDay: ekEvent.isAllDay
            )
        }.sorted { $0.startDate < $1.startDate }
        
        if self.todayEvents.isEmpty {
            self.todayEvents = generateSampleEvents()
        }
    }
    
    private func extractMeetingURL(from text: String) -> URL? {
        let patterns = [
            "https://[a-zA-Z0-9.-]*zoom.us/j/[a-zA-Z0-9?=_&-]+",
            "https://meet.google.com/[a-zA-Z0-9-]+",
            "https://teams.microsoft.com/l/meetup-join/[a-zA-Z0-9%?=_&-]+"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
                if let range = Range(match.range, in: text) {
                    return URL(string: String(text[range]))
                }
            }
        }
        return nil
    }
    
    private func generateSampleEvents() -> [CalendarMeeting] {
        let calendar = Calendar.current
        let now = Date()
        
        let start1 = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now) ?? now
        let end1 = calendar.date(bySettingHour: 10, minute: 45, second: 0, of: now) ?? now
        
        let start2 = calendar.date(bySettingHour: 13, minute: 30, second: 0, of: now) ?? now
        let end2 = calendar.date(bySettingHour: 14, minute: 30, second: 0, of: now) ?? now
        
        let start3 = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: now) ?? now
        let end3 = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: now) ?? now
        
        return [
            CalendarMeeting(
                id: "sample-1",
                title: "Product Architecture Review",
                startDate: start1,
                endDate: end1,
                location: "Google Meet",
                joinURL: URL(string: "https://meet.google.com/abc-defg-hij"),
                isAllDay: false
            ),
            CalendarMeeting(
                id: "sample-2",
                title: "Design Sync: Liquid Glass UI",
                startDate: start2,
                endDate: end2,
                location: "Zoom Video Call",
                joinURL: URL(string: "https://zoom.us/j/1234567890"),
                isAllDay: false
            ),
            CalendarMeeting(
                id: "sample-3",
                title: "Master Dock Release Planning",
                startDate: start3,
                endDate: end3,
                location: "Conference Room A",
                joinURL: nil,
                isAllDay: false
            )
        ]
    }
}
