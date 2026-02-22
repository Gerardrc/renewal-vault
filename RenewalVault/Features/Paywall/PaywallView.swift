import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var entitlement: EntitlementService
    @Environment(\.dismiss) private var dismiss
    @State private var products: [Product] = []

    var body: some View {
        NavigationStack {
            List {
                Section("paywall.title".localized) {
                    Text("paywall.features".localized)
                }
                ForEach(products, id: \.id) { product in
                    Button("\(product.displayName) - \(product.displayPrice)") {
                        Task { try? await entitlement.purchase(product: product); dismiss() }
                    }
                }
            }
            .task {
                products = (try? await Product.products(for: entitlement.productIDs)) ?? []
            }
        }
    }
}
