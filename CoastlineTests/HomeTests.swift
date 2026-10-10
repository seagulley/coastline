import XCTest
@testable import Coastline

@MainActor
final class HomeTests: XCTestCase {
    private let january = YearMonth(year: 2026, month: 1)
    private let loanID = UUID(uuidString: "0A0A0A0A-1B1B-2C2C-3D3D-4E4E4E4E4E4E")!

    func testEngineReportsMonthsAwayAndEachLoanPayoff() {
        let projection = PlanProjectionEngine(start: january).project(payoffPlan())
        let typical = try! XCTUnwrap(projection.scenario(.typical))
        XCTAssertEqual(typical.coastFireDate, CalendarDate(year: 2026, month: 7, day: 1))
        XCTAssertEqual(typical.monthsUntilCoastFire, 6)
        XCTAssertEqual(typical.loanPayoffs, [PlannedPayoff(loanID: loanID, month: january, payment: 100)])
    }

    func testPayoffItemShowsInTheProjectedPayoffMonth() throws {
        let model = try savedModel(payoffPlan(), currentMonth: january)
        XCTAssertEqual(
            model.payoffItems,
            [PayoffItem(loanID: loanID, loanName: "Student loan", month: january, payment: 100)]
        )
        XCTAssertEqual(
            HomeView.payoffSentence(model.payoffItems[0]),
            "Your Student loan should be paid off in January 2026. Its $100.00 payment is free."
        )
    }

    func testComingUpIsEmptyBeforeThePayoffMonth() throws {
        var plan = payoffPlan()
        plan.loans[0].balance = 1000
        let model = try savedModel(plan, currentMonth: january)
        XCTAssertEqual(model.payoffItems, [])
    }

    func testEachAnswerHasItsOwnDatesAndNothingIsSavedUntilTheUserAnswers() async throws {
        let store = MemoryPlanStore()
        let model = try savedModel(payoffPlan(), currentMonth: january, store: store)
        let before = model.plan

        let choice = await model.payoffChoice(for: loanID)
        XCTAssertEqual(choice.invest.scenario(.typical)?.coastFireDate, CalendarDate(year: 2026, month: 7, day: 1))
        XCTAssertEqual(choice.keep.scenario(.typical)?.coastFireDate, CalendarDate(year: 2026, month: 12, day: 1))
        XCTAssertEqual(choice.invest.scenarios.map(\.scenario), [.good, .typical, .bad])
        XCTAssertEqual(model.plan, before)
        XCTAssertEqual(try store.load(), before)

        try model.answerPayoff(of: loanID, with: .keep)
        XCTAssertEqual(try store.load()?.loans[0].freedPaymentAnswer, .keep)
        XCTAssertEqual(model.projection, choice.keep)
        XCTAssertEqual(model.payoffItems, [])
    }

    func testAnswersAreSavedPerLoan() throws {
        var plan = payoffPlan()
        let otherID = UUID()
        plan.loans.append(loan(id: otherID, name: "Car loan", balance: 100))
        let model = try savedModel(plan, currentMonth: january)
        XCTAssertEqual(model.payoffItems.map(\.loanID), [loanID, otherID])

        try model.answerPayoff(of: otherID, with: .invest)
        XCTAssertEqual(model.plan.loans.map(\.freedPaymentAnswer), [nil, .invest])
        XCTAssertEqual(model.payoffItems.map(\.loanID), [loanID])
    }

    func testNotPaidOffYetHidesTheItemUntilNextMonth() throws {
        let store = MemoryPlanStore()
        let model = try savedModel(payoffPlan(), currentMonth: january, store: store)
        let projection = model.projection

        try model.hidePayoffItem(of: loanID)
        XCTAssertEqual(model.payoffItems, [])
        XCTAssertEqual(model.projection, projection)
        XCTAssertNil(model.plan.loans[0].freedPaymentAnswer)

        let nextMonth = AppModel(
            store: store,
            engine: PlanProjectionEngine(start: january.next),
            currentMonth: january.next
        )
        XCTAssertEqual(nextMonth.payoffItems.map(\.loanID), [loanID])
    }

    func testMonthlySplitComesFromTheEngine() throws {
        var plan = payoffPlan()
        plan.money.monthlyAmount = 1000
        plan.split.loanShare = planDecimal("0.35")
        let model = try savedModel(plan, currentMonth: january)
        XCTAssertEqual(
            model.monthlySplit,
            MonthlySplit(loanShare: planDecimal("0.35"), investShare: planDecimal("0.65"), toLoan: 350, toInvesting: 650)
        )
    }

    func testOldPlansWithoutAnswersStillLoad() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("coastline-home-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FilePlanStore(directory: directory)
        try store.save(payoffPlan())
        let url = directory.appendingPathComponent("plan.json")
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(text.contains("freedPaymentAnswer"))
        XCTAssertEqual(try store.load(), payoffPlan())
    }

    func testTimeAwayRoundsToYears() {
        XCTAssertEqual(PlanFormatting.timeAway(months: 0), "Reached now")
        XCTAssertEqual(PlanFormatting.timeAway(months: 1), "about 1 month away")
        XCTAssertEqual(PlanFormatting.timeAway(months: 11), "about 11 months away")
        XCTAssertEqual(PlanFormatting.timeAway(months: 17), "about 1 year away")
        XCTAssertEqual(PlanFormatting.timeAway(months: 18), "about 2 years away")
        XCTAssertEqual(PlanFormatting.timeAway(months: 89), "about 7 years away")
    }

    private func savedModel(
        _ plan: UserPlan,
        currentMonth: YearMonth,
        store: MemoryPlanStore = MemoryPlanStore()
    ) throws -> AppModel {
        try store.save(plan)
        let model = AppModel(store: store, engine: PlanProjectionEngine(start: currentMonth), currentMonth: currentMonth)
        XCTAssertFalse(model.usingStarterPlan)
        return model
    }

    /// $100 a month invested at 0% returns, and a loan repaid by its first $100 minimum payment.
    /// Coast FIRE is $1,200 invested.
    private func payoffPlan() -> UserPlan {
        var plan = UserPlan.empty
        plan.loans = [loan(id: loanID, name: "Student loan", balance: 100)]
        plan.money.monthlyAmount = 100
        plan.split.loanShare = 0
        plan.investments = Investments(balance: 0, fundType: .indexETF)
        plan.goal = CoastFireGoal(currentAge: 40, retirementAge: 45, yearlyRetirementSpending: 1200, withdrawalRate: 1)
        plan.assumptions.badAnnualReturn = 0
        plan.assumptions.typicalAnnualReturn = 0
        plan.assumptions.goodAnnualReturn = 0
        plan.assumptions.inflation = 0
        plan.assumptions.primeRate = 0
        plan.assumptions.annualFee = 0
        plan.assumptions.contributionsRiseWithInflation = false
        return plan
    }

    private func loan(id: UUID, name: String, balance: Decimal) -> Loan {
        Loan(
            id: id,
            name: name,
            balance: balance,
            disbursement: .afterJuly12023,
            rate: .fixed(annualRate: 0),
            interestStart: CalendarDate(year: 2026, month: 1, day: 1),
            minimumPayment: 100,
            repaymentTermMonths: nil,
            interestMethod: .dailyAccrualMonthlyApplication
        )
    }
}
