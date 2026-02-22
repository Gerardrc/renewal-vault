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
}
