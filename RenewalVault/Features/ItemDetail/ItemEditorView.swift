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

    var body: some View {
        Form {
            TextField("item.title".localized, text: $title)
            Picker("item.category".localized, selection: $category) {
                ForEach(ItemCategory.allCases) { c in Text(c.rawValue).tag(c.rawValue) }
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
        guard let item else { return }
        title = item.title; category = item.category; issuer = item.issuer ?? ""; expiryDate = item.expiryDate; notes = item.notes
        reminderDays = item.reminderScheduleDays
    }

    private func save() {
        guard !title.isEmpty else { return }
        if item == nil && !FeatureGate.canCreateItem(currentCount: items.count, tier: entitlement.isPro ? .pro : .free) { return }
        let normalized = Array(Set(reminderDays.filter { $0 >= 0 })).sorted(by: >)
        if let item {
            item.title = title; item.category = category; item.issuer = issuer.isEmpty ? nil : issuer
            item.expiryDate = expiryDate; item.notes = notes; item.reminderScheduleDays = normalized; item.updatedAt = .now
            Task { await NotificationService.shared.reschedule(item: item) }
        } else {
            let new = Item(title: title, category: category, issuer: issuer.isEmpty ? nil : issuer, expiryDate: expiryDate, reminderScheduleDays: normalized, notes: notes, vault: vaults.first)
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
    let common = [90,60,30,14,7,3,1,0]

    var body: some View {
        Section("item.reminders".localized) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))]) {
                ForEach(common, id: \.self) { day in
                    let selected = reminderDays.contains(day)
                    Button("\(day)") {
                        if selected { reminderDays.removeAll { $0 == day } } else { reminderDays.append(day) }
                    }.buttonStyle(.borderedProminent).tint(selected ? .blue : .gray)
                }
            }
            HStack {
                TextField("custom", text: $custom)
                Button("common.add".localized) {
                    if let d = Int(custom), d >= 0, !reminderDays.contains(d) { reminderDays.append(d) }
                    custom = ""
                }
            }
        }
    }
}
