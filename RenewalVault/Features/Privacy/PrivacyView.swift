import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("privacy.title".localized)
                    .font(.title.bold())

                privacySection(
                    titleKey: "privacy.section.data.title",
                    bodyKey: "privacy.section.data.body"
                )

                privacySection(
                    titleKey: "privacy.section.attachments.title",
                    bodyKey: "privacy.section.attachments.body"
                )

                privacySection(
                    titleKey: "privacy.section.notifications.title",
                    bodyKey: "privacy.section.notifications.body"
                )

                privacySection(
                    titleKey: "privacy.section.calendar.title",
                    bodyKey: "privacy.section.calendar.body"
                )

                privacySection(
                    titleKey: "privacy.section.subscriptions.title",
                    bodyKey: "privacy.section.subscriptions.body"
                )

                privacySection(
                    titleKey: "privacy.section.pdf.title",
                    bodyKey: "privacy.section.pdf.body"
                )

                privacySection(
                    titleKey: "privacy.section.sharing.title",
                    bodyKey: "privacy.section.sharing.body"
                )

                privacySection(
                    titleKey: "privacy.section.control.title",
                    bodyKey: "privacy.section.control.body"
                )

                privacySection(
                    titleKey: "privacy.section.changes.title",
                    bodyKey: "privacy.section.changes.body"
                )
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("settings.privacy".localized)
    }

    @ViewBuilder
    private func privacySection(titleKey: String, bodyKey: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titleKey.localized)
                .font(.headline)

            Text(bodyKey.localized)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)
        }
    }
}
