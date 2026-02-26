 (cd "$(git rev-parse --show-toplevel)" && git apply --3way <<'EOF' 
diff --git a/README.md b/README.md
index 42ffffb4efc41c22dd898e75f340b4ff004f368c..1c3c19ea092c8913d97b2a9c2141ca9ff56162b6 100644
--- a/README.md
+++ b/README.md
@@ -1 +1,69 @@
-# renewal-vault
\ No newline at end of file
+# Renewal Vault (iOS MVP)
+
+Native iOS 17+ SwiftUI app for tracking renewals/expirations, attachments, reminders, and Pro subscription features.
+
+## Requirements
+- Xcode 15.2+ (recommended latest Xcode 15/16)
+- iOS 17+
+- Swift 5.9+
+
+## Setup
+1. Open the project in Xcode and set your **Bundle Identifier** (e.g. `com.yourcompany.renewalvault`).
+2. Ensure Signing team is selected.
+3. Add the `StoreKit/RenewalVault.storekit` file to the run scheme for local purchase tests.
+
+## StoreKit product setup (App Store Connect)
+Create an auto-renewable subscription group and two products:
+- `com.renewalvault.pro.monthly`
+- `com.renewalvault.pro.yearly`
+
+Then submit metadata/pricing and attach to app version.
+
+## Local purchase testing
+1. In Xcode, Edit Scheme → Run → Options → StoreKit Configuration: select `RenewalVault.storekit`.
+2. Launch app and open Paywall.
+3. Purchase monthly/yearly and verify Pro gates unlock.
+4. Use “Restore Purchases” in Settings to validate restore flow.
+
+## Sandbox testing
+1. Create Sandbox Tester in App Store Connect (Users and Access → Sandbox).
+2. Sign out of App Store on test device/simulator.
+3. Install TestFlight (or debug build with remote products).
+4. Purchase using sandbox account when prompted.
+
+## Notifications behavior
+- Local notifications only (no APNs).
+- Each item schedules one notification per reminder day at 09:00 local time.
+- Any item edit/renewal cancels prior requests and reschedules.
+- To reset: delete app, or remove item (which clears pending IDs and cancels pending requests).
+
+## Architecture summary
+- SwiftUI + MVVM-ish feature slices under `RenewalVault/Features/*`
+- SwiftData models in `Core/Domain/Models.swift`
+- Runtime in-app language choice via `LanguageManager` + SwiftUI locale environment
+- Launch flow router: Language Picker → Onboarding (once) → Main tabs
+- Subscription gating centralized in `FeatureGate`
+
+## MVP coverage
+- Language picker before onboarding (English/Spanish)
+- One-time onboarding
+- Vault CRUD (default Personal)
+- Item CRUD + reminder day editor
+- Home buckets (soon/later/expired), search/upcoming toggle
+- Item detail + renewal events
+- Local reminders scheduling
+- Paywall + purchase/restore + entitlement observation
+- Privacy screen
+- DEBUG tools: simulate Pro + reset onboarding
+
+## Notes
+- Attachment ingest UI (camera/library/files) is scaffold-ready; storage and file protection implementation are included in `AttachmentStorage`.
+- PDF export engine is implemented with UIKit PDF renderer (`VaultPDFExporter`).
+
+
+## Recent UX updates
+- In-app language switch now updates UI immediately via runtime localization bundle override (`LocalizationBundle`) + `LanguageManager` publish refresh.
+- Onboarding is a 4-page flow with Skip, Next, and Get started.
+- Item detail supports **Renew** and **No renewal** paths; no-renewal marks item completed and stops notifications.
+- Home adds **Show completed** toggle (completed hidden by default).
+- Item add/edit now includes Vault picker so items can be moved between vaults.
diff --git a/RenewalVault/App/AppState.swift b/RenewalVault/App/AppState.swift
new file mode 100644
index 0000000000000000000000000000000000000000..45ed480961bf68c0d3cc0f81b6e3945791985a8d
--- /dev/null
+++ b/RenewalVault/App/AppState.swift
@@ -0,0 +1,50 @@
+import Foundation
+import SwiftData
+
+struct TransientMessage: Identifiable, Equatable {
+    let id = UUID()
+    let text: String
+}
+
+@MainActor
+final class AppState: ObservableObject {
+    @Published var hasChosenLanguage: Bool = false
+    @Published var hasCompletedOnboarding: Bool = false
+    @Published var transientMessage: TransientMessage?
+
+    private let onboardingKey = "onboarding.completed"
+
+    func bootstrapIfNeeded(modelContext: ModelContext) async {
+        hasChosenLanguage = UserDefaults.standard.string(forKey: LanguageManager.languageCodeKey) != nil
+        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
+
+        do {
+            let descriptor = FetchDescriptor<Vault>()
+            let count = try modelContext.fetchCount(descriptor)
+            if count == 0 {
+                modelContext.insert(Vault(name: "Personal"))
+                try modelContext.save()
+            }
+        } catch {
+            assertionFailure("Failed initial bootstrap")
+        }
+    }
+
+    func setLanguageChosen() {
+        hasChosenLanguage = true
+    }
+
+    func finishOnboarding() {
+        UserDefaults.standard.set(true, forKey: onboardingKey)
+        hasCompletedOnboarding = true
+    }
+
+    func resetOnboarding() {
+        UserDefaults.standard.set(false, forKey: onboardingKey)
+        hasCompletedOnboarding = false
+    }
+
+    func showMessage(_ text: String) {
+        transientMessage = TransientMessage(text: text)
+    }
+}
diff --git a/RenewalVault/App/RenewalVaultApp.swift b/RenewalVault/App/RenewalVaultApp.swift
new file mode 100644
index 0000000000000000000000000000000000000000..04f9d817655e978396451222b728394215312576
--- /dev/null
+++ b/RenewalVault/App/RenewalVaultApp.swift
@@ -0,0 +1,40 @@
+import SwiftUI
+import SwiftData
+
+@main
+struct RenewalVaultApp: App {
+    @StateObject private var appState = AppState()
+    @StateObject private var languageManager = LanguageManager()
+    @StateObject private var entitlementService = EntitlementService()
+
+    var sharedModelContainer: ModelContainer = {
+        let schema = Schema([
+            Vault.self,
+            Item.self,
+            Attachment.self,
+            RenewalEvent.self,
+            AppPreference.self
+        ])
+        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
+        do {
+            return try ModelContainer(for: schema, configurations: [config])
+        } catch {
+            fatalError("Could not create ModelContainer: \(error)")
+        }
+    }()
+
+    var body: some Scene {
+        WindowGroup {
+            RootRouterView()
+                .environmentObject(appState)
+                .environmentObject(languageManager)
+                .environmentObject(entitlementService)
+                .environment(\.locale, languageManager.locale)
+                .task {
+                    await appState.bootstrapIfNeeded(modelContext: sharedModelContainer.mainContext)
+                    await entitlementService.observeEntitlements()
+                }
+        }
+        .modelContainer(sharedModelContainer)
+    }
+}
diff --git a/RenewalVault/App/RootRouterView.swift b/RenewalVault/App/RootRouterView.swift
new file mode 100644
index 0000000000000000000000000000000000000000..404e0c115e59ab38fc715a9d24ab123c3aea7b1c
--- /dev/null
+++ b/RenewalVault/App/RootRouterView.swift
@@ -0,0 +1,39 @@
+import SwiftUI
+
+struct RootRouterView: View {
+    @EnvironmentObject private var appState: AppState
+    @EnvironmentObject private var languageManager: LanguageManager
+
+    var body: some View {
+        Group {
+            if !appState.hasChosenLanguage {
+                LanguagePickerView()
+            } else if !appState.hasCompletedOnboarding {
+                OnboardingView()
+            } else {
+                MainTabView()
+                    .id(languageManager.selectedLanguage.rawValue)
+            }
+        }
+    }
+}
+
+struct MainTabView: View {
+    @EnvironmentObject private var appState: AppState
+
+    var body: some View {
+        TabView {
+            NavigationStack { HomeView() }
+                .tabItem { Label(LocalizedStringKey("tab.home"), systemImage: "house") }
+
+            NavigationStack { VaultListView() }
+                .tabItem { Label(LocalizedStringKey("tab.vaults"), systemImage: "archivebox") }
+
+            NavigationStack { SettingsView() }
+                .tabItem { Label(LocalizedStringKey("tab.settings"), systemImage: "gear") }
+        }
+        .alert(item: $appState.transientMessage) { message in
+            Alert(title: Text("common.notice".localized), message: Text(message.text), dismissButton: .default(Text("common.ok".localized)))
+        }
+    }
+}
diff --git a/RenewalVault/Core/Domain/Models.swift b/RenewalVault/Core/Domain/Models.swift
new file mode 100644
index 0000000000000000000000000000000000000000..f002418682c50ef8defbd0e9ff4e4dc2114cd444
--- /dev/null
+++ b/RenewalVault/Core/Domain/Models.swift
@@ -0,0 +1,148 @@
+import Foundation
+import SwiftData
+
+@Model
+final class Vault {
+    @Attribute(.unique) var id: UUID
+    var name: String
+    var createdAt: Date
+    var updatedAt: Date
+    @Relationship(deleteRule: .cascade, inverse: \Item.vault) var items: [Item] = []
+
+    init(id: UUID = UUID(), name: String, createdAt: Date = .now, updatedAt: Date = .now) {
+        self.id = id
+        self.name = name
+        self.createdAt = createdAt
+        self.updatedAt = updatedAt
+    }
+}
+
+@Model
+final class Item {
+    @Attribute(.unique) var id: UUID
+    var title: String
+    var category: String
+    var issuer: String?
+    var expiryDate: Date
+    var reminderScheduleDays: [Int]
+    var repeatAfterRenewal: Bool
+    var isCompleted: Bool
+    var notes: String
+    var createdAt: Date
+    var updatedAt: Date
+    var scheduledNotificationIdentifiers: [String]
+
+    var vault: Vault?
+    @Relationship(deleteRule: .cascade, inverse: \Attachment.item) var attachments: [Attachment] = []
+    @Relationship(deleteRule: .cascade, inverse: \RenewalEvent.item) var renewalEvents: [RenewalEvent] = []
+
+    init(
+        id: UUID = UUID(),
+        title: String,
+        category: String,
+        issuer: String? = nil,
+        expiryDate: Date,
+        reminderScheduleDays: [Int] = [30, 14, 7, 1],
+        repeatAfterRenewal: Bool = true,
+        isCompleted: Bool = false,
+        notes: String = "",
+        createdAt: Date = .now,
+        updatedAt: Date = .now,
+        scheduledNotificationIdentifiers: [String] = [],
+        vault: Vault? = nil
+    ) {
+        self.id = id
+        self.title = title
+        self.category = category
+        self.issuer = issuer
+        self.expiryDate = expiryDate
+        self.reminderScheduleDays = reminderScheduleDays
+        self.repeatAfterRenewal = repeatAfterRenewal
+        self.isCompleted = isCompleted
+        self.notes = notes
+        self.createdAt = createdAt
+        self.updatedAt = updatedAt
+        self.scheduledNotificationIdentifiers = scheduledNotificationIdentifiers
+        self.vault = vault
+    }
+}
+
+@Model
+final class Attachment {
+    @Attribute(.unique) var id: UUID
+    var kind: String
+    var filename: String
+    var localPath: String
+    var createdAt: Date
+    var item: Item?
+
+    init(id: UUID = UUID(), kind: String, filename: String, localPath: String, createdAt: Date = .now, item: Item? = nil) {
+        self.id = id
+        self.kind = kind
+        self.filename = filename
+        self.localPath = localPath
+        self.createdAt = createdAt
+        self.item = item
+    }
+}
+
+@Model
+final class RenewalEvent {
+    @Attribute(.unique) var id: UUID
+    var renewedAt: Date
+    var previousExpiryDate: Date
+    var newExpiryDate: Date
+    var item: Item?
+
+    init(id: UUID = UUID(), renewedAt: Date = .now, previousExpiryDate: Date, newExpiryDate: Date, item: Item? = nil) {
+        self.id = id
+        self.renewedAt = renewedAt
+        self.previousExpiryDate = previousExpiryDate
+        self.newExpiryDate = newExpiryDate
+        self.item = item
+    }
+}
+
+@Model
+final class AppPreference {
+    @Attribute(.unique) var key: String
+    var value: String
+
+    init(key: String, value: String) {
+        self.key = key
+        self.value = value
+    }
+}
+
+enum ItemCategory: String, CaseIterable, Identifiable {
+    case passport, nationalID, driversLicense, carInsurance, lease, healthInsurance, subscription, other
+    var id: String { rawValue }
+
+    var icon: String {
+        switch self {
+        case .passport: "globe"
+        case .nationalID: "person.text.rectangle"
+        case .driversLicense: "car"
+        case .carInsurance: "shield.lefthalf.filled"
+        case .lease: "house"
+        case .healthInsurance: "heart.text.square"
+        case .subscription: "creditcard"
+        case .other: "doc"
+        }
+    }
+}
+
+
+extension Item {
+    func markNoRenewal() {
+        repeatAfterRenewal = false
+        isCompleted = true
+        updatedAt = .now
+    }
+
+    func reactivate() {
+        isCompleted = false
+        repeatAfterRenewal = true
+        updatedAt = .now
+    }
+}
diff --git a/RenewalVault/Core/Localization/LanguageManager.swift b/RenewalVault/Core/Localization/LanguageManager.swift
new file mode 100644
index 0000000000000000000000000000000000000000..71a314add84ccaa24860ea9ae71db12e8239c1da
--- /dev/null
+++ b/RenewalVault/Core/Localization/LanguageManager.swift
@@ -0,0 +1,59 @@
+import Foundation
+import SwiftUI
+
+enum AppLanguage: String, CaseIterable, Identifiable {
+    case en
+    case es
+
+    var id: String { rawValue }
+    var displayName: String {
+        switch self {
+        case .en: return "language.english".localized
+        case .es: return "language.spanish".localized
+        }
+    }
+
+    var bundleCode: String { rawValue }
+
+    static var systemDefault: AppLanguage {
+        Locale.preferredLanguages.first?.hasPrefix("es") == true ? .es : .en
+    }
+}
+
+@MainActor
+final class LanguageManager: ObservableObject {
+    static let languageCodeKey = "app.language.code"
+
+    @Published private(set) var selectedLanguage: AppLanguage {
+        didSet {
+            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: Self.languageCodeKey)
+            LocalizationBundle.setLanguage(code: selectedLanguage.bundleCode)
+            locale = Locale(identifier: selectedLanguage.bundleCode)
+            objectWillChange.send()
+        }
+    }
+
+    @Published private(set) var locale: Locale
+
+    init() {
+        let saved = UserDefaults.standard.string(forKey: Self.languageCodeKey)
+        let language = AppLanguage(rawValue: saved ?? "") ?? AppLanguage.systemDefault
+        self.selectedLanguage = language
+        self.locale = Locale(identifier: language.bundleCode)
+        LocalizationBundle.setLanguage(code: language.bundleCode)
+    }
+
+    func setLanguage(_ language: AppLanguage) {
+        selectedLanguage = language
+    }
+
+    func setLanguage(code: String) {
+        setLanguage(AppLanguage(rawValue: code) ?? .en)
+    }
+}
+
+extension String {
+    var localized: String {
+        NSLocalizedString(self, comment: "")
+    }
+}
diff --git a/RenewalVault/Core/Localization/LocalizationBundle.swift b/RenewalVault/Core/Localization/LocalizationBundle.swift
new file mode 100644
index 0000000000000000000000000000000000000000..34e5d8c9f24298676eae807c6d802384fba2bbfc
--- /dev/null
+++ b/RenewalVault/Core/Localization/LocalizationBundle.swift
@@ -0,0 +1,29 @@
+import Foundation
+import ObjectiveC.runtime
+
+private var bundleKey: UInt8 = 0
+
+private final class LocalizedBundle: Bundle, @unchecked Sendable {
+    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
+        guard
+            let path = objc_getAssociatedObject(self, &bundleKey) as? String,
+            let bundle = Bundle(path: path)
+        else {
+            return super.localizedString(forKey: key, value: value, table: tableName)
+        }
+        return bundle.localizedString(forKey: key, value: value, table: tableName)
+    }
+}
+
+enum LocalizationBundle {
+    private static var didSwap = false
+
+    static func setLanguage(code: String) {
+        guard let path = Bundle.main.path(forResource: code, ofType: "lproj") else { return }
+        if !didSwap {
+            object_setClass(Bundle.main, LocalizedBundle.self)
+            didSwap = true
+        }
+        objc_setAssociatedObject(Bundle.main, &bundleKey, path, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
+    }
+}
diff --git a/RenewalVault/Core/Monetization/EntitlementService.swift b/RenewalVault/Core/Monetization/EntitlementService.swift
new file mode 100644
index 0000000000000000000000000000000000000000..844955710bdff9b68a046cb6253146107badd9bc
--- /dev/null
+++ b/RenewalVault/Core/Monetization/EntitlementService.swift
@@ -0,0 +1,46 @@
+import Foundation
+import StoreKit
+
+@MainActor
+final class EntitlementService: ObservableObject {
+    @Published var isPro: Bool = false
+    #if DEBUG
+    @Published var debugForcePro: Bool = false
+    #endif
+
+    let productIDs = ["com.renewalvault.pro.monthly", "com.renewalvault.pro.yearly"]
+
+    func observeEntitlements() async {
+        await refreshEntitlements()
+        for await _ in Transaction.updates {
+            await refreshEntitlements()
+        }
+    }
+
+    func refreshEntitlements() async {
+        var hasPro = false
+        for await result in Transaction.currentEntitlements {
+            if case .verified(let transaction) = result, productIDs.contains(transaction.productID) {
+                hasPro = true
+            }
+        }
+        #if DEBUG
+        isPro = hasPro || debugForcePro
+        #else
+        isPro = hasPro
+        #endif
+    }
+
+    func purchase(product: Product) async throws {
+        let result = try await product.purchase()
+        if case .success(let verification) = result, case .verified(let transaction) = verification {
+            await transaction.finish()
+            await refreshEntitlements()
+        }
+    }
+
+    func restorePurchases() async throws {
+        try await AppStore.sync()
+        await refreshEntitlements()
+    }
+}
diff --git a/RenewalVault/Core/Monetization/SubscriptionTier.swift b/RenewalVault/Core/Monetization/SubscriptionTier.swift
new file mode 100644
index 0000000000000000000000000000000000000000..b50dbbcd467729c952a59c6a555bf00ee7f8201a
--- /dev/null
+++ b/RenewalVault/Core/Monetization/SubscriptionTier.swift
@@ -0,0 +1,24 @@
+import Foundation
+
+enum SubscriptionTier {
+    case free
+    case pro
+}
+
+struct FeatureGate {
+    static func canCreateVault(currentCount: Int, tier: SubscriptionTier) -> Bool {
+        tier == .pro || currentCount < 1
+    }
+
+    static func canCreateItem(currentCount: Int, tier: SubscriptionTier) -> Bool {
+        tier == .pro || currentCount < 5
+    }
+
+    static func canAddAttachment(currentCount: Int, tier: SubscriptionTier) -> Bool {
+        tier == .pro || currentCount < 3
+    }
+
+    static func canExportPDF(tier: SubscriptionTier) -> Bool {
+        tier == .pro
+    }
+}
diff --git a/RenewalVault/Core/Notifications/NotificationService.swift b/RenewalVault/Core/Notifications/NotificationService.swift
new file mode 100644
index 0000000000000000000000000000000000000000..f3bed82904d94d9359c59417ee7232c58e71d705
--- /dev/null
+++ b/RenewalVault/Core/Notifications/NotificationService.swift
@@ -0,0 +1,46 @@
+import Foundation
+import UserNotifications
+import UIKit
+
+struct NotificationService {
+    static let shared = NotificationService()
+
+    func requestPermission() async -> Bool {
+        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) ?? false
+    }
+
+    func openSettings() {
+        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
+        Task { @MainActor in
+            UIApplication.shared.open(url)
+        }
+    }
+
+    func cancelNotifications(for item: Item) {
+        let center = UNUserNotificationCenter.current()
+        center.removePendingNotificationRequests(withIdentifiers: item.scheduledNotificationIdentifiers)
+        item.scheduledNotificationIdentifiers = []
+    }
+
+    func reschedule(item: Item) async {
+        cancelNotifications(for: item)
+        guard !item.isCompleted else { return }
+
+        let center = UNUserNotificationCenter.current()
+        let dates = ReminderScheduler.reminderDates(expiryDate: item.expiryDate, reminderDays: item.reminderScheduleDays)
+        for (index, date) in dates.enumerated() {
+            var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
+            components.hour = 9
+            components.minute = 0
+            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
+            let content = UNMutableNotificationContent()
+            content.title = "notification.title".localized
+            let days = Calendar.current.dateComponents([.day], from: .now, to: item.expiryDate).day ?? 0
+            content.body = days < 0 ? "notification.expired".localized : String(format: "notification.expires_in".localized, item.title, max(days, 0))
+            let id = "item-\(item.id)-\(index)"
+            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
+            try? await center.add(request)
+            item.scheduledNotificationIdentifiers.append(id)
+        }
+    }
+}
diff --git a/RenewalVault/Core/Notifications/ReminderScheduler.swift b/RenewalVault/Core/Notifications/ReminderScheduler.swift
new file mode 100644
index 0000000000000000000000000000000000000000..06e0d50e2cd64010b706d60300c52c0932619d05
--- /dev/null
+++ b/RenewalVault/Core/Notifications/ReminderScheduler.swift
@@ -0,0 +1,31 @@
+import Foundation
+
+struct ReminderScheduler {
+    static func reminderDates(expiryDate: Date, reminderDays: [Int], calendar: Calendar = .current) -> [Date] {
+        reminderDays
+            .filter { $0 >= 0 }
+            .removingDuplicates()
+            .compactMap { days in calendar.date(byAdding: .day, value: -days, to: expiryDate) }
+            .sorted()
+    }
+
+    static func bucket(for item: Item, now: Date = .now, calendar: Calendar = .current) -> ItemBucket {
+        let start = calendar.startOfDay(for: now)
+        let end = calendar.startOfDay(for: item.expiryDate)
+        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
+        if days < 0 { return .expired }
+        if days <= 30 { return .soon }
+        return .later
+    }
+}
+
+enum ItemBucket: String {
+    case soon, later, expired
+}
+
+private extension Array where Element: Hashable {
+    func removingDuplicates() -> [Element] {
+        var seen = Set<Element>()
+        return filter { seen.insert($0).inserted }
+    }
+}
diff --git a/RenewalVault/Core/PDF/VaultPDFExporter.swift b/RenewalVault/Core/PDF/VaultPDFExporter.swift
new file mode 100644
index 0000000000000000000000000000000000000000..1c71f6a4a1bf75c1f6159845d70974b8bfe02795
--- /dev/null
+++ b/RenewalVault/Core/PDF/VaultPDFExporter.swift
@@ -0,0 +1,27 @@
+import Foundation
+import PDFKit
+import UIKit
+
+struct VaultPDFExporter {
+    func export(vault: Vault) -> URL? {
+        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
+        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(vault.name)-report.pdf")
+        do {
+            try renderer.writePDF(to: url) { ctx in
+                ctx.beginPage()
+                let header = "\(vault.name) - \(Date().formatted(date: .abbreviated, time: .shortened))"
+                header.draw(at: CGPoint(x: 36, y: 36), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 20)])
+                var y: CGFloat = 80
+                for item in vault.items.sorted(by: { $0.expiryDate < $1.expiryDate }) {
+                    let line = "• \(item.title) | \(item.category) | \(item.expiryDate.formatted(date: .abbreviated, time: .omitted))"
+                    line.draw(at: CGPoint(x: 36, y: y), withAttributes: [.font: UIFont.systemFont(ofSize: 12)])
+                    y += 18
+                    if y > 800 { ctx.beginPage(); y = 36 }
+                }
+            }
+            return url
+        } catch {
+            return nil
+        }
+    }
+}
diff --git a/RenewalVault/Core/Persistence/.gitkeep b/RenewalVault/Core/Persistence/.gitkeep
new file mode 100644
index 0000000000000000000000000000000000000000..35636d609d460feccdf2676711c0b1ef53cdd9a4
--- /dev/null
+++ b/RenewalVault/Core/Persistence/.gitkeep
@@ -0,0 +1 @@
+# Keep directory in git
diff --git a/RenewalVault/Core/Storage/AttachmentStorage.swift b/RenewalVault/Core/Storage/AttachmentStorage.swift
new file mode 100644
index 0000000000000000000000000000000000000000..d57d0c83376a9ac5dce1da10a4fdab05dbeb2c72
--- /dev/null
+++ b/RenewalVault/Core/Storage/AttachmentStorage.swift
@@ -0,0 +1,27 @@
+import Foundation
+
+struct AttachmentStorage {
+    static let shared = AttachmentStorage()
+
+    private var baseURL: URL {
+        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
+        let folder = appSupport.appendingPathComponent("Attachments", isDirectory: true)
+        if !FileManager.default.fileExists(atPath: folder.path) {
+            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
+            try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: folder.path)
+        }
+        return folder
+    }
+
+    func save(data: Data, fileExtension: String) throws -> String {
+        let filename = "\(UUID().uuidString).\(fileExtension)"
+        let url = baseURL.appendingPathComponent(filename)
+        try data.write(to: url, options: .atomic)
+        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
+        return filename
+    }
+
+    func fileURL(relativePath: String) -> URL {
+        baseURL.appendingPathComponent(relativePath)
+    }
+}
diff --git a/RenewalVault/Core/Utilities/.gitkeep b/RenewalVault/Core/Utilities/.gitkeep
new file mode 100644
index 0000000000000000000000000000000000000000..35636d609d460feccdf2676711c0b1ef53cdd9a4
--- /dev/null
+++ b/RenewalVault/Core/Utilities/.gitkeep
@@ -0,0 +1 @@
+# Keep directory in git
diff --git a/RenewalVault/Features/Home/HomeView.swift b/RenewalVault/Features/Home/HomeView.swift
new file mode 100644
index 0000000000000000000000000000000000000000..cfdf3832b1d0bb92e90e5ee50e2434b64c317340
--- /dev/null
+++ b/RenewalVault/Features/Home/HomeView.swift
@@ -0,0 +1,87 @@
+import SwiftUI
+import SwiftData
+
+struct HomeView: View {
+    @Query(sort: \Item.expiryDate) private var items: [Item]
+    @Query(sort: \Vault.name) private var vaults: [Vault]
+    @State private var query = ""
+    @State private var selectedVaultID: UUID?
+    @State private var categoryFilter = ""
+    @State private var upcomingOnly = false
+    @State private var showCompleted = false
+
+    private var filtered: [Item] {
+        items.filter { item in
+            let qOK = query.isEmpty || item.title.localizedCaseInsensitiveContains(query) || (item.issuer?.localizedCaseInsensitiveContains(query) ?? false)
+            let vOK = selectedVaultID == nil || item.vault?.id == selectedVaultID
+            let cOK = categoryFilter.isEmpty || item.category == categoryFilter
+            let upOK = !upcomingOnly || item.expiryDate >= Calendar.current.startOfDay(for: .now)
+            let completionOK = showCompleted || !item.isCompleted
+            return qOK && vOK && cOK && upOK && completionOK
+        }
+    }
+
+    var body: some View {
+        List {
+            Section("home.filters".localized) {
+                TextField("home.search".localized, text: $query)
+                Picker("home.vault_filter".localized, selection: $selectedVaultID) {
+                    Text("home.all_vaults".localized).tag(UUID?.none)
+                    ForEach(vaults) { vault in
+                        Text(vault.name).tag(Optional(vault.id))
+                    }
+                }
+                Picker("home.category_filter".localized, selection: $categoryFilter) {
+                    Text("home.all_categories".localized).tag("")
+                    ForEach(ItemCategory.allCases) { c in
+                        Text("category.\(c.rawValue)".localized).tag(c.rawValue)
+                    }
+                }
+                Toggle("home.upcoming_only".localized, isOn: $upcomingOnly)
+                Toggle("home.show_completed".localized, isOn: $showCompleted)
+            }
+
+            bucketSection(title: "home.expiring_soon".localized, bucket: .soon)
+            bucketSection(title: "home.later".localized, bucket: .later)
+            bucketSection(title: "home.expired".localized, bucket: .expired)
+
+            if items.isEmpty {
+                Section("home.empty".localized) {
+                    Text("home.empty_templates".localized)
+                        .font(.caption)
+                }
+            }
+        }
+        .navigationTitle("tab.home".localized)
+        .toolbar {
+            NavigationLink(destination: ItemEditorView(item: nil)) {
+                Label("common.add".localized, systemImage: "plus")
+            }
+        }
+    }
+
+    @ViewBuilder
+    private func bucketSection(title: String, bucket: ItemBucket) -> some View {
+        let sectionItems = filtered.filter { ReminderScheduler.bucket(for: $0) == bucket }
+        if !sectionItems.isEmpty {
+            Section(title) {
+                ForEach(sectionItems) { item in
+                    NavigationLink(destination: ItemDetailView(item: item)) {
+                        VStack(alignment: .leading) {
+                            HStack {
+                                Text(item.title).font(.headline)
+                                if item.isCompleted {
+                                    Text("item.completed_badge".localized)
+                                        .font(.caption2)
+                                        .padding(4)
+                                        .background(.gray.opacity(0.2), in: Capsule())
+                                }
+                            }
+                            Text(item.vault?.name ?? "-") + Text(" · \(item.expiryDate.formatted(date: .abbreviated, time: .omitted))")
+                        }
+                    }
+                }
+            }
+        }
+    }
+}
diff --git a/RenewalVault/Features/ItemDetail/ItemDetailView.swift b/RenewalVault/Features/ItemDetail/ItemDetailView.swift
new file mode 100644
index 0000000000000000000000000000000000000000..9af90922c2891e23d748d78a02d21f51fcef6e68
--- /dev/null
+++ b/RenewalVault/Features/ItemDetail/ItemDetailView.swift
@@ -0,0 +1,162 @@
+import SwiftUI
+import SwiftData
+import QuickLook
+import PhotosUI
+import UniformTypeIdentifiers
+
+struct ItemDetailView: View {
+    @Environment(\.modelContext) private var modelContext
+    @Environment(\.dismiss) private var dismiss
+    @EnvironmentObject private var appState: AppState
+    @EnvironmentObject private var entitlement: EntitlementService
+
+    let item: Item
+    @State private var showingRenew = false
+    @State private var newDate = Date()
+    @State private var showingRenewActions = false
+    @State private var selectedPhotoItem: PhotosPickerItem?
+    @State private var showingFileImporter = false
+    @State private var showingAttachmentLimitAlert = false
+
+    var body: some View {
+        List {
+            Section("item.details".localized) {
+                Text(item.title)
+                Text("category.\(item.category)".localized)
+                Text(item.expiryDate.formatted(date: .abbreviated, time: .omitted))
+                if item.isCompleted {
+                    Text("item.completed_badge".localized)
+                        .font(.caption)
+                        .foregroundStyle(.secondary)
+                }
+                Text(item.notes)
+            }
+
+            Section("item.attachments".localized) {
+                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
+                    Label("attachment.add_photo".localized, systemImage: "photo")
+                }
+
+                Button {
+                    showingFileImporter = true
+                } label: {
+                    Label("attachment.add_file".localized, systemImage: "doc")
+                }
+
+                ForEach(item.attachments) { a in
+                    Text("\(a.kind.uppercased()): \(a.filename)")
+                }
+            }
+
+            Section("item.renewal_history".localized) {
+                ForEach(item.renewalEvents.sorted { $0.renewedAt > $1.renewedAt }) { event in
+                    Text("\(event.previousExpiryDate.formatted(date: .abbreviated, time: .omitted)) → \(event.newExpiryDate.formatted(date: .abbreviated, time: .omitted))")
+                }
+            }
+        }
+        .navigationTitle("item.detail".localized)
+        .toolbar {
+            NavigationLink("common.edit".localized) { ItemEditorView(item: item) }
+            Button(item.isCompleted ? "item.reactivate".localized : "item.mark_renewed".localized) {
+                if item.isCompleted {
+                    reactivate()
+                } else {
+                    showingRenewActions = true
+                }
+            }
+            Button("item.delete".localized, role: .destructive, action: deleteItem)
+        }
+        .confirmationDialog("item.renew_options".localized, isPresented: $showingRenewActions) {
+            Button("item.renew".localized) {
+                newDate = item.expiryDate.addingTimeInterval(60*60*24*365)
+                showingRenew = true
+            }
+            Button("item.no_renewal".localized, role: .destructive) {
+                markNoRenewal()
+            }
+            Button("common.cancel".localized, role: .cancel) {}
+        }
+        .alert("common.notice".localized, isPresented: $showingAttachmentLimitAlert) {
+            Button("common.ok".localized, role: .cancel) {}
+        } message: {
+            Text("attachment.upgrade_required".localized)
+        }
+        .sheet(isPresented: $showingRenew) {
+            NavigationStack {
+                Form { DatePicker("item.new_expiry".localized, selection: $newDate, displayedComponents: .date) }
+                    .toolbar {
+                        Button("common.save".localized) {
+                            let event = RenewalEvent(previousExpiryDate: item.expiryDate, newExpiryDate: newDate, item: item)
+                            item.expiryDate = newDate
+                            item.isCompleted = false
+                            item.repeatAfterRenewal = true
+                            item.renewalEvents.append(event)
+                            modelContext.insert(event)
+                            try? modelContext.save()
+                            Task { await NotificationService.shared.reschedule(item: item) }
+                            showingRenew = false
+                        }
+                    }
+            }
+        }
+        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.pdf, .data], allowsMultipleSelection: false) { result in
+            guard canAddAttachment() else {
+                showingAttachmentLimitAlert = true
+                return
+            }
+            guard case .success(let urls) = result, let url = urls.first else { return }
+            addFileAttachment(url: url)
+        }
+        .onChange(of: selectedPhotoItem) { newValue in
+            guard let newValue else { return }
+            guard canAddAttachment() else {
+                showingAttachmentLimitAlert = true
+                return
+            }
+            Task { await addPhotoAttachment(item: newValue) }
+        }
+    }
+
+    private func canAddAttachment() -> Bool {
+        FeatureGate.canAddAttachment(currentCount: item.attachments.count, tier: entitlement.isPro ? .pro : .free)
+    }
+
+    private func addFileAttachment(url: URL) {
+        guard let data = try? Data(contentsOf: url) else { return }
+        let ext = url.pathExtension.isEmpty ? "pdf" : url.pathExtension
+        guard let stored = try? AttachmentStorage.shared.save(data: data, fileExtension: ext) else { return }
+        let attachment = Attachment(kind: "pdf", filename: url.lastPathComponent, localPath: stored, item: item)
+        modelContext.insert(attachment)
+        item.attachments.append(attachment)
+        try? modelContext.save()
+    }
+
+    private func addPhotoAttachment(item photoItem: PhotosPickerItem) async {
+        guard let data = try? await photoItem.loadTransferable(type: Data.self) else { return }
+        guard let stored = try? AttachmentStorage.shared.save(data: data, fileExtension: "jpg") else { return }
+        let attachment = Attachment(kind: "photo", filename: "photo-\(Date().timeIntervalSince1970).jpg", localPath: stored, item: item)
+        modelContext.insert(attachment)
+        item.attachments.append(attachment)
+        try? modelContext.save()
+    }
+
+    private func markNoRenewal() {
+        item.markNoRenewal()
+        NotificationService.shared.cancelNotifications(for: item)
+        try? modelContext.save()
+    }
+
+    private func reactivate() {
+        item.reactivate()
+        try? modelContext.save()
+        Task { await NotificationService.shared.reschedule(item: item) }
+    }
+
+    private func deleteItem() {
+        NotificationService.shared.cancelNotifications(for: item)
+        modelContext.delete(item)
+        try? modelContext.save()
+        appState.showMessage("item.deleted_success".localized)
+        dismiss()
+    }
+}
diff --git a/RenewalVault/Features/ItemDetail/ItemEditorView.swift b/RenewalVault/Features/ItemDetail/ItemEditorView.swift
new file mode 100644
index 0000000000000000000000000000000000000000..e6500b76275acb4c5e9437ac8b53cd328f8dc4e3
--- /dev/null
+++ b/RenewalVault/Features/ItemDetail/ItemEditorView.swift
@@ -0,0 +1,134 @@
+import SwiftUI
+import SwiftData
+
+struct ItemEditorView: View {
+    @Environment(\.modelContext) private var modelContext
+    @Environment(\.dismiss) private var dismiss
+    @EnvironmentObject private var entitlement: EntitlementService
+    @Query private var items: [Item]
+    @Query(sort: \Vault.name) private var vaults: [Vault]
+
+    let item: Item?
+    @State private var title = ""
+    @State private var category = ItemCategory.passport.rawValue
+    @State private var issuer = ""
+    @State private var expiryDate = Date().addingTimeInterval(60*60*24*30)
+    @State private var notes = ""
+    @State private var reminderDays = [30,14,7,1]
+    @State private var selectedVaultID: UUID?
+
+    var body: some View {
+        Form {
+            TextField("item.title".localized, text: $title)
+
+            Picker("item.vault".localized, selection: $selectedVaultID) {
+                ForEach(vaults) { vault in
+                    Text(vault.name).tag(Optional(vault.id))
+                }
+            }
+            .disabled(vaults.count <= 1)
+
+            Picker("item.category".localized, selection: $category) {
+                ForEach(ItemCategory.allCases) { c in Text("category.\(c.rawValue)".localized).tag(c.rawValue) }
+            }
+            TextField("item.issuer".localized, text: $issuer)
+            DatePicker("item.expiry".localized, selection: $expiryDate, displayedComponents: .date)
+            TextField("item.notes".localized, text: $notes, axis: .vertical)
+            ReminderEditorView(reminderDays: $reminderDays)
+        }
+        .navigationTitle(item == nil ? "item.add".localized : "item.edit".localized)
+        .toolbar {
+            Button("common.save".localized) { save() }
+        }
+        .onAppear { load() }
+    }
+
+    private func load() {
+        guard let item else {
+            selectedVaultID = vaults.first?.id
+            return
+        }
+        title = item.title
+        category = item.category
+        issuer = item.issuer ?? ""
+        expiryDate = item.expiryDate
+        notes = item.notes
+        reminderDays = item.reminderScheduleDays
+        selectedVaultID = item.vault?.id ?? vaults.first?.id
+    }
+
+    private func save() {
+        guard !title.isEmpty else { return }
+        if item == nil && !FeatureGate.canCreateItem(currentCount: items.count, tier: entitlement.isPro ? .pro : .free) { return }
+        let normalized = Array(Set(reminderDays.filter { $0 >= 1 })).sorted(by: >)
+        let selectedVault = vaults.first(where: { $0.id == selectedVaultID }) ?? vaults.first
+
+        if let item {
+            item.title = title
+            item.category = category
+            item.issuer = issuer.isEmpty ? nil : issuer
+            item.expiryDate = expiryDate
+            item.notes = notes
+            item.reminderScheduleDays = normalized
+            item.vault = selectedVault
+            item.updatedAt = .now
+            Task { await NotificationService.shared.reschedule(item: item) }
+        } else {
+            let new = Item(title: title, category: category, issuer: issuer.isEmpty ? nil : issuer, expiryDate: expiryDate, reminderScheduleDays: normalized, notes: notes, vault: selectedVault)
+            modelContext.insert(new)
+            Task { await NotificationService.shared.reschedule(item: new) }
+        }
+        try? modelContext.save()
+        dismiss()
+    }
+}
+
+struct ReminderEditorView: View {
+    @Binding var reminderDays: [Int]
+    @State private var custom = ""
+    @FocusState private var customFocused: Bool
+    let common = [90,60,30,14,7,1]
+
+    var body: some View {
+        Section("item.reminders".localized) {
+            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))]) {
+                ForEach(common, id: \.self) { day in
+                    let selected = reminderDays.contains(day)
+                    Button("\(day)") {
+                        if selected {
+                            reminderDays.removeAll { $0 == day }
+                        } else {
+                            reminderDays.append(day)
+                            reminderDays = Array(Set(reminderDays)).sorted(by: >)
+                        }
+                    }
+                    .buttonStyle(.borderedProminent)
+                    .tint(selected ? .blue : .gray)
+                }
+            }
+            HStack {
+                TextField("item.custom_days".localized, text: $custom)
+                    .keyboardType(.numberPad)
+                    .focused($customFocused)
+                Button("common.add".localized, action: addCustomDay)
+            }
+        }
+    }
+
+    private func addCustomDay() {
+        let trimmed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
+        guard let day = Int(trimmed), day >= 1 else {
+            custom = ""
+            return
+        }
+        guard !reminderDays.contains(day) else {
+            custom = ""
+            customFocused = false
+            return
+        }
+        reminderDays.append(day)
+        reminderDays = Array(Set(reminderDays)).sorted(by: >)
+        custom = ""
+        customFocused = false
+    }
+}
diff --git a/RenewalVault/Features/Language/LanguagePickerView.swift b/RenewalVault/Features/Language/LanguagePickerView.swift
new file mode 100644
index 0000000000000000000000000000000000000000..7591f084a706fe0df60db59362d00972aba66472
--- /dev/null
+++ b/RenewalVault/Features/Language/LanguagePickerView.swift
@@ -0,0 +1,31 @@
+import SwiftUI
+
+struct LanguagePickerView: View {
+    @EnvironmentObject private var languageManager: LanguageManager
+    @EnvironmentObject private var appState: AppState
+    @State private var selected: AppLanguage
+
+    init() {
+        _selected = State(initialValue: AppLanguage.systemDefault)
+    }
+
+    var body: some View {
+        VStack(spacing: 20) {
+            Text("language.title".localized).font(.largeTitle.bold())
+            Picker("language.select".localized, selection: $selected) {
+                ForEach(AppLanguage.allCases) { language in
+                    Text(language.displayName).tag(language)
+                }
+            }
+            .pickerStyle(.segmented)
+
+            Button("language.continue".localized) {
+                languageManager.setLanguage(selected)
+                appState.setLanguageChosen()
+            }
+            .buttonStyle(.borderedProminent)
+        }
+        .padding()
+        .onAppear { selected = languageManager.selectedLanguage }
+    }
+}
diff --git a/RenewalVault/Features/Onboarding/OnboardingView.swift b/RenewalVault/Features/Onboarding/OnboardingView.swift
new file mode 100644
index 0000000000000000000000000000000000000000..c2e6967400718ccf2faf56e58898dba920409b9a
--- /dev/null
+++ b/RenewalVault/Features/Onboarding/OnboardingView.swift
@@ -0,0 +1,57 @@
+import SwiftUI
+
+struct OnboardingView: View {
+    @EnvironmentObject private var appState: AppState
+    @State private var page = 0
+
+    private let pages: [(title: String, icon: String)] = [
+        ("onboard.track", "calendar.badge.clock"),
+        ("onboard.smart", "bell.badge"),
+        ("onboard.attach", "paperclip"),
+        ("onboard.export", "doc.richtext")
+    ]
+
+    var body: some View {
+        VStack {
+            HStack {
+                Spacer()
+                Button("common.skip".localized) { appState.finishOnboarding() }
+            }
+            .padding([.top, .horizontal])
+
+            TabView(selection: $page) {
+                ForEach(Array(pages.enumerated()), id: \.offset) { idx, pageData in
+                    VStack(spacing: 12) {
+                        Image(systemName: pageData.icon)
+                            .font(.system(size: 58))
+                        Text(pageData.title.localized)
+                            .font(.title2.bold())
+                            .multilineTextAlignment(.center)
+                            .padding(.horizontal)
+                    }
+                    .tag(idx)
+                }
+            }
+            .tabViewStyle(.page)
+
+            HStack {
+                if page < pages.count - 1 {
+                    Button("common.next".localized) {
+                        withAnimation { page += 1 }
+                    }
+                    .buttonStyle(.bordered)
+                }
+                Spacer()
+                Button("onboard.get_started".localized) {
+                    if page < pages.count - 1 {
+                        withAnimation { page += 1 }
+                    } else {
+                        appState.finishOnboarding()
+                    }
+                }
+                .buttonStyle(.borderedProminent)
+            }
+            .padding()
+        }
+    }
+}
diff --git a/RenewalVault/Features/Paywall/PaywallView.swift b/RenewalVault/Features/Paywall/PaywallView.swift
new file mode 100644
index 0000000000000000000000000000000000000000..542a612c675ee3702d303897fa851486bd6b9f6d
--- /dev/null
+++ b/RenewalVault/Features/Paywall/PaywallView.swift
@@ -0,0 +1,26 @@
+import SwiftUI
+import StoreKit
+
+struct PaywallView: View {
+    @EnvironmentObject private var entitlement: EntitlementService
+    @Environment(\.dismiss) private var dismiss
+    @State private var products: [Product] = []
+
+    var body: some View {
+        NavigationStack {
+            List {
+                Section("paywall.title".localized) {
+                    Text("paywall.features".localized)
+                }
+                ForEach(products, id: \.id) { product in
+                    Button("\(product.displayName) - \(product.displayPrice)") {
+                        Task { try? await entitlement.purchase(product: product); dismiss() }
+                    }
+                }
+            }
+            .task {
+                products = (try? await Product.products(for: entitlement.productIDs)) ?? []
+            }
+        }
+    }
+}
diff --git a/RenewalVault/Features/Privacy/PrivacyView.swift b/RenewalVault/Features/Privacy/PrivacyView.swift
new file mode 100644
index 0000000000000000000000000000000000000000..bcc1e17713184224aba3d6248d43e9e4232f2ba1
--- /dev/null
+++ b/RenewalVault/Features/Privacy/PrivacyView.swift
@@ -0,0 +1,11 @@
+import SwiftUI
+
+struct PrivacyView: View {
+    var body: some View {
+        ScrollView {
+            Text("privacy.body".localized)
+                .padding()
+        }
+        .navigationTitle("settings.privacy".localized)
+    }
+}
diff --git a/RenewalVault/Features/Search/.gitkeep b/RenewalVault/Features/Search/.gitkeep
new file mode 100644
index 0000000000000000000000000000000000000000..35636d609d460feccdf2676711c0b1ef53cdd9a4
--- /dev/null
+++ b/RenewalVault/Features/Search/.gitkeep
@@ -0,0 +1 @@
+# Keep directory in git
diff --git a/RenewalVault/Features/Settings/SettingsView.swift b/RenewalVault/Features/Settings/SettingsView.swift
new file mode 100644
index 0000000000000000000000000000000000000000..1e7861f68a83dd21dcfeca0c7c9e76bf09ba6823
--- /dev/null
+++ b/RenewalVault/Features/Settings/SettingsView.swift
@@ -0,0 +1,53 @@
+import SwiftUI
+
+struct SettingsView: View {
+    @EnvironmentObject private var languageManager: LanguageManager
+    @EnvironmentObject private var appState: AppState
+    @EnvironmentObject private var entitlement: EntitlementService
+    @State private var showPaywall = false
+
+    private var languageBinding: Binding<AppLanguage> {
+        Binding(
+            get: { languageManager.selectedLanguage },
+            set: { languageManager.setLanguage($0) }
+        )
+    }
+
+    var body: some View {
+        List {
+            Section("settings.language".localized) {
+                Picker("settings.language".localized, selection: languageBinding) {
+                    ForEach(AppLanguage.allCases) { language in
+                        Text(language.displayName).tag(language)
+                    }
+                }
+                .pickerStyle(.segmented)
+            }
+
+            Section("settings.subscription".localized) {
+                Button("settings.manage_subscription".localized) { showPaywall = true }
+                Button("settings.restore".localized) { Task { try? await entitlement.restorePurchases() } }
+            }
+
+            Section("settings.notifications".localized) {
+                Button("settings.notification_settings".localized) { NotificationService.shared.openSettings() }
+            }
+
+            Section("settings.privacy".localized) {
+                NavigationLink("settings.privacy".localized) { PrivacyView() }
+            }
+
+            #if DEBUG
+            Section("settings.developer".localized) {
+                Toggle("settings.simulate_pro".localized, isOn: $entitlement.debugForcePro)
+                    .onChange(of: entitlement.debugForcePro) { _ in
+                        Task { await entitlement.refreshEntitlements() }
+                    }
+                Button("settings.reset_onboarding".localized) { appState.resetOnboarding() }
+            }
+            #endif
+        }
+        .navigationTitle("tab.settings".localized)
+        .sheet(isPresented: $showPaywall) { PaywallView() }
+    }
+}
diff --git a/RenewalVault/Features/Shared/.gitkeep b/RenewalVault/Features/Shared/.gitkeep
new file mode 100644
index 0000000000000000000000000000000000000000..35636d609d460feccdf2676711c0b1ef53cdd9a4
--- /dev/null
+++ b/RenewalVault/Features/Shared/.gitkeep
@@ -0,0 +1 @@
+# Keep directory in git
diff --git a/RenewalVault/Features/Vaults/VaultListView.swift b/RenewalVault/Features/Vaults/VaultListView.swift
new file mode 100644
index 0000000000000000000000000000000000000000..4ed2346c390b2fb4260a55135d0268b9ffc2a949
--- /dev/null
+++ b/RenewalVault/Features/Vaults/VaultListView.swift
@@ -0,0 +1,46 @@
+import SwiftUI
+import SwiftData
+
+struct VaultListView: View {
+    @Environment(\.modelContext) private var modelContext
+    @EnvironmentObject private var entitlement: EntitlementService
+    @State private var showUpgradeAlert = false
+    @Query(sort: \Vault.createdAt) private var vaults: [Vault]
+    @State private var name = ""
+
+    var body: some View {
+        List {
+            ForEach(vaults) { vault in
+                Text(vault.name)
+            }
+            .onDelete(perform: delete)
+
+            Section("vault.new".localized) {
+                TextField("vault.name".localized, text: $name)
+                Button("common.add".localized, action: add)
+            }
+        }
+        .navigationTitle("tab.vaults".localized)
+        .alert("common.notice".localized, isPresented: $showUpgradeAlert) {
+            Button("common.ok".localized, role: .cancel) {}
+        } message: {
+            Text("vault.upgrade_required".localized)
+        }
+    }
+
+    private func add() {
+        guard !name.isEmpty else { return }
+        guard FeatureGate.canCreateVault(currentCount: vaults.count, tier: entitlement.isPro ? .pro : .free) else {
+            showUpgradeAlert = true
+            return
+        }
+        modelContext.insert(Vault(name: name))
+        try? modelContext.save()
+        name = ""
+    }
+
+    private func delete(at offsets: IndexSet) {
+        offsets.map { vaults[$0] }.forEach(modelContext.delete)
+        try? modelContext.save()
+    }
+}
diff --git a/RenewalVault/Resources/Assets.xcassets/Contents.json b/RenewalVault/Resources/Assets.xcassets/Contents.json
new file mode 100644
index 0000000000000000000000000000000000000000..73c00596a7fca3f3d4bdd64053b69d86745f9e10
--- /dev/null
+++ b/RenewalVault/Resources/Assets.xcassets/Contents.json
@@ -0,0 +1,6 @@
+{
+  "info" : {
+    "author" : "xcode",
+    "version" : 1
+  }
+}
diff --git a/RenewalVault/Resources/en.lproj/Localizable.strings b/RenewalVault/Resources/en.lproj/Localizable.strings
new file mode 100644
index 0000000000000000000000000000000000000000..eab97e4438176064d3754d73804c6c51abf865ef
--- /dev/null
+++ b/RenewalVault/Resources/en.lproj/Localizable.strings
@@ -0,0 +1,100 @@
+"language.title" = "Choose your language";
+"language.select" = "Language";
+"language.continue" = "Continue";
+"language.english" = "English";
+"language.spanish" = "Spanish";
+
+"tab.home" = "Home";
+"tab.vaults" = "Vaults";
+"tab.settings" = "Settings";
+
+"common.skip" = "Skip";
+"common.next" = "Next";
+"common.add" = "Add";
+"common.save" = "Save";
+"common.edit" = "Edit";
+"common.cancel" = "Cancel";
+
+"onboard.get_started" = "Get started";
+"onboard.track" = "Track all your expirations in one place.";
+"onboard.smart" = "Get smart reminders before deadlines.";
+"onboard.attach" = "Attach photos and PDFs to each item.";
+"onboard.export" = "Export your vault to PDF with Pro.";
+
+"home.filters" = "Filters";
+"home.search" = "Search title or issuer";
+"home.upcoming_only" = "Upcoming only";
+"home.show_completed" = "Show completed";
+"home.vault_filter" = "Vault";
+"home.all_vaults" = "All vaults";
+"home.category_filter" = "Category";
+"home.all_categories" = "All categories";
+"home.expiring_soon" = "Expiring soon";
+"home.later" = "Later";
+"home.expired" = "Expired";
+"home.empty" = "No renewals yet";
+"home.empty_templates" = "Passport • National ID • Driver's license • Car insurance • Lease • Health insurance";
+
+"item.title" = "Title";
+"item.category" = "Category";
+"item.vault" = "Vault";
+"item.issuer" = "Issuer";
+"item.expiry" = "Expiry date";
+"item.notes" = "Notes";
+"item.reminders" = "Reminders (days before)";
+"item.custom_days" = "Custom days";
+"item.add" = "Add Item";
+"item.edit" = "Edit Item";
+"item.detail" = "Item Detail";
+"item.details" = "Details";
+"item.attachments" = "Attachments";
+"item.renewal_history" = "Renewal history";
+"item.mark_renewed" = "Mark renewed";
+"item.new_expiry" = "New expiry date";
+"item.renew_options" = "Renewal options";
+"item.renew" = "Renew";
+"item.no_renewal" = "No renewal";
+"item.completed_badge" = "Completed";
+"item.reactivate" = "Reactivate";
+"item.delete" = "Delete item";
+
+"category.passport" = "Passport";
+"category.nationalID" = "National ID";
+"category.driversLicense" = "Driver's license";
+"category.carInsurance" = "Car insurance";
+"category.lease" = "Lease";
+"category.healthInsurance" = "Health insurance";
+"category.subscription" = "Subscription";
+"category.other" = "Other";
+
+"vault.new" = "New Vault";
+"vault.name" = "Vault name";
+
+"settings.language" = "Language";
+"settings.subscription" = "Subscription";
+"settings.manage_subscription" = "Upgrade to Pro";
+"settings.restore" = "Restore Purchases";
+"settings.notifications" = "Notifications";
+"settings.notification_settings" = "Open Notification Settings";
+"settings.privacy" = "Privacy";
+"settings.developer" = "Developer";
+"settings.simulate_pro" = "Simulate Pro";
+"settings.reset_onboarding" = "Reset onboarding";
+
+"privacy.body" = "Renewal Vault stores your data locally on device. We do not track your activity by default.";
+
+"paywall.title" = "Renewal Vault Pro";
+"paywall.features" = "Unlimited vaults, unlimited items, unlimited attachments, PDF export.";
+
+"notification.title" = "Renewal Reminder";
+"notification.expired" = "This item is expired.";
+"notification.expires_in" = "%@ expires in %d day(s).";
+
+
+"common.notice" = "Notice";
+"common.ok" = "OK";
+"vault.upgrade_required" = "Upgrade to Pro to add new Vaults.";
+"item.deleted_success" = "Item deleted successfully.";
+"attachment.add_photo" = "Add photo from library";
+"attachment.add_file" = "Add PDF/File";
+"attachment.upgrade_required" = "Upgrade to Pro to add more attachments.";
diff --git a/RenewalVault/Resources/es.lproj/Localizable.strings b/RenewalVault/Resources/es.lproj/Localizable.strings
new file mode 100644
index 0000000000000000000000000000000000000000..bca78ebffda787a54ff36efdc58d581dfe6ba74a
--- /dev/null
+++ b/RenewalVault/Resources/es.lproj/Localizable.strings
@@ -0,0 +1,100 @@
+"language.title" = "Elige tu idioma";
+"language.select" = "Idioma";
+"language.continue" = "Continuar";
+"language.english" = "Inglés";
+"language.spanish" = "Español";
+
+"tab.home" = "Inicio";
+"tab.vaults" = "Bóvedas";
+"tab.settings" = "Ajustes";
+
+"common.skip" = "Omitir";
+"common.next" = "Siguiente";
+"common.add" = "Agregar";
+"common.save" = "Guardar";
+"common.edit" = "Editar";
+"common.cancel" = "Cancelar";
+
+"onboard.get_started" = "Comenzar";
+"onboard.track" = "Controla todos tus vencimientos en un solo lugar.";
+"onboard.smart" = "Recibe recordatorios inteligentes antes de las fechas límite.";
+"onboard.attach" = "Adjunta fotos y PDF a cada elemento.";
+"onboard.export" = "Exporta tu bóveda a PDF con Pro.";
+
+"home.filters" = "Filtros";
+"home.search" = "Buscar por título o emisor";
+"home.upcoming_only" = "Solo próximos";
+"home.show_completed" = "Mostrar completados";
+"home.vault_filter" = "Bóveda";
+"home.all_vaults" = "Todas las bóvedas";
+"home.category_filter" = "Categoría";
+"home.all_categories" = "Todas las categorías";
+"home.expiring_soon" = "Vencen pronto";
+"home.later" = "Después";
+"home.expired" = "Vencidos";
+"home.empty" = "Aún no hay renovaciones";
+"home.empty_templates" = "Pasaporte • DNI • Licencia de conducir • Seguro de coche • Alquiler • Seguro de salud";
+
+"item.title" = "Título";
+"item.category" = "Categoría";
+"item.vault" = "Bóveda";
+"item.issuer" = "Emisor";
+"item.expiry" = "Fecha de vencimiento";
+"item.notes" = "Notas";
+"item.reminders" = "Recordatorios (días antes)";
+"item.custom_days" = "Días personalizados";
+"item.add" = "Agregar elemento";
+"item.edit" = "Editar elemento";
+"item.detail" = "Detalle";
+"item.details" = "Detalles";
+"item.attachments" = "Adjuntos";
+"item.renewal_history" = "Historial de renovación";
+"item.mark_renewed" = "Marcar renovado";
+"item.new_expiry" = "Nueva fecha de vencimiento";
+"item.renew_options" = "Opciones de renovación";
+"item.renew" = "Renovar";
+"item.no_renewal" = "Sin renovación";
+"item.completed_badge" = "Completado";
+"item.reactivate" = "Reactivar";
+"item.delete" = "Eliminar elemento";
+
+"category.passport" = "Pasaporte";
+"category.nationalID" = "DNI";
+"category.driversLicense" = "Licencia de conducir";
+"category.carInsurance" = "Seguro de coche";
+"category.lease" = "Alquiler";
+"category.healthInsurance" = "Seguro de salud";
+"category.subscription" = "Suscripción";
+"category.other" = "Otro";
+
+"vault.new" = "Nueva bóveda";
+"vault.name" = "Nombre de bóveda";
+
+"settings.language" = "Idioma";
+"settings.subscription" = "Suscripción";
+"settings.manage_subscription" = "Actualizar a Pro";
+"settings.restore" = "Restaurar compras";
+"settings.notifications" = "Notificaciones";
+"settings.notification_settings" = "Abrir ajustes de notificación";
+"settings.privacy" = "Privacidad";
+"settings.developer" = "Desarrollador";
+"settings.simulate_pro" = "Simular Pro";
+"settings.reset_onboarding" = "Reiniciar onboarding";
+
+"privacy.body" = "Renewal Vault guarda tus datos localmente en el dispositivo. No rastreamos tu actividad por defecto.";
+
+"paywall.title" = "Renewal Vault Pro";
+"paywall.features" = "Bóvedas ilimitadas, elementos ilimitados, adjuntos ilimitados, exportación PDF.";
+
+"notification.title" = "Recordatorio de renovación";
+"notification.expired" = "Este elemento está vencido.";
+"notification.expires_in" = "%@ vence en %d día(s).";
+
+
+"common.notice" = "Aviso";
+"common.ok" = "Aceptar";
+"vault.upgrade_required" = "Actualiza a Pro para añadir nuevas bóvedas.";
+"item.deleted_success" = "Elemento eliminado correctamente.";
+"attachment.add_photo" = "Añadir foto desde biblioteca";
+"attachment.add_file" = "Añadir PDF/archivo";
+"attachment.upgrade_required" = "Actualiza a Pro para añadir más adjuntos.";
diff --git a/RenewalVaultTests/RenewalVaultTests.swift b/RenewalVaultTests/RenewalVaultTests.swift
new file mode 100644
index 0000000000000000000000000000000000000000..685160f763d580329009c1dfac13d00c016d8a9c
--- /dev/null
+++ b/RenewalVaultTests/RenewalVaultTests.swift
@@ -0,0 +1,83 @@
+import XCTest
+@testable import RenewalVault
+
+final class RenewalVaultTests: XCTestCase {
+    func testGroupingLogic() {
+        let vault = Vault(name: "P")
+        let now = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
+        let soonItem = Item(title: "Soon", category: "passport", expiryDate: Calendar.current.date(byAdding: .day, value: 15, to: now)!, vault: vault)
+        let laterItem = Item(title: "Later", category: "passport", expiryDate: Calendar.current.date(byAdding: .day, value: 100, to: now)!, vault: vault)
+        let expiredItem = Item(title: "Expired", category: "passport", expiryDate: Calendar.current.date(byAdding: .day, value: -1, to: now)!, vault: vault)
+
+        XCTAssertEqual(ReminderScheduler.bucket(for: soonItem, now: now), .soon)
+        XCTAssertEqual(ReminderScheduler.bucket(for: laterItem, now: now), .later)
+        XCTAssertEqual(ReminderScheduler.bucket(for: expiredItem, now: now), .expired)
+    }
+
+    func testReminderSchedulingLeapYear() {
+        var calendar = Calendar(identifier: .gregorian)
+        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
+        let expiry = calendar.date(from: DateComponents(year: 2024, month: 3, day: 1))!
+
+        let dates = ReminderScheduler.reminderDates(expiryDate: expiry, reminderDays: [1, 30], calendar: calendar)
+        let expectedOne = calendar.date(from: DateComponents(year: 2024, month: 2, day: 29))!
+        let expectedThirty = calendar.date(from: DateComponents(year: 2024, month: 1, day: 31))!
+        XCTAssertTrue(dates.contains(expectedOne))
+        XCTAssertTrue(dates.contains(expectedThirty))
+    }
+
+    func testFreeVsProGate() {
+        XCTAssertFalse(FeatureGate.canCreateItem(currentCount: 5, tier: .free))
+        XCTAssertTrue(FeatureGate.canCreateItem(currentCount: 5, tier: .pro))
+        XCTAssertFalse(FeatureGate.canExportPDF(tier: .free))
+        XCTAssertTrue(FeatureGate.canExportPDF(tier: .pro))
+    }
+
+    @MainActor
+    func testLanguageFlowStateMachine() async {
+        let defaults = UserDefaults.standard
+        defaults.removeObject(forKey: LanguageManager.languageCodeKey)
+        defaults.removeObject(forKey: "onboarding.completed")
+
+        let state = AppState()
+        XCTAssertFalse(state.hasChosenLanguage)
+        XCTAssertFalse(state.hasCompletedOnboarding)
+    }
+
+    func testNoRenewalMarksCompleted() {
+        let item = Item(title: "Lease", category: "lease", expiryDate: .now, scheduledNotificationIdentifiers: ["a", "b"])
+        item.markNoRenewal()
+
+        XCTAssertTrue(item.isCompleted)
+        XCTAssertFalse(item.repeatAfterRenewal)
+    }
+
+    func testVaultRelationshipCanChange() {
+        let v1 = Vault(name: "Personal")
+        let v2 = Vault(name: "Business")
+        let item = Item(title: "Passport", category: "passport", expiryDate: .now, vault: v1)
+
+        XCTAssertEqual(item.vault?.name, "Personal")
+        item.vault = v2
+        XCTAssertEqual(item.vault?.name, "Business")
+    }
+
+    func testFreeTierVaultLimit() {
+        XCTAssertFalse(FeatureGate.canCreateVault(currentCount: 1, tier: .free))
+        XCTAssertTrue(FeatureGate.canCreateVault(currentCount: 1, tier: .pro))
+    }
+
+    func testAttachmentLimitGate() {
+        XCTAssertFalse(FeatureGate.canAddAttachment(currentCount: 3, tier: .free))
+        XCTAssertTrue(FeatureGate.canAddAttachment(currentCount: 3, tier: .pro))
+    }
+
+    @MainActor
+    func testLanguagePersistence() {
+        let manager = LanguageManager()
+        manager.setLanguage(.es)
+
+        XCTAssertEqual(UserDefaults.standard.string(forKey: LanguageManager.languageCodeKey), "es")
+        XCTAssertEqual(manager.locale.identifier, "es")
+    }
+}
diff --git a/StoreKit/RenewalVault.storekit b/StoreKit/RenewalVault.storekit
new file mode 100644
index 0000000000000000000000000000000000000000..48437d61af084c6d946d5f0bb3644e5195a4bfe8
--- /dev/null
+++ b/StoreKit/RenewalVault.storekit
@@ -0,0 +1,88 @@
+{
+  "identifier" : "RenewalVaultLocalConfig",
+  "nonRenewingSubscriptions" : [
+
+  ],
+  "products" : [
+
+  ],
+  "settings" : {
+    "_applicationInternalID" : "123456789",
+    "_developerTeamID" : "TEAMID1234",
+    "_failTransactionsEnabled" : false,
+    "_lastSynchronizedDate" : 0,
+    "_locale" : "en_US",
+    "_renewalBillingIssuesEnabled" : false,
+    "_storefront" : "USA",
+    "_timeRate" : 1
+  },
+  "subscriptionGroups" : [
+    {
+      "id" : "group.renewalvault.pro",
+      "localizations" : [
+        {
+          "description" : "Unlock unlimited vaults, items, and attachments.",
+          "displayName" : "Renewal Vault Pro",
+          "locale" : "en_US"
+        }
+      ],
+      "name" : "Renewal Vault Pro",
+      "subscriptions" : [
+        {
+          "adHocOffers" : [
+
+          ],
+          "codeOffers" : [
+
+          ],
+          "displayPrice" : "4.99",
+          "familyShareable" : false,
+          "groupNumber" : 1,
+          "internalID" : "monthly001",
+          "introductoryOffer" : null,
+          "localizations" : [
+            {
+              "description" : "Monthly Pro access",
+              "displayName" : "Pro Monthly",
+              "locale" : "en_US"
+            }
+          ],
+          "productID" : "com.renewalvault.pro.monthly",
+          "recurringSubscriptionPeriod" : "P1M",
+          "referenceName" : "Pro Monthly",
+          "subscriptionGroupID" : "group.renewalvault.pro",
+          "type" : "RecurringSubscription"
+        },
+        {
+          "adHocOffers" : [
+
+          ],
+          "codeOffers" : [
+
+          ],
+          "displayPrice" : "39.99",
+          "familyShareable" : false,
+          "groupNumber" : 2,
+          "internalID" : "yearly001",
+          "introductoryOffer" : null,
+          "localizations" : [
+            {
+              "description" : "Annual Pro access",
+              "displayName" : "Pro Yearly",
+              "locale" : "en_US"
+            }
+          ],
+          "productID" : "com.renewalvault.pro.yearly",
+          "recurringSubscriptionPeriod" : "P1Y",
+          "referenceName" : "Pro Yearly",
+          "subscriptionGroupID" : "group.renewalvault.pro",
+          "type" : "RecurringSubscription"
+        }
+      ]
+    }
+  ],
+  "version" : {
+    "major" : 3,
+    "minor" : 0
+  }
+}
 
EOF
)
