import Foundation
import SwiftData

@Model
final class TodoGroup {
    var id: UUID
    var name: String
    var createdAt: Date
    var colorHex: String?
    @Relationship(deleteRule: .nullify) var items: [TodoItem]

    init(name: String, colorHex: String? = nil) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.colorHex = colorHex
        self.items = []
    }
}
