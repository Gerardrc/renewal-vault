import Foundation
import EventKit

final class CalendarEventService {
    static let shared = CalendarEventService()
    private let store = EKEventStore()

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
    func addExpiryEvent(for item: Item) async throws {
        let granted = try await requestCalendarAccess()
        guard granted else { throw CalendarEventError.accessDenied }

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
