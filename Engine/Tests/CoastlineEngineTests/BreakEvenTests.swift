import XCTest
@testable import CoastlineEngine

final class BreakEvenTests: XCTestCase {
    private let start = YearMonth(year: 2026, month: 1)

    func testMonthlyInterestCompoundsOverAYearThenAddsTheFee() throws {
        let input = makeInput(loans: [makeLoan(rate: .fixed(annualRate: decimal("0.05")), method: .monthlyNominal)])
        let breakEven = try XCTUnwrap(BreakEven.annualReturn(input))
        let expected = pow(1 + 0.05 / 12, 12) - 1 + 0.002
        XCTAssertEqual(double(breakEven), expected, accuracy: 1e-12)
        XCTAssertEqual(double(breakEven), 0.0531619, accuracy: 1e-7)
    }

    func testDailyAccrualUsesEachMonthsDays() throws {
        let input = makeInput(loans: [makeLoan(rate: .fixed(annualRate: decimal("0.0365")))])
        let breakEven = try XCTUnwrap(BreakEven.annualReturn(input))
        let days2026 = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        let expected = days2026.reduce(1.0) { $0 * (1 + 0.0365 * Double($1) / 365) } - 1 + 0.002
        XCTAssertEqual(double(breakEven), expected, accuracy: 1e-12)
    }

    func testComparesWithTheHighestRateLoanThatHasABalance() throws {
        let input = makeInput(loans: [
            makeLoan(rate: .fixed(annualRate: decimal("0.04")), method: .monthlyNominal),
            makeLoan(balance: 0, rate: .fixed(annualRate: decimal("0.12")), method: .monthlyNominal),
            makeLoan(rate: .floating(margin: decimal("0.01")), method: .monthlyNominal),
        ])
        let breakEven = try XCTUnwrap(BreakEven.annualReturn(input))
        XCTAssertEqual(double(breakEven), pow(1 + 0.055 / 12, 12) - 1 + 0.002, accuracy: 1e-12)

        var lowerPrime = input
        lowerPrime.assumptions.primeRate = decimal("0.02")
        let fixedWins = try XCTUnwrap(BreakEven.annualReturn(lowerPrime))
        XCTAssertEqual(double(fixedWins), pow(1 + 0.04 / 12, 12) - 1 + 0.002, accuracy: 1e-12)
    }

    func testUnsetFeeUsesTheFundTypeDefault() throws {
        var input = makeInput(loans: [makeLoan(rate: .fixed(annualRate: decimal("0.05")), method: .monthlyNominal)])
        input.assumptions.annualFee = nil
        input.investments.fundType = .mutualFund
        let breakEven = try XCTUnwrap(BreakEven.annualReturn(input))
        XCTAssertEqual(double(breakEven), pow(1 + 0.05 / 12, 12) - 1 + 0.02, accuracy: 1e-12)
    }

    func testNoLoanBalanceHasNoBreakEven() {
        XCTAssertNil(BreakEven.annualReturn(makeInput(loans: [])))
        XCTAssertNil(BreakEven.annualReturn(makeInput(loans: [makeLoan(balance: 0, rate: .fixed(annualRate: decimal("0.05")))])))
    }

    private func makeInput(loans: [Loan]) -> ProjectionInput {
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

    private func makeLoan(
        balance: Decimal = 8000,
        rate: LoanRate,
        method: InterestMethod = .dailyAccrualMonthlyApplication
    ) -> Loan {
        Loan(
            balance: balance,
            disbursedBeforeJuly2023: false,
            rate: rate,
            interestStart: start,
            minimumPayment: 150,
            interestMethod: method
        )
    }

    private func decimal(_ value: String) -> Decimal {
        Decimal(string: value)!
    }

    private func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}
