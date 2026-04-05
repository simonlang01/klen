import SwiftUI
import SwiftData
import KeyboardShortcuts
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label(LocalizedStringKey("settings.tab.general"), systemImage: "paintbrush") }

            SmartInputTab()
                .tabItem { Label(LocalizedStringKey("settings.tab.smartInput"), systemImage: "sparkles") }

            NotificationsTab()
                .tabItem { Label(LocalizedStringKey("settings.tab.notifications"), systemImage: "bell") }

            ShortcutTab()
                .tabItem { Label(LocalizedStringKey("settings.tab.shortcut"), systemImage: "keyboard") }

            AdvancedTab()
                .tabItem { Label(LocalizedStringKey("settings.tab.advanced"), systemImage: "gearshape") }
        }
        .frame(width: 460)
    }
}

// MARK: – General Tab

private struct GeneralTab: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.appAccent) private var accent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Language
                SettingsRow(icon: "globe", title: LocalizedStringKey("settings.language.title"),
                            desc: LocalizedStringKey("settings.language.desc")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 0) {
                            ForEach([("en", "settings.language.en"), ("de", "settings.language.de")], id: \.0) { code, key in
                                let isSelected = appState.appLanguage == code
                                Button {
                                    if appState.appLanguage != code {
                                        appState.appLanguage = code
                                        restartApp()
                                    }
                                } label: {
                                    Text(LocalizedStringKey(key))
                                        .scaledFont(size: 12, weight: isSelected ? .semibold : .regular)
                                        .foregroundStyle(isSelected ? .white : .primary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? accent : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(3)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))

                        // Coming soon
                        HStack(spacing: 6) {
                            Text("🇪🇸")
                                .scaledFont(size: 12)
                            Text(LocalizedStringKey("settings.language.spanish.soon"))
                                .scaledFont(size: 11)
                                .foregroundStyle(.secondary)
                            Text(LocalizedStringKey("settings.language.spanish.badge"))
                                .scaledFont(size: 10, weight: .semibold)
                                .foregroundStyle(accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(accent.opacity(0.12), in: Capsule())
                        }
                    }
                }

                Divider().padding(.horizontal, 20)

                // Appearance mode
                SettingsRow(icon: "circle.lefthalf.filled", title: LocalizedStringKey("settings.appearance.title"),
                            desc: LocalizedStringKey("settings.appearance.desc")) {
                    HStack(spacing: 10) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            AppearanceCard(mode: mode, isSelected: appState.appearanceMode == mode) {
                                appState.appearanceMode = mode
                            }
                        }
                    }
                }

                Divider().padding(.horizontal, 20)

                // Accent color
                SettingsRow(icon: "paintpalette", title: LocalizedStringKey("settings.accent.title"),
                            desc: LocalizedStringKey("settings.accent.desc")) {
                    HStack(spacing: 10) {
                        ForEach(AccentColorOption.allCases) { option in
                            AccentColorSwatch(option: option, isSelected: appState.accentOption == option) {
                                appState.accentOption = option
                            }
                        }
                    }
                }

                Divider().padding(.horizontal, 20)

                // Font size
                SettingsRow(icon: "textformat.size", title: LocalizedStringKey("settings.fontSize.title"),
                            desc: LocalizedStringKey("settings.fontSize.desc")) {
                    FontScaleControl(scale: $appState.fontScale)
                }

                Divider().padding(.horizontal, 20)

                // Font style
                SettingsRow(icon: "textformat", title: LocalizedStringKey("settings.fontStyle.title"),
                            desc: LocalizedStringKey("settings.fontStyle.desc")) {
                    HStack(spacing: 8) {
                        ForEach(FontStyleOption.allCases) { option in
                            FontStyleSwatch(option: option, isSelected: appState.fontStyle == option) {
                                appState.fontStyle = option
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .frame(minHeight: 260)
    }
}

// MARK: – Smart Input Tab

private struct SmartInputTab: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.appAccent) private var accent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Toggle
                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey("settings.smart.desc"))
                        .scaledFont(size: 12)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Toggle(isOn: $appState.smartInputEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey("settings.smart.toggle"))
                                .scaledFont(size: 13)
                            Text(LocalizedStringKey("settings.smart.toggle.sub"))
                                .scaledFont(size: 11)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(accent)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Engine badge
                let engine = SmartEngine.current
                HStack(spacing: 10) {
                    Image(systemName: engine == .foundationModels ? "apple.intelligence" : "cpu")
                        .scaledFont(size: 20)
                        .foregroundStyle(engine == .foundationModels ? accent : .secondary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: NSLocalizedString("settings.smart.engine", comment: ""), engine.label))
                            .scaledFont(size: 12, weight: .semibold)
                            .foregroundStyle(engine == .foundationModels ? accent : .primary)
                        Text(LocalizedStringKey(engine == .foundationModels ? "settings.smart.engine.ai.desc" : "settings.smart.engine.nlp.desc"))
                            .scaledFont(size: 11)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 20)

                // Usage hints (only when enabled)
                if appState.smartInputEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HelpRow(step: "✦", text: NSLocalizedString("settings.smart.help1", comment: ""))
                        HelpRow(step: "→", text: NSLocalizedString("settings.smart.help2", comment: ""))
                        HelpRow(step: "→", text: NSLocalizedString("settings.smart.help3", comment: ""))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 20)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer(minLength: 20)
            }
            .animation(.easeInOut(duration: 0.2), value: appState.smartInputEnabled)
        }
        .frame(minHeight: 260)
    }
}

// MARK: – Notifications Tab

private struct NotificationsTab: View {
    @ObservedObject private var nm = NotificationManager.shared
    @Query(sort: \TodoGroup.name) private var groups: [TodoGroup]
    @Query private var allItems: [TodoItem]
    @Environment(\.appAccent) private var accent

    var body: some View {
        ZStack(alignment: .top) {
            // Greyed-out content
            ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Always-visible setup hint — macOS can't distinguish Banners vs Alerts in code
                if nm.authStatus == .authorized {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.badge.fill")
                            .scaledFont(size: 20)
                            .foregroundStyle(accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(LocalizedStringKey("settings.notif.alertstyle.title"))
                                .scaledFont(size: 12, weight: .semibold)
                            Text(LocalizedStringKey("settings.notif.alertstyle.desc"))
                                .scaledFont(size: 11)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Button {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
                        } label: {
                            Text(LocalizedStringKey("settings.notif.alertstyle.button"))
                                .scaledFont(size: 11, weight: .medium)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Divider().padding(.horizontal, 20).padding(.top, 12)
                }

                // Permission banner (shown when not authorized)
                if nm.authStatus != .authorized {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.slash")
                            .scaledFont(size: 16)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey("settings.notif.permission.title"))
                                .scaledFont(size: 12, weight: .semibold)
                                .foregroundStyle(.orange)
                            Text(LocalizedStringKey("settings.notif.permission.desc"))
                                .scaledFont(size: 11)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Button(LocalizedStringKey("settings.notif.permission.button")) {
                            Task { await nm.requestPermission() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)
                    }
                    .padding(14)
                    .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.orange.opacity(0.2), lineWidth: 1))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Divider().padding(.horizontal, 20).padding(.top, 12)
                }

                // Global kill-switch
                SettingsRow(
                    icon: "bell.badge",
                    title: LocalizedStringKey("settings.notif.global.title"),
                    desc: LocalizedStringKey("settings.notif.global.desc")
                ) {
                    Toggle(isOn: Binding(
                        get: { nm.globalEnabled },
                        set: { nm.globalEnabled = $0; nm.rescheduleAll(allItems) }
                    )) { EmptyView() }
                    .toggleStyle(.switch)
                    .tint(accent)
                    .labelsHidden()
                }

                Divider().padding(.horizontal, 20)

                // Mute / DND
                SettingsRow(
                    icon: "moon.fill",
                    title: LocalizedStringKey("settings.notif.mute.title"),
                    desc: LocalizedStringKey("settings.notif.mute.desc")
                ) {
                    if let until = nm.muteUntil {
                        HStack {
                            Label(muteLabel(until), systemImage: "moon.fill")
                                .scaledFont(size: 12)
                                .foregroundStyle(accent)
                            Spacer()
                            Button(LocalizedStringKey("settings.notif.mute.unmute")) {
                                nm.muteUntil = nil
                                nm.rescheduleAll(allItems)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    } else {
                        HStack(spacing: 8) {
                            ForEach(MuteDuration.allCases) { d in
                                Button(d.label) {
                                    nm.muteUntil = d.until
                                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }

                if !groups.isEmpty {
                    Divider().padding(.horizontal, 20)

                    // Per-group filtering
                    SettingsRow(
                        icon: "folder",
                        title: LocalizedStringKey("settings.notif.groups.title"),
                        desc: LocalizedStringKey("settings.notif.groups.desc")
                    ) {
                        VStack(spacing: 4) {
                            ForEach(groups) { group in
                                let muted = nm.mutedGroupIDs.contains(group.id.uuidString)
                                HStack {
                                    Image(systemName: "folder")
                                        .scaledFont(size: 12)
                                        .foregroundStyle(muted ? .secondary : accent)
                                    Text(group.name)
                                        .scaledFont(size: 13)
                                        .foregroundStyle(muted ? .secondary : .primary)
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { !nm.mutedGroupIDs.contains(group.id.uuidString) },
                                        set: { enabled in
                                            var ids = nm.mutedGroupIDs
                                            if enabled { ids.remove(group.id.uuidString) }
                                            else { ids.insert(group.id.uuidString) }
                                            nm.mutedGroupIDs = ids
                                            nm.rescheduleAll(allItems)
                                        }
                                    ))
                                    .toggleStyle(.switch)
                                    .tint(accent)
                                    .labelsHidden()
                                }
                                .padding(.vertical, 3)
                            }
                        }
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical, 8)
        }
        .frame(minHeight: 260)
        .onAppear { Task { await nm.refreshAuthStatus() } }
        .disabled(true)
        .opacity(0.35)
        .blur(radius: 0.5)

            // Unavailability banner
            VStack(spacing: 12) {
                Image(systemName: "bell.slash")
                    .scaledFont(size: 28, weight: .light)
                    .foregroundStyle(.secondary)
                Text(LocalizedStringKey("settings.notif.unavailable.title"))
                    .scaledFont(size: 13, weight: .semibold)
                    .multilineTextAlignment(.center)
                Text(LocalizedStringKey("settings.notif.unavailable.desc"))
                    .scaledFont(size: 12)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 320)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.12), radius: 16, y: 4)
            .padding(.top, 60)
        }
    }

    private func muteLabel(_ until: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
        return String(format: NSLocalizedString("settings.notif.mute.until", comment: ""), f.string(from: until))
    }
}

// MARK: – Shortcut Tab

private struct ShortcutTab: View {
    @Environment(\.appAccent) private var accent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Text(LocalizedStringKey("settings.shortcut.desc"))
                    .scaledFont(size: 12)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                // Recorder row
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(LocalizedStringKey("settings.shortcut.label"))
                            .scaledFont(size: 13)
                        Text(LocalizedStringKey("settings.shortcut.default"))
                            .scaledFont(size: 11)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    KeyboardShortcuts.Recorder("", name: .quickAdd)
                }
                .padding(.horizontal, 20)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(LocalizedStringKey("settings.shortcut.focusMode.label"))
                            .scaledFont(size: 13)
                        Text(LocalizedStringKey("settings.shortcut.focusMode.default"))
                            .scaledFont(size: 11)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    KeyboardShortcuts.Recorder("", name: .focusMode)
                }
                .padding(.horizontal, 20)

                Divider().padding(.horizontal, 20)

                // How to change
                VStack(alignment: .leading, spacing: 8) {
                    Label(LocalizedStringKey("settings.shortcut.howto"), systemImage: "info.circle")
                        .scaledFont(size: 11, weight: .semibold)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 6) {
                        HelpRow(step: "1", text: NSLocalizedString("settings.shortcut.step1", comment: ""))
                        HelpRow(step: "2", text: NSLocalizedString("settings.shortcut.step2", comment: ""))
                        HelpRow(step: "3", text: NSLocalizedString("settings.shortcut.step3", comment: ""))
                        HelpRow(step: "!", text: NSLocalizedString("settings.shortcut.warning", comment: ""), isWarning: true)
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 20)
            }
        }
        .frame(minHeight: 260)
    }
}

// MARK: – Advanced Tab

private struct AdvancedTab: View {
    @Environment(\.modelContext) private var ctx
    @Query private var allItems: [TodoItem]
    @Query private var allGroups: [TodoGroup]
    @State private var showResetConfirm = false
    @State private var isBusy = false
    @Environment(\.appAccent) private var accent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Backup section
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "externaldrive")
                            .scaledFont(size: 16)
                            .foregroundStyle(accent)
                        Text(LocalizedStringKey("settings.backup.title"))
                            .scaledFont(size: 15, weight: .semibold)
                    }
                    Text(LocalizedStringKey("settings.backup.desc"))
                        .scaledFont(size: 12)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Button {
                            isBusy = true
                            Task { await BackupManager.shared.export(context: ctx); isBusy = false }
                        } label: {
                            Label(LocalizedStringKey("settings.backup.export"), systemImage: "square.and.arrow.up")
                                .scaledFont(size: 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        .controlSize(.small)
                        .disabled(isBusy || (allItems.isEmpty && allGroups.isEmpty))

                        Button {
                            isBusy = true
                            Task { await BackupManager.shared.import(context: ctx); isBusy = false }
                        } label: {
                            Label(LocalizedStringKey("settings.backup.import"), systemImage: "square.and.arrow.down")
                                .scaledFont(size: 12)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isBusy)

                        if isBusy { ProgressView().controlSize(.small) }
                    }
                }
                .padding(16)
                .background(accent.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(accent.opacity(0.12), lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Reset section
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .scaledFont(size: 16)
                            .foregroundStyle(.red.opacity(0.7))
                        Text(LocalizedStringKey("settings.reset.title"))
                            .scaledFont(size: 15, weight: .semibold)
                    }

                    Text(LocalizedStringKey("settings.reset.desc"))
                        .scaledFont(size: 12)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: NSLocalizedString("settings.reset.summary", comment: ""), allItems.count, allGroups.count))
                                .scaledFont(size: 12)
                                .foregroundStyle(.secondary)
                            Text(LocalizedStringKey("settings.reset.permanent"))
                                .scaledFont(size: 11)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            showResetConfirm = true
                        } label: {
                            Label(LocalizedStringKey("settings.reset.button"), systemImage: "trash")
                                .scaledFont(size: 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red.opacity(0.85))
                        .controlSize(.small)
                        .disabled(allItems.isEmpty && allGroups.isEmpty)
                    }
                }
                .padding(16)
                .background(Color.red.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.red.opacity(0.1), lineWidth: 1))
                .padding(.horizontal, 20)

                Spacer(minLength: 20)
            }
        }
        .frame(minHeight: 360)
        .confirmationDialog(
            LocalizedStringKey("settings.reset.confirm.title"),
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button(LocalizedStringKey("settings.reset.confirm.button"), role: .destructive) { resetAll() }
            Button(LocalizedStringKey("action.cancel"), role: .cancel) {}
        } message: {
            Text(String(format: NSLocalizedString("settings.reset.confirm.message", comment: ""), allItems.count, allGroups.count))
        }
    }

    private func resetAll() {
        allItems.forEach  { ctx.delete($0) }
        allGroups.forEach { ctx.delete($0) }
    }
}

// MARK: – Row wrapper

private struct SettingsRow<Content: View>: View {
    let icon: String
    let title: LocalizedStringKey
    let desc: LocalizedStringKey
    @ViewBuilder let content: Content
    @Environment(\.appAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .scaledFont(size: 16)
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).scaledFont(size: 13, weight: .semibold)
                    Text(desc).scaledFont(size: 11).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: – Accent color swatch

private struct AccentColorSwatch: View {
    let option: AccentColorOption
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(option.color)
                        .frame(width: 28, height: 28)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .scaledFont(size: 11, weight: .bold)
                            .foregroundStyle(.white)
                    }
                }
                .overlay(
                    Circle().strokeBorder(
                        isSelected ? option.color : (hovering ? Color.primary.opacity(0.2) : Color.clear),
                        lineWidth: isSelected ? 2 : 1
                    )
                    .scaleEffect(1.3)
                )
                .padding(4)

                Text(option.label)
                    .scaledFont(size: 9)
                    .foregroundStyle(isSelected ? option.color : .secondary)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .frame(maxWidth: .infinity)
    }
}

// MARK: – Font style swatch

private struct FontStyleSwatch: View {
    let option: FontStyleOption
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.appAccent) private var accent
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? accent.opacity(0.15) : Color.primary.opacity(hovering ? 0.07 : 0.04))
                        .frame(width: 52, height: 36)
                    Text("Aa")
                        .font(.system(size: 16, weight: isSelected ? .semibold : .regular, design: option.design))
                        .foregroundStyle(isSelected ? accent : .primary)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? accent : Color.clear, lineWidth: 1.5)
                )
                Text(option.label)
                    .scaledFont(size: 9)
                    .foregroundStyle(isSelected ? accent : .secondary)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

// MARK: – Appearance card

private struct AppearanceCard: View {
    let mode: AppearanceMode
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.appAccent) private var accent

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(previewBg)
                        .frame(height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(isSelected ? accent : Color.primary.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                        )
                    VStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { i in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(accent.opacity(0.6 - Double(i) * 0.15))
                                    .frame(width: 5, height: 5)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(previewFg.opacity(0.7 - Double(i) * 0.2))
                                    .frame(height: 4)
                            }
                            .padding(.horizontal, 10)
                        }
                    }
                }
                HStack(spacing: 4) {
                    Image(systemName: mode.icon).scaledFont(size: 10)
                    Text(mode.label).scaledFont(size: 11, weight: .medium)
                }
                .foregroundStyle(isSelected ? accent : .secondary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var previewBg: Color {
        switch mode {
        case .system: return Color(NSColor.windowBackgroundColor)
        case .light:  return Color(white: 0.97)
        case .dark:   return Color(white: 0.13)
        }
    }
    private var previewFg: Color { mode == .dark ? .white : .black }
}

// MARK: – Help row

private struct HelpRow: View {
    let step: String
    let text: String
    var isWarning: Bool = false
    @Environment(\.appAccent) private var accent

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(step)
                .scaledFont(size: 10, weight: .bold)
                .foregroundStyle(isWarning ? .orange : accent)
                .frame(width: 16, height: 16)
                .background((isWarning ? Color.orange : accent).opacity(0.12), in: Circle())
            Text(text)
                .scaledFont(size: 11)
                .foregroundStyle(isWarning ? Color.orange.opacity(0.9) : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: – Font scale control

private struct FontScaleControl: View {
    @Binding var scale: Double
    @Environment(\.appAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Preview
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .scaledFont(size: 14)
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("settings.fontSize.preview.title", comment: ""))
                        .scaledFont(size: 13.5, weight: .medium)
                    Text(NSLocalizedString("settings.fontSize.preview.desc", comment: ""))
                        .scaledFont(size: 12)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))

            // Slider
            HStack(spacing: 8) {
                Text("A").scaledFont(size: 10).foregroundStyle(.secondary)
                Slider(value: $scale, in: 0.75...1.50, step: 0.05)
                    .tint(accent)
                Text("A").scaledFont(size: 16).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: – Restart helper

private func restartApp() {
    // Close all windows (dismisses any open sheets/panels) so terminate is clean.
    NSApp.windows.forEach { $0.close() }

    // Spawn a shell that waits for this process to exit, then relaunches the app.
    // This avoids the double-instance problem caused by opening a new instance
    // before the current one has fully terminated.
    let pid  = ProcessInfo.processInfo.processIdentifier
    let path = Bundle.main.bundlePath
        .replacingOccurrences(of: "'", with: "'\\''") // safe single-quote escaping
    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments  = ["-c", "while kill -0 \(pid) 2>/dev/null; do sleep 0.05; done; open '\(path)'"]
    try? task.run()

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { NSApp.terminate(nil) }
}
