import SwiftUI

struct LanguagePickerView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var appState: AppState
    @State private var selected: AppLanguage

    init() {
        _selected = State(initialValue: AppLanguage.systemDefault)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("language.title".localized).font(.largeTitle.bold())
            Picker("language.select".localized, selection: $selected) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(.segmented)

            Button("language.continue".localized) {
                languageManager.setLanguage(selected)
                appState.setLanguageChosen()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear { selected = languageManager.selectedLanguage }
    }
}
