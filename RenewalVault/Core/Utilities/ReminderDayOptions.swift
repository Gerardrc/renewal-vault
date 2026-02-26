import Foundation

enum ReminderDayOptions {
    static let presets = [90, 60, 30, 14, 7, 1]

    static func normalized(_ days: [Int]) -> [Int] {
        Array(Set(days.filter { $0 >= 1 })).sorted(by: >)
    }

    static func availableDays(selected: [Int], customAvailable: [Int]) -> [Int] {
        normalized(presets + selected + customAvailable)
    }

    static func toggle(day: Int, selected: [Int]) -> [Int] {
        var values = Set(selected)
        if values.contains(day) { values.remove(day) } else { values.insert(day) }
        return Array(values).sorted(by: >)
    }

    static func parseCustom(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value >= 1 else { return nil }
        return value
    }
}
