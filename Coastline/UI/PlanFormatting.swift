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

    /// Whole dollars, for amounts shown side by side.
    static func wholeCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CAD"
        formatter.locale = Locale(identifier: "en_CA")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: value))
            ?? NSDecimalNumber(decimal: value).stringValue
    }

    /// An annual rate such as 6.5% or 0.2%.
    static func rate(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
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
        format(date, as: "MMMM yyyy")
    }

    /// "Nov 2033", for narrow table columns.
    static func shortMonthAndYear(_ date: CalendarDate) -> String {
        format(date, as: "MMM yyyy")
    }

    /// The first day of `month`, for chart axes and date pickers.
    static func firstDay(of month: YearMonth) -> Date? {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: month.year, month: month.month, day: 1))
    }

    private static func format(_ date: CalendarDate, as dateFormat: String) -> String {
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
        formatter.dateFormat = dateFormat
        return formatter.string(from: day)
    }
}
