import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var page = 0

    private let pages = ["onboard.track", "onboard.smart", "onboard.attach", "onboard.export"]

    var body: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { idx, key in
                    VStack(spacing: 12) {
                        Image(systemName: ["calendar.badge.clock","bell.badge","paperclip","doc.richtext"][idx])
                            .font(.system(size: 58))
                        Text(key.localized).font(.title2.bold())
                    }
                    .tag(idx)
                }
            }
            .tabViewStyle(.page)

            HStack {
                Button("common.skip".localized) { appState.finishOnboarding() }
                Spacer()
                Button("onboard.get_started".localized) { appState.finishOnboarding() }
                    .buttonStyle(.borderedProminent)
            }.padding()
        }
    }
}
