import Foundation
import SwiftData

@Model
final class TodoGroup {
    var id: UUID
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .nullify) var items: [TodoItem]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.items = []
    }
}
