import XCTest
@testable import Coastline

final class SetupDraftTests: XCTestCase {
    func testFourTopicsInOrderWithNoBudgetStep() {
        XCTAssertEqual(
            SetupStep.allCases.map(\.title),
            ["About you", "Loans", "Current investments", "Coast FIRE goal"]
        )
    }

    func testUnknownAssumptionsStartAtTypicalDefaults() {
        let draft = SetupDraft()
        XCTAssertEqual(SetupNumber.age(draft.retirementAge), 65)
        XCTAssertEqual(SetupNumber.percent(draft.withdrawalRatePercent), planDecimal("0.04"))
        XCTAssertEqual(SetupNumber.percent(draft.inflationPercent), planDecimal("0.02"))
        XCTAssertEqual(SetupNumber.years(LoanDraft().repaymentTermYears), 10)
        XCTAssertEqual(LoanDraft().interestMethod, .dailyAccrualMonthlyApplication)
        XCTAssertEqual(LoanDraft().disbursement, .afterJuly12023)
    }

    func testEachStepSaysWhatIsMissing() {
        let draft = SetupDraft()
        XCTAssertEqual(draft.issues(for: .aboutYou).count, 2)
        XCTAssertEqual(draft.issues(for: .loans), [])
        XCTAssertEqual(draft.issues(for: .investments).count, 2)
        XCTAssertEqual(draft.issues(for: .goal), ["Enter your yearly spending in retirement."])
        XCTAssertNil(draft.plan(updating: .empty))
        XCTAssertEqual(completeDraft().issues(for: .goal), [])
    }

    func testRetirementMustComeAfterCurrentAge() {
        var draft = completeDraft()
        draft.retirementAge = draft.currentAge
        XCTAssertEqual(draft.issues(for: .goal), ["Retirement age must be later than your current age."])
    }

    func testPrimeIsAskedOnlyForAFloatingLoan() {
        var draft = completeDraft()
        XCTAssertFalse(draft.needsPrimeRate)
        draft.loans[0].rateType = .floating
        draft.loans[0].ratePercent = "-0.5"
        XCTAssertTrue(draft.needsPrimeRate)
        XCTAssertEqual(draft.issues(for: .loans).count, 1)

        draft.primeRatePercent = "4.95"
        let plan = try! XCTUnwrap(draft.plan(updating: .empty))
        XCTAssertEqual(plan.loans[0].rate, .floating(marginOverPrime: planDecimal("-0.005")))
        XCTAssertEqual(plan.assumptions.primeRate, planDecimal("0.0495"))
    }

    func testCompletedDraftBuildsThePlan() throws {
        let plan = try XCTUnwrap(completeDraft().plan(updating: .empty))

        XCTAssertEqual(plan.goal, CoastFireGoal(
            currentAge: 30,
            retirementAge: 65,
            yearlyRetirementSpending: 40000,
            withdrawalRate: planDecimal("0.04")
        ))
        XCTAssertEqual(plan.money.monthlyAmount, 1200)
        XCTAssertEqual(plan.investments, Investments(balance: planDecimal("15000.5"), fundType: .mutualFund))
        XCTAssertEqual(plan.assumptions.inflation, planDecimal("0.02"))
        XCTAssertNil(plan.assumptions.annualFee)
        XCTAssertEqual(plan.budget, .empty)
        XCTAssertNil(plan.chosenPlan)

        let loan = try XCTUnwrap(plan.loans.first)
        XCTAssertEqual(loan.name, "Student loan")
        XCTAssertEqual(loan.balance, 8000)
        XCTAssertEqual(loan.rate, .fixed(annualRate: planDecimal("0.055")))
        XCTAssertNil(loan.interestStart)
        XCTAssertNil(loan.minimumPayment)
        XCTAssertEqual(loan.repaymentTermMonths, 120)
    }

    func testSetupKeepsWhatItDoesNotAsk() throws {
        var base = UserPlan.starter
        base.assumptions.annualFee = planDecimal("0.005")
        base.assumptions.typicalAnnualReturn = planDecimal("0.07")
        base.assumptions.riskToleranceMonths = 6
        base.chosenPlan = ChosenPlan(mode: .everyMonth, loanShare: planDecimal("0.3"), chosenAt: Date(timeIntervalSince1970: 0))

        let plan = try XCTUnwrap(completeDraft().plan(updating: base))

        XCTAssertEqual(plan.assumptions.annualFee, planDecimal("0.005"))
        XCTAssertEqual(plan.assumptions.typicalAnnualReturn, planDecimal("0.07"))
        XCTAssertEqual(plan.assumptions.riskToleranceMonths, 6)
        XCTAssertEqual(plan.assumptions.primeRate, base.assumptions.primeRate)
        XCTAssertEqual(plan.chosenPlan, base.chosenPlan)
        XCTAssertEqual(plan.split, base.split)
    }

    func testStatementPaymentAndFutureInterestStartAreKept() throws {
        let today = try XCTUnwrap(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 10, day: 10)))
        var draft = completeDraft()
        draft.loans[0].minimumPayment = "215.40"
        draft.loans[0].interestHasStarted = false
        draft.loans[0].interestStart = try XCTUnwrap(
            Calendar(identifier: .gregorian).date(from: DateComponents(year: 2027, month: 5, day: 1))
        )
        let plan = try XCTUnwrap(draft.plan(updating: .empty))
        XCTAssertEqual(plan.loans[0].minimumPayment, planDecimal("215.4"))
        XCTAssertEqual(plan.loans[0].interestStart, CalendarDate(year: 2027, month: 5, day: 1))

        XCTAssertEqual(SetupDraft(plan: plan, today: today).plan(updating: plan), plan)
    }

    func testIncompleteLoanBlocksTheLoansStep() {
        var draft = completeDraft()
        draft.loans[0].minimumPayment = ""
        draft.loans[0].repaymentTermYears = ""
        XCTAssertEqual(draft.loans[0].issues, ["Enter the minimum payment, or the years left to repay."])
        XCTAssertEqual(draft.issues(for: .loans), ["Finish the details for each loan."])
        XCTAssertNil(draft.plan(updating: .empty))
    }

    func testNumbersAreReadAsTyped() {
        let canada = Locale(identifier: "en_CA")
        XCTAssertEqual(SetupNumber.decimal("$12,000.50", locale: canada), planDecimal("12000.5"))
        XCTAssertEqual(SetupNumber.decimal(" 6.5 % ", locale: canada), planDecimal("6.5"))
        XCTAssertEqual(SetupNumber.decimal("-0.5", locale: canada), planDecimal("-0.5"))
        XCTAssertNil(SetupNumber.decimal("12abc", locale: canada))
        XCTAssertNil(SetupNumber.decimal("", locale: canada))
        XCTAssertNil(SetupNumber.amount("-1"))
        XCTAssertEqual(SetupNumber.decimal("6,5", locale: Locale(identifier: "fr_CA")), planDecimal("6.5"))
        XCTAssertEqual(SetupNumber.percentText(planDecimal("0.065"), locale: canada), "6.5")
    }

    private func completeDraft() -> SetupDraft {
        var draft = SetupDraft()
        draft.currentAge = "30"
        draft.monthlyAmount = "1200"
        var loan = LoanDraft()
        loan.name = " Student loan "
        loan.balance = "8000"
        loan.ratePercent = "5.5"
        draft.loans = [loan]
        draft.investmentBalance = "15000.50"
        draft.fundType = .mutualFund
        draft.yearlySpending = "40000"
        return draft
    }
}

@MainActor
final class FinishSetupTests: XCTestCase {
    private let engine = PlanProjectionEngine(start: YearMonth(year: 2026, month: 1))

    func testFinishingSavesThePlanWithTheRecommendedSplitAsASuggestion() throws {
        let store = MemoryPlanStore()
        let model = AppModel(store: store, engine: engine)
        var entered = UserPlan.starter
        entered.split.loanShare = nil

        let recommendation = try XCTUnwrap(try model.finishSetup(entered))

        XCTAssertTrue(model.hasStoredPlan)
        XCTAssertFalse(model.usingStarterPlan)
        XCTAssertEqual(model.plan.split.loanShare, recommendation.loanShare)
        XCTAssertNil(model.plan.chosenPlan)
        XCTAssertEqual(try store.load(), model.plan)
        XCTAssertEqual(model.projection, recommendation.projection)
        XCTAssertNotNil(model.projection.scenarios.first { $0.scenario == .typical }?.coastFireDate)
    }

    func testWithNoLoansEverythingIsInvested() throws {
        let model = AppModel(store: MemoryPlanStore(), engine: engine)
        var entered = UserPlan.starter
        entered.loans = []

        XCTAssertNil(try model.finishSetup(entered))
        XCTAssertEqual(model.plan.split.loanShare, 0)
    }

    func testAChosenSplitIsNotReplaced() throws {
        let model = AppModel(store: MemoryPlanStore(), engine: engine)
        var entered = UserPlan.starter
        entered.split.loanShare = planDecimal("0.3")
        entered.chosenPlan = ChosenPlan(mode: .everyMonth, loanShare: planDecimal("0.3"), chosenAt: Date(timeIntervalSince1970: 0))

        XCTAssertNil(try model.finishSetup(entered))
        XCTAssertEqual(model.plan.split.loanShare, planDecimal("0.3"))
    }
}
