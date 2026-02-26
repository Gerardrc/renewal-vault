import Foundation
import SwiftData

struct TransientMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

@MainActor
final class AppState: ObservableObject {
    @Published var hasChosenLanguage: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    @Published var transientMessage: TransientMessage?

    private let onboardingKey = "onboarding.completed"

    func bootstrapIfNeeded(modelContext: ModelContext) async {
        hasChosenLanguage = UserDefaults.standard.string(forKey: LanguageManager.languageCodeKey) != nil
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)

        do {
            let descriptor = FetchDescriptor<Vault>()
            let vaults = try modelContext.fetch(descriptor)
            if vaults.isEmpty {
                modelContext.insert(Vault(name: "Personal", isSystemDefault: true))
                try modelContext.save()
            } else if !vaults.contains(where: { $0.isProtectedDefault }) {
                if let personal = vaults.first(where: { $0.name.caseInsensitiveCompare("Personal") == .orderedSame }) ?? vaults.first {
                    personal.isSystemDefault = true
                    try modelContext.save()
                }
            }
        } catch {
            assertionFailure("Failed initial bootstrap")
        }
    }

    func setLanguageChosen() { hasChosenLanguage = true }

    func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: onboardingKey)
        hasCompletedOnboarding = true
    }

    func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: onboardingKey)
        hasCompletedOnboarding = false
    }

    func showMessage(_ text: String) {
        transientMessage = TransientMessage(text: text)
    }
}
