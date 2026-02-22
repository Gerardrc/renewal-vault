import Foundation
import SwiftUI

@MainActor
final class LanguageManager: ObservableObject {
    static let languageCodeKey = "app.language.code"

    @Published var selectedLanguageCode: String {
        didSet {
            UserDefaults.standard.set(selectedLanguageCode, forKey: Self.languageCodeKey)
            locale = Locale(identifier: selectedLanguageCode)
        }
    }

    @Published private(set) var locale: Locale

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.languageCodeKey)
        let preferred = Locale.preferredLanguages.first?.hasPrefix("es") == true ? "es" : "en"
        let code = saved ?? preferred
        self.selectedLanguageCode = code
        self.locale = Locale(identifier: code)
    }

    func setLanguage(_ code: String) {
        selectedLanguageCode = code
    }
}

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
}
