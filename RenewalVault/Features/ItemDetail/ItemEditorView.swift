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
    @State private var reminderDays: [Int] = []
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
            reminderDays = []
            return
        }
        title = item.title
        category = item.category
        issuer = item.issuer ?? ""
        expiryDate = item.expiryDate
        notes = item.notes
        reminderDays = ReminderDayOptions.normalized(item.reminderScheduleDays)
        selectedVaultID = item.vault?.id ?? vaults.first?.id
    }

    private func save() {
        guard !title.isEmpty else { return }
        if item == nil && !FeatureGate.canCreateItem(currentCount: items.count, tier: entitlement.isPro ? .pro : .free) { return }
        let normalized = ReminderDayOptions.normalized(reminderDays)
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
    @State private var customOptions: [Int] = []
    @FocusState private var customFocused: Bool

    private var availableDays: [Int] {
        ReminderDayOptions.availableDays(selected: reminderDays, customAvailable: customOptions)
    }

    var body: some View {
        Section("item.reminders".localized) {
            VStack(alignment: .leading, spacing: 8) {
                Text("item.reminders_help".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                FlowWrap(items: availableDays) { day in
                    Button {
                        reminderDays = ReminderDayOptions.toggle(day: day, selected: reminderDays)
                    } label: {
                        Text("\(day)")
                            .font(.subheadline.weight(.semibold))
                            .frame(minWidth: 44)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                reminderDays.contains(day) ? Color.accentColor : Color.gray.opacity(0.15),
                                in: Capsule()
                            )
                            .foregroundStyle(
                                reminderDays.contains(day) ? Color.white : Color.primary
                            )
                    }
                    .buttonStyle(.plain)
                }

                if reminderDays.isEmpty {
                    Text("item.reminders_none_selected".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(String(format: "item.reminders_selected_count".localized, reminderDays.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    TextField("item.custom_days".localized, text: $custom)
                        .keyboardType(.numberPad)
                        .focused($customFocused)
                    Button("common.add".localized, action: addCustomDay)
                }
            }
        }
        .onAppear {
            customOptions = reminderDays.filter { !ReminderDayOptions.presets.contains($0) }
        }
    }

    private func addCustomDay() {
        guard let day = ReminderDayOptions.parseCustom(custom) else {
            custom = ""
            return
        }

        if !customOptions.contains(day) {
            customOptions.append(day)
            customOptions = ReminderDayOptions.normalized(customOptions)
        }

        if !reminderDays.contains(day) {
            reminderDays.append(day)
            reminderDays = ReminderDayOptions.normalized(reminderDays)
        }

        custom = ""
        customFocused = false
    }
}

private struct FlowWrap<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self, content: content)
        }
    }
}
