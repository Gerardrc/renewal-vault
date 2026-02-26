import SwiftUI
import QuickLook

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let item: Item
    @State private var showingRenew = false
    @State private var newDate = Date()
    @State private var showingRenewActions = false

    var body: some View {
        List {
            Section("item.details".localized) {
                Text(item.title)
                Text("category.\(item.category)".localized)
                Text(item.expiryDate.formatted(date: .abbreviated, time: .omitted))
                if item.isCompleted {
                    Text("item.completed_badge".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(item.notes)
            }

            Section("item.attachments".localized) {
                ForEach(item.attachments) { a in
                    Text("\(a.kind.uppercased()): \(a.filename)")
                }
            }

            Section("item.renewal_history".localized) {
                ForEach(item.renewalEvents.sorted { $0.renewedAt > $1.renewedAt }) { event in
                    Text("\(event.previousExpiryDate.formatted(date: .abbreviated, time: .omitted)) → \(event.newExpiryDate.formatted(date: .abbreviated, time: .omitted))")
                }
            }
        }
        .navigationTitle("item.detail".localized)
        .toolbar {
            NavigationLink("common.edit".localized) { ItemEditorView(item: item) }
            Button(item.isCompleted ? "item.reactivate".localized : "item.mark_renewed".localized) {
                if item.isCompleted {
                    reactivate()
                } else {
                    showingRenewActions = true
                }
            }
            Button("item.delete".localized, role: .destructive) {
                NotificationService.shared.cancelNotifications(for: item)
                modelContext.delete(item)
                try? modelContext.save()
            }
        }
        .confirmationDialog("item.renew_options".localized, isPresented: $showingRenewActions) {
            Button("item.renew".localized) {
                newDate = item.expiryDate.addingTimeInterval(60*60*24*365)
                showingRenew = true
            }
            Button("item.no_renewal".localized, role: .destructive) {
                markNoRenewal()
            }
            Button("common.cancel".localized, role: .cancel) {}
        }
        .sheet(isPresented: $showingRenew) {
            NavigationStack {
                Form { DatePicker("item.new_expiry".localized, selection: $newDate, displayedComponents: .date) }
                    .toolbar {
                        Button("common.save".localized) {
                            let event = RenewalEvent(previousExpiryDate: item.expiryDate, newExpiryDate: newDate, item: item)
                            item.expiryDate = newDate
                            item.isCompleted = false
                            item.repeatAfterRenewal = true
                            item.renewalEvents.append(event)
                            modelContext.insert(event)
                            try? modelContext.save()
                            Task { await NotificationService.shared.reschedule(item: item) }
                            showingRenew = false
                        }
                    }
            }
        }
    }

    private func markNoRenewal() {
        item.markNoRenewal()
        NotificationService.shared.cancelNotifications(for: item)
        try? modelContext.save()
    }

    private func reactivate() {
        item.reactivate()
        try? modelContext.save()
        Task { await NotificationService.shared.reschedule(item: item) }
    }
}
