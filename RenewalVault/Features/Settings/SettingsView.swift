import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var entitlement: EntitlementService
    @State private var showPaywall = false

    var body: some View {
        List {
            Section("settings.language".localized) {
                Picker("settings.language".localized, selection: $languageManager.selectedLanguageCode) {
                    Text("English").tag("en")
                    Text("Español").tag("es")
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

            #if DEBUG
            Section("Developer") {
                Toggle("Simulate Pro", isOn: $entitlement.debugForcePro)
                    .onChange(of: entitlement.debugForcePro) { _ in
                        Task { await entitlement.refreshEntitlements() }
                    }
                Button("Reset onboarding") { appState.resetOnboarding() }
            }
            #endif
        }
        .navigationTitle("tab.settings".localized)
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }
}
