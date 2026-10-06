import Foundation

public enum ProjectionScenario: String, Hashable, Sendable, CaseIterable {
    case good
    case typical
    case bad
}

public enum InterestMethod: Hashable, Sendable {
    /// `balance * annualRate * (daysInMonth / 365)`. Interest is applied once a month and does not compound inside the month.
    case dailyAccrualMonthlyApplication
    /// `balance * annualRate / 12`.
    case monthlyNominal
}

public enum LoanRate: Hashable, Sendable {
    /// Nominal annual rate. It does not change when prime changes.
    case fixed(annualRate: Decimal)
    /// Nominal annual rate is `prime + margin`. Margin may be negative.
    case floating(margin: Decimal)

    func annualRate(prime: Decimal) -> Decimal {
        switch self {
        case .fixed(let annualRate):
            return annualRate
        case .floating(let margin):
            return prime + margin
        }
    }
}

public enum FundType: Hashable, Sendable {
    case indexETF
    case mutualFund
}

public struct Loan: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var balance: Decimal
    /// Recorded for the loan. The MVP monthly step does not change interest or payments based on this flag.
    public var disbursedBeforeJuly2023: Bool
    public var rate: LoanRate
    public var interestStart: YearMonth
    /// Statement payment. When nil, the engine estimates a payment from `repaymentTermMonths`.
    public var minimumPayment: Decimal?
    /// Remaining term, in months. Used only when `minimumPayment` is nil.
    public var repaymentTermMonths: Int?
    public var interestMethod: InterestMethod

    public init(
        id: UUID = UUID(),
        balance: Decimal,
        disbursedBeforeJuly2023: Bool,
        rate: LoanRate,
        interestStart: YearMonth,
        minimumPayment: Decimal? = nil,
        repaymentTermMonths: Int? = nil,
        interestMethod: InterestMethod = .dailyAccrualMonthlyApplication
    ) {
        self.id = id
        self.balance = balance
        self.disbursedBeforeJuly2023 = disbursedBeforeJuly2023
        self.rate = rate
        self.interestStart = interestStart
        self.minimumPayment = minimumPayment
        self.repaymentTermMonths = repaymentTermMonths
        self.interestMethod = interestMethod
    }
}

public struct LumpSum: Hashable, Sendable {
    public var amount: Decimal
    public var month: YearMonth

    public init(amount: Decimal, month: YearMonth) {
        self.amount = amount
        self.month = month
    }
}

public struct Investments: Hashable, Sendable {
    public var balance: Decimal
    public var fundType: FundType

    public init(balance: Decimal, fundType: FundType) {
        self.balance = balance
        self.fundType = fundType
    }
}

public struct CoastFireGoal: Hashable, Sendable {
    public var currentAge: Int
    public var retirementAge: Int
    /// Today's dollars. It is not inflated inside the simulation.
    public var yearlySpending: Decimal
    public var withdrawalRate: Decimal

    public init(currentAge: Int, retirementAge: Int, yearlySpending: Decimal, withdrawalRate: Decimal) {
        self.currentAge = currentAge
        self.retirementAge = retirementAge
        self.yearlySpending = yearlySpending
        self.withdrawalRate = withdrawalRate
    }
}

public struct Assumptions: Hashable, Sendable {
    public var goodAnnualReturn: Decimal
    public var typicalAnnualReturn: Decimal
    public var badAnnualReturn: Decimal
    public var inflation: Decimal
    /// Held constant for the whole projection.
    public var primeRate: Decimal
    /// Annual fund fee, subtracted from the scenario return before monthly growth.
    public var annualFee: Decimal

    public init(
        goodAnnualReturn: Decimal = Assumptions.defaultGoodAnnualReturn,
        typicalAnnualReturn: Decimal = Assumptions.defaultTypicalAnnualReturn,
        badAnnualReturn: Decimal = Assumptions.defaultBadAnnualReturn,
        inflation: Decimal,
        primeRate: Decimal,
        annualFee: Decimal = 0
    ) {
        self.goodAnnualReturn = goodAnnualReturn
        self.typicalAnnualReturn = typicalAnnualReturn
        self.badAnnualReturn = badAnnualReturn
        self.inflation = inflation
        self.primeRate = primeRate
        self.annualFee = annualFee
    }

    /// Bad, typical, and good nominal annual returns before fees: 3%, 6.5%, and 10%.
    public static let defaultBadAnnualReturn = Decimal(3) / Decimal(100)
    public static let defaultTypicalAnnualReturn = Decimal(65) / Decimal(1000)
    public static let defaultGoodAnnualReturn = Decimal(10) / Decimal(100)

    func annualReturn(for scenario: ProjectionScenario) -> Decimal {
        switch scenario {
        case .good:
            return goodAnnualReturn
        case .typical:
            return typicalAnnualReturn
        case .bad:
            return badAnnualReturn
        }
    }
}

public struct BudgetCategory: Hashable, Sendable {
    public enum Role: Hashable, Sendable {
        case needs
        case emergencyFund
        case extraLoanPayment
        case investing
        case other
    }

    public var amount: Decimal
    public var role: Role

    public init(amount: Decimal, role: Role) {
        self.amount = amount
        self.role = role
    }
}

public struct Budget: Hashable, Sendable {
    public var categories: [BudgetCategory]
    public var emergencyFundIsFull: Bool

    public init(categories: [BudgetCategory] = [], emergencyFundIsFull: Bool = true) {
        self.categories = categories
        self.emergencyFundIsFull = emergencyFundIsFull
    }
}

/// Everything one projection needs. A screen fills this in and reads `ProjectionResult`.
public struct ProjectionInput: Hashable, Sendable {
    public var start: YearMonth
    public var loans: [Loan]
    /// Money allocated between extra loan payments and investing. Minimum payments are paid in addition to this amount.
    public var monthlyAmount: Decimal
    /// When true, the investing slice of `monthlyAmount` rises with inflation. Loan payments stay flat.
    public var contributionsGrowWithInflation: Bool
    public var lumpSums: [LumpSum]
    /// Fraction of `monthlyAmount` and of each lump sum that goes to extra loan payments. The rest is invested.
    public var loanShare: Decimal
    public var investments: Investments
    public var goal: CoastFireGoal
    public var assumptions: Assumptions
    public var scenario: ProjectionScenario
    /// Current budget, used only to split a loan payment once that loan is paid off.
    public var budget: Budget

    public init(
        start: YearMonth,
        loans: [Loan],
        monthlyAmount: Decimal,
        contributionsGrowWithInflation: Bool = true,
        lumpSums: [LumpSum] = [],
        loanShare: Decimal,
        investments: Investments,
        goal: CoastFireGoal,
        assumptions: Assumptions,
        scenario: ProjectionScenario,
        budget: Budget = Budget()
    ) {
        self.start = start
        self.loans = loans
        self.monthlyAmount = monthlyAmount
        self.contributionsGrowWithInflation = contributionsGrowWithInflation
        self.lumpSums = lumpSums
        self.loanShare = loanShare
        self.investments = investments
        self.goal = goal
        self.assumptions = assumptions
        self.scenario = scenario
        self.budget = budget
    }
}
