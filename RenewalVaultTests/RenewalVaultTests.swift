import XCTest
@testable import Renewal_Vault

final class RenewalVaultTests: XCTestCase {
    func testGroupingLogic() {
        let vault = Vault(name: "P")
        let now = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let soonItem = Item(title: "Soon", category: "passport", expiryDate: Calendar.current.date(byAdding: .day, value: 15, to: now)!, vault: vault)
        let laterItem = Item(title: "Later", category: "passport", expiryDate: Calendar.current.date(byAdding: .day, value: 100, to: now)!, vault: vault)
        let expiredItem = Item(title: "Expired", category: "passport", expiryDate: Calendar.current.date(byAdding: .day, value: -1, to: now)!, vault: vault)

        XCTAssertEqual(ReminderScheduler.bucket(for: soonItem, now: now), .soon)
        XCTAssertEqual(ReminderScheduler.bucket(for: laterItem, now: now), .later)
        XCTAssertEqual(ReminderScheduler.bucket(for: expiredItem, now: now), .expired)
    }

    func testReminderSchedulingLeapYear() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let expiry = calendar.date(from: DateComponents(year: 2024, month: 3, day: 1))!

        let dates = ReminderScheduler.reminderDates(expiryDate: expiry, reminderDays: [1, 30], calendar: calendar)
        let expectedOne = calendar.date(from: DateComponents(year: 2024, month: 2, day: 29))!
        let expectedThirty = calendar.date(from: DateComponents(year: 2024, month: 1, day: 31))!
        XCTAssertTrue(dates.contains(expectedOne))
        XCTAssertTrue(dates.contains(expectedThirty))
    }

    func testFreeVsProGate() {
        XCTAssertFalse(FeatureGate.canCreateItem(currentCount: 5, tier: .free))
        XCTAssertTrue(FeatureGate.canCreateItem(currentCount: 5, tier: .pro))
        XCTAssertFalse(FeatureGate.canExportPDF(tier: .free))
        XCTAssertTrue(FeatureGate.canExportPDF(tier: .pro))
    }

    @MainActor
    func testLanguageFlowStateMachine() async {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: LanguageManager.languageCodeKey)
        defaults.removeObject(forKey: "onboarding.completed")

        let state = AppState()
        XCTAssertFalse(state.hasChosenLanguage)
        XCTAssertFalse(state.hasCompletedOnboarding)
    }

    func testNoRenewalMarksCompleted() {
        let item = Item(title: "Lease", category: "lease", expiryDate: .now, scheduledNotificationIdentifiers: ["a", "b"])
        item.markNoRenewal()

        XCTAssertTrue(item.isCompleted)
        XCTAssertFalse(item.repeatAfterRenewal)
    }

    func testVaultRelationshipCanChange() {
        let v1 = Vault(name: "Personal")
        let v2 = Vault(name: "Business")
        let item = Item(title: "Passport", category: "passport", expiryDate: .now, vault: v1)

        XCTAssertEqual(item.vault?.name, "Personal")
        item.vault = v2
        XCTAssertEqual(item.vault?.name, "Business")
    }

    @MainActor
    func testLanguagePersistence() {
        let manager = LanguageManager()
        manager.setLanguage(.es)

        XCTAssertEqual(UserDefaults.standard.string(forKey: LanguageManager.languageCodeKey), "es")
        XCTAssertEqual(manager.locale.identifier, "es")
    }
}
