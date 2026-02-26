import Foundation
import UserNotifications
import UIKit

struct NotificationService {
    static let shared = NotificationService()

    func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        Task { @MainActor in
            UIApplication.shared.open(url)
        }
    }

    func cancelNotifications(for item: Item) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: item.scheduledNotificationIdentifiers)
        item.scheduledNotificationIdentifiers = []
    }

    func reschedule(item: Item) async {
        cancelNotifications(for: item)
        guard !item.isCompleted else { return }

        let center = UNUserNotificationCenter.current()
        let dates = ReminderScheduler.reminderDates(expiryDate: item.expiryDate, reminderDays: item.reminderScheduleDays)
        for (index, date) in dates.enumerated() {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
            components.hour = 9
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let content = UNMutableNotificationContent()
            content.title = "notification.title".localized
            let days = Calendar.current.dateComponents([.day], from: .now, to: item.expiryDate).day ?? 0
            content.body = days < 0 ? "notification.expired".localized : String(format: "notification.expires_in".localized, item.title, max(days, 0))
            let id = "item-\(item.id)-\(index)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try? await center.add(request)
            item.scheduledNotificationIdentifiers.append(id)
        }
    }
}
