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

    /// A yearly rate such as a fee or a return, e.g. "0.20%" or "6.5%".
    static func rate(_ rate: Decimal, minimumFractionDigits: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = max(2, minimumFractionDigits)
        formatter.locale = Locale(identifier: "en_CA")
        return formatter.string(from: NSDecimalNumber(decimal: rate))
            ?? NSDecimalNumber(decimal: rate).stringValue
    }

    static func monthAndYear(_ date: CalendarDate) -> String {
        format(date, as: "MMMM yyyy")
    }

    static func monthAndYear(_ month: YearMonth) -> String {
        monthAndYear(CalendarDate(year: month.year, month: month.month, day: 1))
    }

    /// "about 7 years" from the engine's whole-month count. Under a year it counts months.
    static func timeAway(months: Int) -> String {
        if months <= 0 {
            return "Reached now"
        }
        if months < 12 {
            return months == 1 ? "about 1 month away" : "about \(months) months away"
        }
        let years = (Double(months) / 12).rounded()
        return years == 1 ? "about 1 year away" : "about \(Int(years)) years away"
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
