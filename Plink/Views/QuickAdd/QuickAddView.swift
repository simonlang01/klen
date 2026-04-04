import SwiftUI
import SwiftData

struct QuickAddView: View {
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var ctx
    @Environment(\.appAccent) private var accent
    @Query(sort: \TodoGroup.name) private var groups: [TodoGroup]

    @State private var title = ""
    @State private var selectedGroup: TodoGroup? = nil
    @State private var dueDate: Date? = nil
    @State private var hasDueTime = false
    @State private var dueTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var priority: Priority = .none
    @State private var smartMode: Bool
    @FocusState private var focused: Bool

    let smartInputEnabled: Bool

    init(smartInputEnabled: Bool, onDismiss: @escaping () -> Void) {
        self.smartInputEnabled = smartInputEnabled
        self.onDismiss = onDismiss
        _smartMode = State(initialValue: smartInputEnabled)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Input row
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(accent)

                TextField(smartMode ? LocalizedStringKey("smart.placeholder") : LocalizedStringKey("task.title.placeholder"), text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($focused)
                    .onSubmit { submitWithCurrentDate() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            // Date + time row (manual mode only)
            if !smartMode {
                DateTimePickerRow(date: $dueDate, hasDueTime: $hasDueTime, dueTime: $dueTime)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 2)
            }

            // Action row
            HStack(spacing: 8) {
                if !smartMode {
                    Menu {
                        ForEach(Priority.allCases, id: \.self) { p in
                            Button {
                                priority = p
                            } label: {
                                Label(p.chipLabel, systemImage: priority == p ? "checkmark" : "")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: priority == .none ? "flag" : "flag.fill")
                                .font(.system(size: 11))
                            if priority != .none {
                                Text(priority.chipLabel).font(.system(size: 12))
                            }
                        }
                        .foregroundStyle(priority == .none ? .secondary : priority.color)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    if !groups.isEmpty {
                        Divider().frame(height: 14)
                        Menu {
                            Button(LocalizedStringKey("group.allTasks")) { selectedGroup = nil }
                            Divider()
                            ForEach(groups) { group in
                                Button(group.name) { selectedGroup = group }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "folder").font(.system(size: 11))
                                Text(selectedGroup?.name ?? NSLocalizedString("group.title", comment: ""))
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(selectedGroup == nil ? .secondary : accent)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                } else {
                    // Smart mode hint
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                        Text(LocalizedStringKey("smart.hint"))
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(accent.opacity(0.7))
                }

                Spacer()

                // Smart input toggle (only shown if feature is enabled in Settings)
                if smartInputEnabled {
                    Button {
                        smartMode.toggle()
                        if !smartMode {
                            dueDate = nil
                            hasDueTime = false
                            priority = .none
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                            Text(LocalizedStringKey("smart.toggle.label"))
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(smartMode ? accent : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(smartMode ? accent.opacity(0.1) : Color.clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(LocalizedStringKey("smart.toggle.help"))
                }

                Button {
                    submitWithCurrentDate()
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(title.trimmingCharacters(in: .whitespaces).isEmpty
                            ? accent.opacity(0.25) : accent)
                }
                .buttonStyle(.plain)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.regularMaterial)
        .onAppear { DispatchQueue.main.async { focused = true } }
        .onExitCommand { onDismiss() }
    }

    private func submitWithCurrentDate() {
        if smartMode {
            let t = title.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { return }
            onDismiss() // dismiss immediately; insert happens async
            Task {
                let result = await SmartInputParser.parse(t)
                await MainActor.run {
                    ctx.insert(TodoItem(title: result.title, desc: result.desc, priority: result.priority, dueDate: result.dueDate, group: selectedGroup))
                }
            }
        } else {
            let finalDate: Date? = dueDate.map { base in
                guard hasDueTime else { return base }
                let c = Calendar.current.dateComponents([.hour, .minute], from: dueTime)
                return Calendar.current.date(bySettingHour: c.hour ?? 9, minute: c.minute ?? 0, second: 0, of: base) ?? base
            }
            let t = title.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { return }
            let item = TodoItem(title: t, priority: priority, dueDate: finalDate, group: selectedGroup)
            item.hasDueTime = dueDate != nil && hasDueTime
            ctx.insert(item)
            NotificationManager.shared.schedule(for: item)
            onDismiss()
        }
    }

    private func submit(dueDate: Date?) {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        ctx.insert(TodoItem(title: t, priority: priority, dueDate: dueDate, group: selectedGroup))
        onDismiss()
    }
}

// MARK: – Chip

private struct QuickAddChip: View {
    enum Label {
        case localized(LocalizedStringKey)
        case plain(String)
    }

    let label: Label
    let icon: String
    var active: Bool = false
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.appAccent) private var accent

    init(label: LocalizedStringKey, icon: String, active: Bool = false, action: @escaping () -> Void) {
        self.label = .localized(label)
        self.icon = icon
        self.active = active
        self.action = action
    }

    init(label: String, icon: String, active: Bool = false, action: @escaping () -> Void) {
        self.label = .plain(label)
        self.icon = icon
        self.active = active
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11))
                Group {
                    switch label {
                    case .localized(let key): Text(key)
                    case .plain(let str):     Text(str)
                    }
                }
                .font(.system(size: 12))
                .lineLimit(1)
            }
            .foregroundStyle(active || hovering ? accent : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(active || hovering ? accent.opacity(0.1) : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
