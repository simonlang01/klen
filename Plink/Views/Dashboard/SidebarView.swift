import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var groupFilter: GroupFilter
    @Binding var showTrash: Bool
    @Binding var showActivityLog: Bool
    @Query(sort: \TodoGroup.name) private var groups: [TodoGroup]
    @Query private var allItems: [TodoItem]
    @Environment(\.modelContext) private var ctx
    @Environment(\.openSettings) private var openSettings
    @State private var newGroupName = ""
    @State private var isAdding = false
    @State private var groupPendingDelete: TodoGroup? = nil
    @State private var groupPendingRename: TodoGroup? = nil
    @State private var renameText = ""
    @State private var dropTargetFilter: GroupFilter? = nil
    @FocusState private var fieldFocused: Bool
    @FocusState private var renameFocused: Bool
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

            // ── Navigation section ────────────────────────────────
            VStack(spacing: 1) {
                SidebarRow(
                    label: NSLocalizedString("group.allTasks", comment: ""),
                    icon: "tray.full",
                    isSelected: groupFilter == .all && !showTrash && !showActivityLog,
                    isDropTarget: dropTargetFilter == .all
                ) {
                    groupFilter = .all; showTrash = false; showActivityLog = false
                }
                .dropDestination(for: String.self) { items, _ in
                    items.forEach { assignTask(uuidString: $0, to: nil) }
                    return true
                } isTargeted: { dropTargetFilter = $0 ? .all : nil }

                SidebarRow(
                    label: NSLocalizedString("group.unassigned", comment: ""),
                    icon: "tray",
                    isSelected: groupFilter == .unassigned && !showTrash && !showActivityLog,
                    openCount: openCount(for: .unassigned),
                    overdueCount: overdueCount(for: .unassigned),
                    isDropTarget: dropTargetFilter == .unassigned
                ) {
                    groupFilter = .unassigned; showTrash = false; showActivityLog = false
                }
                .dropDestination(for: String.self) { items, _ in
                    items.forEach { assignTask(uuidString: $0, to: nil) }
                    return true
                } isTargeted: { dropTargetFilter = $0 ? .unassigned : nil }
            }
            .padding(.top, 10)

            // ── Groups ────────────────────────────────────────────
            if !groups.isEmpty {
                SidebarSectionLabel("sidebar.groups")

                VStack(spacing: 1) {
                    ForEach(groups) { group in
                        if groupPendingRename?.id == group.id {
                            SidebarRenameField(
                                icon: "folder",
                                text: $renameText,
                                focused: $renameFocused,
                                onCommit: commitRename,
                                onCancel: { groupPendingRename = nil }
                            )
                        } else {
                            SidebarRow(
                                label: group.name,
                                icon: "folder",
                                isSelected: groupFilter == .group(group) && !showTrash && !showActivityLog,
                                openCount: openCount(for: .group(group)),
                                overdueCount: overdueCount(for: .group(group)),
                                isDropTarget: dropTargetFilter == .group(group)
                            ) {
                                groupFilter = .group(group); showTrash = false; showActivityLog = false
                            }
                            .dropDestination(for: String.self) { items, _ in
                                items.forEach { assignTask(uuidString: $0, to: group) }
                                return true
                            } isTargeted: { dropTargetFilter = $0 ? .group(group) : nil }
                            .contextMenu {
                                Button("action.rename") {
                                    renameText = group.name
                                    groupPendingRename = group
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        renameFocused = true
                                    }
                                }
                                Divider()
                                Button("action.delete", role: .destructive) {
                                    groupPendingDelete = group
                                }
                            }
                        }
                    }
                }
            }

            // ── Add group ─────────────────────────────────────────
            if isAdding {
                SidebarRenameField(
                    icon: "folder.badge.plus",
                    text: $newGroupName,
                    focused: $fieldFocused,
                    onCommit: commitGroup,
                    onCancel: { isAdding = false; newGroupName = "" }
                )
                .padding(.top, groups.isEmpty ? 8 : 1)
            } else {
                Button {
                    isAdding = true; fieldFocused = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .scaledFont(size: 11, weight: .semibold)
                            .frame(width: 18)
                        Text(LocalizedStringKey("group.new"))
                            .scaledFont(size: 12)
                    }
                    .foregroundStyle(accent.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .padding(.top, groups.isEmpty ? 8 : 2)
            }

            Spacer()

            // ── Utility section ───────────────────────────────────
            Divider()
                .padding(.horizontal, 12)
                .padding(.bottom, 2)
                .padding(.top, 6)

            VStack(spacing: 1) {
                SidebarRow(
                    label: NSLocalizedString("activitylog.title", comment: ""),
                    icon: "chart.bar.doc.horizontal",
                    isSelected: showActivityLog
                ) {
                    showActivityLog = true; showTrash = false; groupFilter = .all
                }

                // Trash row — custom because of the count badge style difference
                SidebarRow(
                    label: NSLocalizedString("trash.title", comment: ""),
                    icon: "trash",
                    isSelected: showTrash,
                    openCount: trashCount,
                    overdueCount: 0,
                    isDestructive: true
                ) {
                    showTrash = true; showActivityLog = false; groupFilter = .all
                }

                SidebarRow(
                    label: NSLocalizedString("sidebar.settings", comment: ""),
                    icon: "gearshape",
                    isSelected: false
                ) {
                    openSettings()
                }
            }
            .padding(.bottom, 8)
        }
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

    // MARK: – Actions

    private func commitRename() {
        let name = renameText.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { groupPendingRename?.name = name }
        groupPendingRename = nil
    }

    private func commitGroup() {
        let name = newGroupName.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { ctx.insert(TodoGroup(name: name)) }
        newGroupName = ""; isAdding = false
    }

    private func assignTask(uuidString: String, to group: TodoGroup?) {
        guard let uuid = UUID(uuidString: uuidString),
              let item = allItems.first(where: { $0.id == uuid }) else { return }
        item.group = group
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

// MARK: – Section label

private struct SidebarSectionLabel: View {
    let key: LocalizedStringKey
    init(_ key: LocalizedStringKey) { self.key = key }

    var body: some View {
        Text(key)
            .scaledFont(size: 10, weight: .semibold)
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
            .tracking(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }
}

// MARK: – Inline rename field

private struct SidebarRenameField: View {
    let icon: String
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    let onCommit: () -> Void
    let onCancel: () -> Void
    @Environment(\.appAccent) private var accent

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .scaledFont(size: 12)
                .foregroundStyle(accent)
                .frame(width: 18)
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .scaledFont(size: 13)
                .focused(focused)
                .onSubmit { onCommit() }
                .onExitCommand { onCancel() }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }
}

// MARK: – Row

private struct SidebarRow: View {
    let label: String
    let icon: String
    let isSelected: Bool
    var openCount: Int = 0
    var overdueCount: Int = 0
    var isDestructive: Bool = false
    var isDropTarget: Bool = false
    let action: () -> Void

    @State private var hovering = false
    @Environment(\.appAccent) private var accent

    private var activeColor: Color { isDestructive ? .red.opacity(0.7) : accent }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {

                // Left accent stripe
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? activeColor : (isDropTarget ? activeColor.opacity(0.6) : Color.clear))
                    .frame(width: 3, height: 16)
                    .padding(.leading, 6)
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
                    .animation(.easeInOut(duration: 0.15), value: isDropTarget)

                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .scaledFont(size: 12, weight: isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected || isDropTarget ? activeColor : .secondary)
                        .frame(width: 18)
                        .animation(.easeInOut(duration: 0.12), value: isSelected)

                    Text(label)
                        .scaledFont(size: 13, weight: isSelected ? .medium : .regular)
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                        .animation(.easeInOut(duration: 0.12), value: isSelected)

                    Spacer()

                    // Count badges
                    if overdueCount > 0 {
                        Text("\(overdueCount)")
                            .scaledFont(size: 10, weight: .semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.75), in: Capsule())
                    } else if openCount > 0 {
                        Text("\(openCount)")
                            .scaledFont(size: 10, weight: .medium)
                            .foregroundStyle(isSelected ? activeColor : Color.primary.opacity(0.3))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                (isSelected ? activeColor : Color.primary).opacity(0.08),
                                in: Capsule()
                            )
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isDropTarget
                              ? activeColor.opacity(0.10)
                              : (isSelected ? activeColor.opacity(0.07)
                                 : (hovering ? Color.primary.opacity(0.04) : Color.clear)))
                )
                .animation(.easeInOut(duration: 0.15), value: isDropTarget)
                .padding(.trailing, 6)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
