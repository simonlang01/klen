import SwiftUI

struct RecurrencePickerRow: View {
    @Binding var frequency: RecurrenceFrequency
    @Binding var interval: Int
    var disabled: Bool = false
    @Environment(\.appAccent) private var accent

    var body: some View {
        HStack(spacing: 8) {
            // Frequency menu
            Menu {
                ForEach(RecurrenceFrequency.allCases, id: \.self) { freq in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { frequency = freq }
                    } label: {
                        Label(freq.label, systemImage: frequency == freq ? "checkmark" : freq.icon)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.2.circlepath")
                        .scaledFont(size: 12)
                    Text(frequency == .none
                         ? NSLocalizedString("recurrence.add", comment: "")
                         : frequency.label)
                        .scaledFont(size: 12)
                }
                .foregroundStyle(disabled ? Color.primary.opacity(0.25) : (frequency == .none ? .secondary : accent))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    disabled ? Color.primary.opacity(0.04) : (frequency == .none ? Color.primary.opacity(0.06) : accent.opacity(0.12)),
                    in: Capsule()
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(disabled)

            // Interval stepper — only when a frequency is set
            if frequency != .none {
                HStack(spacing: 6) {
                    Text(NSLocalizedString("recurrence.every", comment: ""))
                        .scaledFont(size: 12)
                        .foregroundStyle(.secondary)

                    Stepper(value: $interval, in: 1...99) {
                        Text("\(interval)")
                            .scaledFont(size: 12, weight: .medium)
                            .foregroundStyle(accent)
                            .frame(minWidth: 18, alignment: .trailing)
                    }
                    .fixedSize()

                    Text(unitLabel)
                        .scaledFont(size: 12)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }

            Spacer()
        }
    }

    private var unitLabel: String {
        switch frequency {
        case .none:    return ""
        case .daily:   return interval == 1
            ? NSLocalizedString("recurrence.unit.day", comment: "")
            : NSLocalizedString("recurrence.unit.days", comment: "")
        case .weekly:  return interval == 1
            ? NSLocalizedString("recurrence.unit.week", comment: "")
            : NSLocalizedString("recurrence.unit.weeks", comment: "")
        case .monthly: return interval == 1
            ? NSLocalizedString("recurrence.unit.month", comment: "")
            : NSLocalizedString("recurrence.unit.months", comment: "")
        case .yearly:  return interval == 1
            ? NSLocalizedString("recurrence.unit.year", comment: "")
            : NSLocalizedString("recurrence.unit.years", comment: "")
        }
    }
}
