import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var entitlement: EntitlementService
    @State private var showPaywall = false

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { languageManager.selectedLanguage },
            set: { languageManager.setLanguage($0) }
        )
    }

    var body: some View {
        List {
            Section("settings.language".localized) {
                Picker("settings.language".localized, selection: languageBinding) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("settings.subscription".localized) {
                Button("settings.manage_subscription".localized) { showPaywall = true }
                Button("settings.restore".localized) { Task { try? await entitlement.restorePurchases() } }
            }

            Section("settings.notifications".localized) {
                Button("settings.notification_settings".localized) { NotificationService.shared.openSettings() }
            }

            Section("settings.privacy".localized) {
                NavigationLink("settings.privacy".localized) { PrivacyView() }
            }
/*
            #if DEBUG
            Section("settings.developer".localized) {
                Toggle("settings.simulate_pro".localized, isOn: $entitlement.debugForcePro)
                    .onChange(of: entitlement.debugForcePro) { _ in
                        Task { await entitlement.refreshEntitlements() }
                    }
                Button("settings.reset_onboarding".localized) { appState.resetOnboarding() }
            }
            #endif
        }
 */
        .navigationTitle("tab.settings".localized)
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }
}
}
