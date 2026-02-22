import Foundation

struct ReminderScheduler {
    static func reminderDates(expiryDate: Date, reminderDays: [Int], calendar: Calendar = .current) -> [Date] {
        reminderDays
            .filter { $0 >= 0 }
            .removingDuplicates()
            .compactMap { days in calendar.date(byAdding: .day, value: -days, to: expiryDate) }
            .sorted()
    }

    static func bucket(for item: Item, now: Date = .now, calendar: Calendar = .current) -> ItemBucket {
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: item.expiryDate)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        if days < 0 { return .expired }
        if days <= 30 { return .soon }
        return .later
    }
}

enum ItemBucket: String {
    case soon, later, expired
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
