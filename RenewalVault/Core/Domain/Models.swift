import Foundation
import SwiftData

@Model
final class Vault {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var isSystemDefault: Bool
    @Relationship(deleteRule: .cascade, inverse: \Item.vault) var items: [Item] = []

    init(id: UUID = UUID(), name: String, createdAt: Date = .now, updatedAt: Date = .now, isSystemDefault: Bool = false) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSystemDefault = isSystemDefault
    }
}

@Model
final class Item {
    @Attribute(.unique) var id: UUID
    var title: String
    var category: String
    var issuer: String?
    var expiryDate: Date
    var reminderScheduleDays: [Int]
    var repeatAfterRenewal: Bool
    var isCompleted: Bool
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var scheduledNotificationIdentifiers: [String]

    var vault: Vault?
    @Relationship(deleteRule: .cascade, inverse: \Attachment.item) var attachments: [Attachment] = []
    @Relationship(deleteRule: .cascade, inverse: \RenewalEvent.item) var renewalEvents: [RenewalEvent] = []

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        issuer: String? = nil,
        expiryDate: Date,
        reminderScheduleDays: [Int] = [30, 14, 7, 1],
        repeatAfterRenewal: Bool = true,
        isCompleted: Bool = false,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        scheduledNotificationIdentifiers: [String] = [],
        vault: Vault? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.issuer = issuer
        self.expiryDate = expiryDate
        self.reminderScheduleDays = reminderScheduleDays
        self.repeatAfterRenewal = repeatAfterRenewal
        self.isCompleted = isCompleted
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.scheduledNotificationIdentifiers = scheduledNotificationIdentifiers
        self.vault = vault
    }
}

@Model
final class Attachment {
    @Attribute(.unique) var id: UUID
    var kind: String
    var filename: String
    var localPath: String
    var createdAt: Date
    var item: Item?

    init(id: UUID = UUID(), kind: String, filename: String, localPath: String, createdAt: Date = .now, item: Item? = nil) {
        self.id = id
        self.kind = kind
        self.filename = filename
        self.localPath = localPath
        self.createdAt = createdAt
        self.item = item
    }
}

@Model
final class RenewalEvent {
    @Attribute(.unique) var id: UUID
    var renewedAt: Date
    var previousExpiryDate: Date
    var newExpiryDate: Date
    var item: Item?

    init(id: UUID = UUID(), renewedAt: Date = .now, previousExpiryDate: Date, newExpiryDate: Date, item: Item? = nil) {
        self.id = id
        self.renewedAt = renewedAt
        self.previousExpiryDate = previousExpiryDate
        self.newExpiryDate = newExpiryDate
        self.item = item
    }
}

@Model
final class AppPreference {
    @Attribute(.unique) var key: String
    var value: String

    init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

enum ItemCategory: String, CaseIterable, Identifiable {
    case passport, nationalID, driversLicense, carInsurance, lease, healthInsurance, subscription, other
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .passport: "globe"
        case .nationalID: "person.text.rectangle"
        case .driversLicense: "car"
        case .carInsurance: "shield.lefthalf.filled"
        case .lease: "house"
        case .healthInsurance: "heart.text.square"
        case .subscription: "creditcard"
        case .other: "doc"
        }
    }
}


extension Item {
    func markNoRenewal() {
        repeatAfterRenewal = false
        isCompleted = true
        updatedAt = .now
    }

    func reactivate() {
        isCompleted = false
        repeatAfterRenewal = true
        updatedAt = .now
    }
}


extension Vault {
    var isProtectedDefault: Bool {
        isSystemDefault || name.caseInsensitiveCompare("Personal") == .orderedSame
    }
}
