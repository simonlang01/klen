import SwiftUI

// MARK: – Accent colour options

enum AccentColorOption: String, CaseIterable, Identifiable {
    case teal, blue, indigo, violet, pink, red, orange, yellow, gray

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .teal:   return Color(hex: "#1D9E75")
        case .blue:   return Color(hex: "#0A84FF")
        case .indigo: return Color(hex: "#4F46E5")
        case .violet: return Color(hex: "#7C3AED")
        case .pink:   return Color(hex: "#DB2777")
        case .red:    return Color(hex: "#E03131")
        case .orange: return Color(hex: "#E8590C")
        case .yellow: return Color(hex: "#E67700")
        case .gray:   return Color(hex: "#5C5F66")
        }
    }

    var label: String { rawValue.capitalized }
}

// MARK: – Environment keys

struct AppAccentKey: EnvironmentKey {
    static let defaultValue: Color = AccentColorOption.teal.color
}

struct AppFontScaleKey: EnvironmentKey {
    static let defaultValue: Double = 1.0
}

extension EnvironmentValues {
    var appAccent: Color {
        get { self[AppAccentKey.self] }
        set { self[AppAccentKey.self] = newValue }
    }
    var appFontScale: Double {
        get { self[AppFontScaleKey.self] }
        set { self[AppFontScaleKey.self] = newValue }
    }
}

// MARK: – Static palette

enum Theme {
    // Brand background palette (from icon_reference.html)
    static let backgroundDark  = Color(hex: "#0A1F16")
    static let accentLight     = Color(hex: "#9FE1CB")
    static let cardDark        = Color(hex: "#0F3D28")
    static let cardMedium      = Color(hex: "#0F6E56")
    static let taskLine        = Color(hex: "#5DCAA5")
    static let backgroundLight = Color(hex: "#E1F5EE")
    static let backgroundDeep  = Color(hex: "#063D26")

    /// Default accent — use `@Environment(\.appAccent)` in views for the live value.
    static let defaultAccent   = AccentColorOption.teal.color
}

// MARK: – Scaled font modifier

private struct ScaledFontModifier: ViewModifier {
    let size: CGFloat
    var weight: Font.Weight = .regular
    var design: Font.Design = .default
    @Environment(\.appFontScale) private var scale

    func body(content: Content) -> some View {
        content.font(.system(size: size * scale, weight: weight, design: design))
    }
}

extension View {
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(ScaledFontModifier(size: size, weight: weight, design: design))
    }
}

// MARK: – Hex init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
