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

// MARK: – Font style options

enum FontStyleOption: String, CaseIterable, Identifiable {
    case system, rounded, monospaced, serif

    var id: String { rawValue }

    var design: Font.Design {
        switch self {
        case .system:     return .default
        case .rounded:    return .rounded
        case .monospaced: return .monospaced
        case .serif:      return .serif
        }
    }

    var label: String {
        switch self {
        case .system:     return "San Francisco"
        case .rounded:    return "Rounded"
        case .monospaced: return "Monospaced"
        case .serif:      return "New York"
        }
    }

    var icon: String {
        switch self {
        case .system:     return "a"
        case .rounded:    return "a.circle"
        case .monospaced: return "chevron.left.forwardslash.chevron.right"
        case .serif:      return "italic"
        }
    }
}

// MARK: – Environment keys

struct AppAccentKey: EnvironmentKey {
    static let defaultValue: Color = AccentColorOption.teal.color
}

struct AppFontScaleKey: EnvironmentKey {
    static let defaultValue: Double = 1.0
}

struct AppFontStyleKey: EnvironmentKey {
    static let defaultValue: FontStyleOption = .system
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
    var appFontStyle: FontStyleOption {
        get { self[AppFontStyleKey.self] }
        set { self[AppFontStyleKey.self] = newValue }
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
    var design: Font.Design? = nil
    @Environment(\.appFontScale) private var scale
    @Environment(\.appFontStyle) private var style

    func body(content: Content) -> some View {
        content.font(.system(size: size * scale, weight: weight, design: design ?? style.design))
    }
}

extension View {
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design? = nil) -> some View {
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
