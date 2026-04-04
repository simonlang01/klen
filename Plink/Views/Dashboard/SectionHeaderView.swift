import SwiftUI

struct SectionHeaderView: View {
    let section: TaskSection
    let count: Int
    var searchActive: Bool = false
    @Environment(\.appAccent) private var accent

    private var label: LocalizedStringKey {
        if section == .recentlyCompleted && searchActive { return "section.completed" }
        return section.label
    }

    private var sectionColor: Color {
        switch section {
        case .overdue:           return .red.opacity(0.75)
        case .recentlyCompleted: return accent.opacity(0.7)
        default:                 return .secondary
        }
    }

    private var icon: String? {
        switch section {
        case .overdue:           return "exclamationmark.circle.fill"
        case .recentlyCompleted: return "checkmark.circle.fill"
        case .today:             return "sun.max.fill"
        case .tomorrow:          return "sunrise.fill"
        case .next7Days:         return "calendar"
        case .later:             return "ellipsis.circle"
        case .noDate:            return "tray"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(sectionColor)
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(sectionColor)
                .textCase(.uppercase)
                .tracking(0.5)
            Text("\(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .padding(.bottom, 4)
    }
}
