import SwiftUI
import SwiftData
import QuickLook
import PhotosUI
import UniformTypeIdentifiers

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var entitlement: EntitlementService

    let item: Item
    @State private var showingRenew = false
    @State private var newDate = Date()
    @State private var showingRenewActions = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingFileImporter = false
    @State private var showingAttachmentLimitAlert = false

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
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("attachment.add_photo".localized, systemImage: "photo")
                }

                Button {
                    showingFileImporter = true
                } label: {
                    Label("attachment.add_file".localized, systemImage: "doc")
                }

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
            Button("item.delete".localized, role: .destructive, action: deleteItem)
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
        .alert("common.notice".localized, isPresented: $showingAttachmentLimitAlert) {
            Button("common.ok".localized, role: .cancel) {}
        } message: {
            Text("attachment.upgrade_required".localized)
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
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.pdf, .data], allowsMultipleSelection: false) { result in
            guard canAddAttachment() else {
                showingAttachmentLimitAlert = true
                return
            }
            guard case .success(let urls) = result, let url = urls.first else { return }
            addFileAttachment(url: url)
        }
        .onChange(of: selectedPhotoItem) { newValue in
            guard let newValue else { return }
            guard canAddAttachment() else {
                showingAttachmentLimitAlert = true
                return
            }
            Task { await addPhotoAttachment(item: newValue) }
        }
    }

    private func canAddAttachment() -> Bool {
        FeatureGate.canAddAttachment(currentCount: item.attachments.count, tier: entitlement.isPro ? .pro : .free)
    }

    private func addFileAttachment(url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        let ext = url.pathExtension.isEmpty ? "pdf" : url.pathExtension
        guard let stored = try? AttachmentStorage.shared.save(data: data, fileExtension: ext) else { return }
        let attachment = Attachment(kind: "pdf", filename: url.lastPathComponent, localPath: stored, item: item)
        modelContext.insert(attachment)
        item.attachments.append(attachment)
        try? modelContext.save()
    }

    private func addPhotoAttachment(item photoItem: PhotosPickerItem) async {
        guard let data = try? await photoItem.loadTransferable(type: Data.self) else { return }
        guard let stored = try? AttachmentStorage.shared.save(data: data, fileExtension: "jpg") else { return }
        let attachment = Attachment(kind: "photo", filename: "photo-\(Date().timeIntervalSince1970).jpg", localPath: stored, item: item)
        modelContext.insert(attachment)
        item.attachments.append(attachment)
        try? modelContext.save()
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

    private func deleteItem() {
        NotificationService.shared.cancelNotifications(for: item)
        modelContext.delete(item)
        try? modelContext.save()
        appState.showMessage("item.deleted_success".localized)
        dismiss()
    }
}
