import Foundation

/// The only way a screen obtains a projection. Implementations do the financial math.
/// The scaffold ships a stand-in that returns no scenarios.
protocol ProjectionEngine {
    func project(_ plan: UserPlan) -> Projection
}

struct Projection: Equatable, Sendable {
    var scenarios: [ScenarioProjection]

    static let empty = Projection(scenarios: [])
}

struct ScenarioProjection: Equatable, Sendable {
    var scenario: ReturnScenario
    var coastFireDate: CalendarDate?
    var loanPayoffDate: CalendarDate?
    var totalInterestPaid: Decimal?
    var months: [MonthRecord]

    init(
        scenario: ReturnScenario,
        coastFireDate: CalendarDate? = nil,
        loanPayoffDate: CalendarDate? = nil,
        totalInterestPaid: Decimal? = nil,
        months: [MonthRecord] = []
    ) {
        self.scenario = scenario
        self.coastFireDate = coastFireDate
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
}
