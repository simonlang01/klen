import Foundation
import AppKit
import SwiftData

// MARK: – Data Transfer Objects

private struct BackupFile: Codable {
    var version: Int = 1
    var exportedAt: Date
    var groups: [GroupDTO]
    var items: [ItemDTO]
}

private struct GroupDTO: Codable {
    var id: UUID
    var name: String
    var createdAt: Date
}

private struct ItemDTO: Codable {
    var id: UUID
    var title: String
    var desc: String
    var priority: Int
    var dueDate: Date?
    var isCompleted: Bool
    var isDeleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var deletedAt: Date?
    var groupID: UUID?
    var links: [String]
    var locationAddress: String
    var blockingStatus: Int?
    var attachments: [AttachmentDTO]
}

private struct AttachmentDTO: Codable {
    var id: UUID
    var filename: String
    var typeIdentifier: String
    var data: Data?          // base64-encoded file contents; nil if file was missing at export time
}

// MARK: – BackupManager

@MainActor
final class BackupManager {

    static let shared = BackupManager()
    private init() {}

    // MARK: Export

    func export(context: ModelContext) async {
        guard
            let groups = try? context.fetch(FetchDescriptor<TodoGroup>()),
            let items  = try? context.fetch(FetchDescriptor<TodoItem>())
        else { showAlert(title: NSLocalizedString("backup.error.title", comment: ""), message: NSLocalizedString("backup.export.error.fetch", comment: "")); return }

        // Build DTOs
        let groupDTOs = groups.map { GroupDTO(id: $0.id, name: $0.name, createdAt: $0.createdAt) }

        let itemDTOs: [ItemDTO] = items.map { item in
            let attDTOs = item.attachments.map { att -> AttachmentDTO in
                let fileData = try? Data(contentsOf: URL(fileURLWithPath: att.filePath))
                return AttachmentDTO(id: att.id, filename: att.filename, typeIdentifier: att.typeIdentifier, data: fileData)
            }
            return ItemDTO(
                id: item.id,
                title: item.title,
                desc: item.desc,
                priority: item.priority.rawValue,
                dueDate: item.dueDate,
                isCompleted: item.isCompleted,
                isDeleted: item.isDeleted,
                createdAt: item.createdAt,
                completedAt: item.completedAt,
                deletedAt: item.deletedAt,
                groupID: item.group?.id,
                links: item.links,
                locationAddress: item.locationAddress,
                blockingStatus: item.blockingStatus?.rawValue,
                attachments: attDTOs
            )
        }

        let backup = BackupFile(exportedAt: Date(), groups: groupDTOs, items: itemDTOs)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let jsonData = try? encoder.encode(backup) else {
            showAlert(title: NSLocalizedString("backup.error.title", comment: ""), message: NSLocalizedString("backup.export.error.encode", comment: "")); return
        }

        // Save panel
        let panel = NSSavePanel()
        panel.title = NSLocalizedString("backup.export.panel.title", comment: "")
        panel.nameFieldStringValue = "Plink-Backup-\(Self.dateStamp()).plinkbackup"
        panel.allowedContentTypes = [.init(exportedAs: "com.plink.backup", conformingTo: .json)]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let dest = panel.url else { return }

        let accessing = dest.startAccessingSecurityScopedResource()
        defer { if accessing { dest.stopAccessingSecurityScopedResource() } }

        do {
            try jsonData.write(to: dest, options: .atomic)
        } catch {
            showAlert(title: NSLocalizedString("backup.error.title", comment: ""), message: error.localizedDescription)
        }
    }

    // MARK: Import

    func `import`(context: ModelContext) async {
        let panel = NSOpenPanel()
        panel.title = NSLocalizedString("backup.import.panel.title", comment: "")
        panel.allowedContentTypes = [.init(exportedAs: "com.plink.backup", conformingTo: .json)]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let src = panel.url else { return }
        guard await confirmReplace() else { return }

        let accessing = src.startAccessingSecurityScopedResource()
        defer { if accessing { src.stopAccessingSecurityScopedResource() } }

        guard let jsonData = try? Data(contentsOf: src) else {
            showAlert(title: NSLocalizedString("backup.error.title", comment: ""), message: NSLocalizedString("backup.import.error.read", comment: "")); return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(BackupFile.self, from: jsonData) else {
            showAlert(title: NSLocalizedString("backup.error.title", comment: ""), message: NSLocalizedString("backup.import.error.decode", comment: "")); return
        }

        // Delete all existing data (cascade deletes attachments)
        if let existingItems = try? context.fetch(FetchDescriptor<TodoItem>()) {
            existingItems.forEach { context.delete($0) }
        }
        if let existingGroups = try? context.fetch(FetchDescriptor<TodoGroup>()) {
            existingGroups.forEach { context.delete($0) }
        }

        // Prepare attachments directory
        let attachmentsDir = PersistenceController.dataDirectory
            .appending(path: "Attachments", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)

        // Insert groups
        var groupIndex: [UUID: TodoGroup] = [:]
        for dto in backup.groups {
            let g = TodoGroup(name: dto.name)
            g.id = dto.id
            g.createdAt = dto.createdAt
            context.insert(g)
            groupIndex[dto.id] = g
        }

        // Insert items + attachments
        for dto in backup.items {
            let item = TodoItem(title: dto.title)
            item.id           = dto.id
            item.desc         = dto.desc
            item.priority     = Priority(rawValue: dto.priority) ?? .none
            item.dueDate      = dto.dueDate
            item.isCompleted  = dto.isCompleted
            item.isDeleted    = dto.isDeleted
            item.createdAt    = dto.createdAt
            item.completedAt  = dto.completedAt
            item.deletedAt    = dto.deletedAt
            item.links        = dto.links
            item.locationAddress = dto.locationAddress
            item.blockingStatus  = dto.blockingStatus.flatMap { BlockingStatus(rawValue: $0) }
            item.group           = dto.groupID.flatMap { groupIndex[$0] }

            for attDTO in dto.attachments {
                let ext = URL(fileURLWithPath: attDTO.filename).pathExtension
                let destFile = attachmentsDir.appending(path: "\(attDTO.id).\(ext)")
                if let data = attDTO.data {
                    try? data.write(to: destFile, options: .atomic)
                }
                let att = TaskAttachment(filename: attDTO.filename, filePath: destFile.path, typeIdentifier: attDTO.typeIdentifier)
                att.id   = attDTO.id
                att.task = item
                context.insert(att)
                item.attachments.append(att)
            }
            context.insert(item)
        }

        do {
            try context.save()
        } catch {
            showAlert(title: NSLocalizedString("backup.error.title", comment: ""), message: error.localizedDescription)
        }
    }

    // MARK: Helpers

    private func confirmReplace() async -> Bool {
        await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText     = NSLocalizedString("backup.import.confirm.title", comment: "")
            alert.informativeText = NSLocalizedString("backup.import.confirm.message", comment: "")
            alert.alertStyle      = .warning
            alert.addButton(withTitle: NSLocalizedString("backup.import.confirm.button", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("action.cancel", comment: ""))
            continuation.resume(returning: alert.runModal() == .alertFirstButtonReturn)
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText     = title
        alert.informativeText = message
        alert.alertStyle      = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static func dateStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
