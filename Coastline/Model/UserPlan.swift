import Foundation

/// Everything the app keeps for one person: inputs, assumptions, and an explicit choice.
/// Projections are not stored. The engine computes them from this plan.
struct UserPlan: Codable, Equatable, Sendable {
    var loans: [Loan]
    var money: MoneyToAllocate
    var split: AllocationSplit
    var investments: Investments
    var goal: CoastFireGoal
    var assumptions: Assumptions
    /// Set only after the user picks a split. Nil while a projection is still a suggestion.
    var chosenPlan: ChosenPlan?
    /// Current budget proportions. Used when a loan payoff frees a payment.
    var budget: PlanBudget

    static let empty = UserPlan(
        loans: [],
        money: MoneyToAllocate(monthlyAmount: nil, lumpSums: []),
        split: AllocationSplit(loanShare: nil),
        investments: Investments(balance: nil, fundType: nil),
        goal: CoastFireGoal(
            currentAge: nil,
            retirementAge: nil,
            yearlyRetirementSpending: nil,
            withdrawalRate: nil
        ),
        assumptions: .defaults,
        chosenPlan: nil,
        budget: .empty
    )

    /// Enough of a plan for the engine to return good, typical, and bad scenarios
    /// before Setup exists. It is saved only when the user chooses to save it, and it is not a product default.
    static let starter = UserPlan(
        loans: [
            Loan(
                id: UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!,
                balance: planDecimal("8000"),
                disbursement: .afterJuly12023,
                rate: .fixed(annualRate: planDecimal("0.05")),
                interestStart: CalendarDate(year: 2026, month: 1, day: 1),
                minimumPayment: planDecimal("150"),
                repaymentTermMonths: nil,
                interestMethod: .dailyAccrualMonthlyApplication
            )
        ],
        money: MoneyToAllocate(monthlyAmount: planDecimal("2000"), lumpSums: []),
        split: AllocationSplit(loanShare: 0),
        investments: Investments(balance: planDecimal("15000"), fundType: .indexETF),
        goal: CoastFireGoal(
            currentAge: 35,
            retirementAge: 65,
            yearlyRetirementSpending: planDecimal("24000"),
            withdrawalRate: planDecimal("0.04")
        ),
        assumptions: Assumptions(
            badAnnualReturn: planDecimal("0.03"),
            typicalAnnualReturn: planDecimal("0.065"),
            goodAnnualReturn: planDecimal("0.10"),
            inflation: planDecimal("0.02"),
            primeRate: planDecimal("0.045"),
            annualFee: planDecimal("0.002"),
            riskToleranceMonths: 12,
            contributionsRiseWithInflation: true
        ),
        chosenPlan: nil,
        budget: .empty
    )
}

struct Loan: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var balance: Decimal
    /// Disbursed before or after July 1, 2023.
    var disbursement: Disbursement
    var rate: LoanRate
    var interestStart: CalendarDate?
    /// From a statement, when the user has one.
    var minimumPayment: Decimal?
    /// Used to estimate the minimum payment until a statement amount is entered.
    var repaymentTermMonths: Int?
    var interestMethod: InterestMethod

    enum Disbursement: String, Codable, Sendable {
        case beforeJuly12023
        case afterJuly12023
    }

    enum InterestMethod: String, Codable, Sendable {
        case dailyAccrualMonthlyApplication
        case monthlyNominal
    }
}

enum LoanRate: Codable, Equatable, Sendable {
    case fixed(annualRate: Decimal)
    /// Margin added to the current prime rate.
    case floating(marginOverPrime: Decimal)
}

struct MoneyToAllocate: Codable, Equatable, Sendable {
    var monthlyAmount: Decimal?
    var lumpSums: [LumpSum]
}

struct LumpSum: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var amount: Decimal
    var month: YearMonth
    /// Share of this lump sum that goes to an extra loan payment. Nil follows the monthly split.
    var loanShare: Decimal?
}

/// Share of allocatable money that goes to an extra loan payment, from 0 to 1.
/// The rest is invested. Nil until a split is suggested or chosen.
struct AllocationSplit: Codable, Equatable, Sendable {
    var loanShare: Decimal?
}

extension UserPlan {
    /// The same plan with `share` going to the loan from the monthly amount or from one lump sum.
    func applyingLoanShare(_ share: Decimal, to target: SplitTarget) -> UserPlan {
        var plan = self
        switch target {
        case .everyMonth:
            plan.split.loanShare = share
        case .lumpSum(let id):
            if let index = plan.money.lumpSums.firstIndex(where: { $0.id == id }) {
                plan.money.lumpSums[index].loanShare = share
            }
        }
        return plan
    }
}

struct Investments: Codable, Equatable, Sendable {
    var balance: Decimal?
    var fundType: FundType?
}

enum FundType: String, Codable, Sendable {
    case indexETF
    case mutualFund
}

struct CoastFireGoal: Codable, Equatable, Sendable {
    var currentAge: Int?
    var retirementAge: Int?
    var yearlyRetirementSpending: Decimal?
    var withdrawalRate: Decimal?
}

struct Assumptions: Codable, Equatable, Sendable {
    var badAnnualReturn: Decimal
    var typicalAnnualReturn: Decimal
    var goodAnnualReturn: Decimal
    var inflation: Decimal?
    var primeRate: Decimal?
    /// Annual fee for the fund the user holds. Depends on fund type once it is set.
    var annualFee: Decimal?
    /// How many months a candidate may trail the safest bad-case Coast FIRE date and still be eligible.
    var riskToleranceMonths: Int
    var contributionsRiseWithInflation: Bool

    /// Decided defaults: bad 3%, typical 6.5%, good 10%, risk tolerance 12 months.
    /// Contributions rise with inflation unless the user turns that off.
    static let defaults = Assumptions(
        badAnnualReturn: planDecimal("0.03"),
        typicalAnnualReturn: planDecimal("0.065"),
        goodAnnualReturn: planDecimal("0.10"),
        inflation: nil,
        primeRate: nil,
        annualFee: nil,
        riskToleranceMonths: 12,
        contributionsRiseWithInflation: true
    )
}

struct ChosenPlan: Codable, Equatable, Sendable {
    var mode: AllocationMode
    var loanShare: Decimal
    var chosenAt: Date
    /// The lump sum a one-time choice applies to.
    var lumpSumID: UUID?
}

enum AllocationMode: String, Codable, Sendable {
    case everyMonth
    case oneTime
}

/// The money a split applies to: the monthly amount, or one lump sum.
enum SplitTarget: Hashable, Sendable {
    case everyMonth
    case lumpSum(id: UUID)

    var mode: AllocationMode {
        switch self {
        case .everyMonth: .everyMonth
        case .lumpSum: .oneTime
        }
    }

    var lumpSumID: UUID? {
        switch self {
        case .everyMonth: nil
        case .lumpSum(let id): id
        }
    }
}

struct YearMonth: Codable, Equatable, Hashable, Sendable {
    var year: Int
    /// 1 through 12.
    var month: Int
}

struct CalendarDate: Codable, Equatable, Hashable, Sendable {
    var year: Int
    var month: Int
    var day: Int
}

struct PlanBudget: Codable, Equatable, Sendable {
    var categories: [PlanBudgetCategory]
    var emergencyFundIsFull: Bool

    static let empty = PlanBudget(categories: [], emergencyFundIsFull: true)
}

struct PlanBudgetCategory: Codable, Equatable, Sendable {
    enum Role: String, Codable, Sendable {
        case needs
        case emergencyFund
        case extraLoanPayment
        case investing
        case other
    }

    var amount: Decimal
    var role: Role
}

func planDecimal(_ literal: String) -> Decimal {
    guard let value = Decimal(string: literal, locale: Locale(identifier: "en_US_POSIX")) else {
        preconditionFailure("Invalid decimal literal: \(literal)")
    }
    return value
}
