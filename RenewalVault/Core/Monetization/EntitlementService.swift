import Foundation
import StoreKit

@MainActor
final class EntitlementService: ObservableObject {
    @Published var isPro: Bool = false
    #if DEBUG
    @Published var debugForcePro: Bool = false
    #endif

    let productIDs = ["com.renewalvault.pro.monthly", "com.renewalvault.pro.yearly"]

    func observeEntitlements() async {
        await refreshEntitlements()
        for await _ in Transaction.updates {
            await refreshEntitlements()
        }
    }

    func refreshEntitlements() async {
        var hasPro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, productIDs.contains(transaction.productID) {
                hasPro = true
            }
        }
        #if DEBUG
        isPro = hasPro || debugForcePro
        #else
        isPro = hasPro
        #endif
    }

    func purchase(product: Product) async throws {
        let result = try await product.purchase()
        if case .success(let verification) = result, case .verified(let transaction) = verification {
            await transaction.finish()
            await refreshEntitlements()
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }
}
