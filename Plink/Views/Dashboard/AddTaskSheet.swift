import SwiftUI
import SwiftData

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
    @State private var hasDueDate = false
    @State private var selectedGroup: TodoGroup? = nil
    @State private var smartMode: Bool
    @State private var links: [String] = []
    @State private var locationAddress: String = ""
    @State private var blockingStatus: BlockingStatus = .none
    @State private var pendingAttachments: [(name: String, path: String, uti: String)] = []
    @State private var showFilePicker = false
    @FocusState private var titleFocused: Bool

    init(smartInputEnabled: Bool, preselectedGroup: TodoGroup? = nil) {
        self.smartInputEnabled = smartInputEnabled
        _smartMode = State(initialValue: smartInputEnabled)
        _selectedGroup = State(initialValue: preselectedGroup)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with optional smart toggle
            HStack(alignment: .firstTextBaseline) {
                Text(LocalizedStringKey(smartMode ? "addSheet.title.smart" : "addSheet.title.manual"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if smartInputEnabled {
                    Button {
                        smartMode.toggle()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles").font(.system(size: 11))
                            Text(LocalizedStringKey("smart.toggle.label")).font(.system(size: 12))
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

            // Title / Smart input field
            TextField(smartMode ? LocalizedStringKey("smart.placeholder") : LocalizedStringKey("task.title.placeholder"), text: $title, axis: smartMode ? .vertical : .horizontal)
                .font(.system(size: 15, weight: .medium))
                .textFieldStyle(.plain)
                .lineLimit(smartMode ? 3 : 1)
                .focused($titleFocused)
                .onSubmit { submit() }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            Divider().padding(.horizontal, 20)

            // Description (hidden in smart mode — parser fills it)
            if !smartMode {
                TextField(LocalizedStringKey("task.desc.placeholder"), text: $desc)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)

                Divider().padding(.horizontal, 20)
            }

            // Blocking status (manual mode only)
            if !smartMode {
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
            }

            // Attributes row 1: priority / due date toggle / group
            HStack(spacing: 12) {
                // Priority picker
                Menu {
                    ForEach(Priority.allCases, id: \.self) { p in
                        Button {
                            priority = p
                        } label: {
                            Label(p.label, systemImage: priority == p ? "checkmark" : "")
                        }
                    }
                } label: {
                    Label(priority.label, systemImage: "flag")
                        .font(.system(size: 12))
                        .foregroundStyle(priority == .none ? .secondary : accent)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Divider().frame(height: 16)

                // Due date toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        hasDueDate.toggle()
                        if hasDueDate { dueDate = Calendar.current.startOfDay(for: Date()) }
                    }
                } label: {
                    Label(LocalizedStringKey("task.dueDate"), systemImage: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(hasDueDate ? accent : .secondary)
                }
                .buttonStyle(.borderless)

                Divider().frame(height: 16)

                // Group picker
                if !groups.isEmpty {
                    Menu {
                        Button(LocalizedStringKey("group.allTasks")) { selectedGroup = nil }
                        Divider()
                        ForEach(groups) { group in
                            Button(group.name) { selectedGroup = group }
                        }
                    } label: {
                        Label(selectedGroup?.name ?? NSLocalizedString("group.title", comment: ""), systemImage: "folder")
                            .font(.system(size: 12))
                            .foregroundStyle(selectedGroup == nil ? .secondary : accent)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, hasDueDate ? 6 : 10)

            // Attributes row 2: date picker (expands below when toggled)
            if hasDueDate {
                HStack(spacing: 10) {
                    DatePicker("", selection: Binding(
                        get: { dueDate ?? Date() },
                        set: { dueDate = $0 }
                    ), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()

                    Divider().frame(height: 16)

                    Button("section.today") {
                        dueDate = Calendar.current.startOfDay(for: Date())
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 12))
                    .foregroundStyle(accent)

                    Button("section.tomorrow") {
                        dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 12))
                    .foregroundStyle(accent)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Extras (manual mode only)
            if !smartMode {
                Divider().padding(.horizontal, 20)

                ExtrasAttachmentsRow(
                    existing: [],
                    pending: pendingAttachments,
                    onAdd: { showFilePicker = true },
                    onRemoveExisting: { _ in },
                    onRemovePending: { pendingAttachments.remove(at: $0) }
                )
                .padding(.horizontal, 6)

                Divider().padding(.horizontal, 20)

                ExtrasLinksRow(links: $links)
                    .padding(.horizontal, 6)

                Divider().padding(.horizontal, 20)

                ExtrasLocationRow(address: $locationAddress)
                    .padding(.horizontal, 6)
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
        .frame(width: 520)
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

    private func submit() {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        if smartMode {
            dismiss()
            Task {
                let result = await SmartInputParser.parse(t)
                await MainActor.run {
                    ctx.insert(TodoItem(title: result.title, desc: result.desc, priority: result.priority, dueDate: result.dueDate, group: selectedGroup))
                }
            }
        } else {
            let item = TodoItem(title: t, desc: desc, priority: priority, dueDate: hasDueDate ? (dueDate ?? Date()) : nil, group: selectedGroup)
            item.links = links
            item.locationAddress = locationAddress
            item.blockingStatus = blockingStatus == .none ? nil : blockingStatus
            ctx.insert(item)
            for att in pendingAttachments {
                let attachment = TaskAttachment(filename: att.name, filePath: att.path, typeIdentifier: att.uti)
                ctx.insert(attachment)
                item.attachments.append(attachment)
            }
            dismiss()
        }
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
