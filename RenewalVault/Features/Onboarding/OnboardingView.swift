import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var page = 0

    static var usesPermissionPrimerAlert: Bool { false }

    static let pageContent: [(title: String, icon: String)] = [
        ("onboard.track", "calendar.badge.clock"),
        ("onboard.smart", "bell.badge"),
        ("onboard.attach", "paperclip"),
        ("onboard.dashboard", "chart.pie"),
        ("onboard.export", "doc.richtext")
    ]

    private let pages = Self.pageContent
    private var isLastPage: Bool { page == pages.count - 1 }

    var body: some View {
        VStack {
            HStack {
                Spacer()
                if !isLastPage {
                    Button("common.skip".localized) { completeFlow() }
                }
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
                Spacer()
                if isLastPage {
                    Button("onboard.get_started".localized) {
                        completeFlow()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("common.next".localized) {
                        withAnimation { page += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }

    private func completeFlow() {
        appState.finishOnboarding()
    }
}
