import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var page = 0

    private let pages: [(title: String, icon: String)] = [
        ("onboard.track", "calendar.badge.clock"),
        ("onboard.smart", "bell.badge"),
        ("onboard.attach", "paperclip"),
        ("onboard.export", "doc.richtext")
    ]

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("common.skip".localized) { appState.finishOnboarding() }
            }
            .padding([.top, .horizontal])

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { idx, pageData in
                    VStack(spacing: 12) {
                        Image(systemName: pageData.icon)
                            .font(.system(size: 58))
                        Text(pageData.title.localized)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .tag(idx)
                }
            }
            .tabViewStyle(.page)

            HStack {
                if page < pages.count - 1 {
                    Button("common.next".localized) {
                        withAnimation { page += 1 }
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
                Button("onboard.get_started".localized) {
                    if page < pages.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        appState.finishOnboarding()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}
