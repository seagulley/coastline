import Foundation

public enum BreakEven {
    /// The yearly market return, before fees, below which an extra dollar does better paying a loan than invested.
    ///
    /// Extra money pays the highest-rate loan first, so the comparison is with that loan: its rate compounded the way
    /// the monthly step charges interest over the 12 months from `input.start`, plus the fee, which investing pays and
    /// the loan does not. Nil when no loan has a balance.
    public static func annualReturn(_ input: ProjectionInput) -> Decimal? {
        let prime = input.assumptions.primeRate
        let first = input.loans.enumerated()
            .filter { $0.element.balance > 0 }
            .min { left, right in
                let leftRate = left.element.rate.annualRate(prime: prime)
                let rightRate = right.element.rate.annualRate(prime: prime)
                if leftRate != rightRate {
                    return leftRate > rightRate
                }
                return left.offset < right.offset
            }
        guard let loan = first?.element else { return nil }
        let rate = loan.rate.annualRate(prime: prime)
        var growth: Decimal = 1
        for offset in 0..<12 {
            switch loan.interestMethod {
            case .dailyAccrualMonthlyApplication:
                growth *= 1 + rate * Decimal(input.start.adding(months: offset).days) / 365
            case .monthlyNominal:
                growth *= 1 + rate / 12
            }
        }
        return growth - 1 + input.annualFee
    }
}
