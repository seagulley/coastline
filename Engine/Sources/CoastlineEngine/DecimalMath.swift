import Foundation

enum Cents {
    /// Nearest cent. Halfway cases round away from zero.
    static func round(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, 2, .plain)
        return result
    }
}

enum Compounding {
    /// `base ^ exponent`. Non-positive bases return 0, except `x^0 = 1`.
    static func power(_ base: Decimal, _ exponent: Decimal) -> Decimal {
        if exponent == 0 { return 1 }
        let baseDouble = (base as NSDecimalNumber).doubleValue
        let exponentDouble = (exponent as NSDecimalNumber).doubleValue
        guard baseDouble > 0, baseDouble.isFinite, exponentDouble.isFinite else { return 0 }
        let value = pow(baseDouble, exponentDouble)
        guard value.isFinite else { return 0 }
        return Decimal(value)
    }
}
