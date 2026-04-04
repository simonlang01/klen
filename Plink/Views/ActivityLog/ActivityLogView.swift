import SwiftUI
import SwiftData

// MARK: – Model

struct ActivityEvent: Identifiable {
    enum Kind { case created, completed, deleted }
    let id: UUID
    let title: String
    let kind: Kind
    let date: Date
    let groupName: String?
}

// MARK: – View

struct ActivityLogView: View {
    @Query private var allItems: [TodoItem]
    @Environment(\.appAccent) private var accent

    private static let windowDays = 30

    private var events: [(Date, [ActivityEvent])] {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -Self.windowDays, to: cal.startOfDay(for: Date()))!

        var result: [ActivityEvent] = []
        for item in allItems {
            if item.createdAt >= cutoff {
                result.append(.init(id: UUID(), title: item.title, kind: .created,
                                    date: item.createdAt, groupName: item.group?.name))
            }
            if let d = item.completedAt, d >= cutoff {
                result.append(.init(id: UUID(), title: item.title, kind: .completed,
                                    date: d, groupName: item.group?.name))
            }
            if let d = item.deletedAt, d >= cutoff {
                result.append(.init(id: UUID(), title: item.title, kind: .deleted,
                                    date: d, groupName: item.group?.name))
            }
        }

        result.sort { $0.date > $1.date }

        // Group by calendar day
        let grouped = Dictionary(grouping: result) { event in
            cal.startOfDay(for: event.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .full; f.timeStyle = .none; return f
    }()
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none; return f
    }()

    var body: some View {
        if events.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(events, id: \.0) { day, dayEvents in
                        SwiftUI.Section {
                            ForEach(dayEvents) { event in
                                EventRow(event: event, timeFmt: Self.timeFmt)
                            }
                        } header: {
                            DayHeader(date: day, count: dayEvents.count, fmt: Self.dayFmt)
                                .background(.background)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(accent.opacity(0.4))
            Text(LocalizedStringKey("activitylog.empty"))
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: – Day header

private struct DayHeader: View {
    let date: Date
    let count: Int
    let fmt: DateFormatter
    @Environment(\.appAccent) private var accent

    private var isToday: Bool { Calendar.current.isDateInToday(date) }
    private var isYesterday: Bool { Calendar.current.isDateInYesterday(date) }

    private var label: String {
        if isToday     { return NSLocalizedString("task.date.today", comment: "") }
        if isYesterday { return NSLocalizedString("date.yesterday", comment: "") }
        return fmt.string(from: date)
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isToday ? accent : .secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Text("\(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 4)
    }
}

// MARK: – Event row

private struct EventRow: View {
    let event: ActivityEvent
    let timeFmt: DateFormatter

    private var icon: String {
        switch event.kind {
        case .created:   return "plus.circle"
        case .completed: return "checkmark.circle.fill"
        case .deleted:   return "trash"
        }
    }

    private var iconColor: Color {
        switch event.kind {
        case .created:   return .secondary
        case .completed: return .green.opacity(0.75)
        case .deleted:   return .red.opacity(0.6)
        }
    }

    private var kindLabel: LocalizedStringKey {
        switch event.kind {
        case .created:   return "activitylog.created"
        case .completed: return "activitylog.completed"
        case .deleted:   return "activitylog.deleted"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 13))
                    .foregroundStyle(event.kind == .deleted ? .secondary : .primary)
                    .strikethrough(event.kind == .deleted, color: .secondary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(kindLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    if let group = event.groupName {
                        Text("·").font(.system(size: 11)).foregroundStyle(.tertiary)
                        Text(group).font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Text(timeFmt.string(from: event.date))
                .font(.system(size: 11))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}
