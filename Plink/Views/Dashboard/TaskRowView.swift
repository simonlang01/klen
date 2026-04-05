import SwiftUI

struct TaskRowView: View {
    let item: TodoItem
    var isSelected: Bool = false
    let onComplete: () -> Void
    let onDelete: () -> Void
    let onSelect: () -> Void

    @State private var hovering = false
    @State private var checkHovering = false
    @Environment(\.appAccent) private var accent

    private var isOverdue: Bool {
        guard let due = item.dueDate, !item.isCompleted else { return false }
        if item.hasDueTime { return due < Date() }
        return due < Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        HStack(spacing: 12) {

            // ── Circular checkbox ────────────────────────────────
            Button(action: onComplete) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            item.isCompleted
                                ? Color.clear
                                : (checkHovering ? accent : Color.primary.opacity(0.2)),
                            lineWidth: 1.5
                        )
                        .frame(width: 20, height: 20)

                    Circle()
                        .fill(item.isCompleted ? accent : Color.clear)
                        .frame(width: 20, height: 20)

                    if item.isCompleted {
                        Image(systemName: "checkmark")
                            .scaledFont(size: 10, weight: .bold)
                            .foregroundStyle(.white)
                    } else if checkHovering {
                        Image(systemName: "checkmark")
                            .scaledFont(size: 10, weight: .bold)
                            .foregroundStyle(accent.opacity(0.5))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: item.isCompleted)
                .animation(.easeInOut(duration: 0.12), value: checkHovering)
            }
            .buttonStyle(.plain)
            .onHover { checkHovering = $0 }

            // ── Text content ─────────────────────────────────────
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .scaledFont(size: 13.5, weight: item.isCompleted ? .regular : .medium)
                    .foregroundStyle(item.isCompleted ? .tertiary : .primary)
                    .strikethrough(item.isCompleted, color: Color.primary.opacity(0.3))
                    .lineLimit(1)
                    .animation(.easeInOut(duration: 0.15), value: item.isCompleted)

                if !item.desc.isEmpty {
                    Text(item.desc)
                        .scaledFont(size: 12)
                        .foregroundStyle(.quaternary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // ── Delete button (hover) ────────────────────────────
            if hovering && !item.isCompleted {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .scaledFont(size: 14)
                        .foregroundStyle(Color.secondary.opacity(0.35))
                }
                .buttonStyle(.plain)
                .help(LocalizedStringKey("action.delete"))
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }

            // ── Badges ───────────────────────────────────────────
            HStack(spacing: 6) {
                if let bs = item.blockingStatus, bs != .none {
                    BlockingBadge(status: bs)
                }

                HStack(spacing: 5) {
                    if !item.attachments.isEmpty {
                        Image(systemName: "paperclip")
                            .scaledFont(size: 11)
                            .foregroundStyle(.quaternary)
                    }
                    if !item.links.isEmpty {
                        Image(systemName: "link")
                            .scaledFont(size: 11)
                            .foregroundStyle(.quaternary)
                    }
                    if !item.locationAddress.isEmpty {
                        Image(systemName: "mappin")
                            .scaledFont(size: 11)
                            .foregroundStyle(.quaternary)
                    }
                }

                if item.isRecurring {
                    Image(systemName: "arrow.2.circlepath")
                        .scaledFont(size: 10)
                        .foregroundStyle(.quaternary)
                }

                if item.priority != .none {
                    PriorityDot(priority: item.priority)
                }

                if let due = item.dueDate {
                    DueDateLabel(date: due, hasDueTime: item.hasDueTime, isOverdue: isOverdue)
                }
            }
            .opacity(item.isCompleted ? 0.4 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected
                      ? accent.opacity(0.08)
                      : hovering ? Color.primary.opacity(0.035) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? accent.opacity(0.18) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: hovering)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
        .contextMenu {
            Button(LocalizedStringKey("task.edit")) { onSelect() }
            Button(item.isCompleted
                   ? LocalizedStringKey("task.markIncomplete")
                   : LocalizedStringKey("task.markComplete"), action: onComplete)
            Divider()
            Button("action.delete", role: .destructive, action: onDelete)
        }
        .draggable(item.id.uuidString)
    }
}

// MARK: – Circular checkbox (standalone, for reuse)

struct CircularCheckbox: View {
    let isCompleted: Bool
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.appAccent) private var accent

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(
                        isCompleted ? Color.clear : (hovering ? accent : Color.primary.opacity(0.2)),
                        lineWidth: 1.5
                    )
                Circle()
                    .fill(isCompleted ? accent : Color.clear)
                if isCompleted {
                    Image(systemName: "checkmark")
                        .scaledFont(size: 10, weight: .bold)
                        .foregroundStyle(.white)
                } else if hovering {
                    Image(systemName: "checkmark")
                        .scaledFont(size: 10, weight: .bold)
                        .foregroundStyle(accent.opacity(0.5))
                }
            }
            .frame(width: 20, height: 20)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCompleted)
            .animation(.easeInOut(duration: 0.12), value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: – Priority dot

private struct PriorityDot: View {
    let priority: Priority
    @Environment(\.appAccent) private var accent

    private var color: Color {
        switch priority {
        case .high:   return .red.opacity(0.75)
        case .medium: return .orange.opacity(0.75)
        case .low:    return accent.opacity(0.75)
        case .none:   return .clear
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(priority.chipLabel)
                .scaledFont(size: 11)
                .foregroundStyle(color)
        }
    }
}

// MARK: – Due date label

private struct DueDateLabel: View {
    let date: Date
    let hasDueTime: Bool
    let isOverdue: Bool

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none; return f
    }()

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "calendar")
                .scaledFont(size: 10)
            Text(Self.dateFmt.string(from: date))
            if hasDueTime {
                Text("·").opacity(0.5)
                Text(Self.timeFmt.string(from: date))
            }
        }
        .scaledFont(size: 11)
        .foregroundStyle(isOverdue ? Color.red.opacity(0.8) : Color.primary.opacity(0.35))
    }
}

// MARK: – Blocking badge

private struct BlockingBadge: View {
    let status: BlockingStatus

    private var color: Color { status == .blocking ? .red : .orange }
    private var icon: String { status == .blocking ? "exclamationmark.circle.fill" : "hand.raised.fill" }
    private var label: String {
        status == .blocking
            ? NSLocalizedString("blocking.status.blocking", comment: "")
            : NSLocalizedString("blocking.status.blocked", comment: "")
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).scaledFont(size: 9, weight: .semibold)
            Text(label).scaledFont(size: 11, weight: .medium)
        }
        .foregroundStyle(color.opacity(0.85))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.10), in: Capsule())
    }
}
