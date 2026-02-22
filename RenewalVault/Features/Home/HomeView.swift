import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Item.expiryDate) private var items: [Item]
    @Query(sort: \Vault.name) private var vaults: [Vault]
    @State private var query = ""
    @State private var selectedVaultID: UUID?
    @State private var categoryFilter = ""
    @State private var upcomingOnly = false

    private var filtered: [Item] {
        items.filter { item in
            let qOK = query.isEmpty || item.title.localizedCaseInsensitiveContains(query) || (item.issuer?.localizedCaseInsensitiveContains(query) ?? false)
            let vOK = selectedVaultID == nil || item.vault?.id == selectedVaultID
            let cOK = categoryFilter.isEmpty || item.category == categoryFilter
            let upOK = !upcomingOnly || item.expiryDate >= Calendar.current.startOfDay(for: .now)
            return qOK && vOK && cOK && upOK
        }
    }

    var body: some View {
        List {
            Section("home.filters".localized) {
                TextField("home.search".localized, text: $query)
                Toggle("home.upcoming_only".localized, isOn: $upcomingOnly)
            }

            bucketSection(title: "home.expiring_soon".localized, bucket: .soon)
            bucketSection(title: "home.later".localized, bucket: .later)
            bucketSection(title: "home.expired".localized, bucket: .expired)

            if items.isEmpty {
                Section("home.empty".localized) {
                    Text("Passport • National ID • Driver’s license • Car insurance • Lease • Health insurance")
                        .font(.caption)
                }
            }
        }
        .navigationTitle("tab.home".localized)
        .toolbar {
            NavigationLink(destination: ItemEditorView(item: nil)) {
                Label("common.add".localized, systemImage: "plus")
            }
        }
    }

    @ViewBuilder
    private func bucketSection(title: String, bucket: ItemBucket) -> some View {
        let sectionItems = filtered.filter { ReminderScheduler.bucket(for: $0) == bucket }
        if !sectionItems.isEmpty {
            Section(title) {
                ForEach(sectionItems) { item in
                    NavigationLink(destination: ItemDetailView(item: item)) {
                        VStack(alignment: .leading) {
                            Text(item.title).font(.headline)
                            Text(item.vault?.name ?? "-") + Text(" · \(item.expiryDate.formatted(date: .abbreviated, time: .omitted))")
                        }
                    }
                }
            }
        }
    }
}
