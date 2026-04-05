import SwiftUI

/// Unified date + time picker row used in AddTaskSheet, TaskDetailView, and QuickAddView.
/// Shows Today / Tomorrow / custom-date chips, plus an optional time chip once a date is selected.
struct DateTimePickerRow: View {
    /// The selected date (date-only, no time component). nil = no date.
    @Binding var date: Date?
    @Binding var hasDueTime: Bool
    @Binding var dueTime: Date

    @State private var showCalendar = false
    @Environment(\.appAccent) private var accent

    private var isToday: Bool    { date.map { Calendar.current.isDateInToday($0) } ?? false }
    private var isTomorrow: Bool { date.map { Calendar.current.isDateInTomorrow($0) } ?? false }
    private var isCustom: Bool   { date != nil && !isToday && !isTomorrow }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none; return f
    }()

    var body: some View {
        HStack(spacing: 6) {
            // ── Today ──────────────────────────────────────────────
            DTChip(label: NSLocalizedString("task.date.today", comment: ""), icon: "sun.max", active: isToday) {
                if isToday { clearDate() }
                else { date = .today }
            }

            // ── Tomorrow ───────────────────────────────────────────
            DTChip(label: NSLocalizedString("task.date.tomorrow", comment: ""), icon: "sunrise", active: isTomorrow) {
                if isTomorrow { clearDate() }
                else { date = .tomorrow }
            }

            // ── Custom date ────────────────────────────────────────
            DTChip(
                label: isCustom ? Self.dateFmt.string(from: date!) : NSLocalizedString("task.date.custom", comment: ""),
                icon: "calendar",
                active: isCustom || showCalendar
            ) {
                if isCustom { clearDate() }
                else { showCalendar.toggle() }
            }
            .popover(isPresented: $showCalendar, arrowEdge: .bottom) {
                MiniCalendarPicker(
                    selected: Binding(
                        get: { date ?? .today },
                        set: { date = $0; showCalendar = false }
                    )
                ) { showCalendar = false }
            }

            // ── Time (only when a date is selected) ────────────────
            if date != nil {
                Divider().frame(height: 14)

                DTChip(
                    label: hasDueTime
                        ? Self.timeFmt.string(from: dueTime)
                        : NSLocalizedString("task.time.add", comment: ""),
                    icon: "clock",
                    active: hasDueTime
                ) { hasDueTime.toggle() }

                if hasDueTime {
                    DatePicker("", selection: $dueTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.stepperField)
                        .labelsHidden()
                        .fixedSize()
                }
            }

            Spacer()
        }
    }

    private func clearDate() {
        date = nil
        hasDueTime = false
    }
}

// MARK: – Chip

private struct DTChip: View {
    let label: String
    let icon: String
    var active: Bool = false
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.appAccent) private var accent

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).scaledFont(size: 11)
                Text(label).scaledFont(size: 12).lineLimit(1)
            }
            .foregroundStyle(active || hovering ? accent : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(active || hovering ? accent.opacity(0.1) : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
