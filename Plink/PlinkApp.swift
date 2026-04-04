import SwiftUI
import SwiftData
import Sparkle

@main
struct PlinkApp: App {
    @StateObject private var appState = AppState()
    // Sparkle updater — only active in Release builds
    #if !DEBUG
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    #endif

    init() {
        // Apply saved language before any UI or string resolution happens
        let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? {
            let sys = Locale.current.language.languageCode?.identifier ?? "en"
            return sys == "de" ? "de" : "en"
        }()
        UserDefaults.standard.set([lang], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        LanguageManager.apply()
    }

    private func setup() {
        let container = PersistenceController.shared.container
        QuickAddPanelController.shared.setup(container: container, appState: appState)
        StatusBarController.shared.setup(container: container)
        NotificationManager.shared.setup()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(PersistenceController.shared.container)
                .environmentObject(appState)
                .onAppear { setup() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        #if !DEBUG
        .commands {
            CommandGroup(after: .appInfo) {
                Button(LocalizedStringKey("app.checkForUpdates")) {
                    updaterController.checkForUpdates(nil)
                }
            }
        }
        #endif

        Settings {
            SettingsView()
                .environmentObject(appState)
                .modelContainer(PersistenceController.shared.container)
        }
    }
}
