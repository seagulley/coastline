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
