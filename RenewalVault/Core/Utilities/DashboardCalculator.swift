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
    let groupedRenewals: [DashboardMonthGroup]
}

enum DashboardPriceFilter: String, CaseIterable, Identifiable {
    case all
    case pricedOnly
    case freeOnly

    var id: String { rawValue }
}

enum DashboardDateFilter: Equatable {
    case none
    case year(Int)
    case month(Int)
    case monthYear(month: Int, year: Int)

    var yearValue: Int? {
        switch self {
        case .year(let year): return year
        case .monthYear(_, let year): return year
        default: return nil
        }
    }

    var monthValue: Int? {
        switch self {
        case .month(let month): return month
        case .monthYear(let month, _): return month
        default: return nil
        }
    }
}

struct DashboardFilter: Equatable {
    var priceFilter: DashboardPriceFilter = .all
    var paidOnly: Bool = false
    var dateFilter: DashboardDateFilter = .none

    static var `default`: DashboardFilter { DashboardFilter() }
}

enum DashboardCalculator {
    static func summary(items: [Item], now: Date = .now, calendar: Calendar = .current, filter: DashboardFilter = .default) -> DashboardSummary {
        let filteredItems = applyFilter(items: items, filter: filter, now: now, calendar: calendar)

        let currentYear = calendar.component(.year, from: now)
        let targetYear = filter.dateFilter.yearValue ?? currentYear

        let nextMonthReference = calendar.date(byAdding: .month, value: 1, to: now) ?? now
        let defaultNextMonth = calendar.component(.month, from: nextMonthReference)
        let defaultNextMonthYear = calendar.component(.year, from: nextMonthReference)

        let targetNextMonth = filter.dateFilter.monthValue ?? defaultNextMonth
        let targetNextMonthYear = filter.dateFilter.yearValue ?? defaultNextMonthYear

        let yearToPay = filteredItems.filter {
            !$0.isCompleted
            && $0.priceAmount != nil
            && calendar.component(.year, from: $0.expiryDate) == targetYear
        }

        let nextMonthToPay = filteredItems.filter {
            guard !$0.isCompleted, $0.priceAmount != nil else { return false }
            let components = calendar.dateComponents([.year, .month], from: $0.expiryDate)
            return components.month == targetNextMonth && components.year == targetNextMonthYear
        }

        let paid = filteredItems.filter { $0.isCompleted && $0.priceAmount != nil }

        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let groupingCandidates = filteredItems
            .filter { filter.paidOnly ? true : $0.expiryDate >= monthStart }
            .sorted { $0.expiryDate < $1.expiryDate }

        var grouped: [Date: [Item]] = [:]
        for item in groupingCandidates {
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
            groupedRenewals: monthGroups
        )
    }

    static func applyFilter(items: [Item], filter: DashboardFilter, now: Date = .now, calendar: Calendar = .current) -> [Item] {
        items.filter { item in
            let priceMatch: Bool
            switch filter.priceFilter {
            case .all:
                priceMatch = true
            case .pricedOnly:
                priceMatch = item.priceAmount != nil
            case .freeOnly:
                priceMatch = item.priceAmount == nil
            }

            let paidMatch = !filter.paidOnly || item.isCompleted

            let dateMatch: Bool
            let components = calendar.dateComponents([.year, .month], from: item.expiryDate)
            switch filter.dateFilter {
            case .none:
                dateMatch = true
            case .year(let year):
                dateMatch = components.year == year
            case .month(let month):
                let currentYear = calendar.component(.year, from: now)
                dateMatch = components.month == month && components.year == currentYear
            case .monthYear(let month, let year):
                dateMatch = components.month == month && components.year == year
            }

            return priceMatch && paidMatch && dateMatch
        }
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
