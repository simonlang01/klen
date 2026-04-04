import SwiftUI

struct StatsHeaderView: View {
    let stats: DashboardViewModel.Stats
    @Environment(\.appAccent) private var accent

    var body: some View {
        HStack(spacing: 0) {
            StatCell(
                value: stats.openCount,
                label: NSLocalizedString("stats.open", comment: ""),
                icon: "tray.full",
                color: accent
            )
            divider
            StatCell(
                value: stats.dueToday,
                label: NSLocalizedString("stats.dueToday", comment: ""),
                icon: "sun.max",
                color: stats.dueToday > 0 ? accent : .secondary
            )
            divider
            StatCell(
                value: stats.overdueCount,
                label: NSLocalizedString("stats.overdue", comment: ""),
                icon: "exclamationmark.circle",
                color: stats.overdueCount > 0 ? .red.opacity(0.75) : .secondary
            )
            divider
            StatCell(
                value: stats.completedThisWeek,
                label: NSLocalizedString("stats.completedWeek", comment: ""),
                icon: "checkmark.circle",
                color: stats.completedThisWeek > 0 ? .green.opacity(0.7) : .secondary
            )
            divider
            StatCell(
                value: stats.createdThisWeek,
                label: NSLocalizedString("stats.createdWeek", comment: ""),
                icon: "plus.circle",
                color: .secondary
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.02))
    }

    private var divider: some View {
        Divider().frame(height: 28)
    }
}

private struct StatCell: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
    }
}
