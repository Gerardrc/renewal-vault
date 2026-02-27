import XCTest
@testable import RenewalVault

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

    func testProtectedPersonalVault() {
        let protected = Vault(name: "Personal", isSystemDefault: true)
        let userVault = Vault(name: "Travel")
        XCTAssertTrue(protected.isProtectedDefault)
        XCTAssertFalse(userVault.isProtectedDefault)
    }

    func testFreeTierVaultLimit() {
        XCTAssertFalse(FeatureGate.canCreateVault(currentCount: 1, tier: .free))
        XCTAssertTrue(FeatureGate.canCreateVault(currentCount: 1, tier: .pro))
    }

    func testAttachmentLimitGate() {
        XCTAssertFalse(FeatureGate.canAddAttachment(currentCount: 3, tier: .free))
        XCTAssertTrue(FeatureGate.canAddAttachment(currentCount: 3, tier: .pro))
    }

    func testReminderOptionsCustomAddAndToggle() {
        var selected = [30]
        selected = ReminderDayOptions.toggle(day: 45, selected: selected)
        XCTAssertTrue(selected.contains(45))

        selected = ReminderDayOptions.toggle(day: 45, selected: selected)
        XCTAssertFalse(selected.contains(45))

        XCTAssertNil(ReminderDayOptions.parseCustom("0"))
        XCTAssertEqual(ReminderDayOptions.parseCustom(" 15 "), 15)
    }

    func testReminderAvailableDaysKeepsCustomVisible() {
        let values = ReminderDayOptions.availableDays(selected: [45], customAvailable: [45])
        XCTAssertTrue(values.contains(45))
        XCTAssertTrue(values.contains(90))
    }

    @MainActor
    func testLanguageChosenFlagPersistsFirstLaunchGate() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: AppState.languageChosenKey)
        let state = AppState()
        state.setLanguageChosen()
        XCTAssertTrue(defaults.bool(forKey: AppState.languageChosenKey))
    }

    @MainActor
    func testInitialPermissionRequestOnlyOnceFlag() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: AppState.initialPermissionsRequestedKey)
        let state = AppState()
        XCTAssertTrue(state.shouldRequestInitialPermissions())
        defaults.set(true, forKey: AppState.initialPermissionsRequestedKey)
        XCTAssertFalse(state.shouldRequestInitialPermissions())
    }

    func testPriceFormattingAndParsing() {
        XCTAssertEqual(PriceFormatter.text(amount: 12.5, currency: "€"), "€12.50")
        XCTAssertEqual(PriceFormatter.text(amount: 12.5, currency: nil), "€12.50")
        XCTAssertEqual(PriceFormatter.parseAmount(" 19,99 "), 19.99)
        XCTAssertNil(PriceFormatter.text(amount: nil, currency: "$"))
    }

    func testItemPricePersistenceFields() {
        let item = Item(title: "Netflix", category: "subscription", expiryDate: .now, priceAmount: 9.99, priceCurrency: "$")
        XCTAssertEqual(item.priceAmount, 9.99)
        XCTAssertEqual(item.priceCurrency, "$")
        XCTAssertEqual(item.formattedPriceText, "$9.99")
    }

    func testHomeSubtitlePrefersPriceOverVault() {
        let vault = Vault(name: "Personal")
        let priced = Item(title: "Plan", category: "subscription", expiryDate: .now, priceAmount: 29.99, priceCurrency: "€", vault: vault)
        let noPrice = Item(title: "Doc", category: "passport", expiryDate: .now, vault: vault)

        let pricedWithoutCurrency = Item(title: "Plan2", category: "subscription", expiryDate: .now, priceAmount: 11.0, priceCurrency: nil, vault: vault)

        XCTAssertEqual(HomeView.subtitleText(for: priced), "€29.99")
        XCTAssertEqual(HomeView.subtitleText(for: pricedWithoutCurrency), "€11.00")
        XCTAssertEqual(HomeView.subtitleText(for: noPrice), "Personal")
    }



    @MainActor
    func testInitialPermissionsCallsNotificationThenCalendar() async {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: AppState.initialPermissionsRequestedKey)

        let state = AppState()
        var calls: [String] = []

        await state.requestInitialPermissions(
            requestNotifications: {
                calls.append("notification")
                return true
            },
            requestCalendar: {
                calls.append("calendar")
                return true
            },
            sleepNanoseconds: { _ in }
        )

        XCTAssertEqual(calls, ["notification", "calendar"])
        XCTAssertTrue(defaults.bool(forKey: AppState.initialPermissionsRequestedKey))
    }



    func testCalendarEventTitleIncludesPriceWhenPresent() {
        let itemWithPrice = Item(title: "Netflix", category: "subscription", expiryDate: .now, priceAmount: 12.99, priceCurrency: "€")
        let itemNoPrice = Item(title: "Passport", category: "passport", expiryDate: .now)

        XCTAssertEqual(CalendarEventService.titleText(for: itemWithPrice), "Netflix (€12.99)")
        XCTAssertEqual(CalendarEventService.titleText(for: itemNoPrice), "Passport")
    }

    func testCalendarEventDefaultStartTimeIsEightAM() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let expiry = calendar.date(from: DateComponents(year: 2027, month: 3, day: 12, hour: 0, minute: 0))!

        let start = CalendarEventService.defaultStartDate(for: expiry)
        let components = Calendar.current.dateComponents([.hour, .minute], from: start)
        XCTAssertEqual(components.hour, 8)
        XCTAssertEqual(components.minute, 0)
    }

    func testVaultIconPersistenceField() {
        let vault = Vault(name: "Travel", iconSystemName: VaultIcon.suitcase.systemName)
        XCTAssertEqual(vault.iconSystemName, "suitcase")
        XCTAssertEqual(vault.resolvedIconSystemName, "suitcase")
    }

    func testVaultDetailItemsFiltering() {
        let vaultA = Vault(name: "A")
        let vaultB = Vault(name: "B")
        let itemA = Item(title: "A1", category: "other", expiryDate: .now, vault: vaultA)
        let itemB = Item(title: "B1", category: "other", expiryDate: .now, vault: vaultB)

        let filtered = VaultDetailView.items(for: vaultA.id, in: [itemA, itemB])
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.title, "A1")
    }

    func testProGatedVaultAlertActionsAreCloseAndGoPro() {
        XCTAssertEqual(ProUpgradeAction.vaultCreationActions, [.close, .goPro])
    }



    func testDashboardYearlyTotalCalculationByCurrency() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 10))!

        let itemA = Item(title: "A", category: "subscription", expiryDate: calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!, priceAmount: 10, priceCurrency: "€")
        let itemB = Item(title: "B", category: "subscription", expiryDate: calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!, priceAmount: 15, priceCurrency: "€")
        let itemC = Item(title: "C", category: "subscription", expiryDate: calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!, priceAmount: 20, priceCurrency: "$")
        let noPrice = Item(title: "D", category: "subscription", expiryDate: calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!)

        let summary = DashboardCalculator.summary(items: [itemA, itemB, itemC, noPrice], now: now, calendar: calendar)
        XCTAssertEqual(summary.yearToPayTotals.count, 2)
        XCTAssertEqual(summary.yearToPayTotals.first(where: { $0.currency == "€" })?.amount, 25)
        XCTAssertEqual(summary.yearToPayTotals.first(where: { $0.currency == "$" })?.amount, 20)
    }

    func testDashboardUpcomingMonthToPayExcludesCompletedAndMatchesNextMonth() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 10))!

        let nextMonthUnpaid = Item(title: "A", category: "subscription", expiryDate: calendar.date(from: DateComponents(year: 2026, month: 5, day: 2))!, priceAmount: 12, priceCurrency: "€")
        let nextMonthCompleted = Item(title: "B", category: "subscription", expiryDate: calendar.date(from: DateComponents(year: 2026, month: 5, day: 15))!, priceAmount: 9, priceCurrency: "€", isCompleted: true)
        let thisMonth = Item(title: "C", category: "subscription", expiryDate: calendar.date(from: DateComponents(year: 2026, month: 4, day: 20))!, priceAmount: 7, priceCurrency: "€")

        let summary = DashboardCalculator.summary(items: [nextMonthUnpaid, nextMonthCompleted, thisMonth], now: now, calendar: calendar)
        XCTAssertEqual(summary.nextMonthToPayTotals, [DashboardCurrencyTotal(currency: "€", amount: 12)])
    }

    func testDashboardPaidTotalUsesCompletedPricedItemsOnly() {
        let paidOne = Item(title: "A", category: "subscription", expiryDate: .now, priceAmount: 5, priceCurrency: "€", isCompleted: true)
        let paidTwo = Item(title: "B", category: "subscription", expiryDate: .now, priceAmount: 7, priceCurrency: "€", isCompleted: true)
        let unpaid = Item(title: "C", category: "subscription", expiryDate: .now, priceAmount: 3, priceCurrency: "€", isCompleted: false)
        let noPricePaid = Item(title: "D", category: "subscription", expiryDate: .now, isCompleted: true)

        let summary = DashboardCalculator.summary(items: [paidOne, paidTwo, unpaid, noPricePaid])
        XCTAssertEqual(summary.paidTotals, [DashboardCurrencyTotal(currency: "€", amount: 12)])
    }

    func testDashboardGroupsUpcomingRenewalsByMonth() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 10))!

        let may = Item(title: "May", category: "subscription", expiryDate: calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!)
        let june = Item(title: "June", category: "subscription", expiryDate: calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!)
        let april = Item(title: "April", category: "subscription", expiryDate: calendar.date(from: DateComponents(year: 2026, month: 4, day: 20))!)

        let summary = DashboardCalculator.summary(items: [june, may, april], now: now, calendar: calendar)
        XCTAssertEqual(summary.upcomingMonthGroups.count, 3)
        XCTAssertEqual(summary.upcomingMonthGroups.first?.items.first?.title, "April")
    }

    func testDashboardAccessIsProOnly() {
        XCTAssertFalse(FeatureGate.canAccessDashboard(tier: .free))
        XCTAssertTrue(FeatureGate.canAccessDashboard(tier: .pro))
    }

    @MainActor
    func testLanguagePersistence() {
        let manager = LanguageManager()
        manager.setLanguage(.es)

        XCTAssertEqual(UserDefaults.standard.string(forKey: LanguageManager.languageCodeKey), "es")
        XCTAssertEqual(manager.locale.identifier, "es")
    }
}
