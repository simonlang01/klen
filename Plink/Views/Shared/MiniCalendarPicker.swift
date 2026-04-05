import SwiftUI

struct MiniCalendarPicker: View {
    @Binding var selected: Date
    let onConfirm: () -> Void
    @Environment(\.appAccent) private var accent

    @State private var displayMonth: Date

    private let cal = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()

    init(selected: Binding<Date>, onConfirm: @escaping () -> Void) {
        _selected = selected
        self.onConfirm = onConfirm
        _displayMonth = State(initialValue: Calendar.current.startOfMonth(for: selected.wrappedValue))
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left").scaledFont(size: 12, weight: .semibold)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()
                Text(Self.monthFormatter.string(from: displayMonth))
                    .scaledFont(size: 13, weight: .semibold)
                Spacer()

                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right").scaledFont(size: 12, weight: .semibold)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            let syms = weekdaySymbols()
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(syms.indices, id: \.self) { i in
                    Text(syms[i])
                        .scaledFont(size: 10, weight: .medium)
                        .foregroundStyle(.tertiary)
                        .frame(height: 24)
                }
            }

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(days(), id: \.self) { date in
                    if let date {
                        let isSelected = cal.isDate(date, inSameDayAs: selected)
                        let isToday    = cal.isDateInToday(date)
                        let isPast     = date < cal.startOfDay(for: Date()) && !isToday

                        Button {
                            selected = date
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { onConfirm() }
                        } label: {
                            Text("\(cal.component(.day, from: date))")
                                .scaledFont(size: 12, weight: isSelected || isToday ? .semibold : .regular)
                                .foregroundStyle(
                                    isSelected ? Color.white :
                                    isToday    ? accent :
                                    isPast     ? Color.secondary.opacity(0.4) : Color.primary
                                )
                                .frame(width: 28, height: 28)
                                .background(
                                    isSelected ? accent : isToday ? accent.opacity(0.12) : Color.clear,
                                    in: Circle()
                                )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(width: 28, height: 28)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 230)
    }

    private func shiftMonth(_ delta: Int) {
        displayMonth = cal.date(byAdding: .month, value: delta, to: displayMonth) ?? displayMonth
    }

    private func weekdaySymbols() -> [String] {
        let syms = cal.veryShortWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(syms[first...] + syms[..<first])
    }

    private func days() -> [Date?] {
        guard let monthRange = cal.range(of: .day, in: .month, for: displayMonth),
              let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: displayMonth))
        else { return [] }

        let weekday = cal.component(.weekday, from: firstDay)
        let offset  = (weekday - cal.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: offset)
        for day in monthRange {
            result.append(cal.date(byAdding: .day, value: day - 1, to: firstDay))
        }
        return result
    }
}

extension Date {
    static var today: Date    { Calendar.current.startOfDay(for: Date()) }
    static var tomorrow: Date { Calendar.current.date(byAdding: .day, value: 1, to: .today)! }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
