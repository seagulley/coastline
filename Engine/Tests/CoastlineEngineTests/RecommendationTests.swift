import XCTest
@testable import CoastlineEngine

final class RecommendationTests: XCTestCase {
    private let start = YearMonth(year: 2026, month: 1)
    private let base = YearMonth(year: 2030, month: 1)

    func testFixedReturnsRunTheSameInputThroughEachScenario() {
        var input = makeInput(loans: [makeLoan(balance: 8000, rate: decimal("0.05"), minimum: 150)])
        input.scenario = .bad
        let outcomes = FixedReturnScenarios().outcomes(for: input)
        for scenario in ProjectionScenario.allCases {
            var single = input
            single.scenario = scenario
            XCTAssertEqual(outcomes[scenario], ProjectionEngine.project(single))
            XCTAssertEqual(outcomes[scenario].scenario, scenario)
        }
        XCTAssertEqual(FixedReturnScenarios().outcomes(for: input), outcomes)
    }

    func testCandidatesAreTenPercentStepsRunThroughTheSource() {
        let source = StubScenarios(dates: [:], fallback: (typical: 50, bad: 50), base: base)
        let recommendation = Recommender.recommend(makeInput(), scenarios: source)
        XCTAssertEqual(recommendation.candidates.map(\.loanShare), (0...10).map { Decimal($0) / 10 })
        XCTAssertEqual(Recommender.defaultRiskToleranceMonths, 12)
        XCTAssertEqual(recommendation.riskToleranceMonths, 12)
    }

    func testRecommendsTheEarliestTypicalDateWithinTheRiskToleranceOfTheSafest() {
        let source = StubScenarios(
            dates: [
                0: (typical: 0, bad: 30),
                3: (typical: 5, bad: 22),
                6: (typical: 10, bad: 10),
            ],
            fallback: (typical: 50, bad: 50),
            base: base
        )
        let recommendation = Recommender.recommend(makeInput(), scenarios: source)
        XCTAssertEqual(recommendation.safest.loanShare, decimal("0.6"))
        XCTAssertEqual(recommendation.recommended.loanShare, decimal("0.3"))
        XCTAssertEqual(recommendation.typicalMonthsSooner, 5)
        XCTAssertEqual(recommendation.badCaseMonthsBehind, 12)
        XCTAssertEqual(
            recommendation.reason,
            "Reaches Coast FIRE 5 months sooner in a typical market, and only 12 months behind the safest option in a bad market."
        )

        let strict = Recommender.recommend(makeInput(), riskToleranceMonths: 11, scenarios: source)
        XCTAssertEqual(strict.recommended.loanShare, decimal("0.6"))
        XCTAssertEqual(
            strict.reason,
            "Reaches Coast FIRE soonest in a bad market. Splits that are sooner in a typical market trail it by more than 11 months in a bad market."
        )
    }

    func testTiesGoToTheHigherLoanShare() {
        let typicalTie = StubScenarios(
            dates: [
                2: (typical: 5, bad: 12),
                4: (typical: 5, bad: 15),
                8: (typical: 20, bad: 10),
            ],
            fallback: (typical: 50, bad: 50),
            base: base
        )
        let recommendation = Recommender.recommend(makeInput(), scenarios: typicalTie)
        XCTAssertEqual(recommendation.safest.loanShare, decimal("0.8"))
        XCTAssertEqual(recommendation.recommended.loanShare, decimal("0.4"))

        let safestTie = StubScenarios(
            dates: [
                1: (typical: 30, bad: 10),
                7: (typical: 30, bad: 10),
            ],
            fallback: (typical: 50, bad: 50),
            base: base
        )
        XCTAssertEqual(Recommender.recommend(makeInput(), scenarios: safestTie).safest.loanShare, decimal("0.7"))
    }

    func testTypicalTieAgainstTheSafestExplainsTheGuaranteedReturn() {
        let source = StubScenarios(
            dates: [
                2: (typical: 5, bad: 10),
                8: (typical: 5, bad: 12),
            ],
            fallback: (typical: 50, bad: 50),
            base: base
        )
        let recommendation = Recommender.recommend(makeInput(), scenarios: source)
        XCTAssertEqual(recommendation.safest.loanShare, decimal("0.2"))
        XCTAssertEqual(recommendation.recommended.loanShare, decimal("0.8"))
        XCTAssertEqual(recommendation.typicalMonthsSooner, 0)
        XCTAssertEqual(
            recommendation.reason,
            "Matches the safest option in a typical market, and only 2 months behind the safest option in a bad market. It puts more toward the loan, whose return is guaranteed."
        )
    }

    func testDatesThatAreNeverReachedComeLast() {
        let source = StubScenarios(
            dates: [
                0: (typical: 0, bad: nil),
                5: (typical: nil, bad: 8),
                9: (typical: 20, bad: 10),
            ],
            fallback: (typical: nil, bad: nil),
            base: base
        )
        let recommendation = Recommender.recommend(makeInput(), scenarios: source)
        XCTAssertEqual(recommendation.safest.loanShare, decimal("0.5"))
        XCTAssertEqual(recommendation.recommended.loanShare, decimal("0.9"))
        XCTAssertNil(recommendation.typicalMonthsSooner)
        XCTAssertEqual(recommendation.badCaseMonthsBehind, 2)

        let nothing = StubScenarios(dates: [:], fallback: (typical: nil, bad: nil), base: base)
        let fallback = Recommender.recommend(makeInput(), scenarios: nothing)
        XCTAssertEqual(fallback.recommended.loanShare, 1)
        XCTAssertEqual(
            fallback.reason,
            "No split reaches Coast FIRE before retirement, so this one puts the most toward the loan, whose return is guaranteed."
        )
    }

    func testOneMonthIsSingular() {
        let source = StubScenarios(
            dates: [
                1: (typical: 3, bad: 11),
                5: (typical: 4, bad: 10),
            ],
            fallback: (typical: 50, bad: 50),
            base: base
        )
        XCTAssertEqual(
            Recommender.recommend(makeInput(), scenarios: source).reason,
            "Reaches Coast FIRE 1 month sooner in a typical market, and only 1 month behind the safest option in a bad market."
        )
    }

    func testOneTimeCandidatesVaryOnlyTheLumpSum() {
        let lump = LumpSum(amount: 5000, month: start)
        var input = makeInput(loans: [makeLoan(balance: 20000, rate: decimal("0.20"), minimum: 400)])
        input.loanShare = decimal("0.3")
        input.lumpSums = [lump]
        let source = RecordingScenarios()
        let recommendation = Recommender.recommend(input, target: .lumpSum(id: lump.id), scenarios: source)

        XCTAssertEqual(source.inputs.map(\.loanShare), Array(repeating: decimal("0.3"), count: 11))
        XCTAssertEqual(source.inputs.compactMap { $0.lumpSums[0].loanShare }, Recommender.candidateLoanShares)
        XCTAssertEqual(recommendation.candidates.map(\.loanShare), Recommender.candidateLoanShares)
    }

    func testAHighRateLoanWinsALumpSum() {
        let lump = LumpSum(amount: 5000, month: start)
        var input = makeInput(loans: [makeLoan(balance: 20000, rate: decimal("0.20"), minimum: 400)])
        input.lumpSums = [lump]
        let recommendation = Recommender.recommend(input, target: .lumpSum(id: lump.id))
        XCTAssertGreaterThan(recommendation.recommended.loanShare, 0)
    }

    func testAHighRateLoanCanWinAnExtraPayment() {
        let loan = makeLoan(balance: 20000, rate: decimal("0.20"), minimum: 400)
        let recommendation = Recommender.recommend(makeInput(loans: [loan]))
        XCTAssertGreaterThan(recommendation.recommended.loanShare, 0)
        XCTAssertGreaterThan(recommendation.safest.loanShare, 0)
    }

    func testAnInterestFreeLoanIsNotPaidEarly() {
        let loan = makeLoan(balance: 20000, rate: 0, minimum: 200)
        let recommendation = Recommender.recommend(makeInput(loans: [loan]))
        XCTAssertEqual(recommendation.recommended.loanShare, 0)
    }

    func testEveryCandidateReachesCoastFireOnceFreedMoneyIsInvested() {
        let loan = makeLoan(balance: 8000, rate: decimal("0.05"), minimum: 150)
        let recommendation = Recommender.recommend(makeInput(loans: [loan]))
        for candidate in recommendation.candidates {
            XCTAssertNotNil(candidate.typicalCoastFireDate, "loan share \(candidate.loanShare)")
            XCTAssertNotNil(candidate.badCaseCoastFireDate, "loan share \(candidate.loanShare)")
        }
    }

    private func makeInput(loans: [Loan] = []) -> ProjectionInput {
        ProjectionInput(
            start: start,
            loans: loans,
            monthlyAmount: 2000,
            loanShare: 0,
            investments: Investments(balance: 15000, fundType: .indexETF),
            goal: CoastFireGoal(currentAge: 35, retirementAge: 65, yearlySpending: 24000, withdrawalRate: decimal("0.04")),
            assumptions: Assumptions(inflation: decimal("0.02"), primeRate: decimal("0.045"), annualFee: decimal("0.002")),
            scenario: .typical
        )
    }

    private func makeLoan(balance: Decimal, rate: Decimal, minimum: Decimal) -> Loan {
        Loan(
            balance: balance,
            disbursedBeforeJuly2023: false,
            rate: .fixed(annualRate: rate),
            interestStart: start,
            minimumPayment: minimum
        )
    }

    private func decimal(_ value: String) -> Decimal {
        Decimal(string: value)!
    }
}

/// Runs the fixed returns and keeps every input it was asked for.
private final class RecordingScenarios: ScenarioSource, @unchecked Sendable {
    private(set) var inputs: [ProjectionInput] = []

    func outcomes(for input: ProjectionInput) -> ScenarioOutcomes {
        inputs.append(input)
        return FixedReturnScenarios().outcomes(for: input)
    }
}

/// Coast FIRE dates set per loan share, in tenths, as months after `base`. Nil is never reached.
private struct StubScenarios: ScenarioSource {
    typealias Offsets = (typical: Int?, bad: Int?)

    let dates: [Int: Offsets]
    let fallback: Offsets
    let base: YearMonth

    func outcomes(for input: ProjectionInput) -> ScenarioOutcomes {
        let tenths = NSDecimalNumber(decimal: input.loanShare * 10).intValue
        let offsets = dates[tenths] ?? fallback
        return ScenarioOutcomes(
            good: result(.good, offsets.typical.map { $0 - 1 }),
            typical: result(.typical, offsets.typical),
            bad: result(.bad, offsets.bad)
        )
    }

    private func result(_ scenario: ProjectionScenario, _ offset: Int?) -> ProjectionResult {
        let date = offset.map { base.adding(months: $0) }
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
