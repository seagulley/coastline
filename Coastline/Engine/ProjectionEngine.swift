import Foundation

/// The only way a screen obtains a projection. `PlanProjectionEngine` does the financial math.
/// Sendable so screens can run it off the main thread.
protocol ProjectionEngine: Sendable {
    func project(_ plan: UserPlan) -> Projection
    /// The recommended split of `target`, chosen with the plan's risk tolerance. Every other split stays as planned.
    /// Nil when the plan cannot be projected or does not contain the target lump sum.
    func recommend(_ plan: UserPlan, for target: SplitTarget) -> SplitRecommendation?
    /// This month's money split between the extra loan payment and investing. Nil when the plan has no monthly amount.
    func monthlySplit(_ plan: UserPlan) -> MonthlySplit?
}

extension ProjectionEngine {
    func recommend(_ plan: UserPlan) -> SplitRecommendation? {
        recommend(plan, for: .everyMonth)
    }

    func monthlySplit(_: UserPlan) -> MonthlySplit? {
        nil
    }
}

/// Amounts for the current month, which are already in today's dollars.
struct MonthlySplit: Equatable, Sendable {
    var loanShare: Decimal
    var investShare: Decimal
    var toLoan: Decimal
    var toInvesting: Decimal
}

struct Projection: Equatable, Sendable {
    var scenarios: [ScenarioProjection]

    static let empty = Projection(scenarios: [])

    func scenario(_ scenario: ReturnScenario) -> ScenarioProjection? {
        scenarios.first { $0.scenario == scenario }
    }
}

struct SplitRecommendation: Equatable, Sendable {
    /// Share of the target money sent to an extra loan payment, from 0 to 1.
    var loanShare: Decimal
    /// The split with the earliest bad-case Coast FIRE date.
    var safestLoanShare: Decimal
    /// One sentence comparing the recommendation with the safest split.
    var reason: String
    var typicalMonthsSooner: Int?
    var badCaseMonthsBehind: Int?
    /// Good, typical, and bad scenarios for the recommended split.
    var projection: Projection
    /// Every split the recommendation compared, lowest loan share first.
    var candidates: [SplitCandidate]
}

struct SplitCandidate: Equatable, Sendable {
    var loanShare: Decimal
    var projection: Projection
}

struct ScenarioProjection: Equatable, Sendable {
    var scenario: ReturnScenario
    var coastFireDate: CalendarDate?
    /// Whole months from the start of the projection to `coastFireDate`. Zero when it is already reached.
    var monthsUntilCoastFire: Int?
    var coastFireDateIfFreedMoneyInvested: CalendarDate?
    var loanPayoffDate: CalendarDate?
    /// When each loan reaches zero, and the payment that frees.
    var loanPayoffs: [PlannedPayoff]
    var totalInterestPaid: Decimal?
    var months: [MonthRecord]

    init(
        scenario: ReturnScenario,
        coastFireDate: CalendarDate? = nil,
        monthsUntilCoastFire: Int? = nil,
        coastFireDateIfFreedMoneyInvested: CalendarDate? = nil,
        loanPayoffDate: CalendarDate? = nil,
        loanPayoffs: [PlannedPayoff] = [],
        totalInterestPaid: Decimal? = nil,
        months: [MonthRecord] = []
    ) {
        self.scenario = scenario
        self.coastFireDate = coastFireDate
        self.monthsUntilCoastFire = monthsUntilCoastFire
        self.coastFireDateIfFreedMoneyInvested = coastFireDateIfFreedMoneyInvested
        self.loanPayoffDate = loanPayoffDate
        self.loanPayoffs = loanPayoffs
        self.totalInterestPaid = totalInterestPaid
        self.months = months
    }
}

struct PlannedPayoff: Equatable, Sendable {
    var loanID: UUID
    var month: YearMonth
    /// The minimum payment that stops once the loan is repaid. It is due in `month`.
    var payment: Decimal
}

enum ReturnScenario: String, Codable, Equatable, Sendable, CaseIterable {
    case good
    case typical
    case bad

    var title: String {
        switch self {
        case .good: "Good"
        case .typical: "Typical"
        case .bad: "Bad"
        }
    }
}

struct MonthRecord: Equatable, Sendable {
    var month: YearMonth
    var loanBalances: [LoanBalance]
    var investmentBalance: Decimal
    var netWorth: Decimal
    var cumulativeInterestPaid: Decimal
}

struct LoanBalance: Equatable, Sendable {
    var loanID: UUID
    var balance: Decimal
}

/// Returns no scenarios and performs no financial math.
struct UnimplementedProjectionEngine: ProjectionEngine {
    func project(_: UserPlan) -> Projection {
        .empty
    }

    func recommend(_: UserPlan, for _: SplitTarget) -> SplitRecommendation? {
        nil
    }
}
