import Foundation

/// The only way a screen obtains a projection. `PlanProjectionEngine` does the financial math.
/// Sendable so screens can run it off the main thread.
protocol ProjectionEngine: Sendable {
    func project(_ plan: UserPlan) -> Projection
    /// The recommended split of `target`, chosen with the plan's risk tolerance. Every other split stays as planned.
    /// Nil when the plan cannot be projected or does not contain the target lump sum.
    func recommend(_ plan: UserPlan, for target: SplitTarget) -> SplitRecommendation?
}

extension ProjectionEngine {
    func recommend(_ plan: UserPlan) -> SplitRecommendation? {
        recommend(plan, for: .everyMonth)
    }
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
    var coastFireDateIfFreedMoneyInvested: CalendarDate?
    var loanPayoffDate: CalendarDate?
    var totalInterestPaid: Decimal?
    var months: [MonthRecord]

    init(
        scenario: ReturnScenario,
        coastFireDate: CalendarDate? = nil,
        coastFireDateIfFreedMoneyInvested: CalendarDate? = nil,
        loanPayoffDate: CalendarDate? = nil,
        totalInterestPaid: Decimal? = nil,
        months: [MonthRecord] = []
    ) {
        self.scenario = scenario
        self.coastFireDate = coastFireDate
        self.coastFireDateIfFreedMoneyInvested = coastFireDateIfFreedMoneyInvested
        self.loanPayoffDate = loanPayoffDate
        self.totalInterestPaid = totalInterestPaid
        self.months = months
    }
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
