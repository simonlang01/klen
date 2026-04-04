import SwiftUI
import SwiftData

enum TaskSection: String, CaseIterable {
    case overdue, today, tomorrow, next7Days, later, noDate, recentlyCompleted
    var label: LocalizedStringKey {
        switch self {
        case .overdue:           return "section.overdue"
        case .today:             return "section.today"
        case .tomorrow:          return "section.tomorrow"
        case .next7Days:         return "section.next7Days"
        case .later:             return "section.later"
        case .noDate:            return "section.noDate"
        case .recentlyCompleted: return "section.recentlyCompleted"
        }
    }
}

enum GroupFilter: Equatable {
    case all
    case unassigned
    case group(TodoGroup)

    static func == (lhs: GroupFilter, rhs: GroupFilter) -> Bool {
        switch (lhs, rhs) {
        case (.all, .all), (.unassigned, .unassigned): return true
        case (.group(let a), .group(let b)):            return a.id == b.id
        default:                                        return false
        }
    }
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var groupFilter: GroupFilter = .all
    @Published var searchQuery: String = ""

    /// Recently completed window shown in main list (30 min). Activity log shows full history.
    static let completedVisibilityWindow: TimeInterval = 30 * 60

    func sections(from items: [TodoItem], tick: Bool = false) -> [(TaskSection, [TodoItem])] {
        let cal = Calendar.current
        let now = Date()
        let startOfToday    = cal.startOfDay(for: now)
        let startOfTomorrow = cal.date(byAdding: .day, value: 1, to: startOfToday)!
        let startOfDayAfter = cal.date(byAdding: .day, value: 2, to: startOfToday)!
        let startOfIn7Days  = cal.date(byAdding: .day, value: 7, to: startOfTomorrow)!
        let cutoff          = now.addingTimeInterval(-Self.completedVisibilityWindow)

        let active = items.filter { !$0.isCompleted && !$0.isDeleted && matches($0) }
        let recentDone = items.filter {
            $0.isCompleted && !$0.isDeleted && matches($0) &&
            (searchQuery.isEmpty ? ($0.completedAt ?? .distantPast) > cutoff : true)
        }

        func bucket(_ item: TodoItem) -> TaskSection {
            guard let due = item.dueDate else { return .noDate }
            if due < startOfToday    { return .overdue }
            if due < startOfTomorrow { return .today }
            if due < startOfDayAfter { return .tomorrow }
            if due < startOfIn7Days  { return .next7Days }
            return .later
        }

        let grouped = Dictionary(grouping: active, by: bucket)
        var result: [(TaskSection, [TodoItem])] = TaskSection.allCases.compactMap { section in
            guard section != .recentlyCompleted else { return nil }
            guard let items = grouped[section], !items.isEmpty else { return nil }
            return (section, items.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) })
        }

        if !recentDone.isEmpty {
            result.append((.recentlyCompleted, recentDone.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }))
        }
        return result
    }

    // MARK: – Stats

    struct Stats {
        let openCount: Int
        let dueToday: Int
        let completedThisWeek: Int
        let createdThisWeek: Int
        let overdueCount: Int
    }

    func stats(from items: [TodoItem]) -> Stats {
        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        let startOfWeek  = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!

        let active = items.filter { !$0.isDeleted }
        return Stats(
            openCount:         active.filter { !$0.isCompleted }.count,
            dueToday:          active.filter { !$0.isCompleted && ($0.dueDate.map { cal.isDateInToday($0) } ?? false) }.count,
            completedThisWeek: active.filter { $0.isCompleted && ($0.completedAt ?? .distantPast) >= startOfWeek }.count,
            createdThisWeek:   active.filter { $0.createdAt >= startOfWeek }.count,
            overdueCount:      active.filter { !$0.isCompleted && ($0.dueDate.map { $0 < startOfToday } ?? false) }.count
        )
    }

    private func matches(_ item: TodoItem) -> Bool {
        let inGroup: Bool = {
            switch groupFilter {
            case .all:            return true
            case .unassigned:     return item.group == nil
            case .group(let g):   return item.group?.id == g.id
            }
        }()
        guard !searchQuery.isEmpty else { return inGroup }
        let textMatch = item.title.localizedCaseInsensitiveContains(searchQuery)
                     || item.desc.localizedCaseInsensitiveContains(searchQuery)
        return inGroup && textMatch
    }
}
