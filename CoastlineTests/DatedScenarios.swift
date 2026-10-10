import CoastlineEngine
import Foundation

/// Coast FIRE dates by loan share in tenths, as months after January 2030. Good is one month before typical.
/// Shares that are not listed never reach Coast FIRE.
struct DatedScenarios: ScenarioSource {
    var typicalByTenths: [Int: Int]
    var badByTenths: [Int: Int]

    func outcomes(for input: ProjectionInput) -> ScenarioOutcomes {
        let tenths = NSDecimalNumber(decimal: input.loanShare * 10).intValue
        let typical = typicalByTenths[tenths]
        return ScenarioOutcomes(
            good: result(.good, typical.map { $0 - 1 }),
            typical: result(.typical, typical),
            bad: result(.bad, badByTenths[tenths])
        )
    }

    private func result(_ scenario: ProjectionScenario, _ offset: Int?) -> ProjectionResult {
        let date = offset.map { YearMonth(year: 2030, month: 1).adding(months: $0) }
        return ProjectionResult(
            scenario: scenario,
            annualReturn: 0,
            months: [],
            coastFireDate: date,
            coastFireDateIfFreedMoneyInvested: date,
            loanPayoffDate: nil,
            loanPayoffs: [],
            totalInterestPaid: 0,
            suggestedFreedMoneySplit: FreedMoneySplit(loanShare: 0, investShare: 1)
        )
    }
}
