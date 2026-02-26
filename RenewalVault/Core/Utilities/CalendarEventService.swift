import Foundation
import EventKit

struct CalendarEventService {
    static let shared = CalendarEventService()

    func addExpiryEvent(for item: Item) async throws {
        let store = EKEventStore()
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = try await store.requestFullAccessToEvents()
        } else {
            granted = try await withCheckedThrowingContinuation { continuation in
                store.requestAccess(to: .event) { ok, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ok)
                    }
                }
            }
        }

        guard granted else {
            throw CalendarEventError.accessDenied
        }

        let event = EKEvent(eventStore: store)
        event.title = item.title
        event.notes = [
            "\("item.category".localized): \("category.\(item.category)".localized)",
            item.issuer.map { "\("item.issuer".localized): \($0)" } ?? "",
            item.notes.isEmpty ? "" : item.notes
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")

        let start = Calendar.current.startOfDay(for: item.expiryDate)
        event.startDate = start
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: start)
        event.calendar = store.defaultCalendarForNewEvents

        try store.save(event, span: .thisEvent, commit: true)
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
