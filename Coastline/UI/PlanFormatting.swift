import Foundation

/// Turns engine and plan values into text. This is display formatting, not a calculation.
enum PlanFormatting {
    static func currency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CAD"
        formatter.locale = Locale(identifier: "en_CA")
        return formatter.string(from: NSDecimalNumber(decimal: value))
            ?? NSDecimalNumber(decimal: value).stringValue
    }

    static func percent(_ share: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_CA")
        return formatter.string(from: NSDecimalNumber(decimal: share))
            ?? NSDecimalNumber(decimal: share).stringValue
    }

    static func monthAndYear(_ date: CalendarDate) -> String {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = date.year
        components.month = date.month
        components.day = date.day
        guard let day = components.date else {
            return "\(date.year)-\(date.month)-\(date.day)"
        }
        let formatter = DateFormatter()
        formatter.calendar = components.calendar
        formatter.locale = Locale(identifier: "en_CA")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: day)
    }
}
