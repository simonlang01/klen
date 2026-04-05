import SwiftUI
import SwiftData

// MARK: – Token mode (mirrors AddTaskSheet)

private enum TokenMode: Equatable {
    case none
    case group(query: String)
    case date(query: String)
    case time(query: String)
    case priority(query: String)

    var label: String {
        switch self {
        case .none:     return ""
        case .group:    return NSLocalizedString("smart.mode.group",    comment: "")
        case .date:     return NSLocalizedString("smart.mode.date",     comment: "")
        case .time:     return NSLocalizedString("smart.mode.time",     comment: "")
        case .priority: return NSLocalizedString("smart.mode.priority", comment: "")
        }
    }
    var color: Color {
        switch self {
        case .none:     return .clear
        case .group:    return .blue
        case .date:     return .green
        case .time:     return .purple
        case .priority: return .orange
        }
    }
    var icon: String {
        switch self {
        case .none:     return ""
        case .group:    return "folder"
        case .date:     return "calendar"
        case .time:     return "clock"
        case .priority: return "flag"
        }
    }
    var query: String {
        switch self {
        case .none:           return ""
        case .group(let q):   return q
        case .date(let q):    return q
        case .time(let q):    return q
        case .priority(let q):return q
        }
    }
}

// MARK: – View

struct QuickAddView: View {
    let onDismiss: () -> Void
    let smartInputEnabled: Bool

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

    @AppStorage("smartInputHintsHidden") private var hintsHidden: Bool = false

    init(smartInputEnabled: Bool, onDismiss: @escaping () -> Void) {
        self.smartInputEnabled = smartInputEnabled
        self.onDismiss = onDismiss
        _smartMode = State(initialValue: smartInputEnabled)
    }

    // MARK: – Token detection (same logic as AddTaskSheet)

    private var tokenMode: TokenMode {
        let syms: Set<Character> = ["@", "#", "!"]
        var last: TokenMode = .none
        var i = title.startIndex
        while i < title.endIndex {
            let ch = title[i]
            let next = title.index(after: i)
            if ch == "@", next < title.endIndex, title[next] == "@" {
                let after = title.index(after: next)
                last = .time(query: String(title[after...]).lowercased())
                i = after
            } else if ch == "@" {
                last = .date(query: String(title[next...]).lowercased())
                i = next
            } else if ch == "#" {
                last = .group(query: String(title[next...]))
                i = next
            } else if ch == "!" {
                last = .priority(query: String(title[next...]).lowercased())
                i = next
            } else {
                i = title.index(after: i)
            }
            if case .none = last {} else if last.query.contains(where: { syms.contains($0) }) {
                last = .none
            }
        }
        return last
    }

    private var suggestions: [String] {
        let q = tokenMode.query.lowercased()
        switch tokenMode {
        case .group:
            return groups.map(\.name).filter { q.isEmpty || $0.lowercased().hasPrefix(q) }
        case .priority:
            let opts: [(code: String, label: String)] = [
                ("h", NSLocalizedString("priority.high",            comment: "")),
                ("m", NSLocalizedString("priority.medium",          comment: "")),
                ("l", NSLocalizedString("priority.low",             comment: "")),
                ("b", NSLocalizedString("blocking.status.blocked",  comment: "")),
                ("x", NSLocalizedString("blocking.status.blocking", comment: ""))
            ]
            return opts.compactMap { entry in
                let display = "\(entry.code) · \(entry.label)"
                guard q.isEmpty || entry.code.hasPrefix(q) || entry.label.lowercased().contains(q) else { return nil }
                return display
            }
        case .date:
            let opts = LanguageManager.current == "de"
                ? ["heute", "morgen", "übermorgen", "montag", "dienstag", "mittwoch", "donnerstag", "freitag", "samstag"]
                : ["today", "tomorrow", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
            return Array(opts.filter { q.isEmpty || $0.hasPrefix(q) }.prefix(5))
        case .time:
            let candidates = ["08:00","09:00","09:30","10:00","10:30","11:00",
                              "12:00","13:00","14:00","15:00","16:00","17:00","18:00"]
            return q.isEmpty ? Array(candidates.prefix(7)) : candidates.filter { $0.hasPrefix(q) }
        case .none:
            return []
        }
    }

    @discardableResult
    private func acceptTopSuggestion() -> Bool {
        guard let top = suggestions.first else { return false }
        applySuggestion(top)
        return true
    }

    private func applySuggestion(_ s: String) {
        let insertion = s.contains(" · ") ? String(s.prefix(while: { $0 != " " })) : s
        let syms: Set<Character> = ["@", "#", "!"]
        var lastIdx: String.Index? = nil
        var isDouble = false
        var i = title.startIndex
        while i < title.endIndex {
            let ch = title[i]
            let next = title.index(after: i)
            if ch == "@", next < title.endIndex, title[next] == "@" {
                lastIdx = i; isDouble = true
                i = title.index(after: next)
            } else if syms.contains(ch) {
                lastIdx = i; isDouble = false
                i = next
            } else {
                i = next
            }
        }
        guard let idx = lastIdx else { return }
        let queryStart: String.Index
        if isDouble {
            queryStart = title.index(after: title.index(after: idx))
        } else {
            queryStart = title.index(after: idx)
        }
        guard queryStart <= title.endIndex else { return }
        title.replaceSubrange(queryStart..<title.endIndex, with: insertion + " ")
        focused = true
    }

    private func insertToken(_ chars: String) {
        if !title.isEmpty && !title.hasSuffix(" ") { title += " " }
        title += chars
        focused = true
    }

    // MARK: – Body

    var body: some View {
        VStack(spacing: 0) {

            // Input field
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .scaledFont(size: 16)
                    .foregroundStyle(smartMode && tokenMode != .none ? tokenMode.color : accent)
                    .animation(.easeInOut(duration: 0.15), value: tokenMode.label)

                TextField(
                    smartMode ? LocalizedStringKey("smart.placeholder") : LocalizedStringKey("task.title.placeholder"),
                    text: $title
                )
                .textFieldStyle(.plain)
                .scaledFont(size: 14)
                .focused($focused)
                .onSubmit { submit() }
                .onKeyPress(.tab) {
                    guard smartMode else { return .ignored }
                    return acceptTopSuggestion() ? .handled : .ignored
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                smartMode && tokenMode != .none
                    ? tokenMode.color.opacity(0.04)
                    : Color.clear
            )
            .animation(.easeInOut(duration: 0.15), value: tokenMode.label)

            Divider()

            // Smart mode area (same pattern as AddTaskSheet)
            if smartMode {
                smartModeControls
            } else {
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
                            Button { priority = p } label: {
                                Label(p.chipLabel, systemImage: priority == p ? "checkmark" : "")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: priority == .none ? "flag" : "flag.fill")
                                .scaledFont(size: 11)
                            if priority != .none { Text(priority.chipLabel).scaledFont(size: 12) }
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
                            ForEach(groups) { g in Button(g.name) { selectedGroup = g } }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "folder").scaledFont(size: 11)
                                Text(selectedGroup?.name ?? NSLocalizedString("group.title", comment: ""))
                                    .scaledFont(size: 12)
                            }
                            .foregroundStyle(selectedGroup == nil ? .secondary : accent)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                }

                Spacer()

                if smartMode && hintsHidden {
                    Button { withAnimation { hintsHidden = false } } label: {
                        Image(systemName: "questionmark.circle")
                            .scaledFont(size: 13)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help(LocalizedStringKey("smart.hints.reshow"))
                }

                if smartInputEnabled {
                    Button {
                        smartMode.toggle()
                        if !smartMode { dueDate = nil; hasDueTime = false; priority = .none }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles").scaledFont(size: 11)
                            Text(LocalizedStringKey("smart.toggle.label")).scaledFont(size: 12)
                        }
                        .foregroundStyle(smartMode ? accent : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(smartMode ? accent.opacity(0.1) : Color.clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button { submit() } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .scaledFont(size: 20)
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

    // MARK: – Smart mode controls (same structure as AddTaskSheet)

    @ViewBuilder
    private var smartModeControls: some View {
        VStack(alignment: .leading, spacing: 0) {
            let mode = tokenMode

            if case .none = mode {
                // Token insert chips
                HStack(spacing: 6) {
                    Text(LocalizedStringKey("smart.hints.insert"))
                        .scaledFont(size: 11)
                        .foregroundStyle(.tertiary)
                    QATokenInsertChip("@",  label: NSLocalizedString("smart.token.date",  comment: ""), color: .green)  { insertToken("@") }
                    QATokenInsertChip("@@", label: NSLocalizedString("smart.token.time",  comment: ""), color: .purple) { insertToken("@@") }
                    QATokenInsertChip("#",  label: NSLocalizedString("smart.token.group", comment: ""), color: .blue)   { insertToken("#") }
                    QATokenInsertChip("!",  label: NSLocalizedString("smart.token.flag",  comment: ""), color: .orange) { insertToken("!") }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            } else {
                // Active mode pill + suggestions
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Label(mode.label, systemImage: mode.icon)
                            .scaledFont(size: 11, weight: .semibold)
                            .foregroundStyle(mode.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(mode.color.opacity(0.1), in: Capsule())
                            .overlay(Capsule().strokeBorder(mode.color.opacity(0.25), lineWidth: 0.5))

                        Text(LocalizedStringKey("smart.hints.tab"))
                            .scaledFont(size: 11)
                            .foregroundStyle(.tertiary)

                        Spacer()
                    }

                    if !suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 5) {
                                ForEach(Array(suggestions.enumerated()), id: \.offset) { idx, s in
                                    Button { applySuggestion(s) } label: {
                                        Text(s)
                                            .scaledFont(size: 12, weight: idx == 0 ? .semibold : .regular)
                                            .foregroundStyle(idx == 0 ? mode.color : Color.secondary)
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 3)
                                            .background(
                                                idx == 0 ? mode.color.opacity(0.1) : Color.primary.opacity(0.05),
                                                in: Capsule()
                                            )
                                            .overlay(Capsule().strokeBorder(
                                                idx == 0 ? mode.color.opacity(0.3) : Color.clear,
                                                lineWidth: 0.5
                                            ))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }

            // Hints panel
            if !hintsHidden {
                Divider()
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(LocalizedStringKey("smart.hints.syntax"))
                            .scaledFont(size: 10, weight: .semibold)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button { withAnimation { hintsHidden = true } } label: {
                            Text(LocalizedStringKey("smart.hints.hide"))
                                .scaledFont(size: 10)
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    HStack(spacing: 10) {
                        hintBadge("@",  NSLocalizedString("smart.token.date",  comment: ""), .green)
                        hintBadge("@@", NSLocalizedString("smart.token.time",  comment: ""), .purple)
                        hintBadge("#",  NSLocalizedString("smart.token.group", comment: ""), .blue)
                        hintBadge("!",  NSLocalizedString("smart.token.flag",  comment: ""), .orange)
                    }
                    HStack(spacing: 8) {
                        ForEach([
                            ("!h", NSLocalizedString("priority.high",            comment: "")),
                            ("!m", NSLocalizedString("priority.medium",          comment: "")),
                            ("!l", NSLocalizedString("priority.low",             comment: "")),
                            ("!b", NSLocalizedString("blocking.status.blocked",  comment: "")),
                            ("!x", NSLocalizedString("blocking.status.blocking", comment: ""))
                        ], id: \.0) { sym, desc in
                            HStack(spacing: 2) {
                                Text(sym).scaledFont(size: 9, weight: .bold, design: .monospaced).foregroundStyle(.orange)
                                Text(desc).scaledFont(size: 9).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    Text(LocalizedStringKey("smart.hints.example"))
                        .scaledFont(size: 10, design: .monospaced)
                        .foregroundStyle(.tertiary)
                    Text(LocalizedStringKey("smart.hints.unknown"))
                        .scaledFont(size: 9)
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private func hintBadge(_ sym: String, _ desc: String, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Text(sym)
                .scaledFont(size: 10, weight: .bold, design: .monospaced)
                .foregroundStyle(color)
            Text(desc)
                .scaledFont(size: 10)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: – Submit

    private func submit() {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }

        if smartMode {
            let parsed = SmartInputParser.parseWithTokens(t)
            let resolvedGroup: TodoGroup? = {
                guard let name = parsed.groupName else { return nil }
                // Try exact match first, then prefix
                return groups.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
                    ?? groups.first { $0.name.lowercased().hasPrefix(name.lowercased()) }
            }()
            let item = TodoItem(title: parsed.title, desc: "",
                                priority: parsed.priority, dueDate: parsed.dueDate,
                                group: resolvedGroup)
            item.hasDueTime = parsed.hasDueTime
            item.blockingStatus = parsed.blockingStatus
            ctx.insert(item)
            NotificationManager.shared.schedule(for: item)
        } else {
            let finalDate: Date? = dueDate.map { base in
                guard hasDueTime else { return base }
                let c = Calendar.current.dateComponents([.hour, .minute], from: dueTime)
                return Calendar.current.date(bySettingHour: c.hour ?? 9, minute: c.minute ?? 0, second: 0, of: base) ?? base
            }
            let item = TodoItem(title: t, priority: priority, dueDate: finalDate, group: selectedGroup)
            item.hasDueTime = dueDate != nil && hasDueTime
            ctx.insert(item)
            NotificationManager.shared.schedule(for: item)
        }
        onDismiss()
    }
}

// MARK: – Token insert chip (prefixed to avoid conflict)

private struct QATokenInsertChip: View {
    let symbol: String
    let label: String
    let color: Color
    let action: () -> Void

    init(_ symbol: String, label: String, color: Color, action: @escaping () -> Void) {
        self.symbol = symbol; self.label = label; self.color = color; self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(symbol)
                    .scaledFont(size: 10, weight: .bold, design: .monospaced)
                    .foregroundStyle(color)
                Text(label)
                    .scaledFont(size: 11)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.07), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.2), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}
