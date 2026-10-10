import XCTest
@testable import CoastlineEngine

final class ProjectionEngineTests: XCTestCase {
    private let start = YearMonth(year: 2026, month: 1)

    func testTodayDollarsLeaveTheStartUnchangedAndDeflateLaterMonths() {
        XCTAssertEqual(TodayDollars.convert(nominal: 1200, inflation: 1, monthIndex: 0), 1200)
        XCTAssertEqual(TodayDollars.convert(nominal: 1200, inflation: 1, monthIndex: 12), 600)
    }

    func testSnapshotSeparatesNominalBalancesFromTodaysDollars() {
        let result = project(
            monthlyAmount: 100,
            loanShare: 0,
            growContributions: false,
            inflation: 1,
            annualReturn: 0,
            retirementAge: 32
        )
        let month = try! XCTUnwrap(result.snapshot(at: 12))
        XCTAssertEqual(month.nominal.investments, 1200)
        XCTAssertEqual(
            month.today.investments,
            TodayDollars.convert(nominal: month.nominal.investments, inflation: 1, monthIndex: 12)
        )
        XCTAssertEqual(month.today.investments, 600)
        XCTAssertNotEqual(month.today.investments, month.nominal.investments)
    }

    func testInterestPaidInTodaysDollarsIsTheSumOfEachMonth() {
        let loan = makeLoan(balance: 12000, rate: decimal("0.12"), minimum: 0, method: .monthlyNominal)
        let inflated = project(loans: [loan], inflation: decimal("0.10"), retirementAge: 31)
        let flat = project(loans: [loan], inflation: 0, retirementAge: 31)

        let month = try! XCTUnwrap(inflated.snapshot(at: 12))
        let convertedEachMonth = inflated.months.reduce(Decimal(0)) { partial, snapshot in
            Cents.round(
                partial + TodayDollars.convert(
                    nominal: snapshot.interestAccrued,
                    inflation: decimal("0.10"),
                    monthIndex: snapshot.monthIndex
                )
            )
        }
        XCTAssertEqual(month.today.cumulativeInterest, convertedEachMonth)
        XCTAssertEqual(month.nominal.cumulativeInterest, flat.snapshot(at: 12)?.nominal.cumulativeInterest)
        XCTAssertNotEqual(month.today.cumulativeInterest, month.nominal.cumulativeInterest)
        XCTAssertEqual(inflated.totalInterestPaid, month.today.cumulativeInterest)
    }

    func testDailyInterestUsesDaysOver365AndDoesNotCompoundInsideTheMonth() {
        let loan = makeLoan(balance: 10000, rate: decimal("0.12"), minimum: 0)
        let result = project(loans: [loan], retirementAge: 31)
        let january = try! XCTUnwrap(result.snapshot(at: 1))
        XCTAssertEqual(january.interestAccrued, decimal("101.92"))
        XCTAssertEqual(january.nominal.balance(for: loan.id), decimal("10101.92"))
        XCTAssertEqual(january.month, start)
    }

    func testInterestWaitsForTheStartMonth() {
        let loan = makeLoan(
            balance: 10000,
            rate: decimal("0.12"),
            minimum: 0,
            interestStart: YearMonth(year: 2026, month: 2)
        )
        let result = project(loans: [loan], retirementAge: 31)
        XCTAssertEqual(result.snapshot(at: 1)?.nominal.balance(for: loan.id), 10000)
        XCTAssertEqual(result.snapshot(at: 1)?.interestAccrued, 0)
        XCTAssertEqual(result.snapshot(at: 2)?.interestAccrued, decimal("92.05"))
        XCTAssertEqual(result.snapshot(at: 2)?.nominal.balance(for: loan.id), decimal("10092.05"))
    }

    func testLeapYearFebruaryUses29DaysStillDividedBy365() {
        let loan = makeLoan(balance: 10000, rate: decimal("0.12"), minimum: 0)
        let leap = project(start: YearMonth(year: 2028, month: 2), loans: [loan], retirementAge: 31)
        let common = project(start: YearMonth(year: 2027, month: 2), loans: [loan], retirementAge: 31)
        XCTAssertEqual(leap.snapshot(at: 1)?.interestAccrued, decimal("95.34"))
        XCTAssertEqual(common.snapshot(at: 1)?.interestAccrued, decimal("92.05"))
    }

    func testMonthlyNominalInterestAndInterestFirstPayments() {
        let loan = makeLoan(balance: 1200, rate: decimal("0.10"), minimum: 10, method: .monthlyNominal)
        let interestOnly = project(loans: [loan], retirementAge: 31)
        XCTAssertEqual(interestOnly.snapshot(at: 1)?.interestAccrued, 10)
        XCTAssertEqual(interestOnly.snapshot(at: 1)?.nominal.balance(for: loan.id), 1200)

        var extra = loan
        extra.minimumPayment = 30
        let principal = project(loans: [extra], retirementAge: 31)
        XCTAssertEqual(principal.snapshot(at: 1)?.nominal.balance(for: loan.id), 1180)
    }

    func testFloatingRateIsPrimePlusMarginAndFixedIgnoresPrime() {
        let floating = makeLoan(
            balance: 1200,
            minimum: 12,
            method: .monthlyNominal,
            floatingMargin: decimal("0.02")
        )
        let fixed = makeLoan(balance: 1200, rate: decimal("0.03"), minimum: 0, method: .monthlyNominal)
        let floatingResult = project(loans: [floating], prime: decimal("0.10"), retirementAge: 31)
        let fixedResult = project(loans: [fixed], prime: decimal("0.50"), retirementAge: 31)
        XCTAssertEqual(floatingResult.snapshot(at: 1)?.interestAccrued, 12)
        XCTAssertEqual(floatingResult.snapshot(at: 6)?.interestAccrued, floatingResult.snapshot(at: 1)?.interestAccrued)
        XCTAssertEqual(fixedResult.snapshot(at: 1)?.interestAccrued, 3)
    }

    func testDisbursementDateDoesNotChangeTheProjection() {
        var before = makeLoan(balance: 5000, rate: decimal("0.07"), minimum: 100, method: .monthlyNominal)
        before.disbursedBeforeJuly2023 = true
        var after = before
        after.disbursedBeforeJuly2023 = false
        after.id = UUID()
        let early = project(loans: [before], monthlyAmount: 200, loanShare: decimal("0.4"), retirementAge: 40)
        let later = project(loans: [after], monthlyAmount: 200, loanShare: decimal("0.4"), retirementAge: 40)
        XCTAssertEqual(early.months.map(\.nominal.investments), later.months.map(\.nominal.investments))
        XCTAssertEqual(early.months.map(\.interestAccrued), later.months.map(\.interestAccrued))
        XCTAssertEqual(early.totalInterestPaid, later.totalInterestPaid)
    }

    func testMinimumsAreSeparateFromTheSplitAndExtraFollowsTheShare() {
        let loan = makeLoan(balance: 5000, rate: 0, minimum: 100)
        let invested = project(loans: [loan], monthlyAmount: 200, loanShare: 0, annualReturn: 0, retirementAge: 31)
        XCTAssertEqual(invested.snapshot(at: 1)?.nominal.balance(for: loan.id), 4900)
        XCTAssertEqual(invested.snapshot(at: 1)?.nominal.investments, 200)

        let toLoan = project(loans: [loan], monthlyAmount: 200, loanShare: 1, retirementAge: 31)
        XCTAssertEqual(toLoan.snapshot(at: 1)?.nominal.balance(for: loan.id), 4700)
        XCTAssertEqual(toLoan.snapshot(at: 1)?.nominal.investments, 0)
    }

    func testExtraPaymentGoesToTheHighestRateThenInputOrder() {
        let low = makeLoan(balance: 100, rate: decimal("0.01"), minimum: 0, method: .monthlyNominal)
        let high = makeLoan(balance: 100, rate: decimal("0.10"), minimum: 0, method: .monthlyNominal)
        let result = project(loans: [low, high], monthlyAmount: 100, loanShare: 1, retirementAge: 31)
        let highBalance = try! XCTUnwrap(result.snapshot(at: 1)?.nominal.balance(for: high.id))
        let lowBalance = try! XCTUnwrap(result.snapshot(at: 1)?.nominal.balance(for: low.id))
        XCTAssertLessThan(highBalance, lowBalance)

        let first = makeLoan(balance: 100, rate: 0, minimum: 0)
        let second = makeLoan(balance: 100, rate: 0, minimum: 0)
        let tied = project(loans: [first, second], monthlyAmount: 40, loanShare: 1, retirementAge: 31)
        XCTAssertEqual(tied.snapshot(at: 1)?.nominal.balance(for: first.id), 60)
        XCTAssertEqual(tied.snapshot(at: 1)?.nominal.balance(for: second.id), 100)
    }

    func testLumpSumIsSplitInItsMonthOnly() {
        let loan = makeLoan(balance: 1000, rate: 0, minimum: 0)
        let result = project(
            loans: [loan],
            monthlyAmount: 0,
            loanShare: decimal("0.25"),
            lumpSums: [LumpSum(amount: 100, month: YearMonth(year: 2026, month: 3))],
            annualReturn: 0,
            retirementAge: 31
        )
        XCTAssertEqual(result.snapshot(at: 2)?.nominal.investments, 0)
        XCTAssertEqual(result.snapshot(at: 2)?.nominal.balance(for: loan.id), 1000)
        XCTAssertEqual(result.snapshot(at: 3)?.nominal.investments, 75)
        XCTAssertEqual(result.snapshot(at: 3)?.nominal.balance(for: loan.id), 975)
        XCTAssertEqual(result.snapshot(at: 4)?.nominal.investments, 75)
        XCTAssertEqual(result.snapshot(at: 4)?.nominal.balance(for: loan.id), 975)
    }

    func testALumpSumCanHaveItsOwnShare() {
        let loan = makeLoan(balance: 1000, rate: 0, minimum: 0)
        let march = YearMonth(year: 2026, month: 3)
        let result = project(
            loans: [loan],
            monthlyAmount: 100,
            loanShare: 0,
            growContributions: false,
            lumpSums: [
                LumpSum(amount: 200, month: march, loanShare: decimal("0.6")),
                LumpSum(amount: 100, month: march),
            ],
            annualReturn: 0,
            retirementAge: 31
        )
        XCTAssertEqual(result.snapshot(at: 3)?.nominal.balance(for: loan.id), 880)
        XCTAssertEqual(result.snapshot(at: 3)?.nominal.investments, 300 + 80 + 100)
    }

    func testApplyingAShareToALumpSumLeavesTheMonthlySplit() {
        let lump = LumpSum(amount: 500, month: start)
        let input = makeInput(loanShare: decimal("0.3"), lumpSums: [lump])

        let monthly = input.applyingLoanShare(decimal("0.7"), to: .monthly)
        XCTAssertEqual(monthly.loanShare, decimal("0.7"))
        XCTAssertNil(monthly.lumpSums[0].loanShare)

        let oneTime = input.applyingLoanShare(decimal("0.7"), to: .lumpSum(id: lump.id))
        XCTAssertEqual(oneTime.loanShare, decimal("0.3"))
        XCTAssertEqual(oneTime.lumpSums[0].loanShare, decimal("0.7"))

        XCTAssertEqual(input.applyingLoanShare(1, to: .lumpSum(id: UUID())), input)
    }

    func testInvestingRisesWithInflationAndCanStayFlat() {
        let growing = project(monthlyAmount: 100, loanShare: 0, inflation: 1, annualReturn: 0, retirementAge: 33)
        let flat = project(
            monthlyAmount: 100,
            loanShare: 0,
            growContributions: false,
            inflation: 1,
            annualReturn: 0,
            retirementAge: 33
        )
        XCTAssertEqual(flat.snapshot(at: 13)?.nominal.investments, 1300)
        var expected = Decimal(0)
        for elapsed in 0..<13 {
            let scale = TodayDollars.inflationFactor(inflation: 1, monthIndex: elapsed)
            expected = Cents.round(expected + Cents.round(100 * scale))
        }
        XCTAssertEqual(growing.snapshot(at: 13)?.nominal.investments, expected)
        XCTAssertGreaterThan(expected, 1300)
    }

    func testContributionIsAddedBeforeGrowthAndFeesReduceTheReturn() {
        let grown = project(
            monthlyAmount: 100,
            loanShare: 0,
            investments: 1000,
            annualReturn: decimal("0.06"),
            retirementAge: 31
        )
        XCTAssertEqual(grown.snapshot(at: 1)?.nominal.investments, decimal("1105.35"))

        let fee = project(
            investments: 1000,
            annualReturn: decimal("0.06"),
            fee: decimal("0.06"),
            retirementAge: 31
        )
        XCTAssertEqual(fee.snapshot(at: 1)?.nominal.investments, 1000)
    }

    func testScenarioSelectsItsReturn() {
        let good = project(investments: 1000, retirementAge: 31, scenario: .good)
        let bad = project(investments: 1000, retirementAge: 31, scenario: .bad)
        XCTAssertEqual(good.annualReturn, Assumptions.defaultGoodAnnualReturn)
        XCTAssertEqual(bad.annualReturn, Assumptions.defaultBadAnnualReturn)
        XCTAssertEqual(good.snapshot(at: 1)?.nominal.investments, decimal("1007.97"))
        XCTAssertEqual(bad.snapshot(at: 1)?.nominal.investments, decimal("1002.47"))
    }

    func testEstimatedMinimumIsUsedUntilAStatementPaymentExists() {
        XCTAssertEqual(
            MinimumPayment.estimate(balance: 10000, annualRate: decimal("0.06"), termMonths: 12),
            decimal("860.66")
        )
        XCTAssertEqual(
            MinimumPayment.estimate(balance: 200000, annualRate: decimal("0.06"), termMonths: 360),
            decimal("1199.10")
        )
        let estimated = makeLoan(balance: 10000, rate: decimal("0.06"), minimum: nil, term: 12, method: .monthlyNominal)
        let statement = makeLoan(balance: 10000, rate: decimal("0.06"), minimum: 50, term: 12, method: .monthlyNominal)
        let estimatedResult = project(loans: [estimated], retirementAge: 31)
        let statementResult = project(loans: [statement], retirementAge: 31)
        XCTAssertEqual(estimatedResult.snapshot(at: 1)?.nominal.balance(for: estimated.id), decimal("9189.34"))
        XCTAssertEqual(statementResult.snapshot(at: 1)?.nominal.balance(for: statement.id), decimal("10000"))
    }

    func testLoanPayoffDateAndNoNegativeBalance() {
        let loan = makeLoan(balance: 1000, rate: 0, minimum: 400)
        let result = project(loans: [loan], retirementAge: 32)
        XCTAssertEqual(result.loanPayoffDate, YearMonth(year: 2026, month: 3))
        XCTAssertEqual(
            result.loanPayoffs,
            [LoanPayoff(id: loan.id, month: YearMonth(year: 2026, month: 3), payment: 400)]
        )
        XCTAssertEqual(result.snapshot(at: 3)?.nominal.balance(for: loan.id), 0)

        let small = makeLoan(balance: 100, rate: 0, minimum: 0)
        let swept = project(loans: [small], monthlyAmount: 250, loanShare: 1, annualReturn: 0, retirementAge: 31)
        XCTAssertEqual(swept.snapshot(at: 1)?.nominal.balance(for: small.id), 0)
        XCTAssertEqual(swept.snapshot(at: 1)?.nominal.investments, 150)
        XCTAssertEqual(swept.snapshot(at: 1)?.nominal.netWorth, 150)
    }

    func testCoastFireUsesRealReturnAndTodaysDollars() {
        let already = project(
            investments: decimal("748356.84"),
            inflation: decimal("0.02"),
            annualReturn: decimal("0.05"),
            spending: 40000,
            withdrawal: decimal("0.04"),
            currentAge: 55,
            retirementAge: 65
        )
        XCTAssertEqual(already.coastFireDate, start)

        let short = project(
            investments: decimal("748356.82"),
            inflation: decimal("0.02"),
            annualReturn: decimal("0.05"),
            spending: 40000,
            withdrawal: decimal("0.04"),
            currentAge: 55,
            retirementAge: 65
        )
        XCTAssertNotEqual(short.coastFireDate, start)

        let unreachable = project(investments: 0, spending: 40000, withdrawal: decimal("0.04"), retirementAge: 31)
        XCTAssertNil(unreachable.coastFireDate)

        let real = CoastFireMath.realReturn(nominalAnnualReturn: decimal("0.05"), inflation: decimal("0.02"))
        XCTAssertEqual(real, (1 + decimal("0.05")) / (1 + decimal("0.02")) - 1)
    }

    func testCoastFireCheckUsesTheReturnAfterFees() {
        func coastDate(_ balance: String, annualReturn: String, fee: String) -> YearMonth? {
            project(
                investments: decimal(balance),
                inflation: decimal("0.02"),
                annualReturn: decimal(annualReturn),
                fee: decimal(fee),
                spending: 40000,
                withdrawal: decimal("0.04"),
                currentAge: 55,
                retirementAge: 65
            ).coastFireDate
        }
        XCTAssertEqual(coastDate("748356.84", annualReturn: "0.06", fee: "0.01"), start)
        XCTAssertNotEqual(coastDate("748356.82", annualReturn: "0.06", fee: "0.01"), start)
        XCTAssertEqual(coastDate("748356.82", annualReturn: "0.06", fee: "0"), start)
    }

    func testUnsetFeeUsesTheFundTypeDefault() {
        XCTAssertEqual(FundType.indexETF.defaultAnnualFee, decimal("0.002"))
        XCTAssertEqual(FundType.mutualFund.defaultAnnualFee, decimal("0.02"))

        func balance(annualReturn: String, fee: Decimal?, fundType: FundType) -> Decimal? {
            project(
                investments: 100000,
                annualReturn: decimal(annualReturn),
                fee: fee,
                fundType: fundType,
                retirementAge: 31
            ).snapshot(at: 12)?.nominal.investments
        }
        XCTAssertEqual(
            balance(annualReturn: "0.065", fee: nil, fundType: .indexETF),
            balance(annualReturn: "0.063", fee: 0, fundType: .indexETF)
        )
        XCTAssertEqual(
            balance(annualReturn: "0.065", fee: nil, fundType: .mutualFund),
            balance(annualReturn: "0.045", fee: 0, fundType: .mutualFund)
        )
    }

    func testFeeTheUserSetStaysWhenFundTypeChanges() {
        let etf = project(investments: 100000, fee: decimal("0.005"), fundType: .indexETF, retirementAge: 31)
        let mutual = project(investments: 100000, fee: decimal("0.005"), fundType: .mutualFund, retirementAge: 31)
        XCTAssertEqual(etf.snapshot(at: 12)?.nominal.investments, mutual.snapshot(at: 12)?.nominal.investments)
    }

    func testFreedPaymentFollowsTheBudgetAndAllToInvestingIsReported() {
        let paidOff = makeLoan(balance: 1000, rate: 0, minimum: 1000)
        let remaining = makeLoan(balance: 5000, rate: 0, minimum: 100)
        let budget = Budget(
            categories: [
                BudgetCategory(amount: 2000, role: .needs),
                BudgetCategory(amount: 500, role: .emergencyFund),
                BudgetCategory(amount: 300, role: .investing),
                BudgetCategory(amount: 100, role: .extraLoanPayment),
                BudgetCategory(amount: 100, role: .other),
            ],
            emergencyFundIsFull: true
        )
        let result = project(
            loans: [paidOff, remaining],
            annualReturn: 0,
            spending: 800,
            withdrawal: 1,
            currentAge: 40,
            retirementAge: 45,
            budget: budget
        )
        XCTAssertEqual(result.suggestedFreedMoneySplit.loanShare, decimal("0.2"))
        XCTAssertEqual(result.suggestedFreedMoneySplit.investShare, decimal("0.6"))
        XCTAssertEqual(result.snapshot(at: 1)?.nominal.balance(for: remaining.id), 4900)
        XCTAssertEqual(result.snapshot(at: 1)?.nominal.investments, 0)
        XCTAssertEqual(result.snapshot(at: 2)?.nominal.balance(for: remaining.id), 4600)
        XCTAssertEqual(result.snapshot(at: 2)?.nominal.investments, 600)
        XCTAssertEqual(result.coastFireDate, YearMonth(year: 2026, month: 3))
        XCTAssertEqual(result.coastFireDateIfFreedMoneyInvested, YearMonth(year: 2026, month: 2))

        var withoutNeeds = budget
        withoutNeeds.categories[0].amount = 0
        let sameSplit = project(
            loans: [paidOff, remaining],
            annualReturn: 0,
            spending: 800,
            withdrawal: 1,
            currentAge: 40,
            retirementAge: 45,
            budget: withoutNeeds
        )
        XCTAssertEqual(
            sameSplit.months.map(\.nominal.investments),
            result.months.map(\.nominal.investments)
        )
    }

    func testEmergencyFundCountsWhenItIsNotFull() {
        let paidOff = makeLoan(balance: 1000, rate: 0, minimum: 1000)
        let remaining = makeLoan(balance: 5000, rate: 0, minimum: 100)
        let budget = Budget(
            categories: [
                BudgetCategory(amount: 500, role: .emergencyFund),
                BudgetCategory(amount: 300, role: .investing),
                BudgetCategory(amount: 100, role: .extraLoanPayment),
                BudgetCategory(amount: 100, role: .other),
            ],
            emergencyFundIsFull: false
        )
        let result = project(
            loans: [paidOff, remaining],
            annualReturn: 0,
            currentAge: 40,
            retirementAge: 45,
            budget: budget
        )
        XCTAssertEqual(result.suggestedFreedMoneySplit.loanShare, decimal("0.1"))
        XCTAssertEqual(result.suggestedFreedMoneySplit.investShare, decimal("0.3"))
        XCTAssertEqual(result.snapshot(at: 2)?.nominal.investments, 300)
        XCTAssertEqual(result.snapshot(at: 2)?.nominal.balance(for: remaining.id), 4700)
    }

    func testLoanShareOfFreedMoneyIsInvestedOnceNoLoanIsLeft() {
        let loan = makeLoan(balance: 100, rate: 0, minimum: 100)
        let budget = Budget(
            categories: [BudgetCategory(amount: 100, role: .extraLoanPayment)],
            emergencyFundIsFull: true
        )
        let result = project(
            loans: [loan],
            annualReturn: 0,
            spending: 50,
            withdrawal: 1,
            currentAge: 40,
            retirementAge: 45,
            budget: budget
        )
        XCTAssertEqual(result.suggestedFreedMoneySplit.loanShare, 1)
        XCTAssertEqual(result.snapshot(at: 2)?.nominal.investments, 100)
        XCTAssertEqual(result.coastFireDate, YearMonth(year: 2026, month: 2))
        XCTAssertEqual(result.coastFireDateIfFreedMoneyInvested, YearMonth(year: 2026, month: 2))
    }

    func testWithNoBudgetAFreedPaymentIsInvested() {
        let paidOff = makeLoan(balance: 1000, rate: 0, minimum: 1000)
        let remaining = makeLoan(balance: 5000, rate: 0, minimum: 100)
        let result = project(loans: [paidOff, remaining], annualReturn: 0, currentAge: 40, retirementAge: 45)
        XCTAssertEqual(result.suggestedFreedMoneySplit, FreedMoneySplit(loanShare: 0, investShare: 1))
        XCTAssertEqual(result.snapshot(at: 1)?.nominal.investments, 0)
        XCTAssertEqual(result.snapshot(at: 2)?.nominal.investments, 1000)
        XCTAssertEqual(result.snapshot(at: 2)?.nominal.balance(for: remaining.id), 4800)
        XCTAssertEqual(
            result.months.map(\.nominal.investments),
            project(
                loans: [paidOff, remaining],
                annualReturn: 0,
                currentAge: 40,
                retirementAge: 45,
                answers: [paidOff.id: .invest]
            ).months.map(\.nominal.investments)
        )
    }

    func testABudgetWithOnlyNeedsStillInvestsTheFreedPayment() {
        let loan = makeLoan(balance: 100, rate: 0, minimum: 100)
        let budget = Budget(categories: [BudgetCategory(amount: 2000, role: .needs)], emergencyFundIsFull: true)
        let result = project(loans: [loan], annualReturn: 0, currentAge: 40, retirementAge: 45, budget: budget)
        XCTAssertEqual(result.suggestedFreedMoneySplit, FreedMoneySplit(loanShare: 0, investShare: 1))
        XCTAssertEqual(result.snapshot(at: 2)?.nominal.investments, 100)
    }

    func testLoanSliceOfALumpSumIsInvestedOnceNoLoanIsLeft() {
        let loan = makeLoan(balance: 100, rate: 0, minimum: 100)
        let result = project(
            loans: [loan],
            loanShare: 1,
            lumpSums: [LumpSum(amount: 500, month: YearMonth(year: 2026, month: 3))],
            annualReturn: 0,
            currentAge: 40,
            retirementAge: 45
        )
        XCTAssertEqual(result.snapshot(at: 2)?.nominal.investments, 100)
        XCTAssertEqual(result.snapshot(at: 3)?.nominal.investments, 700)
    }

    func testKeepingAFreedPaymentStillDropsIt() {
        let loan = makeLoan(balance: 100, rate: 0, minimum: 100)
        let result = project(
            loans: [loan],
            annualReturn: 0,
            currentAge: 40,
            retirementAge: 45,
            answers: [loan.id: .keep]
        )
        XCTAssertEqual(result.snapshot(at: 12)?.nominal.investments, 0)
    }

    func testEachLoanFollowsItsOwnAnswer() {
        let first = makeLoan(balance: 100, rate: 0, minimum: 100)
        let second = makeLoan(balance: 200, rate: 0, minimum: 100)
        let remaining = makeLoan(balance: 5000, rate: 0, minimum: 100)
        let answered = project(
            loans: [first, second, remaining],
            annualReturn: 0,
            currentAge: 40,
            retirementAge: 45,
            answers: [first.id: .keep, second.id: .invest]
        )
        XCTAssertEqual(answered.snapshot(at: 2)?.nominal.investments, 0)
        XCTAssertEqual(answered.snapshot(at: 3)?.nominal.investments, 100)
        XCTAssertEqual(answered.snapshot(at: 4)?.nominal.investments, 200)
        XCTAssertEqual(answered.snapshot(at: 4)?.nominal.balance(for: remaining.id), 4600)

        let unanswered = project(loans: [first, second, remaining], annualReturn: 0, currentAge: 40, retirementAge: 45)
        XCTAssertEqual(unanswered.snapshot(at: 2)?.nominal.investments, 100)
        XCTAssertEqual(unanswered.snapshot(at: 3)?.nominal.investments, 300)
        XCTAssertEqual(unanswered.snapshot(at: 4)?.nominal.investments, 500)
    }

    func testPayoffReportsTheFreedPayment() {
        let statement = makeLoan(balance: 300, rate: 0, minimum: 150)
        let estimated = makeLoan(balance: 1200, rate: 0, minimum: nil, term: 12)
        let result = project(loans: [statement, estimated], annualReturn: 0, currentAge: 40, retirementAge: 45)
        XCTAssertEqual(
            Set(result.loanPayoffs),
            [
                LoanPayoff(id: statement.id, month: YearMonth(year: 2026, month: 2), payment: 150),
                LoanPayoff(id: estimated.id, month: YearMonth(year: 2026, month: 12), payment: 100),
            ]
        )
    }

    func testAllocationSplitsWithinTheAmount() {
        XCTAssertTrue(Allocation.split(1000, loanShare: decimal("0.4")) == (400, 600))
        XCTAssertTrue(Allocation.split(100, loanShare: decimal("1.5")) == (100, 0))
        XCTAssertTrue(Allocation.split(-50, loanShare: decimal("0.5")) == (0, 0))
    }

    func testAnswerReplacesTheSuggestion() {
        let paidOff = makeLoan(balance: 1000, rate: 0, minimum: 1000)
        let remaining = makeLoan(balance: 5000, rate: 0, minimum: 100)
        let budget = Budget(
            categories: [
                BudgetCategory(amount: 300, role: .investing),
                BudgetCategory(amount: 100, role: .extraLoanPayment),
                BudgetCategory(amount: 100, role: .other),
            ],
            emergencyFundIsFull: true
        )
        let result = project(
            loans: [paidOff, remaining],
            annualReturn: 0,
            currentAge: 40,
            retirementAge: 45,
            budget: budget,
            answers: [paidOff.id: .invest]
        )
        XCTAssertEqual(result.suggestedFreedMoneySplit.loanShare, decimal("0.2"))
        XCTAssertEqual(result.suggestedFreedMoneySplit.investShare, decimal("0.6"))
        XCTAssertEqual(result.snapshot(at: 2)?.nominal.balance(for: remaining.id), 4800)
        XCTAssertEqual(result.snapshot(at: 2)?.nominal.investments, 1000)
    }

    func testExtraLoanMoneyIsInvestedOnceEveryLoanIsRepaid() {
        let loan = makeLoan(balance: 100, rate: 0, minimum: 0)
        let budget = Budget(
            categories: [
                BudgetCategory(amount: 300, role: .investing),
                BudgetCategory(amount: 100, role: .extraLoanPayment),
                BudgetCategory(amount: 100, role: .other),
            ],
            emergencyFundIsFull: true
        )
        let result = project(
            loans: [loan],
            monthlyAmount: 200,
            loanShare: decimal("0.5"),
            annualReturn: 0,
            spending: 300,
            withdrawal: 1,
            currentAge: 40,
            retirementAge: 45,
            budget: budget
        )
        XCTAssertEqual(result.loanPayoffDate, start)
        XCTAssertEqual(result.snapshot(at: 1)?.nominal.investments, 100)
        XCTAssertEqual(result.snapshot(at: 2)?.nominal.investments, 300)
        XCTAssertEqual(result.coastFireDate, YearMonth(year: 2026, month: 2))
        XCTAssertEqual(result.coastFireDateIfFreedMoneyInvested, YearMonth(year: 2026, month: 2))
    }

    func testNetWorthIsInvestmentsMinusLoans() {
        let loan = makeLoan(balance: 400, rate: 0, minimum: 0)
        let result = project(loans: [loan], investments: 1000, retirementAge: 31)
        XCTAssertEqual(result.snapshot(at: 0)?.nominal.netWorth, 600)
        XCTAssertEqual(result.snapshot(at: 0)?.today.netWorth, 600)
    }

    func testDefaultReturnsMatchTheDecidedRates() {
        XCTAssertEqual(Assumptions.defaultBadAnnualReturn, decimal("0.03"))
        XCTAssertEqual(Assumptions.defaultTypicalAnnualReturn, decimal("0.065"))
        XCTAssertEqual(Assumptions.defaultGoodAnnualReturn, decimal("0.10"))
    }

    private func project(
        start: YearMonth? = nil,
        loans: [Loan] = [],
        monthlyAmount: Decimal = 0,
        loanShare: Decimal = 0,
        growContributions: Bool = true,
        lumpSums: [LumpSum] = [],
        investments: Decimal = 0,
        inflation: Decimal = 0,
        prime: Decimal = 0,
        annualReturn: Decimal? = nil,
        fee: Decimal? = 0,
        fundType: FundType = .indexETF,
        spending: Decimal = 40000,
        withdrawal: Decimal = 4 / Decimal(100),
        currentAge: Int = 30,
        retirementAge: Int = 65,
        scenario: ProjectionScenario = .typical,
        budget: Budget = Budget(),
        answers: [UUID: FreedPaymentAnswer] = [:]
    ) -> ProjectionResult {
        ProjectionEngine.project(makeInput(
            start: start,
            loans: loans,
            monthlyAmount: monthlyAmount,
            loanShare: loanShare,
            growContributions: growContributions,
            lumpSums: lumpSums,
            investments: investments,
            inflation: inflation,
            prime: prime,
            annualReturn: annualReturn,
            fee: fee,
            fundType: fundType,
            spending: spending,
            withdrawal: withdrawal,
            currentAge: currentAge,
            retirementAge: retirementAge,
            scenario: scenario,
            budget: budget,
            answers: answers
        ))
    }

    private func makeInput(
        start: YearMonth? = nil,
        loans: [Loan] = [],
        monthlyAmount: Decimal = 0,
        loanShare: Decimal = 0,
        growContributions: Bool = true,
        lumpSums: [LumpSum] = [],
        investments: Decimal = 0,
        inflation: Decimal = 0,
        prime: Decimal = 0,
        annualReturn: Decimal? = nil,
        fee: Decimal? = 0,
        fundType: FundType = .indexETF,
        spending: Decimal = 40000,
        withdrawal: Decimal = 4 / Decimal(100),
        currentAge: Int = 30,
        retirementAge: Int = 65,
        scenario: ProjectionScenario = .typical,
        budget: Budget = Budget(),
        answers: [UUID: FreedPaymentAnswer] = [:]
    ) -> ProjectionInput {
        let returns = annualReturn ?? Assumptions.defaultTypicalAnnualReturn
        return ProjectionInput(
            start: start ?? self.start,
            loans: loans,
            monthlyAmount: monthlyAmount,
            contributionsGrowWithInflation: growContributions,
            lumpSums: lumpSums,
            loanShare: loanShare,
            investments: Investments(balance: investments, fundType: fundType),
            goal: CoastFireGoal(
                currentAge: currentAge,
                retirementAge: retirementAge,
                yearlySpending: spending,
                withdrawalRate: withdrawal
            ),
            assumptions: Assumptions(
                goodAnnualReturn: scenario == .good && annualReturn != nil ? returns : Assumptions.defaultGoodAnnualReturn,
                typicalAnnualReturn: annualReturn ?? Assumptions.defaultTypicalAnnualReturn,
                badAnnualReturn: scenario == .bad && annualReturn != nil ? returns : Assumptions.defaultBadAnnualReturn,
                inflation: inflation,
                primeRate: prime,
                annualFee: fee
            ),
            scenario: scenario,
            budget: budget,
            freedPaymentAnswers: answers
        )
    }

    private func makeLoan(
        balance: Decimal,
        rate: Decimal = 0,
        minimum: Decimal? = 0,
        term: Int? = nil,
        method: InterestMethod = .dailyAccrualMonthlyApplication,
        interestStart: YearMonth? = nil,
        floatingMargin: Decimal? = nil
    ) -> Loan {
        let loanRate: LoanRate
        if let floatingMargin {
            loanRate = .floating(margin: floatingMargin)
        } else {
            loanRate = .fixed(annualRate: rate)
        }
        return Loan(
            balance: balance,
            disbursedBeforeJuly2023: false,
            rate: loanRate,
            interestStart: interestStart ?? start,
            minimumPayment: minimum,
            repaymentTermMonths: term,
            interestMethod: method
        )
    }

    private func decimal(_ value: String) -> Decimal {
        Decimal(string: value)!
    }
}

private extension Decimal {
    static func == (lhs: Decimal, rhs: Int) -> Bool {
        lhs == Decimal(rhs)
    }
}
