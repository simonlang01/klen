import SwiftUI
import SwiftData

// MARK: – Active token mode (for autocomplete & visual feedback)

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
        case .none:              return ""
        case .group(let q):      return q
        case .date(let q):       return q
        case .time(let q):       return q
        case .priority(let q):   return q
        }
    }
}

// MARK: – Sheet

struct AddTaskSheet: View {
    let smartInputEnabled: Bool

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccent) private var accent
    @Query(sort: \TodoGroup.name) private var groups: [TodoGroup]

    @State private var title = ""
    @State private var desc = ""
    @State private var priority: Priority = .none
    @State private var dueDate: Date? = nil
    @State private var hasDueTime = false
    @State private var dueTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var selectedGroup: TodoGroup? = nil
    @State private var smartMode: Bool
    @State private var links: [String] = []
    @State private var locationAddress: String = ""
    @State private var blockingStatus: BlockingStatus = .none
    @State private var recurrenceFrequency: RecurrenceFrequency = .none
    @State private var recurrenceInterval: Int = 1
    @State private var pendingAttachments: [(name: String, path: String, uti: String)] = []
    @State private var showFilePicker = false
    @FocusState private var titleFocused: Bool

    @AppStorage("smartInputHintsHidden") private var hintsHidden: Bool = false

    init(smartInputEnabled: Bool, preselectedGroup: TodoGroup? = nil) {
        self.smartInputEnabled = smartInputEnabled
        _smartMode = State(initialValue: smartInputEnabled)
        _selectedGroup = State(initialValue: preselectedGroup)
    }

    // MARK: – Token mode detection

    /// Detects the active token being typed: the last token trigger in the string.
    private var tokenMode: TokenMode {
        let syms: Set<Character> = ["@", "#", "!"]
        var lastMode: TokenMode = .none

        var i = title.startIndex
        while i < title.endIndex {
            let ch = title[i]
            let next = title.index(after: i)

            if ch == "@", next < title.endIndex, title[next] == "@" {
                // @@ = time
                let after = title.index(after: next)
                let query = String(title[after...]).lowercased()
                lastMode = .time(query: query)
                i = after
            } else if ch == "@" {
                let query = String(title[next...]).lowercased()
                lastMode = .date(query: query)
                i = next
            } else if ch == "#" {
                let query = String(title[next...])
                lastMode = .group(query: query)
                i = next
            } else if ch == "!" {
                let query = String(title[next...]).lowercased()
                lastMode = .priority(query: query)
                i = next
            } else {
                i = title.index(after: i)
            }

            // If we've already passed this trigger and the query contains another trigger, reset
            if case .none = lastMode {} else {
                let q = lastMode.query
                if q.contains(where: { syms.contains($0) }) {
                    lastMode = .none
                }
            }
        }
        return lastMode
    }

    /// Autocomplete suggestions based on current token mode.
    private var suggestions: [String] {
        let q = tokenMode.query
        switch tokenMode {
        case .group:
            return groups.map(\.name).filter { q.isEmpty || $0.lowercased().hasPrefix(q.lowercased()) }
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
                ? ["heute", "morgen", "übermorgen", "montag", "dienstag", "mittwoch", "donnerstag", "freitag", "samstag", "sonntag"]
                : ["today", "tomorrow", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
            return Array(opts.filter { q.isEmpty || $0.hasPrefix(q) }.prefix(6))
        case .time:
            let candidates = ["06:00","07:00","08:00","09:00","09:30",
                              "10:00","10:30","11:00","12:00","13:00",
                              "14:00","14:30","15:00","16:00","17:00",
                              "18:00","19:00","20:00"]
            if q.isEmpty { return Array(candidates.prefix(8)) }
            return candidates.filter { $0.hasPrefix(q) }
        case .none:
            return []
        }
    }

    /// Apply the top suggestion (called on Tab).
    @discardableResult
    private func acceptTopSuggestion() -> Bool {
        guard let top = suggestions.first else { return false }
        applySuggestion(top)
        return true
    }

    private func applySuggestion(_ s: String) {
        // For priority/blocking suggestions, insert only the short code (before " · ")
        let insertion = s.contains(" · ") ? String(s.prefix(while: { $0 != " " })) : s
        let syms: Set<Character> = ["@", "#", "!"]

        // Find last trigger index
        var lastTriggerIdx: String.Index? = nil
        var i = title.startIndex
        while i < title.endIndex {
            let ch = title[i]
            let next = title.index(after: i)
            if ch == "@", next < title.endIndex, title[next] == "@" {
                lastTriggerIdx = i
                i = title.index(after: next)
            } else if syms.contains(ch) {
                lastTriggerIdx = i
                i = next
            } else {
                i = next
            }
        }

        guard let triggerIdx = lastTriggerIdx else { return }

        // Determine where the query starts (after @@ or single symbol)
        let ch = title[triggerIdx]
        let next = title.index(after: triggerIdx)
        let queryStart: String.Index
        if ch == "@", next < title.endIndex, title[next] == "@" {
            queryStart = title.index(after: next)
        } else {
            queryStart = next
        }

        // Replace query with insertion + space (so user can keep typing)
        title.replaceSubrange(queryStart..<title.endIndex, with: insertion + " ")
        titleFocused = true
    }

    // MARK: – Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text(LocalizedStringKey(smartMode ? "addSheet.title.smart" : "addSheet.title.manual"))
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundStyle(.secondary)
                Spacer()

                // Re-show hints button (only when hidden)
                if smartMode && hintsHidden {
                    Button {
                        withAnimation { hintsHidden = false }
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .scaledFont(size: 13)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help(LocalizedStringKey("smart.hints.reshow"))
                }

                if smartInputEnabled {
                    Button { smartMode.toggle() } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles").scaledFont(size: 11)
                            Text(LocalizedStringKey("smart.toggle.label")).scaledFont(size: 12)
                        }
                        .foregroundStyle(smartMode ? accent : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(smartMode ? accent.opacity(0.1) : Color.clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Title field
            ZStack(alignment: .leading) {
                // Active mode border highlight
                if smartMode, case .none = tokenMode {} else if smartMode {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(tokenMode.color.opacity(0.4), lineWidth: 1.5)
                        .padding(.horizontal, 16)
                }

                TextField(LocalizedStringKey(smartMode ? "smart.placeholder" : "task.title.placeholder"),
                          text: $title, axis: .vertical)
                    .scaledFont(size: 15, weight: .medium)
                    .textFieldStyle(.plain)
                    .lineLimit(smartMode ? 4 : 1)
                    .focused($titleFocused)
                    .onSubmit { submit() }
                    .padding(.horizontal, 20)
                    .padding(.vertical, smartMode ? 6 : 0)
                    .onKeyPress(.tab) {
                        guard smartMode else { return .ignored }
                        return acceptTopSuggestion() ? .handled : .ignored
                    }
            }
            .padding(.bottom, 8)

            Divider().padding(.horizontal, 20)

            if smartMode {
                smartModeControls
            } else {
                manualForm
            }

            Divider()

            // Action buttons
            HStack {
                Spacer()
                Button("action.cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                Button("action.add") { submit() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 460, idealWidth: 540, maxWidth: 900)
        .background(_FrameAutosaver(name: "PlinkAddTaskSheet"))
        .onAppear { titleFocused = true }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            for url in urls {
                let accessing = url.startAccessingSecurityScopedResource()
                let uti = (try? url.resourceValues(forKeys: [.typeIdentifierKey]))?.typeIdentifier ?? ""
                pendingAttachments.append((name: url.lastPathComponent, path: url.path, uti: uti))
                if accessing { url.stopAccessingSecurityScopedResource() }
            }
        }
    }

    // MARK: – Smart mode controls

    @ViewBuilder
    private var smartModeControls: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Active mode indicator + autocomplete suggestions
            let mode = tokenMode
            if case .none = mode {
                // Token insert chips — shown when no mode active
                HStack(spacing: 6) {
                    Text(LocalizedStringKey("smart.hints.insert"))
                        .scaledFont(size: 11)
                        .foregroundStyle(.tertiary)
                    TokenInsertChip("@",  label: NSLocalizedString("smart.token.date",  comment: "")) { insertToken("@") }
                    TokenInsertChip("@@", label: NSLocalizedString("smart.token.time",  comment: "")) { insertToken("@@") }
                    TokenInsertChip("#",  label: NSLocalizedString("smart.token.group", comment: "")) { insertToken("#") }
                    TokenInsertChip("!",  label: NSLocalizedString("smart.token.flag",  comment: "")) { insertToken("!") }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
            } else {
                // Active mode pill + suggestions
                VStack(alignment: .leading, spacing: 8) {
                    // Mode indicator pill
                    HStack(spacing: 6) {
                        Label(mode.label, systemImage: mode.icon)
                            .scaledFont(size: 11, weight: .semibold)
                            .foregroundStyle(mode.color)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(mode.color.opacity(0.1), in: Capsule())
                            .overlay(Capsule().strokeBorder(mode.color.opacity(0.25), lineWidth: 0.5))

                        Text(LocalizedStringKey("smart.hints.tab"))
                            .scaledFont(size: 11)
                            .foregroundStyle(.tertiary)

                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    // Suggestion chips
                    if !suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(suggestions.enumerated()), id: \.offset) { idx, s in
                                    Button { applySuggestion(s) } label: {
                                        Text(s)
                                            .scaledFont(size: 12, weight: idx == 0 ? .semibold : .regular)
                                            .foregroundStyle(idx == 0 ? mode.color : Color.secondary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(idx == 0 ? mode.color.opacity(0.1) : Color.primary.opacity(0.05), in: Capsule())
                                            .overlay(Capsule().strokeBorder(idx == 0 ? mode.color.opacity(0.3) : Color.clear, lineWidth: 0.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 8)
            }

            // Collapsible hints panel
            if !hintsHidden {
                Divider().padding(.horizontal, 20)
                hintsPanel
            }
        }
    }

    // MARK: – Hints panel

    @ViewBuilder
    private var hintsPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(LocalizedStringKey("smart.hints.syntax"))
                    .scaledFont(size: 11, weight: .semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    withAnimation { hintsHidden = true }
                } label: {
                    Text(LocalizedStringKey("smart.hints.hide"))
                        .scaledFont(size: 11)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    hintRow(symbol: "@",  color: .green,  example: NSLocalizedString("smart.hints.date.example", comment: ""), desc: NSLocalizedString("smart.token.date",  comment: ""))
                    hintRow(symbol: "@@", color: .purple, example: "@@10:00 · @@14:30",                       desc: NSLocalizedString("smart.token.time",  comment: ""))
                    hintRow(symbol: "#",  color: .blue,   example: NSLocalizedString("smart.token.group", comment: ""),                                     desc: NSLocalizedString("smart.token.group",  comment: ""))
                    hintRow(symbol: "!",  color: .orange, example: "!h · !m · !l · !b · !x",                 desc: NSLocalizedString("smart.token.flag",   comment: ""))
                }
                Spacer()
            }

            // Flag legend
            HStack(spacing: 10) {
                ForEach([
                    ("!h", NSLocalizedString("priority.high",            comment: "")),
                    ("!m", NSLocalizedString("priority.medium",          comment: "")),
                    ("!l", NSLocalizedString("priority.low",             comment: "")),
                    ("!b", NSLocalizedString("blocking.status.blocked",  comment: "")),
                    ("!x", NSLocalizedString("blocking.status.blocking", comment: ""))
                ], id: \.0) { sym, desc in
                    HStack(spacing: 2) {
                        Text(sym).scaledFont(size: 10, weight: .bold, design: .monospaced).foregroundStyle(.orange)
                        Text(desc).scaledFont(size: 10).foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.top, 2)

            Text(LocalizedStringKey("smart.hints.example"))
                .scaledFont(size: 11, design: .monospaced)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)

            Text(LocalizedStringKey("smart.hints.unknown"))
                .scaledFont(size: 10)
                .foregroundStyle(Color.secondary.opacity(0.6))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func hintRow(symbol: String, color: Color, example: String, desc: String) -> some View {
        HStack(spacing: 8) {
            Text(symbol)
                .scaledFont(size: 11, weight: .bold, design: .monospaced)
                .foregroundStyle(color)
                .frame(width: 22, alignment: .leading)
            Text(desc)
                .scaledFont(size: 11, weight: .medium)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(example)
                .scaledFont(size: 11, design: .monospaced)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: – Token insertion

    private func insertToken(_ chars: String) {
        if !title.isEmpty && !title.hasSuffix(" ") { title += " " }
        title += chars
        titleFocused = true
    }

    // MARK: – Manual form

    @ViewBuilder
    private var manualForm: some View {
        TextField(LocalizedStringKey("task.desc.placeholder"), text: $desc)
            .scaledFont(size: 13)
            .textFieldStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

        Divider().padding(.horizontal, 20)

        HStack(spacing: 8) {
            BlockingChip(status: .blocking, current: blockingStatus) {
                blockingStatus = blockingStatus == .blocking ? .none : .blocking
                if blockingStatus == .blocking { priority = .high }
            }
            BlockingChip(status: .blocked, current: blockingStatus) {
                blockingStatus = blockingStatus == .blocked ? .none : .blocked
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)

        HStack(spacing: 12) {
            Menu {
                ForEach(Priority.allCases, id: \.self) { p in
                    Button { priority = p } label: {
                        Label(p.label, systemImage: priority == p ? "checkmark" : "")
                    }
                }
            } label: {
                Label(priority.label, systemImage: "flag")
                    .scaledFont(size: 12)
                    .foregroundStyle(priority == .none ? .secondary : accent)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            if !groups.isEmpty {
                Divider().frame(height: 16)
                Menu {
                    Button(LocalizedStringKey("group.allTasks")) { selectedGroup = nil }
                    Divider()
                    ForEach(groups) { group in Button(group.name) { selectedGroup = group } }
                } label: {
                    Label(selectedGroup?.name ?? NSLocalizedString("group.title", comment: ""), systemImage: "folder")
                        .scaledFont(size: 12)
                        .foregroundStyle(selectedGroup == nil ? .secondary : accent)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 6)

        DateTimePickerRow(date: $dueDate, hasDueTime: $hasDueTime, dueTime: $dueTime)
            .padding(.horizontal, 20)
            .padding(.bottom, 4)

        RecurrencePickerRow(frequency: $recurrenceFrequency, interval: $recurrenceInterval,
                            disabled: dueDate == nil)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

        Divider().padding(.horizontal, 20)

        ExtrasAttachmentsRow(
            existing: [], pending: pendingAttachments,
            onAdd: { showFilePicker = true },
            onRemoveExisting: { _ in },
            onRemovePending: { pendingAttachments.remove(at: $0) }
        )
        .padding(.horizontal, 6)

        Divider().padding(.horizontal, 20)
        ExtrasLinksRow(links: $links).padding(.horizontal, 6)
        Divider().padding(.horizontal, 20)
        ExtrasLocationRow(address: $locationAddress).padding(.horizontal, 6)
    }

    // MARK: – Submit

    private func submit() {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }

        if smartMode {
            let parsed = SmartInputParser.parseWithTokens(t)
            let resolvedGroup: TodoGroup? = {
                guard let name = parsed.groupName else { return nil }
                return groups.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
                    ?? groups.first { $0.name.lowercased().hasPrefix(name.lowercased()) }
            }()
            let item = TodoItem(title: parsed.title, desc: "",
                                priority: parsed.priority, dueDate: parsed.dueDate,
                                group: resolvedGroup)
            item.hasDueTime = parsed.hasDueTime
            item.blockingStatus = parsed.blockingStatus
            item.recurrence = recurrenceFrequency
            item.recurrenceInterval = recurrenceInterval
            ctx.insert(item)
            NotificationManager.shared.schedule(for: item)
            dismiss()
        } else {
            let finalDueDate: Date? = dueDate.map { base in
                guard hasDueTime else { return base }
                let c = Calendar.current.dateComponents([.hour, .minute], from: dueTime)
                return Calendar.current.date(bySettingHour: c.hour ?? 9, minute: c.minute ?? 0, second: 0, of: base) ?? base
            }
            let item = TodoItem(title: t, desc: desc, priority: priority,
                                dueDate: finalDueDate, group: selectedGroup)
            item.hasDueTime = dueDate != nil && hasDueTime
            item.links = links
            item.locationAddress = locationAddress
            item.blockingStatus = blockingStatus == .none ? nil : blockingStatus
            item.recurrence = recurrenceFrequency
            item.recurrenceInterval = recurrenceInterval
            ctx.insert(item)
            NotificationManager.shared.schedule(for: item)
            for att in pendingAttachments {
                let attachment = TaskAttachment(filename: att.name, filePath: att.path, typeIdentifier: att.uti)
                ctx.insert(attachment)
                item.attachments.append(attachment)
            }
            dismiss()
        }
    }
}

// MARK: – Token insert chip

private struct TokenInsertChip: View {
    let symbol: String
    let label: String
    let action: () -> Void

    init(_ symbol: String, label: String, action: @escaping () -> Void) {
        self.symbol = symbol; self.label = label; self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(symbol)
                    .scaledFont(size: 11, weight: .bold, design: .monospaced)
                Text(label)
                    .scaledFont(size: 11)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.06), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

private extension Priority {
    var label: LocalizedStringKey {
        switch self {
        case .none:   return "priority.none"
        case .low:    return "priority.low"
        case .medium: return "priority.medium"
        case .high:   return "priority.high"
        }
    }
}

// MARK: – Window frame autosave (persists sheet size across sessions)

import AppKit

private struct _FrameAutosaver: NSViewRepresentable {
    let name: String
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            guard let w = v.window else { return }
            w.styleMask.insert(.resizable)
            w.setFrameAutosaveName(name)
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
