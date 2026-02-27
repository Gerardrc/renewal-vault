import SwiftUI
import SwiftData
import UIKit
import EventKit
import EventKitUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @Query(sort: \Item.expiryDate) private var items: [Item]
    @Query(sort: \Vault.name) private var vaults: [Vault]
    @State private var query = ""
    @State private var selectedVaultID: UUID?
    @State private var categoryFilter = ""
    @State private var upcomingOnly = false
    @State private var showCompleted = false
    @State private var calendarAlertMessage = ""
    @State private var showCalendarAlert = false
    @State private var showCalendarDeniedAlert = false
    @State private var calendarDraft: CalendarDraft?

    private struct CalendarDraft: Identifiable {
        let id = UUID()
        let eventStore: EKEventStore
        let event: EKEvent
    }

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
        .alert("common.notice".localized, isPresented: $showCalendarAlert) {
            Button("common.ok".localized, role: .cancel) {}
        } message: {
            Text(calendarAlertMessage)
        }
        .alert("calendar.access_denied_title".localized, isPresented: $showCalendarDeniedAlert) {
            Button("common.close".localized, role: .cancel) {}
            Button("common.go_to_settings".localized) { openSettings() }
        } message: {
            Text("calendar.access_denied".localized)
        }
        .sheet(item: $calendarDraft) { draft in
            CalendarEventEditorSheet(
                eventStore: draft.eventStore,
                event: draft.event
            )
        }
    }

    @ViewBuilder
    private func bucketSection(title: String, bucket: ItemBucket) -> some View {
        let sectionItems = filtered.filter { ReminderScheduler.bucket(for: $0) == bucket }
        if !sectionItems.isEmpty {
            Section(title) {
                ForEach(sectionItems.indices, id: \.self) { index in
                    HStack(spacing: 12) {
                        NavigationLink(destination: ItemDetailView(item: sectionItems[index])) {
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(sectionItems[index].title).font(.headline)
                                    if sectionItems[index].isCompleted {
                                        Text("item.completed_badge".localized)
                                            .font(.caption2)
                                            .padding(4)
                                            .background(.gray.opacity(0.2), in: Capsule())
                                    }
                                }
                                Text(HomeView.subtitleText(for: sectionItems[index])) +
                                Text(" · \(sectionItems[index].expiryDate.formatted(date: .abbreviated, time: .omitted))")
                            }
                        }
                        Spacer(minLength: 4)
                        Button {
                            Task { await addToCalendar(item: sectionItems[index]) }
                        } label: {
                            Image(systemName: "calendar.badge.plus")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("home.add_to_calendar".localized)
                    }
                }
            }
        }
    }

    static func subtitleText(for item: Item) -> String {
        item.formattedPriceText ?? item.vault?.name ?? "-"
    }

    @MainActor
    private func addToCalendar(item: Item) async {
        do {
            let store = CalendarEventService.shared.eventStore()
            let event = CalendarEventService.shared.prepareEditorEvent(for: item)
            calendarDraft = CalendarDraft(eventStore: store, event: event)
        } catch {
            calendarAlertMessage = "calendar.add_failed".localized
            showCalendarAlert = true
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct CalendarEventEditorSheet: UIViewControllerRepresentable {
    let eventStore: EKEventStore
    let event: EKEvent

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = eventStore
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            controller.dismiss(animated: true)
        }
    }
}

