import Foundation

struct FreedShares: Equatable {
    var loanShare: Decimal
    var investShare: Decimal

    static let none = FreedShares(loanShare: 0, investShare: 0)
    static let allToInvesting = FreedShares(loanShare: 0, investShare: 1)

    init(loanShare: Decimal, investShare: Decimal) {
        self.loanShare = loanShare
        self.investShare = investShare
    }

    init(_ split: FreedMoneySplit) {
        self.init(loanShare: split.loanShare, investShare: split.investShare)
    }

    /// Splits `amount` into loan and investing portions. Rounding stays inside the original amount.
    func allocate(_ amount: Decimal) -> (loans: Decimal, investing: Decimal) {
        let amount = Cents.round(max(amount, 0))
        guard amount > 0 else { return (0, 0) }
        let loanShare = min(max(self.loanShare, 0), 1)
        let toLoans = Cents.round(amount * loanShare)
        let rest = amount - toLoans
        let investWeight = 1 - loanShare
        guard investWeight > 0, investShare > 0 else { return (toLoans, 0) }
        let toInvest = Cents.round(rest * min(max(investShare, 0), 1) / investWeight)
        return (toLoans, min(toInvest, rest))
    }
}

enum FreedMoney {
    static func suggestedShares(from budget: Budget) -> FreedShares {
        let eligible = budget.categories.filter { category in
            guard category.amount > 0 else { return false }
            switch category.role {
            case .needs:
                return false
            case .emergencyFund:
                return !budget.emergencyFundIsFull
            case .extraLoanPayment, .investing, .other:
                return true
            }
        }
        let total = eligible.reduce(Decimal(0)) { $0 + $1.amount }
        guard total > 0 else { return .allToInvesting }
        let loans = eligible
            .filter { $0.role == .extraLoanPayment }
            .reduce(Decimal(0)) { $0 + $1.amount }
        let investing = eligible
            .filter { $0.role == .investing }
            .reduce(Decimal(0)) { $0 + $1.amount }
        return FreedShares(loanShare: loans / total, investShare: investing / total)
    }
}
