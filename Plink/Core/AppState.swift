import SwiftUI

extension Notification.Name {
    static let plinkLanguageChanged = Notification.Name("plinkLanguageChanged")
}

enum AppearanceMode: String, CaseIterable {
    case system, light, dark

    var label: String {
        switch self {
        case .system: return NSLocalizedString("settings.appearance.system", comment: "")
        case .light:  return NSLocalizedString("settings.appearance.light", comment: "")
        case .dark:   return NSLocalizedString("settings.appearance.dark", comment: "")
        }
    }
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// Global observable state shared across the app.
final class AppState: ObservableObject {
    @Published var isStatusBarRunning: Bool = true
    @Published var searchQuery: String = ""
    @Published var quickAddVisible: Bool = false

    @Published var appearanceMode: AppearanceMode {
        didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode") }
    }
    @Published var accentOption: AccentColorOption {
        didSet { UserDefaults.standard.set(accentOption.rawValue, forKey: "accentOption") }
    }
    @Published var smartInputEnabled: Bool {
        didSet { UserDefaults.standard.set(smartInputEnabled, forKey: "smartInputEnabled") }
    }
    @Published var fontScale: Double {
        didSet { UserDefaults.standard.set(fontScale, forKey: "fontScale") }
    }
    @Published var appLanguage: String {
        didSet {
            UserDefaults.standard.set(appLanguage, forKey: "appLanguage")
            UserDefaults.standard.set([appLanguage], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            NotificationCenter.default.post(name: .plinkLanguageChanged, object: nil)
        }
    }

    init() {
        let savedAppearance = UserDefaults.standard.string(forKey: "appearanceMode") ?? ""
        appearanceMode = AppearanceMode(rawValue: savedAppearance) ?? .system
        let savedAccent = UserDefaults.standard.string(forKey: "accentOption") ?? ""
        accentOption = AccentColorOption(rawValue: savedAccent) ?? .teal
        smartInputEnabled = UserDefaults.standard.bool(forKey: "smartInputEnabled")
        let savedScale = UserDefaults.standard.double(forKey: "fontScale")
        fontScale = savedScale == 0 ? 1.0 : savedScale
        appLanguage = LanguageManager.current
    }
}
