import SwiftUI
import SwiftData
import UIKit

struct VaultListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlement: EntitlementService
    @State private var showUpgradeAlert = false
    @State private var showDeleteErrorAlert = false
    @State private var showCreateVault = false
    @State private var editingVault: Vault?
    @State private var showPaywall = false
    @Query(sort: \Vault.createdAt) private var vaults: [Vault]

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(vaults) { vault in
                    NavigationLink(destination: VaultDetailView(vault: vault)) {
                        VaultCardView(vault: vault)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("common.edit".localized) {
                            editingVault = vault
                        }
                        if !vault.isProtectedDefault {
                            Button("item.delete".localized, role: .destructive) {
                                delete(vault)
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("tab.vaults".localized)
        .toolbar {
            Button {
                if canCreateVault() {
                    showCreateVault = true
                } else {
                    showUpgradeAlert = true
                }
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showCreateVault) {
            NavigationStack {
                VaultEditorView(mode: .create)
            }
        }
        .sheet(item: $editingVault) { vault in
            NavigationStack {
                VaultEditorView(mode: .edit(vault))
            }
        }
        .sheet(isPresented: $showPaywall) {
            NavigationStack { PaywallView() }
        }
        .alert("vault.pro_required_title".localized, isPresented: $showUpgradeAlert) {
            Button("common.close".localized, role: .cancel) {}
            Button("common.go_pro".localized) {
                showPaywall = true
            }
        } message: {
            Text("vault.upgrade_required".localized)
        }
        .alert("common.notice".localized, isPresented: $showDeleteErrorAlert) {
            Button("common.ok".localized, role: .cancel) {}
        } message: {
            Text("vault.delete_failed".localized)
        }
    }

    private func canCreateVault() -> Bool {
        FeatureGate.canCreateVault(currentCount: vaults.count, tier: entitlement.isPro ? .pro : .free)
    }

    private func delete(_ vault: Vault) {
        guard !vault.isProtectedDefault else {
            showDeleteErrorAlert = true
            return
        }
        modelContext.delete(vault)
        do {
            try modelContext.save()
        } catch {
            showDeleteErrorAlert = true
        }
    }
}

struct VaultCardView: View {
    let vault: Vault

    static func shouldShowDefaultBadge(for vault: Vault) -> Bool {
        false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: vault.resolvedIconSystemName)
                .font(.title2)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))

            Spacer(minLength: 0)

            Text(vault.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text(String(format: "vault.items_count".localized, vault.items.count))
                .font(.caption)
                .foregroundStyle(.secondary)

        }
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

private enum VaultEditorMode {
    case create
    case edit(Vault)

    var titleKey: String {
        switch self {
        case .create: return "vault.create"
        case .edit: return "vault.edit"
        }
    }

    var isCreate: Bool {
        if case .create = self { return true }
        return false
    }
}

private struct VaultEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: VaultEditorMode
    @State private var name = ""
    @State private var selectedIcon = VaultIcon.person.systemName

    var body: some View {
        Form {
            TextField("vault.name".localized, text: $name)
            Section("vault.icon".localized) {
                VaultIconPicker(selectedIcon: $selectedIcon)
            }
        }
        .navigationTitle(mode.titleKey.localized)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel".localized) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(mode.isCreate ? "vault.create_action".localized : "common.save".localized) {
                    save()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        if case .edit(let vault) = mode {
            name = vault.name
            selectedIcon = vault.resolvedIconSystemName
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch mode {
        case .create:
            modelContext.insert(Vault(name: trimmed, iconSystemName: selectedIcon))
        case .edit(let vault):
            vault.name = trimmed
            vault.iconSystemName = selectedIcon
            vault.updatedAt = .now
        }

        try? modelContext.save()
        dismiss()
    }
}

private struct VaultIconPicker: View {
    @Binding var selectedIcon: String

    private let columns = [GridItem(.adaptive(minimum: 60), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(VaultIcon.allCases) { icon in
                Button {
                    selectedIcon = icon.systemName
                } label: {
                    Image(systemName: icon.systemName)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(selectedIcon == icon.systemName ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct VaultDetailView: View {
    @EnvironmentObject private var entitlement: EntitlementService
    let vault: Vault
    @Query(sort: \Item.expiryDate) private var allItems: [Item]
    @State private var showEdit = false
    @State private var showExportUpsellAlert = false
    @State private var showPaywall = false
    @State private var exportDraft: ExportDraft?
    @State private var showExportErrorAlert = false

    private struct ExportDraft: Identifiable {
        let id = UUID()
        let url: URL
    }

    var vaultItems: [Item] {
        Self.items(for: vault.id, in: allItems)
    }

    var body: some View {
        List {
            if vaultItems.isEmpty {
                Text("vault.empty_items".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vaultItems) { item in
                    NavigationLink(destination: ItemDetailView(item: item)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                            Text(HomeView.subtitleText(for: item)) + Text(" · \(item.expiryDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(vault.name)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("vault.export_pdf".localized) {
                    exportVaultPDF()
                }
                Button("common.edit".localized) {
                    showEdit = true
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            NavigationStack {
                VaultEditorView(mode: .edit(vault))
            }
        }
        .sheet(isPresented: $showPaywall) {
            NavigationStack { PaywallView() }
        }
        .sheet(item: $exportDraft) { draft in
            ShareSheet(activityItems: [draft.url])
        }
        .alert("vault.pro_required_title".localized, isPresented: $showExportUpsellAlert) {
            Button("common.close".localized, role: .cancel) {}
            Button("common.go_pro".localized) {
                showPaywall = true
            }
        } message: {
            Text("vault.export_requires_pro".localized)
        }
        .alert("common.notice".localized, isPresented: $showExportErrorAlert) {
            Button("common.ok".localized, role: .cancel) {}
        } message: {
            Text("vault.export_failed".localized)
        }
    }

    private func exportVaultPDF() {
        guard Self.canExportPDF(isPro: entitlement.isPro) else {
            showExportUpsellAlert = true
            return
        }

        guard let url = VaultPDFExporter().export(vault: vault) else {
            showExportErrorAlert = true
            return
        }

        exportDraft = ExportDraft(url: url)
    }

    static var hasExportAction: Bool { true }

    static func canExportPDF(isPro: Bool) -> Bool {
        FeatureGate.canExportPDF(tier: isPro ? .pro : .free)
    }

    static func items(for vaultID: UUID, in items: [Item]) -> [Item] {
        items.filter { $0.vault?.id == vaultID }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
