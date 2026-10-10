import XCTest
@testable import Coastline

final class PlanStoreTests: XCTestCase {
    func testMissingFileLoadsAsNil() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FilePlanStore(directory: directory)
        let loaded = try store.load()
        XCTAssertNil(loaded)
    }

    func testRoundTripKeepsInputsAssumptionsAndChosenPlan() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FilePlanStore(directory: directory)
        let plan = samplePlan()

        try store.save(plan)
        let loaded = try store.load()

        XCTAssertEqual(loaded, plan)
        let text = try String(contentsOf: directory.appendingPathComponent("plan.json"), encoding: .utf8)
        XCTAssertFalse(text.contains("coastFire"))
        XCTAssertFalse(text.contains("netWorth"))
    }

    func testCorruptFileThrows() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("not json".utf8).write(to: directory.appendingPathComponent("plan.json"))
        let store = FilePlanStore(directory: directory)
        XCTAssertThrowsError(try store.load())
    }
}

@MainActor
final class AppModelTests: XCTestCase {
    func testEmptyStoreShowsTheStarterScenarios() {
        let model = AppModel(
            store: MemoryPlanStore(),
            engine: PlanProjectionEngine(start: YearMonth(year: 2026, month: 1))
        )

        XCTAssertFalse(model.hasStoredPlan)
        XCTAssertEqual(model.plan, .empty)
        XCTAssertTrue(model.usingStarterPlan)
        XCTAssertEqual(model.projection.scenarios.map(\.scenario), [.good, .typical, .bad])
    }

    func testLaunchWithNoFileShowsNothingSavedAndAsksTheEngine() {
        let engine = RecordingEngine()
        let model = AppModel(store: MemoryPlanStore(), engine: engine)

        XCTAssertFalse(model.hasStoredPlan)
        XCTAssertEqual(model.plan, .empty)
        XCTAssertNil(model.storageError)
        XCTAssertEqual(model.projection, .empty)
        XCTAssertFalse(model.usingStarterPlan)
        XCTAssertEqual(engine.plans, [.empty, .starter])
        XCTAssertEqual(model.plan.assumptions, .defaults)
    }

    func testApplySavesAndReloadsWithoutStoringTheProjection() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FilePlanStore(directory: directory)
        let engine = RecordingEngine()
        let model = AppModel(store: store, engine: engine)
        let plan = samplePlan()

        try model.apply(plan)

        XCTAssertTrue(model.hasStoredPlan)
        XCTAssertEqual(model.plan, plan)
        XCTAssertEqual(engine.plans, [.empty, .starter, plan, .starter])

        let reloaded = AppModel(store: FilePlanStore(directory: directory), engine: RecordingEngine())
        XCTAssertTrue(reloaded.hasStoredPlan)
        XCTAssertEqual(reloaded.plan, plan)
        XCTAssertEqual(reloaded.projection, .empty)
    }

    func testSavingTheStarterPlanRecordsTheChosenSplitAndReloads() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let engine = PlanProjectionEngine(start: YearMonth(year: 2026, month: 1))
        let model = AppModel(store: FilePlanStore(directory: directory), engine: engine)
        XCTAssertTrue(model.usingStarterPlan)

        let chosenAt = Date(timeIntervalSince1970: 1_800_000_000)
        try model.saveShownPlan(at: chosenAt)

        XCTAssertTrue(model.hasStoredPlan)
        XCTAssertFalse(model.usingStarterPlan)
        let expected = ChosenPlan(mode: .everyMonth, loanShare: 0, chosenAt: chosenAt)
        XCTAssertEqual(model.plan.chosenPlan, expected)

        let reloaded = AppModel(store: FilePlanStore(directory: directory), engine: engine)
        XCTAssertTrue(reloaded.hasStoredPlan)
        XCTAssertFalse(reloaded.usingStarterPlan)
        XCTAssertEqual(reloaded.plan, model.plan)
        XCTAssertEqual(reloaded.projection, model.projection)
    }

    func testProjectionIsWhateverTheEngineReturns() {
        let engine = RecordingEngine()
        let produced = Projection(scenarios: [
            ScenarioProjection(
                scenario: .typical,
                coastFireDate: CalendarDate(year: 2033, month: 11, day: 1)
            )
        ])
        engine.result = produced

        let model = AppModel(store: MemoryPlanStore(), engine: engine)

        XCTAssertEqual(model.projection, produced)
    }

    func testUnreadablePlanDoesNotInventData() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("not json".utf8).write(to: directory.appendingPathComponent("plan.json"))

        let model = AppModel(store: FilePlanStore(directory: directory), engine: RecordingEngine())

        XCTAssertFalse(model.hasStoredPlan)
        XCTAssertEqual(model.plan, .empty)
        XCTAssertEqual(model.storageError, "The saved plan could not be read.")
        XCTAssertEqual(model.projection, .empty)
    }

    func testFailedSaveLeavesThePreviousPlan() {
        let model = AppModel(store: FailingPlanStore(), engine: RecordingEngine())
        XCTAssertThrowsError(try model.apply(samplePlan()))
        XCTAssertEqual(model.plan, .empty)
        XCTAssertFalse(model.hasStoredPlan)
    }
}

final class PlanFormattingTests: XCTestCase {
    func testMonthAndYearUsesTheCoastFireDisplayForm() {
        let label = PlanFormatting.monthAndYear(CalendarDate(year: 2033, month: 11, day: 1))
        XCTAssertEqual(label, "November 2033")
    }
}

private final class RecordingEngine: ProjectionEngine {
    var result = Projection.empty
    private(set) var plans: [UserPlan] = []

    func project(_ plan: UserPlan) -> Projection {
        plans.append(plan)
        return result
    }
}

private final class FailingPlanStore: PlanStore {
    struct SaveFailed: Error {}

    func load() throws -> UserPlan? { nil }

    func save(_: UserPlan) throws {
        throw SaveFailed()
    }
}

private func samplePlan() -> UserPlan {
    UserPlan(
        loans: [
            Loan(
                id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
                balance: planDecimal("12000.50"),
                disbursement: .beforeJuly12023,
                rate: .floating(marginOverPrime: planDecimal("0.01")),
                interestStart: CalendarDate(year: 2026, month: 9, day: 1),
                minimumPayment: planDecimal("210"),
                repaymentTermMonths: 84,
                interestMethod: .dailyAccrualMonthlyApplication
            ),
            Loan(
                id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
                balance: planDecimal("4000"),
                disbursement: .afterJuly12023,
                rate: .fixed(annualRate: planDecimal("0.049")),
                interestStart: nil,
                minimumPayment: nil,
                repaymentTermMonths: nil,
                interestMethod: .dailyAccrualMonthlyApplication
            )
        ],
        money: MoneyToAllocate(
            monthlyAmount: planDecimal("800"),
            lumpSums: [
                LumpSum(
                    id: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!,
                    amount: planDecimal("1500"),
                    month: YearMonth(year: 2027, month: 4)
                )
            ]
        ),
        split: AllocationSplit(loanShare: planDecimal("0.4")),
        investments: Investments(balance: planDecimal("25000"), fundType: .indexETF),
        goal: CoastFireGoal(
            currentAge: 32,
            retirementAge: 65,
            yearlyRetirementSpending: planDecimal("48000"),
            withdrawalRate: planDecimal("0.04")
        ),
        assumptions: Assumptions(
            badAnnualReturn: planDecimal("0.03"),
            typicalAnnualReturn: planDecimal("0.065"),
            goodAnnualReturn: planDecimal("0.10"),
            inflation: planDecimal("0.021"),
            primeRate: planDecimal("0.047"),
            annualFee: planDecimal("0.002"),
            riskToleranceMonths: 12,
            contributionsRiseWithInflation: true
        ),
        chosenPlan: ChosenPlan(
            mode: .everyMonth,
            loanShare: planDecimal("0.4"),
            chosenAt: Date(timeIntervalSince1970: 1_700_000_000)
        ),
        budget: .empty
    )
}

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("coastline-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
