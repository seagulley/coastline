import Foundation

public enum TodayDollars {
    /// `nominal / (1 + inflation) ^ (monthIndex / 12)`. Month 0 is unchanged.
    public static func convert(nominal: Decimal, inflation: Decimal, monthIndex: Int) -> Decimal {
        let factor = inflationFactor(inflation: inflation, monthIndex: monthIndex)
        guard factor > 0 else { return Cents.round(nominal) }
        return Cents.round(nominal / factor)
    }

    public static func inflationFactor(inflation: Decimal, monthIndex: Int) -> Decimal {
        guard monthIndex > 0 else { return 1 }
        let base = 1 + inflation
        guard base > 0 else { return 0 }
        return Compounding.power(base, Decimal(monthIndex) / 12)
    }
}

public enum CoastFireMath {
    public static func realReturn(nominalAnnualReturn: Decimal, inflation: Decimal) -> Decimal {
        let denominator = 1 + inflation
        guard denominator != 0 else { return 0 }
        return (1 + nominalAnnualReturn) / denominator - 1
    }

    public static func fireNumber(yearlySpending: Decimal, withdrawalRate: Decimal) -> Decimal? {
        guard withdrawalRate > 0 else { return nil }
        return yearlySpending / withdrawalRate
    }

    /// Balance, in today's dollars, that reaches Coast FIRE with `yearsLeft` until retirement.
    public static func coastNumber(
        yearlySpending: Decimal,
        withdrawalRate: Decimal,
        nominalAnnualReturn: Decimal,
        inflation: Decimal,
        yearsLeft: Decimal
    ) -> Decimal? {
        guard let fire = fireNumber(yearlySpending: yearlySpending, withdrawalRate: withdrawalRate) else {
            return nil
        }
        let real = realReturn(nominalAnnualReturn: nominalAnnualReturn, inflation: inflation)
        let years = max(yearsLeft, 0)
        let base = 1 + real
        guard base > 0 else { return nil }
        let growth = Compounding.power(base, years)
        guard growth > 0 else { return nil }
        return fire / growth
    }

    public static func yearsLeft(goal: CoastFireGoal, monthIndex: Int) -> Decimal {
        let totalMonths = max(0, goal.retirementAge - goal.currentAge) * 12
        let remaining = max(0, totalMonths - monthIndex)
        return Decimal(remaining) / 12
    }
}

public enum Allocation {
    /// Splits `amount` into the extra loan payment and the investing amount. Rounding stays inside `amount`.
    public static func split(_ amount: Decimal, loanShare: Decimal) -> (loans: Decimal, investing: Decimal) {
        let amount = Cents.round(max(amount, 0))
        let loans = Cents.round(amount * min(max(loanShare, 0), 1))
        return (loans, amount - loans)
    }
}

public enum MinimumPayment {
    /// Standard amortizing payment from the current balance, nominal annual rate, and remaining term.
    public static func estimate(balance: Decimal, annualRate: Decimal, termMonths: Int) -> Decimal {
        guard termMonths > 0 else { return Cents.round(max(balance, 0)) }
        let principal = max(balance, 0)
        guard annualRate > 0 else {
            return Cents.round(principal / Decimal(termMonths))
        }
        let monthlyRate = annualRate / 12
        let growth = Compounding.power(1 + monthlyRate, Decimal(termMonths))
        guard growth > 1 else { return Cents.round(principal / Decimal(termMonths)) }
        return Cents.round(principal * monthlyRate * growth / (growth - 1))
    }
}
