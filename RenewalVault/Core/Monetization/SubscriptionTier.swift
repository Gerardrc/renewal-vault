import Foundation

enum SubscriptionTier {
    case free
    case pro
}

struct FeatureGate {
    static func canCreateVault(currentCount: Int, tier: SubscriptionTier) -> Bool {
        tier == .pro || currentCount < 1
    }

    static func canCreateItem(currentCount: Int, tier: SubscriptionTier) -> Bool {
        tier == .pro || currentCount < 5
    }

    static func canAddAttachment(currentCount: Int, tier: SubscriptionTier) -> Bool {
        tier == .pro || currentCount < 3
    }

    static func canExportPDF(tier: SubscriptionTier) -> Bool {
        tier == .pro
    }

    static func canAccessDashboard(tier: SubscriptionTier) -> Bool {
        tier == .pro
    }
}


enum ProUpgradeAction: String, CaseIterable {
    case close
    case goPro

    static var vaultCreationActions: [ProUpgradeAction] {
        [.close, .goPro]
    }
}
