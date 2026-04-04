import SwiftUI
import SwiftData

struct MenuBarPopoverView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.appAccent) private var accent

    @Query(filter: #Predicate<TodoItem> { !$0.isDeleted && !$0.isCompleted },
           sort: \TodoItem.dueDate)
    private var allOpen: [TodoItem]

    @State private var quickTitle = ""
    @FocusState private var quickFocused: Bool

    var onOpenApp: () -> Void

    // Show overdue + tasks due today
    private var visibleTasks: [TodoItem] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        return allOpen.filter { item in
            guard let due = item.dueDate else { return false }
            return due < tomorrow
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Plink")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if !visibleTasks.isEmpty {
                    Text("\(visibleTasks.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accent, in: Capsule())
                }
                Button(action: onOpenApp) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("menubar.openPlink", comment: ""))
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Quick add
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(accent.opacity(0.8))
                TextField(LocalizedStringKey("menubar.newTask.placeholder"), text: $quickTitle)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .focused($quickFocused)
                    .onSubmit { addQuick() }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Task list
            if visibleTasks.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(accent.opacity(0.5))
                    Text(LocalizedStringKey("menubar.noTasksToday"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visibleTasks) { item in
                            PopoverTaskRow(item: item) {
                                complete(item)
                            }
                            if item.id != visibleTasks.last?.id {
                                Divider().padding(.leading, 38)
                            }
                        }
                    }
                }
                .frame(maxHeight: 260)
            }

            Divider()

            // Footer
            Button(action: onOpenApp) {
                HStack {
                    Text(LocalizedStringKey("menubar.openPlink"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .frame(width: 300)
        .onAppear { quickFocused = true }
    }

    private func addQuick() {
        let t = quickTitle.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        let item = TodoItem(title: t)
        ctx.insert(item)
        quickTitle = ""
    }

    private func complete(_ item: TodoItem) {
        let wasCompleted = item.isCompleted
        item.isCompleted = true
        item.completedAt = Date()
        if !wasCompleted { item.spawnNextOccurrence(in: ctx) }
    }
}

// MARK: – Compact task row

private struct PopoverTaskRow: View {
    let item: TodoItem
    let onComplete: () -> Void
    @Environment(\.appAccent) private var accent
    @State private var checkHovering = false

    private var isOverdue: Bool {
        guard let due = item.dueDate, !item.isCompleted else { return false }
        if item.hasDueTime { return due < Date() }
        return due < Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        HStack(spacing: 10) {
            // Checkbox
            Button(action: onComplete) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            checkHovering ? accent : Color.primary.opacity(0.2),
                            lineWidth: 1.5
                        )
                        .frame(width: 18, height: 18)
                    if checkHovering {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(accent.opacity(0.5))
                    }
                }
                .animation(.easeInOut(duration: 0.12), value: checkHovering)
            }
            .buttonStyle(.plain)
            .onHover { checkHovering = $0 }

            // Title
            Text(item.title)
                .font(.system(size: 12.5))
                .lineLimit(1)
                .foregroundStyle(.primary)

            Spacer()

            // Due indicator
            if let due = item.dueDate {
                HStack(spacing: 3) {
                    Text(shortDate(due))
                    if item.hasDueTime {
                        Text("·").opacity(0.5)
                        Text(Self.timeFmt.string(from: due))
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(isOverdue ? Color.red.opacity(0.7) : Color.primary.opacity(0.3))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none; return f
    }()

    private func shortDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return NSLocalizedString("section.today", comment: "") }
        if cal.isDateInYesterday(date) { return NSLocalizedString("section.yesterday", comment: "") }
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .none
        return fmt.string(from: date)
    }
}
