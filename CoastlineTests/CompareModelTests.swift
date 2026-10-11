import XCTest
@testable import Coastline

@MainActor
final class CompareModelTests: XCTestCase {
    private let start = YearMonth(year: 2026, month: 1)

    func testEveryMonthRecommendsAndComparesWithBothExtremes() async {
        let engine = TargetRecordingEngine(start: start)
        let model = CompareModel(engine: engine, plan: .starter, startMonth: start)

        await model.loadRecommendation()

        XCTAssertEqual(engine.targets, [.everyMonth])
        let recommendation = try! XCTUnwrap(model.currentRecommendation)
        XCTAssertEqual(recommendation.loanShare, planDecimal("0.3"))
        XCTAssertEqual(model.customShare, planDecimal("0.3"))
        XCTAssertEqual(model.options.map(\.kind), [.recommended, .allToLoan, .allInvested])
        XCTAssertEqual(model.options.map(\.loanShare), [planDecimal("0.3"), 1, 0])
        XCTAssertEqual(model.chosenOption?.kind, .recommended)
    }

    func testOneTimeWaitsForAnAmountThenRecommendsASplitOfThatLumpSum() async {
        let engine = TargetRecordingEngine(start: start)
        let model = CompareModel(engine: engine, plan: .starter, startMonth: start)
        await model.loadRecommendation()

        model.mode = .oneTime
        XCTAssertNil(model.target)
        XCTAssertNil(model.currentRecommendation)
        XCTAssertTrue(model.options.isEmpty)
        await model.loadRecommendation()
        XCTAssertEqual(engine.targets, [.everyMonth])

        model.lumpSumAmount = 5000
        let target = try! XCTUnwrap(model.target)
        XCTAssertNil(model.currentRecommendation, "a new amount reruns the engine")
        await model.loadRecommendation()

        XCTAssertEqual(engine.targets.last, target)
        let lump = try! XCTUnwrap(engine.plans.last?.money.lumpSums.first)
        XCTAssertEqual(target, .lumpSum(id: lump.id))
        XCTAssertEqual(lump.amount, 5000)
        XCTAssertEqual(lump.month, start)
        XCTAssertEqual(engine.plans.last?.split, UserPlan.starter.split)
        XCTAssertNotNil(model.currentRecommendation)

        model.mode = .everyMonth
        XCTAssertNil(model.currentRecommendation, "switching back reruns the engine")
        XCTAssertEqual(model.comparedPlan, .starter)
        await model.loadRecommendation()
        XCTAssertEqual(engine.targets.last, .everyMonth)
    }

    func testOneTimeStartsFromThePlansLumpSum() {
        var plan = UserPlan.starter
        let lump = LumpSum(id: UUID(), amount: 3000, month: YearMonth(year: 2027, month: 4))
        plan.money.lumpSums = [lump]
        let model = CompareModel(engine: TargetRecordingEngine(start: start), plan: plan, startMonth: start)
        model.mode = .oneTime

        XCTAssertEqual(model.target, .lumpSum(id: lump.id))
        XCTAssertEqual(model.comparedPlan, plan)
    }

    func testSliderRunsASplitOffTheTenPercentGrid() async {
        let engine = TargetRecordingEngine(start: start)
        let model = CompareModel(engine: engine, plan: .starter, startMonth: start)
        await model.loadRecommendation()

        model.customShare = planDecimal("0.37")
        await model.loadCustomSplit()

        let custom = try! XCTUnwrap(model.options.first { $0.kind == .custom })
        XCTAssertEqual(custom.loanShare, planDecimal("0.37"))
        XCTAssertEqual(custom.projection, engine.project(UserPlan.starter.applyingLoanShare(planDecimal("0.37"), to: .everyMonth)))
        XCTAssertEqual(model.chosenOption?.kind, .custom)
        XCTAssertEqual(model.options.map(\.kind), [.recommended, .custom, .allToLoan, .allInvested])
    }

    func testComparingSavesNothingUntilTheChoiceIsConfirmed() async throws {
        let store = MemoryPlanStore()
        let app = AppModel(store: store, engine: TargetRecordingEngine(start: start))
        let model = CompareModel(engine: app.engine, plan: app.shownPlan, startMonth: start)

        await model.loadRecommendation()
        model.customShare = planDecimal("0.37")
        await model.loadCustomSplit()
        model.mode = .oneTime
        model.lumpSumAmount = 5000
        await model.loadRecommendation()
        XCTAssertNil(try store.load())

        let chosenAt = Date(timeIntervalSince1970: 1_800_000_000)
        let target = try XCTUnwrap(model.target)
        let result = try app.choose(loanShare: planDecimal("0.6"), for: target, in: model.comparedPlan, at: chosenAt)

        let saved = try XCTUnwrap(try store.load())
        let lump = try XCTUnwrap(saved.money.lumpSums.first)
        XCTAssertEqual(lump.amount, 5000)
        XCTAssertEqual(lump.loanShare, planDecimal("0.6"))
        XCTAssertEqual(saved.split, UserPlan.starter.split)
        XCTAssertEqual(
            saved.chosenPlan,
            ChosenPlan(mode: .oneTime, loanShare: planDecimal("0.6"), chosenAt: chosenAt, lumpSumID: lump.id)
        )
        XCTAssertEqual(result.after, app.projection)
        XCTAssertEqual(result.checklist, app.engine.checklist(saved, for: target))
        XCTAssertEqual(result.checklist?.mode, .oneTime)
        XCTAssertFalse(app.usingStarterPlan)
    }

    func testChecklistStepsNameEachPaymentFromTheEngine() {
        let named = Loan(
            id: UUID(),
            name: "Student loan",
            balance: 8000,
            disbursement: .afterJuly12023,
            rate: .fixed(annualRate: planDecimal("0.05")),
            interestStart: nil,
            minimumPayment: 150,
            repaymentTermMonths: nil,
            interestMethod: .dailyAccrualMonthlyApplication
        )
        var unnamed = named
        unnamed.id = UUID()
        unnamed.name = nil
        let fee = FeeAssumption(annualFee: planDecimal("0.002"), fundType: .indexETF, setByUser: false)
        let everyMonth = ChoiceChecklist(
            mode: .everyMonth,
            month: start,
            loanPayments: [
                ChecklistLoanPayment(loanID: named.id, minimum: 150, extra: 600, total: 750),
                ChecklistLoanPayment(loanID: unnamed.id, minimum: 150, extra: 0, total: 150),
            ],
            investing: 1400,
            investingRisesWithInflation: true,
            fee: fee
        )

        XCTAssertEqual(
            AfterChoosingView.steps(everyMonth, loans: [named, unnamed]),
            [
                "Pay $750.00 a month on Student loan: the $150.00 minimum plus $600.00 extra.",
                "Pay the $150.00 minimum on loan 2 each month.",
                "Invest $1,400.00 a month in your index ETF, such as in a TFSA. Raise it with inflation each year.",
            ]
        )

        let oneTime = ChoiceChecklist(
            mode: .oneTime,
            month: YearMonth(year: 2027, month: 4),
            loanPayments: [ChecklistLoanPayment(loanID: unnamed.id, minimum: 0, extra: 1200, total: 1200)],
            investing: 1800,
            investingRisesWithInflation: false,
            fee: fee
        )
        XCTAssertEqual(
            AfterChoosingView.steps(oneTime, loans: [unnamed]),
            [
                "In April 2027, put $1,200.00 of the one-time money toward your loan.",
                "In April 2027, invest $1,800.00 of the one-time money in your index ETF, such as in a TFSA.",
            ]
        )

        XCTAssertEqual(AfterChoosingView.feeText(fee), "0.20%, index ETF default")
        var setFee = fee
        setFee.annualFee = planDecimal("0.0035")
        setFee.setByUser = true
        XCTAssertEqual(AfterChoosingView.feeText(setFee), "0.35%, set by you")
    }

    func testChoosingEveryMonthSavesTheSplit() throws {
        let store = MemoryPlanStore()
        let app = AppModel(store: store, engine: TargetRecordingEngine(start: start))
        let chosenAt = Date(timeIntervalSince1970: 1_800_000_000)

        try app.choose(loanShare: planDecimal("0.37"), for: .everyMonth, in: app.shownPlan, at: chosenAt)

        let saved = try XCTUnwrap(try store.load())
        XCTAssertEqual(saved.split.loanShare, planDecimal("0.37"))
        XCTAssertEqual(saved.chosenPlan, ChosenPlan(mode: .everyMonth, loanShare: planDecimal("0.37"), chosenAt: chosenAt))
    }
}

/// The plan engine with dated scenarios that recommend 30%, recording each recommendation it is asked for.
private final class TargetRecordingEngine: ProjectionEngine, @unchecked Sendable {
    private let engine: PlanProjectionEngine
    private let lock = NSLock()
    private var recorded: [(plan: UserPlan, target: SplitTarget)] = []

    init(start: YearMonth) {
        engine = PlanProjectionEngine(
            start: start,
            scenarios: DatedScenarios(typicalByTenths: [3: 0, 0: 2, 10: 4], badByTenths: [3: 0, 0: 6, 10: 1])
        )
    }

    var targets: [SplitTarget] { lock.withLock { recorded.map(\.target) } }
    var plans: [UserPlan] { lock.withLock { recorded.map(\.plan) } }

    func project(_ plan: UserPlan) -> Projection {
        engine.project(plan)
    }

    func recommend(_ plan: UserPlan, for target: SplitTarget) -> SplitRecommendation? {
        lock.withLock { recorded.append((plan, target)) }
        return engine.recommend(plan, for: target)
    }

    func checklist(_ plan: UserPlan, for target: SplitTarget) -> ChoiceChecklist? {
        engine.checklist(plan, for: target)
    }
}
