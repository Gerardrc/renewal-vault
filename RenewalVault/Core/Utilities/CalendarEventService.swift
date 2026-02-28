import Foundation
import EventKit

final class CalendarEventService {
    static let shared = CalendarEventService()
    private let store = EKEventStore()

    @MainActor
    func requestCalendarAccessIfNeeded() async throws -> Bool {
        let status = Self.authorizationStatus()
        switch status {
        case .fullAccess, .writeOnly, .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return try await requestCalendarAccess()
        @unknown default:
            return false
        }
    }

    @MainActor
    func requestCalendarAccess() async throws -> Bool {
        if #available(iOS 17.0, *) {
            return try await store.requestFullAccessToEvents()
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                store.requestAccess(to: .event) { ok, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ok)
                    }
                }
            }
        }
    }
    
    @MainActor
    func prepareEditorEvent(for item: Item) -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.title = Self.titleText(for: item)
        event.notes = Self.notesText(for: item)

        let start = Self.defaultStartDate(for: item.expiryDate)
        event.startDate = start
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: start)
        event.calendar = store.defaultCalendarForNewEvents
        return event
    }

    static func authorizationStatus() -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    func eventStore() -> EKEventStore {
        store
    }

    @MainActor
    func prepareExpiryEvent(for item: Item) async throws -> EKEvent {
        let granted = try await requestCalendarAccessIfNeeded()
        guard granted else { throw CalendarEventError.accessDenied }

        let event = EKEvent(eventStore: store)
        event.title = Self.titleText(for: item)
        event.notes = Self.notesText(for: item)

        let start = Self.defaultStartDate(for: item.expiryDate)
        event.startDate = start
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: start)
        event.calendar = store.defaultCalendarForNewEvents
        return event
    }
    

    static func titleText(for item: Item) -> String {
        if let price = item.formattedPriceText {
            return "\(item.title) (\(price))"
        }
        return item.title
    }

    static func defaultStartDate(for expiryDate: Date) -> Date {
        let base = Calendar.current.startOfDay(for: expiryDate)
        return Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: base) ?? base
    }

    static func notesText(for item: Item) -> String {
        [
            item.vault.map { "\("item.vault".localized): \($0.name)" } ?? "",
            "\("item.category".localized): \("category.\(item.category)".localized)",
            item.issuer.map { "\("item.issuer".localized): \($0)" } ?? "",
            item.notes.isEmpty ? "" : item.notes
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }
}

enum CalendarEventError: LocalizedError {
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .accessDenied: return "calendar.access_denied".localized
        }
    }
}
