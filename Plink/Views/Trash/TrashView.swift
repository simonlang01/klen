import SwiftUI
import SwiftData

struct TrashView: View {
    @Query private var allItems: [TodoItem]
    @Environment(\.modelContext) private var ctx
    @Environment(\.appAccent) private var accent

    private var deleted: [TodoItem]   { allItems.filter { $0.isDeleted }.sorted { $0.createdAt > $1.createdAt } }
    private var completed: [TodoItem] { allItems.filter { $0.isCompleted && !$0.isDeleted }.sorted { $0.createdAt > $1.createdAt } }

    var body: some View {
        Group {
            if deleted.isEmpty && completed.isEmpty {
                emptyState
            } else {
                ScrollView {
                    retentionNote
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        if !deleted.isEmpty {
                            SwiftUI.Section {
                                ForEach(deleted) { item in
                                    TrashRowView(item: item, onRestore: { restore(item) }, onDelete: { permanentlyDelete(item) })
                                }
                            } header: {
                                TrashSectionHeader(title: NSLocalizedString("trash.section.deleted", comment: ""), icon: "trash", count: deleted.count) {
                                    deleted.forEach { permanentlyDelete($0) }
                                }
                            }
                        }

                        if !completed.isEmpty {
                            SwiftUI.Section {
                                ForEach(completed) { item in
                                    TrashRowView(item: item, onRestore: { restore(item) }, onDelete: { permanentlyDelete(item) })
                                }
                            } header: {
                                TrashSectionHeader(title: NSLocalizedString("trash.section.completed", comment: ""), icon: "checkmark.circle", count: completed.count) {
                                    completed.forEach { permanentlyDelete($0) }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !deleted.isEmpty || !completed.isEmpty {
                    Button(role: .destructive) {
                        (deleted + completed).forEach { permanentlyDelete($0) }
                    } label: {
                        Label(LocalizedStringKey("trash.emptyAction"), systemImage: "trash")
                            .font(.system(size: 12))
                    }
                    .help(LocalizedStringKey("trash.emptyHelp"))
                }
            }
        }
    }

    private var retentionNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("trash.retention")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.03))
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(Color.primary.opacity(0.08)), alignment: .bottom)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "trash")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(accent.opacity(0.35))
            Text("trash.empty.title")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            Text("trash.empty.subtitle")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            Text("trash.retention")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func restore(_ item: TodoItem) {
        withAnimation {
            item.isDeleted = false
            item.isCompleted = false
            item.completedAt = nil
            item.deletedAt = nil
        }
    }

    private func permanentlyDelete(_ item: TodoItem) {
        withAnimation { ctx.delete(item) }
    }
}

// MARK: – Section header

private struct TrashSectionHeader: View {
    let title: String
    let icon: String
    let count: Int
    let onClearSection: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Text("\(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            Spacer()
            Button(LocalizedStringKey("trash.clear"), action: onClearSection)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .padding(.bottom, 4)
        .background(.background)
    }
}

// MARK: – Row

private struct TrashRowView: View {
    let item: TodoItem
    let onRestore: () -> Void
    let onDelete: () -> Void
    @State private var hovering = false
    @Environment(\.appAccent) private var accent

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.isDeleted ? "trash" : "checkmark.circle")
                .font(.system(size: 13))
                .foregroundStyle(item.isDeleted ? Color.secondary.opacity(0.4) : accent.opacity(0.5))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .strikethrough(true, color: .secondary.opacity(0.5))
                    .lineLimit(1)
                if !item.desc.isEmpty {
                    Text(item.desc)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if hovering {
                HStack(spacing: 6) {
                    Button {
                        onRestore()
                    } label: {
                        Label(LocalizedStringKey("action.restore"), systemImage: "arrow.uturn.backward")
                            .font(.system(size: 11))
                            .foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onDelete()
                    } label: {
                        Label(LocalizedStringKey("action.delete"), systemImage: "xmark")
                            .font(.system(size: 11))
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                if let due = item.dueDate {
                    Text(due, style: .date)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                if item.priority != .none {
                    Circle()
                        .fill(item.priority.color.opacity(0.6))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(hovering ? Color.primary.opacity(0.04) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .animation(.easeInOut(duration: 0.15), value: hovering)
        .onHover { hovering = $0 }
        .contextMenu {
            Button(LocalizedStringKey("action.restore"), action: onRestore)
            Divider()
            Button(LocalizedStringKey("action.deletePermanently"), role: .destructive, action: onDelete)
        }
    }
}
