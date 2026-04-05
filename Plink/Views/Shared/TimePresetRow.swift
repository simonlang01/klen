import SwiftUI

/// Simple time row: a toggle chip + stepper time picker. No presets.
struct TimePresetRow: View {
    @Binding var hasDueTime: Bool
    @Binding var dueTime: Date
    @Environment(\.appAccent) private var accent

    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none; return f
    }()

    var body: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { hasDueTime.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .scaledFont(size: 12)
                    Text(hasDueTime ? Self.fmt.string(from: dueTime) : NSLocalizedString("task.time.add", comment: ""))
                        .scaledFont(size: 12)
                }
                .foregroundStyle(hasDueTime ? accent : .secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(hasDueTime ? accent.opacity(0.12) : Color.primary.opacity(0.06), in: Capsule())
            }
            .buttonStyle(.plain)

            if hasDueTime {
                DatePicker("", selection: $dueTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.stepperField)
                    .labelsHidden()
                    .fixedSize()
            }

            Spacer()
        }
    }
}
