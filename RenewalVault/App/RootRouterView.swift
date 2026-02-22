import SwiftUI

struct RootRouterView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if !appState.hasChosenLanguage {
                LanguagePickerView()
            } else if !appState.hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("tab.home".localized, systemImage: "house") }

            NavigationStack { VaultListView() }
                .tabItem { Label("tab.vaults".localized, systemImage: "archivebox") }

            NavigationStack { SettingsView() }
                .tabItem { Label("tab.settings".localized, systemImage: "gear") }
        }
    }
}
