import Foundation

public enum ProjectionEngine {
    public static func project(_ input: ProjectionInput) -> ProjectionResult {
        let annualReturn = input.assumptions.annualReturn(for: input.scenario)
        let suggested = FreedMoney.suggestedShares(from: input.budget)
        let applied = input.chosenFreedMoneySplit.map(FreedShares.init) ?? suggested
        let primary = simulate(input, annualReturn: annualReturn, freedShares: applied)
        let investedFreed = simulate(input, annualReturn: annualReturn, freedShares: .allToInvesting)
        let presented = present(primary.months, input: input, annualReturn: annualReturn)
        let investedCoastDate = present(investedFreed.months, input: input, annualReturn: annualReturn).coastFireDate

        let payoffMonths = primary.payoffMonthIndex.compactMap { id, monthIndex -> LoanPayoff? in
            guard let month = primary.months.first(where: { $0.monthIndex == monthIndex })?.month else { return nil }
            return LoanPayoff(id: id, month: month)
        }
        .sorted { $0.id.uuidString < $1.id.uuidString }

        let loansThatCount = input.loans.filter { $0.balance > 0 }.map(\.id)
        let loanPayoffDate: YearMonth?
        if loansThatCount.isEmpty {
            loanPayoffDate = nil
        } else if loansThatCount.allSatisfy({ primary.payoffMonthIndex[$0] != nil }) {
            let lastIndex = loansThatCount.compactMap { primary.payoffMonthIndex[$0] }.max() ?? 0
            loanPayoffDate = primary.months.first { $0.monthIndex == lastIndex }?.month
        } else {
            loanPayoffDate = nil
        }

        return ProjectionResult(
            scenario: input.scenario,
            annualReturn: annualReturn,
            months: presented.snapshots,
            coastFireDate: presented.coastFireDate,
            coastFireDateIfFreedMoneyInvested: investedCoastDate,
            loanPayoffDate: loanPayoffDate,
            loanPayoffs: payoffMonths,
            totalInterestPaid: presented.snapshots.last?.today.cumulativeInterest ?? 0,
            suggestedFreedMoneySplit: FreedMoneySplit(
                loanShare: suggested.loanShare,
                investShare: suggested.investShare
            )
        )
    }

    private static func simulate(
        _ input: ProjectionInput,
        annualReturn: Decimal,
        freedShares: FreedShares
    ) -> (months: [NominalMonth], payoffMonthIndex: [UUID: Int]) {
        let netAnnual = annualReturn - input.annualFee
        let growthBase = 1 + netAnnual
        let growthFactor = growthBase > 0 ? Compounding.power(growthBase, 1 / Decimal(12)) : 0
        let horizon = max(0, input.goal.retirementAge - input.goal.currentAge) * 12
        let loans = input.loans.enumerated().map { offset, loan in
            let balance = Cents.round(max(loan.balance, 0))
            return NominalSimulator.LoanState(
                id: loan.id,
                balance: balance,
                rate: loan.rate,
                annualRate: loan.rate.annualRate(prime: input.assumptions.primeRate),
                interestStart: loan.interestStart,
                minimumPayment: resolvedMinimum(loan, prime: input.assumptions.primeRate),
                interestMethod: loan.interestMethod,
                order: offset,
                countsTowardPayoff: balance > 0
            )
        }
        var simulator = NominalSimulator(
            start: input.start,
            loans: loans,
            monthlyAmount: input.monthlyAmount,
            loanShare: input.loanShare,
            contributionsGrowWithInflation: input.contributionsGrowWithInflation,
            lumpSums: input.lumpSums,
            investments: input.investments.balance,
            inflation: input.assumptions.inflation,
            primeRate: input.assumptions.primeRate,
            growthFactor: growthFactor,
            freedShares: freedShares,
            horizonMonths: horizon
        )
        return simulator.run()
    }

    private static func resolvedMinimum(_ loan: Loan, prime: Decimal) -> Decimal {
        if let minimumPayment = loan.minimumPayment {
            return Cents.round(max(minimumPayment, 0))
        }
        guard let term = loan.repaymentTermMonths, term > 0 else { return 0 }
        return MinimumPayment.estimate(
            balance: max(loan.balance, 0),
            annualRate: loan.rate.annualRate(prime: prime),
            termMonths: term
        )
    }

    private static func present(
        _ months: [NominalMonth],
        input: ProjectionInput,
        annualReturn: Decimal
    ) -> (snapshots: [MonthSnapshot], coastFireDate: YearMonth?) {
        let inflation = input.assumptions.inflation
        var coastFireDate: YearMonth?
        var cumulativeInterestToday: Decimal = 0
        let snapshots = months.map { month -> MonthSnapshot in
            let nominalLoans = month.loanBalances
            let nominalDebt = nominalLoans.reduce(Decimal(0)) { $0 + $1.balance }
            let nominal = MonthFigures(
                loans: nominalLoans,
                investments: month.investments,
                netWorth: Cents.round(month.investments - nominalDebt),
                cumulativeInterest: month.cumulativeInterest
            )
            let todayLoans = nominalLoans.map { loan in
                LoanBalance(
                    id: loan.id,
                    balance: TodayDollars.convert(
                        nominal: loan.balance,
                        inflation: inflation,
                        monthIndex: month.monthIndex
                    )
                )
            }
            let todayInvestments = TodayDollars.convert(
                nominal: month.investments,
                inflation: inflation,
                monthIndex: month.monthIndex
            )
            let todayDebt = todayLoans.reduce(Decimal(0)) { $0 + $1.balance }
            let todayInterest = TodayDollars.convert(
                nominal: month.interestAccrued,
                inflation: inflation,
                monthIndex: month.monthIndex
            )
            cumulativeInterestToday = Cents.round(cumulativeInterestToday + todayInterest)
            let today = MonthFigures(
                loans: todayLoans,
                investments: todayInvestments,
                netWorth: Cents.round(todayInvestments - todayDebt),
                cumulativeInterest: cumulativeInterestToday
            )
            if coastFireDate == nil,
               coastReached(todayInvestments, monthIndex: month.monthIndex, input: input, annualReturn: annualReturn) {
                coastFireDate = month.month
            }
            return MonthSnapshot(
                monthIndex: month.monthIndex,
                month: month.month,
                nominal: nominal,
                today: today,
                interestAccrued: month.interestAccrued
            )
        }
        return (snapshots, coastFireDate)
    }

    private static func coastReached(
        _ investmentsToday: Decimal,
        monthIndex: Int,
        input: ProjectionInput,
        annualReturn: Decimal
    ) -> Bool {
        guard let coastNumber = CoastFireMath.coastNumber(
            yearlySpending: input.goal.yearlySpending,
            withdrawalRate: input.goal.withdrawalRate,
            nominalAnnualReturn: annualReturn - input.annualFee,
            inflation: input.assumptions.inflation,
            yearsLeft: CoastFireMath.yearsLeft(goal: input.goal, monthIndex: monthIndex)
        ) else {
            return false
        }
        return investmentsToday >= coastNumber
    }
}
