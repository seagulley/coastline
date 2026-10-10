import XCTest
@testable import Coastline

@MainActor
final class AssumptionsTests: XCTestCase {
    private let start = YearMonth(year: 2026, month: 1)

    func testDraftStartsFromTheAssumptionsAndKeepsAnUnsetFeeUnset() {
        let draft = AssumptionsDraft(assumptions: UserPlan.starter.assumptions)
        XCTAssertEqual(draft.goodReturnPercent, SetupNumber.percentText(planDecimal("0.10")))
        XCTAssertEqual(draft.typicalReturnPercent, SetupNumber.percentText(planDecimal("0.065")))
        XCTAssertEqual(draft.badReturnPercent, SetupNumber.percentText(planDecimal("0.03")))
        XCTAssertFalse(draft.usesDefaultFee)
        XCTAssertEqual(draft.assumptions(updating: UserPlan.starter.assumptions, needsPrimeRate: true), UserPlan.starter.assumptions)

        var unset = UserPlan.starter.assumptions
        unset.annualFee = nil
        let unsetDraft = AssumptionsDraft(assumptions: unset)
        XCTAssertTrue(unsetDraft.usesDefaultFee)
        XCTAssertNil(unsetDraft.assumptions(updating: unset, needsPrimeRate: false)?.annualFee, "an unset fee is passed as unset, not 0")
    }

    func testEditedFieldsBecomeAssumptionsAndResetReturnsTheFeeToTheDefault() throws {
        let base = UserPlan.starter.assumptions
        var draft = AssumptionsDraft(assumptions: base)
        draft.typicalReturnPercent = "7"
        draft.primeRatePercent = "5.2"
        draft.inflationPercent = "2.5"
        draft.feePercent = "0.5"

        let edited = try XCTUnwrap(draft.assumptions(updating: base, needsPrimeRate: true))
        XCTAssertEqual(edited.typicalAnnualReturn, planDecimal("0.07"))
        XCTAssertEqual(edited.primeRate, planDecimal("0.052"))
        XCTAssertEqual(edited.inflation, planDecimal("0.025"))
        XCTAssertEqual(edited.annualFee, planDecimal("0.005"))
        XCTAssertEqual(edited.riskToleranceMonths, base.riskToleranceMonths)

        draft.useDefaultFee()
        XCTAssertTrue(draft.usesDefaultFee)
        XCTAssertNil(try XCTUnwrap(draft.assumptions(updating: base, needsPrimeRate: true)).annualFee)
    }

    func testDraftListsWhatNeedsFixing() {
        var draft = AssumptionsDraft(assumptions: UserPlan.starter.assumptions)
        draft.badReturnPercent = "8"
        draft.inflationPercent = ""
        draft.feePercent = "abc"
        draft.primeRatePercent = ""
        XCTAssertEqual(draft.issues(needsPrimeRate: true), [
            "The bad return can't be above typical, and typical can't be above good.",
            "Enter the prime rate your floating-rate loan follows.",
            "Enter an inflation rate.",
            "Enter the fee as a percent, such as 0.2, or reset it to the default.",
        ])
        XCTAssertNil(draft.assumptions(updating: UserPlan.starter.assumptions, needsPrimeRate: true))

        var noFloating = AssumptionsDraft(assumptions: UserPlan.starter.assumptions)
        noFloating.primeRatePercent = ""
        noFloating.badReturnPercent = "-2"
        XCTAssertEqual(noFloating.issues(needsPrimeRate: false), [], "prime is optional without a floating loan, and returns can be negative")
        XCTAssertNil(noFloating.assumptions(updating: UserPlan.starter.assumptions, needsPrimeRate: false)?.primeRate)
    }

    func testBreakEvenComesFromTheEngine() throws {
        let engine = PlanProjectionEngine(start: start)
        let breakEven = try XCTUnwrap(engine.breakEvenReturn(.starter))
        let days2026 = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        let expected = days2026.reduce(1.0) { $0 * (1 + 0.05 * Double($1) / 365) } - 1 + 0.002
        XCTAssertEqual(NSDecimalNumber(decimal: breakEven).doubleValue, expected, accuracy: 1e-12)
        XCTAssertEqual(PlanFormatting.rate(breakEven), "5.32%")

        var mutualFund = UserPlan.starter
        mutualFund.assumptions.annualFee = nil
        mutualFund.investments.fundType = .mutualFund
        let higherFee = try XCTUnwrap(engine.breakEvenReturn(mutualFund))
        XCTAssertEqual(NSDecimalNumber(decimal: higherFee).doubleValue, expected - 0.002 + 0.02, accuracy: 1e-12)

        var noLoans = UserPlan.starter
        noLoans.loans = []
        XCTAssertNil(engine.breakEvenReturn(noLoans))
    }

    func testChangingAssumptionsRerunsCompare() async {
        let engine = PlanProjectionEngine(start: start)
        let model = CompareModel(engine: engine, plan: .starter, startMonth: start)
        await model.loadRecommendation()
        let before = model.inputs
        XCTAssertNotNil(model.currentRecommendation)

        var lowerReturns = model.plan.assumptions
        lowerReturns.typicalAnnualReturn = planDecimal("0.04")
        lowerReturns.annualFee = nil
        model.useAssumptions(lowerReturns)

        XCTAssertNotEqual(model.inputs, before)
        XCTAssertNil(model.currentRecommendation, "new assumptions rerun the engine")
        await model.loadRecommendation()
        XCTAssertEqual(model.comparedPlan.assumptions, lowerReturns)
        XCTAssertEqual(model.currentRecommendation, engine.recommend(model.comparedPlan))
        XCTAssertEqual(model.breakEvenReturn, engine.breakEvenReturn(model.comparedPlan))
    }

    func testSavingAssumptionsKeepsTheRestOfThePlan() throws {
        let store = MemoryPlanStore()
        var saved = UserPlan.starter
        saved.chosenPlan = ChosenPlan(mode: .everyMonth, loanShare: planDecimal("0.3"), chosenAt: Date(timeIntervalSince1970: 0))
        try store.save(saved)
        let app = AppModel(store: store, engine: PlanProjectionEngine(start: start), currentMonth: start)
        let before = app.projection

        var edited = saved.assumptions
        edited.typicalAnnualReturn = planDecimal("0.08")
        edited.annualFee = nil
        try app.saveAssumptions(edited)

        var expected = saved
        expected.assumptions = edited
        XCTAssertEqual(try store.load(), expected)
        XCTAssertEqual(app.plan, expected)
        XCTAssertNotEqual(app.projection, before, "Home shows the projection on the new assumptions")
    }
}
