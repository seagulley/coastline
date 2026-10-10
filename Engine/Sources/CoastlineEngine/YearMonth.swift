import Foundation

/// A calendar month. Projections step one of these at a time.
public struct YearMonth: Hashable, Comparable, Sendable {
    public var year: Int
    /// 1 through 12.
    public var month: Int

    public init(year: Int, month: Int) {
        precondition((1...12).contains(month), "Month must be 1...12")
        self.year = year
        self.month = month
    }

    public static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        lhs.year == rhs.year ? lhs.month < rhs.month : lhs.year < rhs.year
    }

    public func adding(months delta: Int) -> YearMonth {
        let total = year * 12 + (month - 1) + delta
        var year = total / 12
        var month = total % 12
        if month < 0 {
            month += 12
            year -= 1
        }
        return YearMonth(year: year, month: month + 1)
    }

    /// Whole months from `other` to this month. Negative when `other` is later.
    public func months(since other: YearMonth) -> Int {
        (year * 12 + month) - (other.year * 12 + other.month)
    }

    /// Gregorian length of this month. Leap-year February has 29 days.
    public var days: Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12:
            return 31
        case 4, 6, 9, 11:
            return 30
        case 2:
            return isLeapYear ? 29 : 28
        default:
            return 30
        }
    }

    private var isLeapYear: Bool {
        if year % 400 == 0 { return true }
        if year % 100 == 0 { return false }
        return year % 4 == 0
    }
}
