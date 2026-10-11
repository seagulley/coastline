import XCTest
@testable import Coastline

final class PlanProjectionEngineTests: XCTestCase {
    private let start = YearMonth(year: 2026, month: 1)

    func testStarterPlanShowsGoodTypicalAndBad() {
        let projection = PlanProjectionEngine(start: start).project(.starter)
        XCTAssertEqual(projection.scenarios.map(\.scenario), [.good, .typical, .bad])
        let dates = projection.scenarios.map(\.coastFireDate)
        XCTAssertTrue(dates.allSatisfy { $0 != nil })
        XCTAssertEqual(Set(dates).count, 3)
        XCTAssertFalse(projection.scenarios.contains { $0.months.isEmpty })
    }

    func testIncompletePlanProducesNoProjection() {
        let engine = PlanProjectionEngine(start: start)
        XCTAssertEqual(engine.project(.empty), .empty)
        XCTAssertNil(engine.recommend(.empty))
    }

    func testRecommendationShowsTheProjectionForTheRecommendedSplit() {
        let engine = PlanProjectionEngine(start: start)
        let recommendation = try! XCTUnwrap(engine.recommend(.starter))
        XCTAssertFalse(recommendation.reason.isEmpty)
        XCTAssertTrue((0...10).map { Decimal($0) / 10 }.contains(recommendation.loanShare))

        var recommended = UserPlan.starter
        recommended.split.loanShare = recommendation.loanShare
        XCTAssertEqual(recommendation.projection, engine.project(recommended))
    }

    func testOneTimeRecommendationSplitsOnlyTheLumpSum() {
        let engine = PlanProjectionEngine(start: start)
        var plan = UserPlan.starter
        plan.loans[0].balance = 20000
        plan.loans[0].rate = .fixed(annualRate: planDecimal("0.20"))
        let lump = LumpSum(id: UUID(), amount: 5000, month: start, loanShare: nil)
        plan.money.lumpSums = [lump]

        let recommendation = try! XCTUnwrap(engine.recommend(plan, for: .lumpSum(id: lump.id)))
        XCTAssertGreaterThan(recommendation.loanShare, 0)
        XCTAssertEqual(recommendation.candidates.map(\.loanShare), (0...10).map { Decimal($0) / 10 })
        XCTAssertEqual(
            recommendation.projection,
            engine.project(plan.applyingLoanShare(recommendation.loanShare, to: .lumpSum(id: lump.id)))
        )
        XCTAssertEqual(plan.split.loanShare, 0)

        XCTAssertNil(engine.recommend(plan, for: .lumpSum(id: UUID())))
    }

    func testRecommendationUsesThePlanRiskTolerance() {
        let source = DatedScenarios(typicalByTenths: [2: 0], badByTenths: [2: 13, 6: 0])
        let engine = PlanProjectionEngine(start: start, scenarios: source)
        var plan = UserPlan.starter
        XCTAssertEqual(engine.recommend(plan)?.loanShare, Decimal(string: "0.6"))
        plan.assumptions.riskToleranceMonths = 13
        XCTAssertEqual(engine.recommend(plan)?.loanShare, Decimal(string: "0.2"))
    }

    func testScenarioSourceCanBeReplacedWithoutChangingTheProjectionShape() {
        let source = DatedScenarios(typicalByTenths: [0: 7], badByTenths: [0: 9])
        let projection = PlanProjectionEngine(start: start, scenarios: source).project(.starter)
        XCTAssertEqual(projection.scenarios.map(\.scenario), [.good, .typical, .bad])
        XCTAssertEqual(
            projection.scenarios.map(\.coastFireDate),
            [
                CalendarDate(year: 2030, month: 7, day: 1),
                CalendarDate(year: 2030, month: 8, day: 1),
                CalendarDate(year: 2030, month: 10, day: 1),
            ]
        )
    }

    func testScreenReadsEachScenarioFromTheEngine() {
        let projection = PlanProjectionEngine(start: start).project(savingPlan())
        XCTAssertEqual(projection.scenarios.map(\.scenario), [.good, .typical, .bad])

        for scenario in projection.scenarios {
            XCTAssertEqual(scenario.coastFireDate, CalendarDate(year: 2026, month: 12, day: 1))
            XCTAssertEqual(scenario.months.first?.investmentBalance, 0)
            let december = scenario.months.last { $0.month == YearMonth(year: 2026, month: 12) }
            XCTAssertEqual(december?.investmentBalance, 1200)
            XCTAssertEqual(december?.netWorth, 1200)
        }
    }

    func testFreedLoanPaymentUsesTheSavedBudget() {
        let projection = PlanProjectionEngine(start: start).project(payoffPlan())
        let typical = try! XCTUnwrap(projection.scenarios.first { $0.scenario == .typical })
        let february = typical.months.last { $0.month == YearMonth(year: 2026, month: 2) }

        XCTAssertEqual(february?.investmentBalance, 600)
        XCTAssertEqual(typical.coastFireDate, CalendarDate(year: 2026, month: 3, day: 1))
        XCTAssertEqual(
            typical.coastFireDateIfFreedMoneyInvested,
            CalendarDate(year: 2026, month: 2, day: 1)
        )
    }

    func testUnsetFeeStartsAtTheFundTypeDefault() {
        XCTAssertEqual(FundType.indexETF.defaultAnnualFee, planDecimal("0.002"))
        XCTAssertEqual(FundType.mutualFund.defaultAnnualFee, planDecimal("0.02"))

        let engine = PlanProjectionEngine(start: start)
        var unset = UserPlan.starter
        unset.investments.fundType = .mutualFund
        unset.assumptions.annualFee = nil
        var mutualFundFee = unset
        mutualFundFee.assumptions.annualFee = planDecimal("0.02")

        XCTAssertEqual(engine.project(unset), engine.project(mutualFundFee))
        XCTAssertNotEqual(engine.project(unset), engine.project(.starter))
    }

    func testEveryMonthChecklistReadsTheFirstMonthsPaymentsForTheChosenSplit() {
        let engine = PlanProjectionEngine(start: start)
        let plan = UserPlan.starter.applyingLoanShare(planDecimal("0.5"), to: .everyMonth)

        let checklist = try! XCTUnwrap(engine.checklist(plan, for: .everyMonth))

        XCTAssertEqual(checklist.mode, .everyMonth)
        XCTAssertEqual(checklist.month, start)
        XCTAssertEqual(
            checklist.loanPayments,
            [ChecklistLoanPayment(loanID: plan.loans[0].id, minimum: 150, extra: 1000, total: 1150)]
        )
        XCTAssertEqual(checklist.investing, 1000)
        XCTAssertTrue(checklist.investingRisesWithInflation)
        XCTAssertEqual(checklist.fee, FeeAssumption(annualFee: planDecimal("0.002"), fundType: .indexETF, setByUser: true))
    }

    func testOneTimeChecklistSplitsOnlyTheLumpSum() {
        let engine = PlanProjectionEngine(start: start)
        var plan = UserPlan.starter
        let lump = LumpSum(id: UUID(), amount: 3000, month: YearMonth(year: 2027, month: 4), loanShare: planDecimal("0.4"))
        plan.money.lumpSums = [lump]

        let checklist = try! XCTUnwrap(engine.checklist(plan, for: .lumpSum(id: lump.id)))

        XCTAssertEqual(checklist.mode, .oneTime)
        XCTAssertEqual(checklist.month, lump.month)
        XCTAssertEqual(
            checklist.loanPayments,
            [ChecklistLoanPayment(loanID: plan.loans[0].id, minimum: 0, extra: 1200, total: 1200)]
        )
        XCTAssertEqual(checklist.investing, 1800)
        XCTAssertNil(engine.checklist(plan, for: .lumpSum(id: UUID())))
        XCTAssertNil(engine.checklist(.empty, for: .everyMonth))
    }

    func testChecklistFeeIsTheFundTypeDefaultUnlessTheUserSetOne() {
        let engine = PlanProjectionEngine(start: start)
        var plan = UserPlan.starter
        plan.investments.fundType = .mutualFund
        plan.assumptions.annualFee = nil

        XCTAssertEqual(
            engine.checklist(plan, for: .everyMonth)?.fee,
            FeeAssumption(annualFee: planDecimal("0.02"), fundType: .mutualFund, setByUser: false)
        )

        plan.assumptions.annualFee = planDecimal("0.0035")
        XCTAssertEqual(
            engine.checklist(plan, for: .everyMonth)?.fee,
            FeeAssumption(annualFee: planDecimal("0.0035"), fundType: .mutualFund, setByUser: true)
        )
    }

    private func savingPlan() -> UserPlan {
        var plan = UserPlan.empty
        plan.money.monthlyAmount = 100
        plan.split.loanShare = 0
        plan.investments.balance = 0
        plan.investments.fundType = .indexETF
        plan.goal = CoastFireGoal(
            currentAge: 30,
            retirementAge: 32,
            yearlyRetirementSpending: 1200,
            withdrawalRate: 1
        )
        plan.assumptions = zeroReturns(plan.assumptions)
        plan.assumptions.contributionsRiseWithInflation = false
        return plan
    }

    private func payoffPlan() -> UserPlan {
        var plan = UserPlan.empty
        plan.loans = [
            Loan(
                id: UUID(),
                balance: 1000,
                disbursement: .afterJuly12023,
                rate: .fixed(annualRate: 0),
                interestStart: CalendarDate(year: 2026, month: 1, day: 1),
                minimumPayment: 1000,
                repaymentTermMonths: nil,
                interestMethod: .dailyAccrualMonthlyApplication
            ),
            Loan(
                id: UUID(),
                balance: 5000,
                disbursement: .afterJuly12023,
                rate: .fixed(annualRate: 0),
                interestStart: CalendarDate(year: 2026, month: 1, day: 1),
                minimumPayment: 100,
                repaymentTermMonths: nil,
                interestMethod: .dailyAccrualMonthlyApplication
            ),
        ]
        plan.goal = CoastFireGoal(
            currentAge: 40,
            retirementAge: 45,
            yearlyRetirementSpending: 800,
            withdrawalRate: 1
        )
        plan.assumptions = zeroReturns(plan.assumptions)
        plan.budget = PlanBudget(
            categories: [
                PlanBudgetCategory(amount: 2000, role: .needs),
                PlanBudgetCategory(amount: 500, role: .emergencyFund),
                PlanBudgetCategory(amount: 300, role: .investing),
                PlanBudgetCategory(amount: 100, role: .extraLoanPayment),
                PlanBudgetCategory(amount: 100, role: .other),
            ],
            emergencyFundIsFull: true
        )
        return plan
    }

    private func zeroReturns(_ assumptions: Assumptions) -> Assumptions {
        var assumptions = assumptions
        assumptions.badAnnualReturn = 0
        assumptions.typicalAnnualReturn = 0
        assumptions.goodAnnualReturn = 0
        assumptions.inflation = 0
        assumptions.primeRate = 0
        assumptions.annualFee = 0
        assumptions.contributionsRiseWithInflation = false
        return assumptions
    }
}
