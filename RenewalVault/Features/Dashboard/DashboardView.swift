import SwiftUI
import SwiftData

struct DashboardView: View {
    @EnvironmentObject private var entitlement: EntitlementService
    @EnvironmentObject private var languageManager: LanguageManager
    @Query(sort: \Item.expiryDate) private var items: [Item]
    @State private var showPaywall = false
    @State private var showFilterSheet = false
    @State private var dashboardFilter = DashboardFilter.default

    private var summary: DashboardSummary {
        DashboardCalculator.summary(items: items, filter: dashboardFilter)
    }

    private var filteredItems: [Item] {
        DashboardCalculator.applyFilter(items: items, filter: dashboardFilter)
    }

    var body: some View {
        Group {
            if FeatureGate.canAccessDashboard(tier: entitlement.isPro ? .pro : .free) {
                proDashboardContent
            } else {
                DashboardLockedView(showPaywall: $showPaywall)
            }
        }
        .navigationTitle("tab.dashboard".localized)
        .toolbar {
            if FeatureGate.canAccessDashboard(tier: entitlement.isPro ? .pro : .free) {
                Button {
                    showFilterSheet = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            NavigationStack { PaywallView() }
        }
        .sheet(isPresented: $showFilterSheet) {
            NavigationStack {
                DashboardFilterSheet(filter: $dashboardFilter)
            }
        }
    }

    private var proDashboardContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                DashboardSummaryCard(
                    title: "dashboard.summary.year".localized,
                    totals: summary.yearToPayTotals,
                    vaultBreakdown: summary.yearVaultTotals
                )

                HStack(alignment: .top, spacing: 10) {
                    DashboardSummaryCard(title: "dashboard.summary.paid".localized, totals: summary.paidTotals, compact: true)
                    DashboardSummaryCard(title: "dashboard.summary.next_month".localized, totals: summary.nextMonthToPayTotals, compact: true)
                }

                if hasMultiCurrency {
                    Text("dashboard.multi_currency_notice".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if summary.groupedRenewals.isEmpty {
                    Text("dashboard.empty".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(summary.groupedRenewals) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Self.monthTitle(for: group.monthStart, locale: languageManager.locale))
                                .font(.headline)
                            ForEach(group.items) { item in
                                NavigationLink(destination: ItemDetailView(item: item)) {
                                    DashboardItemCard(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    static func monthTitle(for date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date).capitalized
    }

    private var hasMultiCurrency: Bool {
        let currencies = Set(
            items.compactMap { item -> String? in
                guard item.priceAmount != nil else { return nil }

                if let currency = item.priceCurrency, !currency.isEmpty {
                    return currency
                } else {
                    return CurrencySymbol.euro.rawValue
                }
            }
        )
        return currencies.count > 1
    }
}


private struct DashboardLockedView: View {
    @Binding var showPaywall: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 52))
                .foregroundColor(.accentColor)

            Text("dashboard.locked.title".localized)
                .font(.title3.bold())

            Text("dashboard.locked.body".localized)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Button("common.go_pro".localized) {
                showPaywall = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

private struct DashboardSummaryCard: View {
    let title: String
    let totals: [DashboardCurrencyTotal]
    var compact: Bool = false
    var vaultBreakdown: [DashboardVaultCurrencyTotal] = []

    private var canShowBreakdown: Bool {
        !compact && !vaultBreakdown.isEmpty && Set(vaultBreakdown.map { $0.currency }).count == 1
    }

    private var hasMultiCurrencyBreakdown: Bool {
        !compact && Set(vaultBreakdown.map { $0.currency }).count > 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if totals.isEmpty {
                Text("dashboard.total.none".localized)
                    .font(.headline)
            } else {
                ForEach(totals) { total in
                    Text(total.formattedText)
                        .font(.headline)
                }
            }

            if canShowBreakdown {
                DashboardVaultBreakdownView(vaultTotals: vaultBreakdown)
                    .padding(.top, 2)
            }

            if hasMultiCurrencyBreakdown {
                Text("dashboard.chart_hidden_multi_currency".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 108 : 124, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.gray.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct DashboardVaultBreakdownView: View {
    let vaultTotals: [DashboardVaultCurrencyTotal]

    private var ordered: [DashboardVaultCurrencyTotal] {
        vaultTotals.sorted { $0.amount > $1.amount }
    }

    private var maxAmount: Double {
        ordered.first?.amount ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(ordered) { total in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(total.vaultName)
                            .font(.caption2)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(total.formattedText)
                            .font(.caption2.weight(.semibold))
                    }

                    GeometryReader { geometry in
                        let ratio = maxAmount > 0 ? min(1, total.amount / maxAmount) : 0
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.gray.opacity(0.15))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.accentColor.opacity(0.7))
                                .frame(width: max(4, geometry.size.width * ratio))
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
    }
}

private struct DashboardItemCard: View {
    let item: Item

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                    if item.isCompleted {
                        Text("item.completed_badge".localized)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.2), in: Capsule())
                    }
                }
                Text(item.vault?.name ?? "-")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.expiryDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let price = item.formattedPriceText {
                Text(price)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.gray.opacity(0.15), lineWidth: 1)
        )
    }
}

private enum DashboardDateFilterMode: String, CaseIterable, Identifiable {
    case none
    case year
    case month
    case monthYear

    var id: String { rawValue }
}

private struct DashboardFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: DashboardFilter

    @State private var draftPriceFilter: DashboardPriceFilter = .all
    @State private var draftPaidOnly = false
    @State private var dateMode: DashboardDateFilterMode = .none
    @State private var selectedYear = Calendar.current.component(.year, from: .now)
    @State private var selectedMonth = Calendar.current.component(.month, from: .now)

    private let years = Array((Calendar.current.component(.year, from: .now) - 5)...(Calendar.current.component(.year, from: .now) + 5))
    private let months = Array(1...12)

    var body: some View {
        Form {
            Section("dashboard.filter.price".localized) {
                Picker("dashboard.filter.price".localized, selection: $draftPriceFilter) {
                    Text("dashboard.filter.price.all".localized).tag(DashboardPriceFilter.all)
                    Text("dashboard.filter.price.priced".localized).tag(DashboardPriceFilter.pricedOnly)
                    Text("dashboard.filter.price.free".localized).tag(DashboardPriceFilter.freeOnly)
                }
            }

            Section("dashboard.filter.paid".localized) {
                Toggle("dashboard.filter.paid_only".localized, isOn: $draftPaidOnly)
            }

            Section("dashboard.filter.date".localized) {
                Picker("dashboard.filter.date_mode".localized, selection: $dateMode) {
                    Text("dashboard.filter.date.none".localized).tag(DashboardDateFilterMode.none)
                    Text("dashboard.filter.date.year".localized).tag(DashboardDateFilterMode.year)
                    Text("dashboard.filter.date.month".localized).tag(DashboardDateFilterMode.month)
                    Text("dashboard.filter.date.month_year".localized).tag(DashboardDateFilterMode.monthYear)
                }

                if dateMode == .year || dateMode == .monthYear {
                    Picker("dashboard.filter.year".localized, selection: $selectedYear) {
                        ForEach(years, id: \.self) { year in
                            Text("\(year)").tag(year)
                        }
                    }
                }

                if dateMode == .month || dateMode == .monthYear {
                    Picker("dashboard.filter.month".localized, selection: $selectedMonth) {
                        ForEach(months, id: \.self) { month in
                            Text(monthName(month)).tag(month)
                        }
                    }
                }
            }
        }
        .navigationTitle("dashboard.filter.title".localized)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.close".localized) { dismiss() }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button("dashboard.filter.reset".localized) {
                    draftPriceFilter = .all
                    draftPaidOnly = false
                    dateMode = .none
                    selectedYear = Calendar.current.component(.year, from: .now)
                    selectedMonth = Calendar.current.component(.month, from: .now)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("dashboard.filter.apply".localized) {
                    filter = buildFilter()
                    dismiss()
                }
            }
        }
        .onAppear {
            draftPriceFilter = filter.priceFilter
            draftPaidOnly = filter.paidOnly
            switch filter.dateFilter {
            case .none:
                dateMode = .none
            case .year(let year):
                dateMode = .year
                selectedYear = year
            case .month(let month):
                dateMode = .month
                selectedMonth = month
            case .monthYear(let month, let year):
                dateMode = .monthYear
                selectedMonth = month
                selectedYear = year
            }
        }
    }

    private func buildFilter() -> DashboardFilter {
        let dateFilter: DashboardDateFilter
        switch dateMode {
        case .none:
            dateFilter = .none
        case .year:
            dateFilter = .year(selectedYear)
        case .month:
            dateFilter = .month(selectedMonth)
        case .monthYear:
            dateFilter = .monthYear(month: selectedMonth, year: selectedYear)
        }

        return DashboardFilter(priceFilter: draftPriceFilter, paidOnly: draftPaidOnly, dateFilter: dateFilter)
    }

    private func monthName(_ month: Int) -> String {
        let dateFormatter = DateFormatter()
        let name = dateFormatter.monthSymbols[max(0, min(11, month - 1))]
        return name.capitalized
    }
}
