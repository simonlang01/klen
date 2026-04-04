import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var groupFilter: GroupFilter
    @Binding var showTrash: Bool
    @Query(sort: \TodoGroup.name) private var groups: [TodoGroup]
    @Query private var allItems: [TodoItem]
    @Environment(\.modelContext) private var ctx
    @State private var newGroupName = ""
    @State private var isAdding = false
    @State private var groupPendingDelete: TodoGroup? = nil
    @FocusState private var fieldFocused: Bool
    @Environment(\.appAccent) private var accent

    private var trashCount: Int { allItems.filter { $0.isDeleted || $0.isCompleted }.count }

    // MARK: – Count helpers

    private func openCount(for filter: GroupFilter) -> Int {
        allItems.filter { item in
            !item.isCompleted && !item.isDeleted && belongsTo(item, filter: filter)
        }.count
    }

    private func overdueCount(for filter: GroupFilter) -> Int {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return allItems.filter { item in
            !item.isCompleted && !item.isDeleted &&
            (item.dueDate.map { $0 < startOfToday } ?? false) &&
            belongsTo(item, filter: filter)
        }.count
    }

    private func belongsTo(_ item: TodoItem, filter: GroupFilter) -> Bool {
        switch filter {
        case .all:          return true
        case .unassigned:   return item.group == nil
        case .group(let g): return item.group?.id == g.id
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // All Tasks
            SidebarRow(
                label: NSLocalizedString("group.allTasks", comment: ""),
                icon: "tray.full",
                isSelected: groupFilter == .all
            ) {
                groupFilter = .all; showTrash = false
            }

            Divider().padding(.horizontal, 12).padding(.vertical, 6)

            // Unassigned (always visible, not deletable)
            SidebarRow(
                label: NSLocalizedString("group.unassigned", comment: ""),
                icon: "tray",
                isSelected: groupFilter == .unassigned,
                openCount: openCount(for: .unassigned),
                overdueCount: overdueCount(for: .unassigned)
            ) {
                groupFilter = .unassigned; showTrash = false
            }

            if !groups.isEmpty {
                Divider().padding(.horizontal, 12).padding(.vertical, 6)
                ForEach(groups) { group in
                    SidebarRow(
                        label: group.name,
                        icon: "folder",
                        isSelected: groupFilter == .group(group),
                        openCount: openCount(for: .group(group)),
                        overdueCount: overdueCount(for: .group(group))
                    ) {
                        groupFilter = .group(group); showTrash = false
                    }
                    .contextMenu {
                        Button("action.delete", role: .destructive) {
                            groupPendingDelete = group
                        }
                    }
                }
            }

            Divider().padding(.horizontal, 12).padding(.vertical, 6)

            if isAdding {
                HStack(spacing: 6) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 13))
                        .foregroundStyle(accent)
                        .frame(width: 20)
                    TextField("group.new", text: $newGroupName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($fieldFocused)
                        .onSubmit { commitGroup() }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
            } else {
                Button {
                    isAdding = true; fieldFocused = true
                } label: {
                    Label("group.new", systemImage: "plus")
                        .font(.system(size: 12))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }

            Spacer()

            Divider().padding(.horizontal, 12).padding(.bottom, 4)

            // Trash row
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(showTrash ? Color.red.opacity(0.7) : .secondary)
                    .frame(width: 20)
                Text("trash.title")
                    .font(.system(size: 13))
                    .foregroundStyle(showTrash ? .primary : .secondary)
                Spacer()
                if trashCount > 0 {
                    Text("\(trashCount)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.4), in: Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(showTrash ? Color.red.opacity(0.08) : Color.clear)
                    .padding(.horizontal, 6)
            )
            .contentShape(Rectangle())
            .onTapGesture { showTrash = true; groupFilter = .all }
            .padding(.bottom, 8)
        }
        .padding(.top, 12)
        .frame(minWidth: 180, maxWidth: 220)
        .background(.background)
        .confirmationDialog(
            groupPendingDelete.map { String(format: NSLocalizedString("group.delete.confirm.title", comment: ""), $0.name) } ?? "",
            isPresented: Binding(get: { groupPendingDelete != nil }, set: { if !$0 { groupPendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            if let group = groupPendingDelete {
                let taskCount = allItems.filter { $0.group?.id == group.id && !$0.isDeleted }.count
                Button(String(format: NSLocalizedString("group.delete.withTasks", comment: ""), taskCount), role: .destructive) {
                    deleteGroup(group, moveTasks: false)
                }
                Button(LocalizedStringKey("group.delete.keepTasks")) {
                    deleteGroup(group, moveTasks: true)
                }
                Button(LocalizedStringKey("action.cancel"), role: .cancel) { groupPendingDelete = nil }
            }
        } message: {
            if let group = groupPendingDelete {
                let taskCount = allItems.filter { $0.group?.id == group.id && !$0.isDeleted }.count
                let taskSuffix = taskCount > 0 ? String(format: NSLocalizedString("group.delete.confirm.tasks", comment: ""), taskCount) : ""
                Text(String(format: NSLocalizedString("group.delete.confirm.message", comment: ""), group.name, taskSuffix))
            }
        }
    }

    private func commitGroup() {
        let name = newGroupName.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { ctx.insert(TodoGroup(name: name)) }
        newGroupName = ""; isAdding = false
    }

    private func deleteGroup(_ group: TodoGroup, moveTasks: Bool) {
        if groupFilter == .group(group) { groupFilter = .all }
        let groupItems = allItems.filter { $0.group?.id == group.id }
        if moveTasks {
            groupItems.forEach { $0.group = nil }
        } else {
            let now = Date()
            groupItems.forEach { item in
                item.group = nil; item.isDeleted = true; item.deletedAt = now
            }
        }
        ctx.delete(group)
        groupPendingDelete = nil
    }
}

// MARK: – Row

private struct SidebarRow: View {
    let label: String
    let icon: String
    let isSelected: Bool
    var openCount: Int = 0
    var overdueCount: Int = 0
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.appAccent) private var accent

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? accent : .secondary)
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                Spacer()
                // Count badges
                if overdueCount > 0 {
                    Text("\(overdueCount)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.red.opacity(0.75), in: Capsule())
                } else if openCount > 0 {
                    Text("\(openCount)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isSelected ? accent : .secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            (isSelected ? accent : Color.primary).opacity(0.08),
                            in: Capsule()
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? accent.opacity(0.12) : (hovering ? Color.primary.opacity(0.04) : Color.clear))
                    .padding(.horizontal, 6)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
