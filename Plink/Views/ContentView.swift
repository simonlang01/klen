import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showOnboarding = !FileManager.default.fileExists(
        atPath: PersistenceController.dataDirectory.appendingPathComponent(".onboarding_complete").path
    )
    @State private var languageID = UUID()

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView { showOnboarding = false }
                    .frame(width: 520, height: 480)
            } else {
                DashboardView()
                    .frame(minWidth: 700, minHeight: 480)
            }
        }
        .id(languageID)
        .preferredColorScheme(appState.appearanceMode.colorScheme)
        .environment(\.appAccent, appState.accentOption.color)
        .onReceive(NotificationCenter.default.publisher(for: .plinkLanguageChanged)) { _ in
            languageID = UUID()
        }
    }
}
