import SwiftUI
import SwiftData
import KeyboardShortcuts

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label(LocalizedStringKey("settings.tab.general"), systemImage: "paintbrush") }

            SmartInputTab()
                .tabItem { Label(LocalizedStringKey("settings.tab.smartInput"), systemImage: "sparkles") }

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
                                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
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
                                .font(.system(size: 12))
                            Text(LocalizedStringKey("settings.language.spanish.soon"))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(LocalizedStringKey("settings.language.spanish.badge"))
                                .font(.system(size: 10, weight: .semibold))
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
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Toggle(isOn: $appState.smartInputEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey("settings.smart.toggle"))
                                .font(.system(size: 13))
                            Text(LocalizedStringKey("settings.smart.toggle.sub"))
                                .font(.system(size: 11))
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
                        .font(.system(size: 20))
                        .foregroundStyle(engine == .foundationModels ? accent : .secondary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: NSLocalizedString("settings.smart.engine", comment: ""), engine.label))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(engine == .foundationModels ? accent : .primary)
                        Text(LocalizedStringKey(engine == .foundationModels ? "settings.smart.engine.ai.desc" : "settings.smart.engine.nlp.desc"))
                            .font(.system(size: 11))
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

// MARK: – Shortcut Tab

private struct ShortcutTab: View {
    @Environment(\.appAccent) private var accent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Text(LocalizedStringKey("settings.shortcut.desc"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                // Recorder row
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(LocalizedStringKey("settings.shortcut.label"))
                            .font(.system(size: 13))
                        Text(LocalizedStringKey("settings.shortcut.default"))
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    KeyboardShortcuts.Recorder("", name: .quickAdd)
                }
                .padding(.horizontal, 20)

                Divider().padding(.horizontal, 20)

                // How to change
                VStack(alignment: .leading, spacing: 8) {
                    Label(LocalizedStringKey("settings.shortcut.howto"), systemImage: "info.circle")
                        .font(.system(size: 11, weight: .semibold))
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
    @Environment(\.appAccent) private var accent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Reset section
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 16))
                            .foregroundStyle(.red.opacity(0.7))
                        Text(LocalizedStringKey("settings.reset.title"))
                            .font(.system(size: 15, weight: .semibold))
                    }

                    Text(LocalizedStringKey("settings.reset.desc"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: NSLocalizedString("settings.reset.summary", comment: ""), allItems.count, allGroups.count))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text(LocalizedStringKey("settings.reset.permanent"))
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            showResetConfirm = true
                        } label: {
                            Label(LocalizedStringKey("settings.reset.button"), systemImage: "trash")
                                .font(.system(size: 12))
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
                .padding(.top, 20)

                Spacer(minLength: 20)
            }
        }
        .frame(minHeight: 260)
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
                    .font(.system(size: 16))
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(desc).font(.system(size: 11)).foregroundStyle(.secondary)
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
                            .font(.system(size: 11, weight: .bold))
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
                    .font(.system(size: 9))
                    .foregroundStyle(isSelected ? option.color : .secondary)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .frame(maxWidth: .infinity)
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
                    Image(systemName: mode.icon).font(.system(size: 10))
                    Text(mode.label).font(.system(size: 11, weight: .medium))
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
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(isWarning ? .orange : accent)
                .frame(width: 16, height: 16)
                .background((isWarning ? Color.orange : accent).opacity(0.12), in: Circle())
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(isWarning ? Color.orange.opacity(0.9) : .secondary)
                .fixedSize(horizontal: false, vertical: true)
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
