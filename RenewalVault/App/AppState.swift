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
            let count = try modelContext.fetchCount(descriptor)
            if count == 0 {
                modelContext.insert(Vault(name: "Personal"))
                try modelContext.save()
            }
        } catch {
            assertionFailure("Failed initial bootstrap")
        }
    }

    func setLanguageChosen() {
        hasChosenLanguage = true
    }

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
