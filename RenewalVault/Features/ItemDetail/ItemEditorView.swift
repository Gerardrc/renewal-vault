import SwiftUI
import SwiftData

struct ItemEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entitlement: EntitlementService
    @Query private var items: [Item]
    @Query(sort: \Vault.name) private var vaults: [Vault]

    let item: Item?
    @State private var title = ""
    @State private var category = ItemCategory.passport.rawValue
    @State private var issuer = ""
    @State private var expiryDate = Date().addingTimeInterval(60*60*24*30)
    @State private var notes = ""
    @State private var reminderDays = [30,14,7,1]
    @State private var selectedVaultID: UUID?

    var body: some View {
        Form {
            TextField("item.title".localized, text: $title)

            Picker("item.vault".localized, selection: $selectedVaultID) {
                ForEach(vaults) { vault in
                    Text(vault.name).tag(Optional(vault.id))
                }
            }
            .disabled(vaults.count <= 1)

            Picker("item.category".localized, selection: $category) {
                ForEach(ItemCategory.allCases) { c in Text("category.\(c.rawValue)".localized).tag(c.rawValue) }
            }
            TextField("item.issuer".localized, text: $issuer)
            DatePicker("item.expiry".localized, selection: $expiryDate, displayedComponents: .date)
            TextField("item.notes".localized, text: $notes, axis: .vertical)
            ReminderEditorView(reminderDays: $reminderDays)
        }
        .navigationTitle(item == nil ? "item.add".localized : "item.edit".localized)
        .toolbar {
            Button("common.save".localized) { save() }
        }
        .onAppear { load() }
    }

    private func load() {
        guard let item else {
            selectedVaultID = vaults.first?.id
            return
        }
        title = item.title
        category = item.category
        issuer = item.issuer ?? ""
        expiryDate = item.expiryDate
        notes = item.notes
        reminderDays = item.reminderScheduleDays
        selectedVaultID = item.vault?.id ?? vaults.first?.id
    }

    private func save() {
        guard !title.isEmpty else { return }
        if item == nil && !FeatureGate.canCreateItem(currentCount: items.count, tier: entitlement.isPro ? .pro : .free) { return }
        let normalized = Array(Set(reminderDays.filter { $0 >= 1 })).sorted(by: >)
        let selectedVault = vaults.first(where: { $0.id == selectedVaultID }) ?? vaults.first

        if let item {
            item.title = title
            item.category = category
            item.issuer = issuer.isEmpty ? nil : issuer
            item.expiryDate = expiryDate
            item.notes = notes
            item.reminderScheduleDays = normalized
            item.vault = selectedVault
            item.updatedAt = .now
            Task { await NotificationService.shared.reschedule(item: item) }
        } else {
            let new = Item(title: title, category: category, issuer: issuer.isEmpty ? nil : issuer, expiryDate: expiryDate, reminderScheduleDays: normalized, notes: notes, vault: selectedVault)
            modelContext.insert(new)
            Task { await NotificationService.shared.reschedule(item: new) }
        }
        try? modelContext.save()
        dismiss()
    }
}

struct ReminderEditorView: View {
    @Binding var reminderDays: [Int]
    @State private var custom = ""
    @FocusState private var customFocused: Bool
    let common = [90,60,30,14,7,1]

    var body: some View {
        Section("item.reminders".localized) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))]) {
                ForEach(common, id: \.self) { day in
                    let selected = reminderDays.contains(day)
                    Button("\(day)") {
                        if selected {
                            reminderDays.removeAll { $0 == day }
                        } else {
                            reminderDays.append(day)
                            reminderDays = Array(Set(reminderDays)).sorted(by: >)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(selected ? .blue : .gray)
                }
            }

            let customSelected = reminderDays.filter { !common.contains($0) }.sorted(by: >)
            if !customSelected.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("item.selected_custom".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))]) {
                        ForEach(customSelected, id: \.self) { day in
                            Button("\(day)") {
                                reminderDays.removeAll { $0 == day }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            HStack {
                TextField("item.custom_days".localized, text: $custom)
                    .keyboardType(.numberPad)
                    .focused($customFocused)
                Button("common.add".localized, action: addCustomDay)
            }
        }
    }

    private func addCustomDay() {
        let trimmed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let day = Int(trimmed), day >= 1 else {
            custom = ""
            return
        }
        guard !reminderDays.contains(day) else {
            custom = ""
            customFocused = false
            return
        }
        reminderDays.append(day)
        reminderDays = Array(Set(reminderDays)).sorted(by: >)
        custom = ""
        customFocused = false
    }
}
