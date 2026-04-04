import SwiftUI

struct TaskRowView: View {
    let item: TodoItem
    var isSelected: Bool = false
    let onComplete: () -> Void
    let onDelete: () -> Void
    let onSelect: () -> Void

    @State private var hovering = false
    @Environment(\.appAccent) private var accent

    private var isOverdue: Bool {
        guard let due = item.dueDate else { return false }
        if item.hasDueTime { return due < Date() && !item.isCompleted }
        return due < Calendar.current.startOfDay(for: Date()) && !item.isCompleted
    }

    var body: some View {
        ZStack(alignment: .trailing) {

            // ── Row content (slides left on hover) ──────────────
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 14))
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                        .strikethrough(item.isCompleted, color: .secondary)
                        .lineLimit(1)

                    if !item.desc.isEmpty {
                        Text(item.desc)
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                HStack(spacing: 7) {
                    if let bs = item.blockingStatus, bs != .none {
                        BlockingBadge(status: bs)
                    }
                    if item.priority != .none {
                        PriorityBadge(priority: item.priority)
                    }
                    if !item.attachments.isEmpty {
                        Image(systemName: "paperclip")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    if !item.links.isEmpty {
                        Image(systemName: "link")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    if !item.locationAddress.isEmpty {
                        Image(systemName: "mappin")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    if let due = item.dueDate {
                        HStack(spacing: 3) {
                            Text(due, style: .date)
                            if item.hasDueTime {
                                Text("·").opacity(0.5)
                                Text(due, style: .time)
                            }
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(isOverdue ? AnyShapeStyle(Color.red.opacity(0.8)) : AnyShapeStyle(.tertiary))
                    }
                    if let group = item.group {
                        Text(group.name)
                            .font(.system(size: 11))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(accent.opacity(0.12), in: Capsule())
                            .foregroundStyle(accent)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .padding(.trailing, hovering ? 76 : 0)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isSelected
                          ? accent.opacity(0.10)
                          : hovering ? Color.primary.opacity(0.04) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(isSelected ? accent.opacity(0.25) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }
            .animation(.spring(duration: 0.2), value: hovering)
            .animation(.spring(duration: 0.15), value: isSelected)

            // ── Complete button ──────────────────────────────────
            Button(action: onComplete) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(item.isCompleted ? Color.secondary.opacity(0.1) : accent.opacity(0.12))
                    Image(systemName: item.isCompleted ? "arrow.uturn.backward" : "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(item.isCompleted ? .secondary : accent)
                }
                .frame(width: 68)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .scaleEffect(x: hovering ? 1 : 0.7, anchor: .trailing)
            .allowsHitTesting(hovering)
            .animation(.spring(duration: 0.2), value: hovering)
        }
        .onHover { hovering = $0 }
        .contextMenu {
            Button(LocalizedStringKey("task.edit")) { onSelect() }
            Button(item.isCompleted ? LocalizedStringKey("task.markIncomplete") : LocalizedStringKey("task.markComplete"), action: onComplete)
            Divider()
            Button("action.delete", role: .destructive, action: onDelete)
        }
    }
}

private struct BlockingBadge: View {
    let status: BlockingStatus
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status == .blocking ? "exclamationmark.circle.fill" : "hand.raised.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(status == .blocking
                 ? NSLocalizedString("blocking.status.blocking", comment: "")
                 : NSLocalizedString("blocking.status.blocked", comment: ""))
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(status == .blocking ? Color.red.opacity(0.85) : Color.orange.opacity(0.85))
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(
            (status == .blocking ? Color.red : Color.orange).opacity(0.12),
            in: Capsule()
        )
    }
}

private struct PriorityBadge: View {
    let priority: Priority
    @Environment(\.appAccent) private var accent
    var body: some View {
        Text(priority.chipLabel)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(badgeColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.12), in: Capsule())
    }
    private var badgeColor: Color {
        switch priority {
        case .high:   return .red.opacity(0.8)
        case .medium: return .orange.opacity(0.8)
        case .low:    return accent.opacity(0.8)
        case .none:   return .clear
        }
    }
}
