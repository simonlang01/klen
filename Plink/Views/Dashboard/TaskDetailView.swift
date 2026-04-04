import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct TaskDetailView: View {
    let item: TodoItem
    let onClose: () -> Void
    @Environment(\.appAccent) private var accent
    @Query(sort: \TodoGroup.name) private var groups: [TodoGroup]

    // Local copies — only written back on save
    @State private var title: String
    @State private var desc: String
    @State private var priority: Priority
    @State private var dateSelection: DateSelection
    @State private var selectedGroup: TodoGroup?
    @State private var links: [String]
    @State private var locationAddress: String
    @State private var blockingStatus: BlockingStatus
    @State private var pendingAttachments: [(name: String, path: String, uti: String)] = []
    @State private var removedAttachmentIDs: Set<UUID> = []

    @State private var discardChanges = false
    @State private var showDatePicker = false
    @State private var showFilePicker = false
    @FocusState private var titleFocused: Bool
    @FocusState private var descFocused: Bool

    enum DateSelection: Equatable {
        case none, today, tomorrow, custom(Date)
        var date: Date? {
            switch self {
            case .none:          return nil
            case .today:         return .today
            case .tomorrow:      return .tomorrow
            case .custom(let d): return d
            }
        }
        static func from(_ date: Date?) -> DateSelection {
            guard let date else { return .none }
            let cal = Calendar.current
            if cal.isDateInToday(date)     { return .today }
            if cal.isDateInTomorrow(date)  { return .tomorrow }
            return .custom(date)
        }
    }

    private static let chipDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()

    init(item: TodoItem, onClose: @escaping () -> Void) {
        self.item    = item
        self.onClose = onClose
        _title           = State(initialValue: item.title)
        _desc            = State(initialValue: item.desc)
        _priority        = State(initialValue: item.priority)
        _dateSelection   = State(initialValue: .from(item.dueDate))
        _selectedGroup   = State(initialValue: item.group)
        _links           = State(initialValue: item.links)
        _locationAddress = State(initialValue: item.locationAddress)
        _blockingStatus  = State(initialValue: item.blockingStatus ?? .none)
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Header bar ─────────────────────────────────────────
            HStack(spacing: 0) {
                Text(LocalizedStringKey("task.edit"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 18)
                Spacer()
                Button(action: { discardChanges = true; onClose() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
                .help(LocalizedStringKey("task.discard.help"))
            }
            .frame(height: 44)

            Divider()

            // ── Scrollable content ─────────────────────────────────
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Title ──────────────────────────────────────
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 17))
                            .foregroundStyle(accent)
                        TextField(LocalizedStringKey("task.detail.title.placeholder"), text: $title, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 17, weight: .semibold))
                            .lineLimit(1...4)
                            .focused($titleFocused)
                            .onSubmit { saveAndClose() }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                    .padding(.bottom, 14)

                    Divider()

                    // ── Description ────────────────────────────────
                    // TextEditor used here so Shift+Return naturally inserts a
                    // newline. Plain Return is intercepted to save and close.
                    ZStack(alignment: .topLeading) {
                        if desc.isEmpty && !descFocused {
                            Text(LocalizedStringKey("task.desc.placeholder"))
                                .font(.system(size: 14))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $desc)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 72)
                            .focused($descFocused)
                            .onKeyPress(.return, phases: .down) { press in
                                guard !press.modifiers.contains(.shift) else { return .ignored }
                                saveAndClose()
                                return .handled
                            }
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)

                    Divider()

                    // ── Attribute chips ────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        // Date
                        HStack(spacing: 8) {
                            DetailChip(label: NSLocalizedString("task.date.today", comment: ""), icon: "sun.max", active: dateSelection == .today) {
                                dateSelection = dateSelection == .today ? .none : .today
                            }
                            DetailChip(label: NSLocalizedString("task.date.tomorrow", comment: ""), icon: "sunrise", active: dateSelection == .tomorrow) {
                                dateSelection = dateSelection == .tomorrow ? .none : .tomorrow
                            }
                            DetailChip(
                                label: {
                                    if case .custom(let d) = dateSelection { return Self.chipDateFormatter.string(from: d) }
                                    return NSLocalizedString("task.date.custom", comment: "")
                                }(),
                                icon: "calendar",
                                active: { if case .custom = dateSelection { return true }; return showDatePicker }()
                            ) { showDatePicker.toggle() }
                            .popover(isPresented: $showDatePicker, arrowEdge: .bottom) {
                                MiniCalendarPicker(
                                    selected: Binding(
                                        get: { if case .custom(let d) = dateSelection { return d }; return .today },
                                        set: { dateSelection = .custom($0) }
                                    )
                                ) { showDatePicker = false }
                            }
                        }

                        // Blocking status
                        HStack(spacing: 8) {
                            BlockingChip(status: .blocking, current: blockingStatus) {
                                blockingStatus = blockingStatus == .blocking ? .none : .blocking
                                if blockingStatus == .blocking { priority = .high }
                            }
                            BlockingChip(status: .blocked, current: blockingStatus) {
                                blockingStatus = blockingStatus == .blocked ? .none : .blocked
                            }
                        }

                        // Priority + Group
                        HStack(spacing: 10) {
                            Menu {
                                ForEach(Priority.allCases, id: \.self) { p in
                                    Button { priority = p } label: {
                                        Label(p.chipLabel, systemImage: priority == p ? "checkmark" : "")
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: priority == .none ? "flag" : "flag.fill")
                                        .font(.system(size: 13))
                                    Text(priority == .none ? NSLocalizedString("priority.none", comment: "") : priority.chipLabel)
                                        .font(.system(size: 13))
                                }
                                .foregroundStyle(priority == .none ? .secondary : priority.color)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    (priority == .none ? Color.primary.opacity(0.06) : priority.color.opacity(0.10)),
                                    in: Capsule()
                                )
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()

                            if !groups.isEmpty {
                                Menu {
                                    Button(LocalizedStringKey("task.noGroup")) { selectedGroup = nil }
                                    Divider()
                                    ForEach(groups) { g in Button(g.name) { selectedGroup = g } }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "folder").font(.system(size: 13))
                                        Text(selectedGroup?.name ?? NSLocalizedString("group.title", comment: ""))
                                            .font(.system(size: 13))
                                    }
                                    .foregroundStyle(selectedGroup == nil ? .secondary : accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        selectedGroup == nil ? Color.primary.opacity(0.06) : accent.opacity(0.10),
                                        in: Capsule()
                                    )
                                }
                                .menuStyle(.borderlessButton)
                                .fixedSize()
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)

                    Divider()

                    // ── Attachments ────────────────────────────────
                    ExtrasAttachmentsRow(
                        existing: item.attachments.filter { !removedAttachmentIDs.contains($0.id) },
                        pending: pendingAttachments,
                        onAdd: { showFilePicker = true },
                        onRemoveExisting: { removedAttachmentIDs.insert($0) },
                        onRemovePending: { pendingAttachments.remove(at: $0) }
                    )

                    Divider()

                    // ── Links ──────────────────────────────────────
                    ExtrasLinksRow(links: $links)

                    Divider()

                    // ── Location ───────────────────────────────────
                    ExtrasLocationRow(address: $locationAddress, onSubmit: saveAndClose)

                    Spacer(minLength: 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // ── Save button (pinned) ───────────────────────────────
            HStack {
                Spacer()
                Button {
                    save()
                    discardChanges = true  // prevent double-save in onDisappear
                    onClose()
                } label: {
                    Label(LocalizedStringKey("task.save"), systemImage: "checkmark")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .controlSize(.regular)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .background(.background)
        .onAppear { DispatchQueue.main.async { titleFocused = true } }
        .onExitCommand { discardChanges = true; onClose() }
        .onDisappear { if !discardChanges { save() } }
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

    private func saveAndClose() {
        save()
        discardChanges = true
        onClose()
    }

    private func save() {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        item.title           = t
        item.desc            = desc
        item.priority        = priority
        item.dueDate         = dateSelection.date
        item.group           = selectedGroup
        item.links           = links
        item.locationAddress = locationAddress
        item.blockingStatus  = blockingStatus == .none ? nil : blockingStatus
        for id in removedAttachmentIDs {
            item.attachments.removeAll { $0.id == id }
        }
        for att in pendingAttachments {
            item.attachments.append(TaskAttachment(filename: att.name, filePath: att.path, typeIdentifier: att.uti))
        }
        if item.isCompleted && item.completedAt == nil { item.completedAt = Date() }
    }
}

// MARK: – Blocking Chip

struct BlockingChip: View {
    let status: BlockingStatus
    let current: BlockingStatus
    let action: () -> Void
    @State private var hovering = false

    private var isActive: Bool { current == status }

    private var label: String {
        status == .blocking
            ? NSLocalizedString("blocking.status.blocking", comment: "")
            : NSLocalizedString("blocking.status.blocked", comment: "")
    }
    private var icon: String {
        status == .blocking ? "exclamationmark.circle.fill" : "hand.raised.fill"
    }
    private var color: Color {
        status == .blocking ? .red : .orange
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12))
                Text(label).font(.system(size: 13))
            }
            .foregroundStyle(isActive || hovering ? color : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isActive ? color.opacity(0.12) : (hovering ? color.opacity(0.07) : Color.primary.opacity(0.06)),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(isActive ? color.opacity(0.35) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: – Detail Chip

private struct DetailChip: View {
    let label: String
    let icon: String
    var active: Bool = false
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.appAccent) private var accent

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12))
                Text(label).font(.system(size: 13)).lineLimit(1)
            }
            .foregroundStyle(active || hovering ? accent : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(active || hovering ? accent.opacity(0.1) : Color.primary.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: – Extras rows

struct ExtrasAttachmentsRow: View {
    let existing: [TaskAttachment]
    let pending: [(name: String, path: String, uti: String)]
    let onAdd: () -> Void
    let onRemoveExisting: (UUID) -> Void
    let onRemovePending: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(LocalizedStringKey("extras.attachments"), systemImage: "paperclip")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus").font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            ForEach(existing) { att in
                let path = att.filePath
                let attID = att.id
                ExtrasItemRow(icon: att.displayIcon, label: att.filename, onOpen: {
                    NSWorkspace.shared.open(URL(fileURLWithPath: path))
                }) { onRemoveExisting(attID) }
            }
            ForEach(pending.indices, id: \.self) { i in
                ExtrasItemRow(
                    icon: pending[i].uti.contains("image") ? "photo" : "paperclip",
                    label: pending[i].name,
                    onOpen: { NSWorkspace.shared.open(URL(fileURLWithPath: pending[i].path)) }
                ) { onRemovePending(i) }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}

struct ExtrasLinksRow: View {
    @Binding var links: [String]
    @State private var newLinkText = ""
    @State private var showField = false
    @FocusState private var focused: Bool
    @Environment(\.appAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(LocalizedStringKey("extras.links"), systemImage: "link")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showField = true
                    DispatchQueue.main.async { focused = true }
                } label: {
                    Image(systemName: "plus").font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            ForEach(links.indices, id: \.self) { i in
                ExtrasItemRow(icon: "link", label: links[i], onOpen: {
                    if let url = URL(string: links[i]) { NSWorkspace.shared.open(url) }
                }) { links.remove(at: i) }
            }

            if showField {
                HStack(spacing: 8) {
                    TextField("https://", text: $newLinkText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($focused)
                        .onSubmit { commitLink() }
                    Button(action: commitLink) {
                        Image(systemName: "return").font(.system(size: 11))
                            .foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(newLinkText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func commitLink() {
        let trimmed = newLinkText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { showField = false; return }
        links.append(trimmed)
        newLinkText = ""
        showField = false
    }
}

struct ExtrasLocationRow: View {
    @Binding var address: String
    var onSubmit: (() -> Void)? = nil
    @Environment(\.appAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                Label(LocalizedStringKey("extras.location"), systemImage: "mappin")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if !address.isEmpty {
                    Button {
                        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        if let url = URL(string: "https://maps.apple.com/?q=\(encoded)") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "arrow.up.forward.square").font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(LocalizedStringKey("extras.location.openMaps"))
                }
            }
            TextField(LocalizedStringKey("extras.location.placeholder"), text: $address, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(1...3)
                .onSubmit { onSubmit?() }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}

// MARK: – Shared item row

struct ExtrasItemRow: View {
    let icon: String
    let label: String
    var onOpen: (() -> Void)? = nil
    let onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
            if hovering {
                if let onOpen {
                    Button(action: onOpen) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(LocalizedStringKey("extras.open"))
                }
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(LocalizedStringKey("extras.remove"))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(hovering ? 0.05 : 0.03), in: RoundedRectangle(cornerRadius: 7))
        .contentShape(Rectangle())
        .onTapGesture { onOpen?() }
        .onHover { hovering = $0 }
    }
}
