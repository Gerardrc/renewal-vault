import SwiftUI

struct RootRouterView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        Group {
            if !appState.hasChosenLanguage {
                LanguagePickerView()
            } else if !appState.hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainTabView()
                    .id(languageManager.selectedLanguage.rawValue)
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label(LocalizedStringKey("tab.home"), systemImage: "house") }

            NavigationStack { VaultListView() }
                .tabItem { Label(LocalizedStringKey("tab.vaults"), systemImage: "archivebox") }

            NavigationStack { SettingsView() }
                .tabItem { Label(LocalizedStringKey("tab.settings"), systemImage: "gear") }
        }
        .alert(item: $appState.transientMessage) { message in
            Alert(title: Text("common.notice".localized), message: Text(message.text), dismissButton: .default(Text("common.ok".localized)))
        }
    }
}
