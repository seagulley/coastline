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

/// What one loan received in a month, in nominal dollars.
public struct LoanPayment: Hashable, Sendable {
    public var id: UUID
    /// The minimum payment, or the balance due when that is smaller.
    public var minimum: Decimal
    /// From the loan slice of the monthly amount and from freed payments, paid highest rate first.
    public var extra: Decimal

    public init(id: UUID, minimum: Decimal, extra: Decimal) {
        self.id = id
        self.minimum = minimum
        self.extra = extra
    }

    public var total: Decimal {
        Cents.round(minimum + extra)
    }
}

/// An amount sent to one loan, in nominal dollars.
public struct LoanAmount: Hashable, Sendable {
    public var id: UUID
    public var amount: Decimal

    public init(id: UUID, amount: Decimal) {
        self.id = id
        self.amount = amount
    }
}

/// Where one lump sum went in its month, in nominal dollars.
public struct LumpSumPayment: Hashable, Sendable {
    public var id: UUID
    /// The loan slice, paid highest rate first after the month's regular payments.
    public var loans: [LoanAmount]
    /// The investing slice, plus any loan slice left once no loan has a balance.
    public var invested: Decimal

    public init(id: UUID, loans: [LoanAmount], invested: Decimal) {
        self.id = id
        self.loans = loans
        self.invested = invested
    }
}

/// Where one month's money went, in nominal dollars. Month 0 has no payments.
public struct MonthPayments: Hashable, Sendable {
    /// Loans that received money this month, in input order.
    public var loans: [LoanPayment]
    /// Added to investments from the monthly amount, freed payments, and loan money left once no loan has a balance.
    /// Lump sums are counted in `lumpSums` instead.
    public var invested: Decimal
    public var lumpSums: [LumpSumPayment]

    public init(loans: [LoanPayment], invested: Decimal, lumpSums: [LumpSumPayment]) {
        self.loans = loans
        self.invested = invested
        self.lumpSums = lumpSums
    }

    public static let none = MonthPayments(loans: [], invested: 0, lumpSums: [])
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
    public var payments: MonthPayments

    public init(
        monthIndex: Int,
        month: YearMonth,
        nominal: MonthFigures,
        today: MonthFigures,
        interestAccrued: Decimal,
        payments: MonthPayments = .none
    ) {
        self.monthIndex = monthIndex
        self.month = month
        self.nominal = nominal
        self.today = today
        self.interestAccrued = interestAccrued
        self.payments = payments
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
