import SwiftUI

// MARK: – Model

struct HelpTopic: Identifiable {
    let id: String
    let icon: String
    let title: String
    let sections: [HelpSection]
}

struct HelpSection: Identifiable {
    let id: String
    let heading: String?
    let body: String
    var tip: String? = nil
    var warning: String? = nil
}

// MARK: – Content

private func loc(_ key: String) -> String { NSLocalizedString(key, comment: "") }

extension HelpTopic {
    // Computed so strings are re-evaluated after language change
    static var all: [HelpTopic] { [dashboard, quickAdd, smartInput, groups, recurring, menuBar, focusMode, notifications, search, trash, settings, shortcuts, backup, activityLog] }

    static var dashboard: HelpTopic { HelpTopic(
        id: "dashboard", icon: "square.grid.2x2", title: loc("help.dashboard.title"),
        sections: [
            .init(id: "d1", heading: loc("help.dashboard.s1.heading"), body: loc("help.dashboard.s1.body")),
            .init(id: "d5", heading: loc("help.dashboard.s5.heading"), body: loc("help.dashboard.s5.body"),
                  tip: loc("help.dashboard.s5.tip")),
            .init(id: "d2", heading: loc("help.dashboard.s2.heading"), body: loc("help.dashboard.s2.body"),
                  tip: loc("help.dashboard.s2.tip")),
            .init(id: "d3", heading: loc("help.dashboard.s3.heading"), body: loc("help.dashboard.s3.body")),
            .init(id: "d4", heading: loc("help.dashboard.s4.heading"), body: loc("help.dashboard.s4.body")),
            .init(id: "d6", heading: loc("help.dashboard.s6.heading"), body: loc("help.dashboard.s6.body"),
                  tip: loc("help.dashboard.s6.tip")),
            .init(id: "d7", heading: loc("help.dashboard.s7.heading"), body: loc("help.dashboard.s7.body"))
        ]
    )}

    static var quickAdd: HelpTopic { HelpTopic(
        id: "quickadd", icon: "plus.circle", title: loc("help.quickadd.title"),
        sections: [
            .init(id: "q1", heading: loc("help.quickadd.s1.heading"), body: loc("help.quickadd.s1.body"),
                  tip: loc("help.quickadd.s1.tip")),
            .init(id: "q2", heading: loc("help.quickadd.s2.heading"), body: loc("help.quickadd.s2.body")),
            .init(id: "q3", heading: loc("help.quickadd.s3.heading"), body: loc("help.quickadd.s3.body")),
            .init(id: "q4", heading: loc("help.quickadd.s4.heading"), body: loc("help.quickadd.s4.body")),
            .init(id: "q5", heading: loc("help.quickadd.s5.heading"), body: loc("help.quickadd.s5.body")),
            .init(id: "q6", heading: loc("help.quickadd.s6.heading"), body: loc("help.quickadd.s6.body"))
        ]
    )}

    static var smartInput: HelpTopic { HelpTopic(
        id: "smart", icon: "sparkles", title: loc("help.smart.title"),
        sections: [
            .init(id: "s1", heading: loc("help.smart.s1.heading"), body: loc("help.smart.s1.body")),
            .init(id: "s2", heading: loc("help.smart.s2.heading"), body: loc("help.smart.s2.body")),
            .init(id: "s3", heading: loc("help.smart.s3.heading"), body: loc("help.smart.s3.body")),
            .init(id: "s4", heading: loc("help.smart.s4.heading"), body: loc("help.smart.s4.body")),
            .init(id: "s5", heading: loc("help.smart.s5.heading"), body: loc("help.smart.s5.body"),
                  tip: loc("help.smart.s5.tip")),
            .init(id: "s6", heading: loc("help.smart.s6.heading"), body: loc("help.smart.s6.body"),
                  tip: loc("help.smart.s6.tip"))
        ]
    )}

    static var notifications: HelpTopic { HelpTopic(
        id: "notifications", icon: "bell.badge", title: loc("help.notif.title"),
        sections: [
            .init(id: "n1", heading: loc("help.notif.s1.heading"), body: loc("help.notif.s1.body")),
            .init(id: "n2", heading: loc("help.notif.s2.heading"), body: loc("help.notif.s2.body"),
                  tip: loc("help.notif.s2.tip")),
            .init(id: "n3", heading: loc("help.notif.s3.heading"), body: loc("help.notif.s3.body")),
            .init(id: "n4", heading: loc("help.notif.s4.heading"), body: loc("help.notif.s4.body"),
                  tip: loc("help.notif.s4.tip")),
        ]
    )}

    static var groups: HelpTopic { HelpTopic(
        id: "groups", icon: "folder", title: loc("help.groups.title"),
        sections: [
            .init(id: "g1", heading: loc("help.groups.s1.heading"), body: loc("help.groups.s1.body")),
            .init(id: "g2", heading: loc("help.groups.s2.heading"), body: loc("help.groups.s2.body")),
            .init(id: "g6", heading: loc("help.groups.s6.heading"), body: loc("help.groups.s6.body")),
            .init(id: "g7", heading: loc("help.groups.s7.heading"), body: loc("help.groups.s7.body"),
                  tip: loc("help.groups.s7.tip")),
            .init(id: "g3", heading: loc("help.groups.s3.heading"), body: loc("help.groups.s3.body")),
            .init(id: "g4", heading: loc("help.groups.s4.heading"), body: loc("help.groups.s4.body"),
                  tip: loc("help.groups.s4.tip")),
            .init(id: "g5", heading: loc("help.groups.s5.heading"), body: loc("help.groups.s5.body"))
        ]
    )}

    static var recurring: HelpTopic { HelpTopic(
        id: "recurring", icon: "arrow.2.circlepath", title: loc("help.recurring.title"),
        sections: [
            .init(id: "r1", heading: loc("help.recurring.s1.heading"), body: loc("help.recurring.s1.body")),
            .init(id: "r2", heading: loc("help.recurring.s2.heading"), body: loc("help.recurring.s2.body"),
                  tip: loc("help.recurring.s2.tip")),
            .init(id: "r3", heading: loc("help.recurring.s3.heading"), body: loc("help.recurring.s3.body"))
        ]
    )}

    static var menuBar: HelpTopic { HelpTopic(
        id: "menubar", icon: "menubar.rectangle", title: loc("help.menubar.title"),
        sections: [
            .init(id: "mb1", heading: loc("help.menubar.s1.heading"), body: loc("help.menubar.s1.body")),
            .init(id: "mb2", heading: loc("help.menubar.s2.heading"), body: loc("help.menubar.s2.body"),
                  tip: loc("help.menubar.s2.tip"))
        ]
    )}

    static var focusMode: HelpTopic { HelpTopic(
        id: "focus", icon: "scope", title: loc("help.focus.title"),
        sections: [
            .init(id: "f1", heading: loc("help.focus.s1.heading"), body: loc("help.focus.s1.body")),
            .init(id: "f2", heading: loc("help.focus.s2.heading"), body: loc("help.focus.s2.body"),
                  tip: loc("help.focus.s2.tip"))
        ]
    )}

    static var search: HelpTopic { HelpTopic(
        id: "search", icon: "magnifyingglass", title: loc("help.search.title"),
        sections: [
            .init(id: "sr1", heading: loc("help.search.s1.heading"), body: loc("help.search.s1.body")),
            .init(id: "sr2", heading: loc("help.search.s2.heading"), body: loc("help.search.s2.body"),
                  tip: loc("help.search.s2.tip")),
            .init(id: "sr3", heading: loc("help.search.s3.heading"), body: loc("help.search.s3.body"))
        ]
    )}

    static var trash: HelpTopic { HelpTopic(
        id: "trash", icon: "trash", title: loc("help.trash.title"),
        sections: [
            .init(id: "t1", heading: loc("help.trash.s1.heading"), body: loc("help.trash.s1.body")),
            .init(id: "t2", heading: loc("help.trash.s2.heading"), body: loc("help.trash.s2.body")),
            .init(id: "t3", heading: loc("help.trash.s3.heading"), body: loc("help.trash.s3.body"),
                  warning: loc("help.trash.s3.warning")),
            .init(id: "t4", heading: loc("help.trash.s4.heading"), body: loc("help.trash.s4.body"))
        ]
    )}

    static var settings: HelpTopic { HelpTopic(
        id: "settings", icon: "gearshape", title: loc("help.settings.title"),
        sections: [
            .init(id: "set1", heading: loc("help.settings.s1.heading"), body: loc("help.settings.s1.body")),
            .init(id: "set5", heading: loc("help.settings.s5.heading"), body: loc("help.settings.s5.body"),
                  tip: loc("help.settings.s5.tip")),
            .init(id: "set6", heading: loc("help.settings.s6.heading"), body: loc("help.settings.s6.body")),
            .init(id: "set2", heading: loc("help.settings.s2.heading"), body: loc("help.settings.s2.body")),
            .init(id: "set3", heading: loc("help.settings.s3.heading"), body: loc("help.settings.s3.body"),
                  warning: loc("help.settings.s3.warning")),
            .init(id: "set4", heading: loc("help.settings.s4.heading"), body: loc("help.settings.s4.body"),
                  warning: loc("help.settings.s4.warning"))
        ]
    )}

    static var shortcuts: HelpTopic { HelpTopic(
        id: "shortcuts", icon: "keyboard", title: loc("help.shortcuts.title"),
        sections: [
            .init(id: "k1", heading: loc("help.shortcuts.s1.heading"), body: loc("help.shortcuts.s1.body")),
            .init(id: "k2", heading: loc("help.shortcuts.s2.heading"), body: loc("help.shortcuts.s2.body")),
            .init(id: "k3", heading: loc("help.shortcuts.s3.heading"), body: loc("help.shortcuts.s3.body")),
            .init(id: "k4", heading: loc("help.shortcuts.s4.heading"), body: loc("help.shortcuts.s4.body")),
            .init(id: "k5", heading: loc("help.shortcuts.s5.heading"), body: loc("help.shortcuts.s5.body")),
            .init(id: "k6", heading: loc("help.shortcuts.s6.heading"), body: loc("help.shortcuts.s6.body"))
        ]
    )}

    static var backup: HelpTopic { HelpTopic(
        id: "backup", icon: "externaldrive", title: loc("help.backup.title"),
        sections: [
            .init(id: "b1", heading: loc("help.backup.s1.heading"), body: loc("help.backup.s1.body")),
            .init(id: "b2", heading: loc("help.backup.s2.heading"), body: loc("help.backup.s2.body"),
                  tip: loc("help.backup.s2.tip")),
            .init(id: "b3", heading: loc("help.backup.s3.heading"), body: loc("help.backup.s3.body"))
        ]
    )}

    static var activityLog: HelpTopic { HelpTopic(
        id: "activitylog", icon: "chart.bar.doc.horizontal", title: loc("help.activitylog.title"),
        sections: [
            .init(id: "al1", heading: loc("help.activitylog.s1.heading"), body: loc("help.activitylog.s1.body")),
            .init(id: "al2", heading: loc("help.activitylog.s2.heading"), body: loc("help.activitylog.s2.body")),
            .init(id: "al3", heading: loc("help.activitylog.s3.heading"), body: loc("help.activitylog.s3.body"),
                  tip: loc("help.activitylog.s3.tip"))
        ]
    )}
}

// MARK: – View

struct HelpView: View {
    @State private var selectedTopic: HelpTopic = HelpTopic.all[0]
    @Environment(\.appAccent) private var accent
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HSplitView {
            // ── Sidebar ──────────────────────────────────────────
            VStack(spacing: 2) {
                ForEach(HelpTopic.all) { topic in
                    HelpSidebarRow(
                        icon: topic.icon,
                        title: topic.title,
                        isSelected: selectedTopic.id == topic.id
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTopic = topic
                        }
                    }
                }
                Spacer()
            }
            .padding(.vertical, 12)
            .frame(minWidth: 140, idealWidth: 180, maxWidth: 300)
            .background(.background)

            // ── Content ──────────────────────────────────────────
            VStack(spacing: 0) {
                // Sticky header with close button
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: selectedTopic.icon)
                        .scaledFont(size: 18)
                        .foregroundStyle(accent)
                    Text(selectedTopic.title)
                        .scaledFont(size: 16, weight: .semibold)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .scaledFont(size: 18)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(LocalizedStringKey("task.discard.help"))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(.background)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(selectedTopic.sections) { section in
                            HelpSectionView(section: section)
                        }
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .frame(minWidth: 300, maxWidth: .infinity)
            .background(Color.primary.opacity(0.02))
        }
        .frame(minWidth: 580, idealWidth: 680, maxWidth: .infinity,
               minHeight: 380, idealHeight: 480, maxHeight: .infinity)
    }
}

// MARK: – Sidebar row

private struct HelpSidebarRow: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.appAccent) private var accent

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .scaledFont(size: 13)
                    .foregroundStyle(isSelected ? accent : .secondary)
                    .frame(width: 18)
                Text(title)
                    .scaledFont(size: 13)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? accent.opacity(0.12) : (hovering ? Color.primary.opacity(0.05) : Color.clear))
                    .padding(.horizontal, 6)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: – Section content

private struct HelpSectionView: View {
    let section: HelpSection
    @Environment(\.appAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let heading = section.heading {
                Text(heading)
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundStyle(accent)
            }

            Text(section.body)
                .scaledFont(size: 13)
                .foregroundStyle(.primary.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if let tip = section.tip {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb")
                        .scaledFont(size: 11)
                        .foregroundStyle(accent)
                        .padding(.top, 1)
                    Text(tip)
                        .scaledFont(size: 11)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            }

            if let warning = section.warning {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .scaledFont(size: 11)
                        .foregroundStyle(.orange)
                        .padding(.top, 1)
                    Text(warning)
                        .scaledFont(size: 11)
                        .foregroundStyle(.orange.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.bottom, 20)
    }
}
