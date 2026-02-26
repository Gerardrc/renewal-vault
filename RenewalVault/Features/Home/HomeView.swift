import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Item.expiryDate) private var items: [Item]
    @Query(sort: \Vault.name) private var vaults: [Vault]
    @State private var query = ""
    @State private var selectedVaultID: UUID?
    @State private var categoryFilter = ""
    @State private var upcomingOnly = false
    @State private var showCompleted = false

    private var filtered: [Item] {
        items.filter { item in
            let qOK = query.isEmpty || item.title.localizedCaseInsensitiveContains(query) || (item.issuer?.localizedCaseInsensitiveContains(query) ?? false)
            let vOK = selectedVaultID == nil || item.vault?.id == selectedVaultID
            let cOK = categoryFilter.isEmpty || item.category == categoryFilter
            let upOK = !upcomingOnly || item.expiryDate >= Calendar.current.startOfDay(for: .now)
            let completionOK = showCompleted || !item.isCompleted
            return qOK && vOK && cOK && upOK && completionOK
        }
    }

    var body: some View {
        List {
            Section("home.filters".localized) {
                TextField("home.search".localized, text: $query)
                Picker("home.vault_filter".localized, selection: $selectedVaultID) {
                    Text("home.all_vaults".localized).tag(UUID?.none)
                    ForEach(vaults) { vault in
                        Text(vault.name).tag(Optional(vault.id))
                    }
                }
                Picker("home.category_filter".localized, selection: $categoryFilter) {
                    Text("home.all_categories".localized).tag("")
                    ForEach(ItemCategory.allCases) { c in
                        Text("category.\(c.rawValue)".localized).tag(c.rawValue)
                    }
                }
                Toggle("home.upcoming_only".localized, isOn: $upcomingOnly)
                Toggle("home.show_completed".localized, isOn: $showCompleted)
            }

            bucketSection(title: "home.expiring_soon".localized, bucket: .soon)
            bucketSection(title: "home.later".localized, bucket: .later)
            bucketSection(title: "home.expired".localized, bucket: .expired)

            if items.isEmpty {
                Section("home.empty".localized) {
                    Text("home.empty_templates".localized)
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
                            HStack {
                                Text(item.title).font(.headline)
                                if item.isCompleted {
                                    Text("item.completed_badge".localized)
                                        .font(.caption2)
                                        .padding(4)
                                        .background(.gray.opacity(0.2), in: Capsule())
                                }
                            }
                            Text(item.vault?.name ?? "-") + Text(" · \(item.expiryDate.formatted(date: .abbreviated, time: .omitted))")
                        }
                    }
                }
            }
        }
    }
}
