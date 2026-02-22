import SwiftUI

struct LanguagePickerView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var appState: AppState
    @State private var selected: String

    init() {
        let preferred = Locale.preferredLanguages.first?.hasPrefix("es") == true ? "es" : "en"
        _selected = State(initialValue: preferred)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("language.title".localized).font(.largeTitle.bold())
            Picker("language.select".localized, selection: $selected) {
                Text("English").tag("en")
                Text("Español").tag("es")
            }
            .pickerStyle(.segmented)

            Button("language.continue".localized) {
                languageManager.setLanguage(selected)
                appState.setLanguageChosen()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
