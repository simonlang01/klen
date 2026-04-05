import SwiftUI
import SwiftData
import KeyboardShortcuts

struct DashboardView: View {
    @StateObject private var vm = DashboardViewModel()
    @Query(filter: #Predicate<TodoItem> { !$0.isDeleted }) private var allItems: [TodoItem]
    @Environment(\.modelContext) private var ctx
    @EnvironmentObject private var appState: AppState
    @State private var showAddSheet = false
    @State private var showTrash = false
    @State private var showHelp = false
    @State private var showActivityLog = false
    @State private var selectedItem: TodoItem?
    @State private var showCelebration = false
    @State private var didCompleteTask = false
    @State private var focusMode = false
    @State private var splitVisibility: NavigationSplitViewVisibility = .all
    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var tick = false
    @Environment(\.appAccent) private var accent

    var body: some View {
        NavigationSplitView(columnVisibility: $splitVisibility) {
            SidebarView(groupFilter: $vm.groupFilter, showTrash: $showTrash, showActivityLog: $showActivityLog)
                .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            HStack(spacing: 0) {
                // ── Task list or activity log ──────────────────────
                Group {
                    if showTrash {
                        TrashView()
                    } else if showActivityLog {
                        ActivityLogView()
                    } else if focusMode {
                        focusLayout
                    } else {
                        VStack(spacing: 0) {
                            StatsHeaderView(stats: vm.stats(from: allItems))
                            taskList
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    if showCelebration {
                        CelebrationOverlay { showCelebration = false }
                            .environment(\.appAccent, appState.accentOption.color)
                            .transition(.opacity)
                            .zIndex(100)
                    }
                }

                // ── Inline detail panel ────────────────────────────
                if let item = selectedItem, !showTrash, !showActivityLog {
                    Divider()
                    TaskDetailView(item: item, onClose: { selectedItem = nil })
                        .frame(width: 420)
                        .id(item.persistentModelID)
                }
            }
        }
        .searchable(text: $vm.searchQuery, placement: .toolbar, prompt: LocalizedStringKey("search.placeholder"))
        .toolbar { toolbarContent }
        .navigationTitle("")
        .frame(minWidth: 720, minHeight: 500)
        .sheet(isPresented: $showHelp) {
            HelpView()
                .environment(\.appAccent, appState.accentOption.color)
        }
        .onChange(of: showTrash) { if $1 { showActivityLog = false } }
        .onChange(of: showActivityLog) { if $1 { showTrash = false } }
        .onChange(of: vm.groupFilter) { _, newFilter in
            guard let item = selectedItem else { return }
            if !isVisible(item, in: newFilter) { selectedItem = nil }
        }
        .onChange(of: selectedItem?.group?.id) { _, _ in
            guard let item = selectedItem else { return }
            if !isVisible(item, in: vm.groupFilter) { selectedItem = nil }
        }
        .sheet(isPresented: $showAddSheet) {
            let preselectedGroup: TodoGroup? = {
                if case .group(let g) = vm.groupFilter { return g }
                return nil
            }()
            AddTaskSheet(smartInputEnabled: appState.smartInputEnabled, preselectedGroup: preselectedGroup)
        }
        .onReceive(refreshTimer) { _ in tick.toggle() }
        .onExitCommand { if focusMode { exitFocus() } }
        .onAppear {
            KeyboardShortcuts.onKeyUp(for: .focusMode) { toggleFocus() }
        }
        .onChange(of: todayClear) { wasClear, isClear in
            if !wasClear && isClear && didCompleteTask {
                showCelebration = true
                didCompleteTask = false
            }
        }
    }

    // MARK: Focus layout

    @ViewBuilder
    private var focusLayout: some View {
        let sections = vm.sections(from: allItems, tick: tick)
            .filter { $0.0 == .overdue || $0.0 == .today }

        VStack(spacing: 0) {
            // Focus header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey("focus.title"))
                        .scaledFont(size: 13, weight: .semibold)
                        .foregroundStyle(.secondary)
                    Text(Date(), style: .date)
                        .scaledFont(size: 11)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button(action: exitFocus) {
                    HStack(spacing: 4) {
                        Text(LocalizedStringKey("focus.exit"))
                            .scaledFont(size: 11)
                        Text("Esc")
                            .scaledFont(size: 10, weight: .medium)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 14)

            Divider()

            if sections.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(sections, id: \.0) { section, items in
                            SwiftUI.Section {
                                ForEach(items) { item in
                                    TaskRowView(
                                        item: item,
                                        isSelected: selectedItem?.persistentModelID == item.persistentModelID,
                                        onComplete: { complete(item) },
                                        onDelete: { softDelete(item) },
                                        onSelect: { selectedItem = (selectedItem?.persistentModelID == item.persistentModelID) ? nil : item }
                                    )
                                }
                            } header: {
                                SectionHeaderView(section: section, count: items.count, searchActive: false)
                                    .background(.background)
                            }
                        }
                    }
                    .padding(.bottom, 20)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func toggleFocus() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            focusMode.toggle()
            splitVisibility = focusMode ? .detailOnly : .all
            if focusMode { selectedItem = nil }
        }
    }

    private func exitFocus() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            focusMode = false
            splitVisibility = .all
        }
    }

    // MARK: Task list

    @ViewBuilder
    private var taskList: some View {
        let sections = vm.sections(from: allItems, tick: tick)

        if sections.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(sections, id: \.0) { section, items in
                        SwiftUI.Section {
                            ForEach(items) { item in
                                TaskRowView(
                                    item: item,
                                    isSelected: selectedItem?.persistentModelID == item.persistentModelID,
                                    onComplete: { complete(item) },
                                    onDelete: { softDelete(item) },
                                    onSelect: { selectedItem = (selectedItem?.persistentModelID == item.persistentModelID) ? nil : item }
                                )
                            }
                        } header: {
                            SectionHeaderView(section: section, count: items.count, searchActive: !vm.searchQuery.isEmpty)
                                .background(.background)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .scaledFont(size: 44, weight: .ultraLight)
                .foregroundStyle(accent.opacity(0.4))
            Text("dashboard.empty.title")
                .scaledFont(size: 16, weight: .medium)
                .foregroundStyle(.secondary)
            if allItems.isEmpty {
                Button {
                    showAddSheet = true
                } label: {
                    Label(LocalizedStringKey("dashboard.empty.cta"), systemImage: "plus")
                        .scaledFont(size: 14, weight: .medium)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .controlSize(.regular)
                .padding(.top, 6)
            } else {
                Text(String(format: NSLocalizedString("dashboard.empty.hint", comment: ""), KeyboardShortcuts.getShortcut(for: .quickAdd)?.description ?? "⌥Space"))
                    .scaledFont(size: 13)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .scaledFont(size: 14, weight: .medium)
                    .foregroundStyle(accent)
            }
            .keyboardShortcut("n", modifiers: .option)
            .help(LocalizedStringKey("dashboard.newTask.help"))
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                vm.sortOrder = vm.sortOrder == .date ? .priority : .date
            } label: {
                Image(systemName: vm.sortOrder == .priority ? "flag.fill" : "flag")
                    .scaledFont(size: 14, weight: .medium)
                    .foregroundStyle(vm.sortOrder == .priority ? accent : .secondary)
            }
            .help(LocalizedStringKey(vm.sortOrder == .priority ? "sort.date" : "sort.priority"))
        }
        ToolbarItem(placement: .primaryAction) {
            Button { toggleFocus() } label: {
                Image(systemName: focusMode ? "scope" : "scope")
                    .scaledFont(size: 14)
                    .foregroundStyle(focusMode ? accent : .secondary)
            }
            .help(LocalizedStringKey(focusMode ? "focus.exit" : "focus.enter"))
        }
        ToolbarItem(placement: .automatic) {
            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.secondary)
            }
            .help(LocalizedStringKey("help.title"))
        }
    }

    // MARK: Actions

    private func complete(_ item: TodoItem) {
        let wasCompleted = item.isCompleted
        withAnimation(.spring(duration: 0.25)) {
            item.isCompleted.toggle()
            item.completedAt = item.isCompleted ? Date() : nil
        }
        // Spawn next occurrence when completing (not when un-completing)
        if !wasCompleted && item.isRecurring {
            item.spawnNextOccurrence(in: ctx)
        }
        if !wasCompleted { didCompleteTask = true }
    }

    /// True when there are no open overdue or today tasks in the current view.
    private var todayClear: Bool {
        let sections = vm.sections(from: allItems, tick: tick)
        return !sections.contains { $0.0 == .overdue || $0.0 == .today }
    }

    private func isVisible(_ item: TodoItem, in filter: GroupFilter) -> Bool {
        switch filter {
        case .all:              return true
        case .unassigned:       return item.group == nil
        case .group(let g):     return item.group?.id == g.id
        }
    }

    private func softDelete(_ item: TodoItem) {
        withAnimation(.spring(duration: 0.2)) {
            item.isDeleted = true
            item.deletedAt = Date()
            if selectedItem?.persistentModelID == item.persistentModelID {
                selectedItem = nil
            }
        }
    }
}
