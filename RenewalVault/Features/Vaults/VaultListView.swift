import SwiftUI
import SwiftData

struct VaultListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlement: EntitlementService
    @Query(sort: \Vault.createdAt) private var vaults: [Vault]
    @State private var name = ""

    var body: some View {
        List {
            ForEach(vaults) { vault in
                Text(vault.name)
            }
            .onDelete(perform: delete)

            Section("vault.new".localized) {
                TextField("vault.name".localized, text: $name)
                Button("common.add".localized, action: add)
            }
        }
        .navigationTitle("tab.vaults".localized)
    }

    private func add() {
        guard !name.isEmpty else { return }
        guard FeatureGate.canCreateVault(currentCount: vaults.count, tier: entitlement.isPro ? .pro : .free) else { return }
        modelContext.insert(Vault(name: name))
        try? modelContext.save()
        name = ""
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { vaults[$0] }.forEach(modelContext.delete)
        try? modelContext.save()
    }
}
