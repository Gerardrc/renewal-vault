import Foundation

struct DashboardCurrencyTotal: Equatable, Identifiable {
    let currency: String
    let amount: Double

    var id: String { currency }

    var formattedText: String {
        PriceFormatter.text(amount: amount, currency: currency) ?? "-"
    }
}

struct DashboardMonthGroup: Identifiable {
    let monthStart: Date
    let items: [Item]

    var id: Date { monthStart }
}

struct DashboardSummary {
    let yearToPayTotals: [DashboardCurrencyTotal]
    let nextMonthToPayTotals: [DashboardCurrencyTotal]
    let paidTotals: [DashboardCurrencyTotal]
    let upcomingMonthGroups: [DashboardMonthGroup]
}

enum DashboardCalculator {
    static func summary(items: [Item], now: Date = .now, calendar: Calendar = .current) -> DashboardSummary {
        let currentYear = calendar.component(.year, from: now)
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        let nextMonthComponents = calendar.dateComponents([.year, .month], from: nextMonthDate)

        let yearToPay = items.filter {
            !$0.isCompleted
            && $0.priceAmount != nil
            && calendar.component(.year, from: $0.expiryDate) == currentYear
        }

        let nextMonthToPay = items.filter {
            guard !$0.isCompleted, $0.priceAmount != nil else { return false }
            let components = calendar.dateComponents([.year, .month], from: $0.expiryDate)
            return components.year == nextMonthComponents.year && components.month == nextMonthComponents.month
        }

        let paid = items.filter { $0.isCompleted && $0.priceAmount != nil }

        let upcomingItems = items
            .filter { $0.expiryDate >= monthStart }
            .sorted { $0.expiryDate < $1.expiryDate }

        var grouped: [Date: [Item]] = [:]
        for item in upcomingItems {
            let key = calendar.date(from: calendar.dateComponents([.year, .month], from: item.expiryDate)) ?? monthStart
            grouped[key, default: []].append(item)
        }

        let monthGroups = grouped.keys.sorted().map { key in
            DashboardMonthGroup(monthStart: key, items: grouped[key] ?? [])
        }

        return DashboardSummary(
            yearToPayTotals: totalsByCurrency(for: yearToPay),
            nextMonthToPayTotals: totalsByCurrency(for: nextMonthToPay),
            paidTotals: totalsByCurrency(for: paid),
            upcomingMonthGroups: monthGroups
        )
    }

    static func totalsByCurrency(for items: [Item]) -> [DashboardCurrencyTotal] {
        var totals: [String: Double] = [:]
        for item in items {
            guard let amount = item.priceAmount, amount >= 0 else { continue }
            let currency = (item.priceCurrency?.isEmpty == false ? item.priceCurrency : CurrencySymbol.euro.rawValue) ?? CurrencySymbol.euro.rawValue
            totals[currency, default: 0] += amount
        }

        return totals.keys.sorted().map { currency in
            DashboardCurrencyTotal(currency: currency, amount: totals[currency] ?? 0)
        }
    }
}
