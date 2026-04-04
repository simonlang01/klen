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
