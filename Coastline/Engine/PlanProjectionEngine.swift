import CoastlineEngine
import Foundation

/// Runs the projection engine for each return scenario. Screens call `project` and display the result.
struct PlanProjectionEngine: ProjectionEngine {
    /// First month of the projection. Defaults to the current calendar month.
    var start: YearMonth
    /// Produces the good, typical, and bad results. Replacing it does not change any screen.
    var scenarios: any ScenarioSource

    init(start: YearMonth? = nil, scenarios: any ScenarioSource = FixedReturnScenarios()) {
        if let start {
            self.start = start
        } else {
            let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: Date())
            self.start = YearMonth(year: parts.year ?? 2026, month: parts.month ?? 1)
        }
        self.scenarios = scenarios
    }

    func project(_ plan: UserPlan) -> Projection {
        guard let input = engineInput(plan, scenario: .typical) else { return .empty }
        return projection(scenarios.outcomes(for: input))
    }

    func recommend(_ plan: UserPlan) -> SplitRecommendation? {
        guard let input = engineInput(plan, scenario: .typical) else { return nil }
        let recommendation = Recommender.recommend(
            input,
            riskToleranceMonths: plan.assumptions.riskToleranceMonths,
            scenarios: scenarios
        )
        return SplitRecommendation(
            loanShare: recommendation.recommended.loanShare,
            safestLoanShare: recommendation.safest.loanShare,
            reason: recommendation.reason,
            typicalMonthsSooner: recommendation.typicalMonthsSooner,
            badCaseMonthsBehind: recommendation.badCaseMonthsBehind,
            projection: projection(recommendation.recommended.outcomes)
        )
    }

    private func projection(_ outcomes: ScenarioOutcomes) -> Projection {
        Projection(scenarios: ReturnScenario.allCases.map { scenario in
            scenarioProjection(outcomes[engineScenario(scenario)], scenario: scenario)
        })
    }

    private func engineInput(
        _ plan: UserPlan,
        scenario: CoastlineEngine.ProjectionScenario
    ) -> CoastlineEngine.ProjectionInput? {
        guard
            let currentAge = plan.goal.currentAge,
            let retirementAge = plan.goal.retirementAge,
            let yearlySpending = plan.goal.yearlyRetirementSpending,
            let withdrawalRate = plan.goal.withdrawalRate,
            let inflation = plan.assumptions.inflation
        else {
            return nil
        }

        let start = CoastlineEngine.YearMonth(year: self.start.year, month: clampedMonth(self.start.month))
        let loans = plan.loans.map { loan in
            CoastlineEngine.Loan(
                id: loan.id,
                balance: loan.balance,
                disbursedBeforeJuly2023: loan.disbursement == .beforeJuly12023,
                rate: engineRate(loan.rate),
                interestStart: engineMonth(loan.interestStart) ?? start,
                minimumPayment: loan.minimumPayment,
                repaymentTermMonths: loan.repaymentTermMonths,
                interestMethod: engineInterest(loan.interestMethod)
            )
        }
        let lumpSums = plan.money.lumpSums.compactMap { lump -> CoastlineEngine.LumpSum? in
            guard let month = engineMonth(year: lump.month.year, month: lump.month.month) else { return nil }
            return CoastlineEngine.LumpSum(amount: lump.amount, month: month)
        }

        return CoastlineEngine.ProjectionInput(
            start: start,
            loans: loans,
            monthlyAmount: plan.money.monthlyAmount ?? 0,
            contributionsGrowWithInflation: plan.assumptions.contributionsRiseWithInflation,
            lumpSums: lumpSums,
            loanShare: plan.split.loanShare ?? 0,
            investments: CoastlineEngine.Investments(
                balance: plan.investments.balance ?? 0,
                fundType: plan.investments.fundType == .mutualFund ? .mutualFund : .indexETF
            ),
            goal: CoastlineEngine.CoastFireGoal(
                currentAge: currentAge,
                retirementAge: retirementAge,
                yearlySpending: yearlySpending,
                withdrawalRate: withdrawalRate
            ),
            assumptions: CoastlineEngine.Assumptions(
                goodAnnualReturn: plan.assumptions.goodAnnualReturn,
                typicalAnnualReturn: plan.assumptions.typicalAnnualReturn,
                badAnnualReturn: plan.assumptions.badAnnualReturn,
                inflation: inflation,
                primeRate: plan.assumptions.primeRate ?? 0,
                annualFee: plan.assumptions.annualFee ?? 0
            ),
            scenario: scenario,
            budget: CoastlineEngine.Budget(
                categories: plan.budget.categories.map { category in
                    CoastlineEngine.BudgetCategory(amount: category.amount, role: engineRole(category.role))
                },
                emergencyFundIsFull: plan.budget.emergencyFundIsFull
            )
        )
    }

    private func scenarioProjection(
        _ result: CoastlineEngine.ProjectionResult,
        scenario: ReturnScenario
    ) -> ScenarioProjection {
        ScenarioProjection(
            scenario: scenario,
            coastFireDate: calendarDate(result.coastFireDate),
            coastFireDateIfFreedMoneyInvested: calendarDate(result.coastFireDateIfFreedMoneyInvested),
            loanPayoffDate: calendarDate(result.loanPayoffDate),
            totalInterestPaid: result.totalInterestPaid,
            months: result.months.map { month in
                MonthRecord(
                    month: YearMonth(year: month.month.year, month: month.month.month),
                    loanBalances: month.today.loans.map { loan in
                        LoanBalance(loanID: loan.id, balance: loan.balance)
                    },
                    investmentBalance: month.today.investments,
                    netWorth: month.today.netWorth,
                    cumulativeInterestPaid: month.today.cumulativeInterest
                )
            }
        )
    }

    private func engineScenario(_ scenario: ReturnScenario) -> CoastlineEngine.ProjectionScenario {
        switch scenario {
        case .good: .good
        case .typical: .typical
        case .bad: .bad
        }
    }

    private func engineInterest(_ method: Loan.InterestMethod) -> CoastlineEngine.InterestMethod {
        switch method {
        case .dailyAccrualMonthlyApplication:
            .dailyAccrualMonthlyApplication
        case .monthlyNominal:
            .monthlyNominal
        }
    }

    private func engineRate(_ rate: LoanRate) -> CoastlineEngine.LoanRate {
        switch rate {
        case .fixed(let annualRate):
            .fixed(annualRate: annualRate)
        case .floating(let marginOverPrime):
            .floating(margin: marginOverPrime)
        }
    }

    private func engineRole(_ role: PlanBudgetCategory.Role) -> CoastlineEngine.BudgetCategory.Role {
        switch role {
        case .needs: .needs
        case .emergencyFund: .emergencyFund
        case .extraLoanPayment: .extraLoanPayment
        case .investing: .investing
        case .other: .other
        }
    }

    private func engineMonth(_ date: CalendarDate?) -> CoastlineEngine.YearMonth? {
        guard let date else { return nil }
        return engineMonth(year: date.year, month: date.month)
    }

    private func engineMonth(year: Int, month: Int) -> CoastlineEngine.YearMonth? {
        guard (1...12).contains(month) else { return nil }
        return CoastlineEngine.YearMonth(year: year, month: month)
    }

    private func calendarDate(_ month: CoastlineEngine.YearMonth?) -> CalendarDate? {
        guard let month else { return nil }
        return CalendarDate(year: month.year, month: month.month, day: 1)
    }

    private func clampedMonth(_ month: Int) -> Int {
        min(max(month, 1), 12)
    }
}
