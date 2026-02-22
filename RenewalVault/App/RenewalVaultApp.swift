import SwiftUI
import SwiftData

@main
struct RenewalVaultApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var entitlementService = EntitlementService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Vault.self,
            Item.self,
            Attachment.self,
            RenewalEvent.self,
            AppPreference.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootRouterView()
                .environmentObject(appState)
                .environmentObject(languageManager)
                .environmentObject(entitlementService)
                .environment(\.locale, languageManager.locale)
                .task {
                    await appState.bootstrapIfNeeded(modelContext: sharedModelContainer.mainContext)
                    await entitlementService.observeEntitlements()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
