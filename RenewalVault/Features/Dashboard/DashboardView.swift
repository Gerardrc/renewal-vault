import SwiftUI
import SwiftData

struct DashboardView: View {
    @EnvironmentObject private var entitlement: EntitlementService
    @Query(sort: \Item.expiryDate) private var items: [Item]
    @State private var showPaywall = false

    private var summary: DashboardSummary {
        DashboardCalculator.summary(items: items)
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
        .sheet(isPresented: $showPaywall) {
            NavigationStack { PaywallView() }
        }
    }

    private var proDashboardContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    DashboardSummaryCard(title: "dashboard.summary.year".localized, totals: summary.yearToPayTotals)
                    DashboardSummaryCard(title: "dashboard.summary.next_month".localized, totals: summary.nextMonthToPayTotals)
                    DashboardSummaryCard(title: "dashboard.summary.paid".localized, totals: summary.paidTotals)
                }

                if hasMultiCurrency {
                    Text("dashboard.multi_currency_notice".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if summary.upcomingMonthGroups.isEmpty {
                    Text("dashboard.empty".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(summary.upcomingMonthGroups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.monthStart.formatted(.dateTime.month(.wide).year()))
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.gray.opacity(0.18), lineWidth: 1)
        )
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
