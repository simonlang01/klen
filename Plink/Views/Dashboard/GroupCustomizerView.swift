import SwiftUI

struct GroupColorOption: Identifiable {
    let id: String
    let hex: String
    var isNone: Bool { hex == "none" }
}

let groupColorOptions: [GroupColorOption] = [
    .init(id: "#FF6B6B", hex: "#FF6B6B"), .init(id: "#FF9F43", hex: "#FF9F43"),
    .init(id: "#FECA57", hex: "#FECA57"), .init(id: "#48DBFB", hex: "#48DBFB"),
    .init(id: "#1DD1A1", hex: "#1DD1A1"), .init(id: "#54A0FF", hex: "#54A0FF"),
    .init(id: "#5F27CD", hex: "#5F27CD"), .init(id: "#FF9FF3", hex: "#FF9FF3"),
    .init(id: "#8395A7", hex: "#8395A7"), .init(id: "#2ECC71", hex: "#2ECC71"),
    .init(id: "#E17055", hex: "#E17055"), .init(id: "none",    hex: "none")
]

struct GroupColorGrid: View {
    let selectedHex: String?
    let onSelect: (String?) -> Void

    var body: some View {
        let cols = 6
        let rows = (groupColorOptions.count + cols - 1) / cols
        VStack(spacing: 6) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<cols, id: \.self) { col in
                        let idx = row * cols + col
                        if idx < groupColorOptions.count {
                            colorSwatch(groupColorOptions[idx])
                        }
                    }
                }
            }
        }
    }

    private func colorSwatch(_ option: GroupColorOption) -> some View {
        let isSelected = selectedHex == (option.isNone ? nil : option.hex)
        return Button { onSelect(option.isNone ? nil : option.hex) } label: {
            ZStack {
                if option.isNone {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                        .frame(width: 26, height: 26)
                    Image(systemName: "xmark").font(.system(size: 10)).foregroundStyle(.secondary)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: option.hex))
                        .frame(width: 26, height: 26)
                }
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(option.isNone ? .primary : .white)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct GroupCustomizerView: View {
    @Bindable var group: TodoGroup
    @Environment(\.appAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(LocalizedStringKey("group.customize.title"))
                .scaledFont(size: 13, weight: .semibold)

            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey("group.customize.color"))
                    .scaledFont(size: 11)
                    .foregroundStyle(.secondary)
                GroupColorGrid(selectedHex: group.colorHex) { hex in
                    group.colorHex = hex
                }
            }
        }
        .padding(16)
        .frame(width: 220)
    }
}
