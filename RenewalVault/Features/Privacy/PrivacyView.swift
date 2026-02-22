import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            Text("privacy.body".localized)
                .padding()
        }
        .navigationTitle("settings.privacy".localized)
    }
}
