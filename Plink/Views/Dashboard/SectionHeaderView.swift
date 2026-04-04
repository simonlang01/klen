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

    private var labelColor: Color {
        switch section {
        case .overdue: return .red.opacity(0.7)
        default:       return Color.primary.opacity(0.35)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Thin separator line
            Rectangle()
                .fill(labelColor.opacity(0.4))
                .frame(height: 1)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(labelColor)

            Text("\(count)")
                .font(.system(size: 11))
                .foregroundStyle(labelColor.opacity(0.5))

            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .padding(.bottom, 6)
    }
}
