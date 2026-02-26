import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case en
    case es

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .en: return "language.english".localized
        case .es: return "language.spanish".localized
        }
    }

    var bundleCode: String { rawValue }

    static var systemDefault: AppLanguage {
        Locale.preferredLanguages.first?.hasPrefix("es") == true ? .es : .en
    }
}

@MainActor
final class LanguageManager: ObservableObject {
    static let languageCodeKey = "app.language.code"

    @Published private(set) var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: Self.languageCodeKey)
            LocalizationBundle.setLanguage(code: selectedLanguage.bundleCode)
            locale = Locale(identifier: selectedLanguage.bundleCode)
            objectWillChange.send()
        }
    }

    @Published private(set) var locale: Locale

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.languageCodeKey)
        let language = AppLanguage(rawValue: saved ?? "") ?? AppLanguage.systemDefault
        self.selectedLanguage = language
        self.locale = Locale(identifier: language.bundleCode)
        LocalizationBundle.setLanguage(code: language.bundleCode)
    }

    func setLanguage(_ language: AppLanguage) {
        selectedLanguage = language
    }

    func setLanguage(code: String) {
        setLanguage(AppLanguage(rawValue: code) ?? .en)
    }
}

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
}
