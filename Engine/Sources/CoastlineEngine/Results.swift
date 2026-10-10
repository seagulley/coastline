import Foundation

public struct LoanBalance: Hashable, Sendable {
    public var id: UUID
    public var balance: Decimal

    public init(id: UUID, balance: Decimal) {
        self.id = id
        self.balance = balance
    }
}

public struct MonthFigures: Hashable, Sendable {
    public var loans: [LoanBalance]
    public var investments: Decimal
    public var netWorth: Decimal
    public var cumulativeInterest: Decimal

    public init(loans: [LoanBalance], investments: Decimal, netWorth: Decimal, cumulativeInterest: Decimal) {
        self.loans = loans
        self.investments = investments
        self.netWorth = netWorth
        self.cumulativeInterest = cumulativeInterest
    }

    public func balance(for id: UUID) -> Decimal? {
        loans.first { $0.id == id }?.balance
    }
}

public struct MonthSnapshot: Hashable, Sendable {
    /// 0 is the start of the projection. Each later index is the end of one simulated month.
    public var monthIndex: Int
    public var month: YearMonth
    public var nominal: MonthFigures
    /// Nominal figures converted with `todayDollars = nominal / (1 + inflation) ^ (monthIndex / 12)`.
    public var today: MonthFigures
    /// Interest accrued this month, in nominal dollars. Month 0 is zero.
    public var interestAccrued: Decimal

    public init(
        monthIndex: Int,
        month: YearMonth,
        nominal: MonthFigures,
        today: MonthFigures,
        interestAccrued: Decimal
    ) {
        self.monthIndex = monthIndex
        self.month = month
        self.nominal = nominal
        self.today = today
        self.interestAccrued = interestAccrued
    }
}

public struct LoanPayoff: Hashable, Sendable {
    public var id: UUID
    public var month: YearMonth
    /// The loan's monthly minimum payment, which is free once the loan is repaid. The statement amount, or the
    /// estimate from the repayment term. Payments are flat, so this is the nominal amount due in `month`.
    public var payment: Decimal

    public init(id: UUID, month: YearMonth, payment: Decimal) {
        self.id = id
        self.month = month
        self.payment = payment
    }
}

/// Share of a freed loan payment that the projection sends to loans and to investing.
/// The rest follows other budget categories and leaves the projection.
public struct FreedMoneySplit: Hashable, Sendable {
    public var loanShare: Decimal
    public var investShare: Decimal

    public init(loanShare: Decimal, investShare: Decimal) {
        self.loanShare = loanShare
        self.investShare = investShare
    }
}

public struct ProjectionResult: Hashable, Sendable {
    public var scenario: ProjectionScenario
    public var annualReturn: Decimal
    /// Month 0, then one snapshot per simulated month through retirement.
    public var months: [MonthSnapshot]
    /// First month the invested balance, in today's dollars, reaches the Coast FIRE number.
    /// Each freed loan payment follows the user's answer for that loan, or the suggested split until the user answers.
    public var coastFireDate: YearMonth?
    /// Same projection, except every freed loan payment is invested. Informational.
    public var coastFireDateIfFreedMoneyInvested: YearMonth?
    /// Month the last remaining loan reaches zero.
    public var loanPayoffDate: YearMonth?
    public var loanPayoffs: [LoanPayoff]
    /// Sum of each month's interest, converted to today's dollars in that month.
    public var totalInterestPaid: Decimal
    public var suggestedFreedMoneySplit: FreedMoneySplit

    public init(
        scenario: ProjectionScenario,
        annualReturn: Decimal,
        months: [MonthSnapshot],
        coastFireDate: YearMonth?,
        coastFireDateIfFreedMoneyInvested: YearMonth?,
        loanPayoffDate: YearMonth?,
        loanPayoffs: [LoanPayoff],
        totalInterestPaid: Decimal,
        suggestedFreedMoneySplit: FreedMoneySplit
    ) {
        self.scenario = scenario
        self.annualReturn = annualReturn
        self.months = months
        self.coastFireDate = coastFireDate
        self.coastFireDateIfFreedMoneyInvested = coastFireDateIfFreedMoneyInvested
        self.loanPayoffDate = loanPayoffDate
        self.loanPayoffs = loanPayoffs
        self.totalInterestPaid = totalInterestPaid
        self.suggestedFreedMoneySplit = suggestedFreedMoneySplit
    }

    public func snapshot(at monthIndex: Int) -> MonthSnapshot? {
        months.first { $0.monthIndex == monthIndex }
    }
}
