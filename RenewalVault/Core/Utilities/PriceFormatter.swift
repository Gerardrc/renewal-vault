import Foundation

enum CurrencySymbol: String, CaseIterable, Identifiable {
    case euro = "€"
    case dollar = "$"
    case yen = "¥"
    case pound = "£"

    var id: String { rawValue }
}

enum PriceFormatter {
    static func text(amount: Double?, currency: String?) -> String? {
        guard let amount, amount >= 0 else { return nil }
        let resolvedCurrency = (currency?.isEmpty == false ? currency : CurrencySymbol.euro.rawValue) ?? CurrencySymbol.euro.rawValue
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let amountText = formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
        return "\(resolvedCurrency)\(amountText)"
    }

    static func parseAmount(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }
}
