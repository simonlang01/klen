import Foundation
import SwiftUI
import SwiftData
// MARK: – TaskAttachment

@Model
final class TaskAttachment {
    var id: UUID
    var filename: String
    var filePath: String
    var typeIdentifier: String
    var task: TodoItem?

    init(filename: String, filePath: String, typeIdentifier: String = "") {
        self.id = UUID()
        self.filename = filename
        self.filePath = filePath
        self.typeIdentifier = typeIdentifier
    }

    var displayIcon: String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf":                          return "doc.richtext"
        case "png", "jpg", "jpeg", "heic", "gif", "webp": return "photo"
        case "docx", "doc":                  return "doc.text"
        case "xlsx", "xls":                  return "tablecells"
        case "pptx", "ppt":                  return "rectangle.on.rectangle"
        case "mp4", "mov", "avi", "mkv":     return "video"
        case "mp3", "m4a", "wav", "aac":     return "music.note"
        case "zip", "rar", "7z":             return "archivebox"
        default:                             return "paperclip"
        }
    }
}

// MARK: – BlockingStatus

enum BlockingStatus: Int, Codable {
    case none = 0
    case blocking  // I am blocking someone else
    case blocked   // I am blocked by someone else
}

// MARK: – Recurrence

enum RecurrenceFrequency: Int, Codable, CaseIterable {
    case none = 0, daily, weekly, monthly, yearly

    var label: String {
        switch self {
        case .none:    return NSLocalizedString("recurrence.none", comment: "")
        case .daily:   return NSLocalizedString("recurrence.daily", comment: "")
        case .weekly:  return NSLocalizedString("recurrence.weekly", comment: "")
        case .monthly: return NSLocalizedString("recurrence.monthly", comment: "")
        case .yearly:  return NSLocalizedString("recurrence.yearly", comment: "")
        }
    }

    var icon: String {
        switch self {
        case .none:    return "arrow.2.circlepath"
        case .daily:   return "sun.max"
        case .weekly:  return "calendar"
        case .monthly: return "calendar.badge.clock"
        case .yearly:  return "calendar.badge.plus"
        }
    }

    /// Returns the next due date from a given anchor date.
    func nextDate(from date: Date, interval: Int) -> Date {
        let cal = Calendar.current
        switch self {
        case .none:    return date
        case .daily:   return cal.date(byAdding: .day,   value: interval, to: date) ?? date
        case .weekly:  return cal.date(byAdding: .weekOfYear, value: interval, to: date) ?? date
        case .monthly: return cal.date(byAdding: .month, value: interval, to: date) ?? date
        case .yearly:  return cal.date(byAdding: .year,  value: interval, to: date) ?? date
        }
    }
}

// MARK: – Priority

enum Priority: Int, Codable, CaseIterable {
    case none = 0, low, medium, high

    var chipLabel: String {
        switch self {
        case .none:   return NSLocalizedString("priority.none", comment: "")
        case .low:    return NSLocalizedString("priority.low", comment: "")
        case .medium: return NSLocalizedString("priority.medium", comment: "")
        case .high:   return NSLocalizedString("priority.high", comment: "")
        }
    }

    var color: Color {
        switch self {
        case .none:   return .secondary
        case .low:    return Theme.defaultAccent
        case .medium: return .orange
        case .high:   return .red
        }
    }
}

@Model
final class TodoItem {
    var id: UUID
    var title: String
    var desc: String
    var priority: Priority
    var dueDate: Date?
    var hasDueTime: Bool = false
    var isCompleted: Bool
    var isDeleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var deletedAt: Date?
    var group: TodoGroup?
    @Relationship(deleteRule: .cascade)
    var attachments: [TaskAttachment] = []
    var links: [String] = []
    var locationAddress: String = ""
    var blockingStatus: BlockingStatus?
    var recurrenceFrequency: Int = 0   // RecurrenceFrequency.rawValue
    var recurrenceInterval: Int  = 1   // every N units

    var recurrence: RecurrenceFrequency {
        get { RecurrenceFrequency(rawValue: recurrenceFrequency) ?? .none }
        set { recurrenceFrequency = newValue.rawValue }
    }

    var isRecurring: Bool { recurrence != .none }

    /// Spawns the next occurrence. Call after marking this item completed.
    func spawnNextOccurrence(in context: ModelContext) {
        guard let anchor = dueDate, isRecurring else { return }
        let nextDate = recurrence.nextDate(from: anchor, interval: recurrenceInterval)
        let next = TodoItem(title: title, desc: desc, priority: priority,
                            dueDate: nextDate, group: group)
        next.hasDueTime          = hasDueTime
        next.links               = links
        next.locationAddress     = locationAddress
        next.blockingStatus      = blockingStatus
        next.recurrenceFrequency = recurrenceFrequency
        next.recurrenceInterval  = recurrenceInterval
        context.insert(next)
        Task { @MainActor in NotificationManager.shared.schedule(for: next) }
    }

    init(
        title: String,
        desc: String = "",
        priority: Priority = .none,
        dueDate: Date? = nil,
        group: TodoGroup? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.desc = desc
        self.priority = priority
        self.dueDate = dueDate
        self.isCompleted = false
        self.isDeleted = false
        self.createdAt = Date()
        self.group = group
    }
}
