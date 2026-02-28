import Foundation
import SwiftData

struct TransientMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

@MainActor
final class AppState: ObservableObject {
    static let languageChosenKey = "app.language.chosen"
    static let onboardingKey = "onboarding.completed"
    static let initialPermissionsRequestedKey = "onboarding.initial_permissions.requested"

    @Published var hasChosenLanguage: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    @Published var transientMessage: TransientMessage?

    init() {
        let defaults = UserDefaults.standard
        let initial = Self.initialLaunchState(defaults: defaults)
        hasChosenLanguage = initial.hasChosenLanguage
        hasCompletedOnboarding = initial.hasCompletedOnboarding
    }

    static func initialLaunchState(defaults: UserDefaults) -> (hasChosenLanguage: Bool, hasCompletedOnboarding: Bool) {
        let hasPersistedLanguage = defaults.string(forKey: LanguageManager.languageCodeKey) != nil
        let hasChosen = defaults.bool(forKey: Self.languageChosenKey) || hasPersistedLanguage
        let hasOnboarded = defaults.bool(forKey: Self.onboardingKey)
        return (hasChosenLanguage: hasChosen, hasCompletedOnboarding: hasOnboarded)
    }

    func bootstrapIfNeeded(modelContext: ModelContext) async {
        let defaults = UserDefaults.standard
        let hasPersistedLanguage = defaults.string(forKey: LanguageManager.languageCodeKey) != nil
        let hasChosen = defaults.bool(forKey: Self.languageChosenKey) || hasPersistedLanguage
        hasChosenLanguage = hasChosen
        hasCompletedOnboarding = defaults.bool(forKey: Self.onboardingKey)

        if hasChosen && !defaults.bool(forKey: Self.languageChosenKey) {
            defaults.set(true, forKey: Self.languageChosenKey)
        }

        do {
            let descriptor = FetchDescriptor<Vault>()
            let vaults = try modelContext.fetch(descriptor)
            if vaults.isEmpty {
                modelContext.insert(Vault(name: "Personal", iconSystemName: "person.crop.circle", isSystemDefault: true))
                try modelContext.save()
            } else if !vaults.contains(where: { $0.isProtectedDefault }) {
                if let personal = vaults.first(where: { $0.name.caseInsensitiveCompare("Personal") == .orderedSame }) ?? vaults.first {
                    personal.isSystemDefault = true
                    if personal.iconSystemName.isEmpty {
                        personal.iconSystemName = "person.crop.circle"
                    }
                    try modelContext.save()
                }
            }
        } catch {
            assertionFailure("Failed initial bootstrap")
        }
    }

    func setLanguageChosen() {
        UserDefaults.standard.set(true, forKey: Self.languageChosenKey)
        hasChosenLanguage = true
    }

    func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
        hasCompletedOnboarding = true
        Task {
            await requestFirstRunPermissionsIfNeeded()
        }
    }

    func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: Self.onboardingKey)
        UserDefaults.standard.set(false, forKey: Self.initialPermissionsRequestedKey)
        hasCompletedOnboarding = false
    }

    func showMessage(_ text: String) {
        transientMessage = TransientMessage(text: text)
    }

    func shouldRequestInitialPermissions() -> Bool {
        !UserDefaults.standard.bool(forKey: Self.initialPermissionsRequestedKey)
    }

    func requestFirstRunPermissionsIfNeeded() async {
        await requestInitialPermissions(
            requestNotifications: { await NotificationService.shared.requestPermission() },
            requestCalendar: { try? await CalendarEventService.shared.requestCalendarAccessIfNeeded() },
            sleepNanoseconds: { try? await Task.sleep(nanoseconds: $0) }
        )
    }

    func requestInitialPermissions(
        requestNotifications: () async -> Bool,
        requestCalendar: () async -> Bool?,
        sleepNanoseconds: (UInt64) async -> Void
    ) async {
        guard shouldRequestInitialPermissions() else { return }
        UserDefaults.standard.set(true, forKey: Self.initialPermissionsRequestedKey)

        _ = await requestNotifications()
        await sleepNanoseconds(400_000_000)
        _ = await requestCalendar()
    }
}
