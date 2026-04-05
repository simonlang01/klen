import SwiftUI

struct StatsHeaderView: View {
    let stats: DashboardViewModel.Stats
    @Environment(\.appAccent) private var accent

    var body: some View {
        HStack(spacing: 16) {
            // Overdue — only shown when non-zero, always prominent
            if stats.overdueCount > 0 {
                StatPill(
                    value: stats.overdueCount,
                    label: NSLocalizedString("stats.overdue", comment: ""),
                    color: .red.opacity(0.8)
                )
            }

            // Due today
            if stats.dueToday > 0 {
                StatPill(
                    value: stats.dueToday,
                    label: NSLocalizedString("stats.dueToday", comment: ""),
                    color: accent
                )
            }

            Spacer()

            // Quiet stats — always visible but visually recessive
            HStack(spacing: 12) {
                QuietStat(value: stats.openCount,         label: NSLocalizedString("stats.open", comment: ""))
                QuietStat(value: stats.completedThisWeek, label: NSLocalizedString("stats.completedWeek.short", comment: ""))
                QuietStat(value: stats.createdThisWeek,   label: NSLocalizedString("stats.createdWeek.short", comment: ""))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .background(.background)
    }
}

// MARK: – Prominent pill (overdue / due today)

private struct StatPill: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Text("\(value)")
                .scaledFont(size: 12, weight: .semibold, design: .rounded)
                .foregroundStyle(color)
            Text(label)
                .scaledFont(size: 12)
                .foregroundStyle(color.opacity(0.85))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(color.opacity(0.10), in: Capsule())
    }
}

// MARK: – Quiet stat (open / done / created)

private struct QuietStat: View {
    let value: Int
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .scaledFont(size: 12, weight: .medium, design: .rounded)
                .foregroundStyle(.secondary)
            Text(label)
                .scaledFont(size: 12)
                .foregroundStyle(.tertiary)
        }
    }
}
