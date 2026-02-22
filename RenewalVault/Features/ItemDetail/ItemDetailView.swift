import SwiftUI
import QuickLook

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let item: Item
    @State private var showingRenew = false
    @State private var newDate = Date()

    var body: some View {
        List {
            Section("item.details".localized) {
                Text(item.title)
                Text(item.category)
                Text(item.expiryDate.formatted(date: .abbreviated, time: .omitted))
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
            Button("item.mark_renewed".localized) {
                newDate = item.expiryDate.addingTimeInterval(60*60*24*365)
                showingRenew = true
            }
        }
        .sheet(isPresented: $showingRenew) {
            NavigationStack {
                Form { DatePicker("item.new_expiry".localized, selection: $newDate, displayedComponents: .date) }
                    .toolbar {
                        Button("common.save".localized) {
                            let event = RenewalEvent(previousExpiryDate: item.expiryDate, newExpiryDate: newDate, item: item)
                            item.expiryDate = newDate
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
}
