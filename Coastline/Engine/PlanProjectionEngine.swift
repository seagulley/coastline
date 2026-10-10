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

    func recommend(_ plan: UserPlan, for target: SplitTarget) -> SplitRecommendation? {
        guard let input = engineInput(plan, scenario: .typical) else { return nil }
        let engineTarget: CoastlineEngine.SplitTarget
        switch target {
        case .everyMonth:
            engineTarget = .monthly
        case .lumpSum(let id):
            guard input.lumpSums.contains(where: { $0.id == id }) else { return nil }
            engineTarget = .lumpSum(id: id)
        }
        let recommendation = Recommender.recommend(
            input,
            target: engineTarget,
            riskToleranceMonths: plan.assumptions.riskToleranceMonths,
            scenarios: scenarios
        )
        return SplitRecommendation(
            loanShare: recommendation.recommended.loanShare,
            safestLoanShare: recommendation.safest.loanShare,
            reason: recommendation.reason,
            typicalMonthsSooner: recommendation.typicalMonthsSooner,
            badCaseMonthsBehind: recommendation.badCaseMonthsBehind,
            projection: projection(recommendation.recommended.outcomes),
            candidates: recommendation.candidates.map { candidate in
                SplitCandidate(loanShare: candidate.loanShare, projection: projection(candidate.outcomes))
            }
        )
    }

    func monthlySplit(_ plan: UserPlan) -> MonthlySplit? {
        guard let amount = plan.money.monthlyAmount else { return nil }
        let share = min(max(plan.split.loanShare ?? 0, 0), 1)
        let split = Allocation.split(amount, loanShare: share)
        return MonthlySplit(loanShare: share, investShare: 1 - share, toLoan: split.loans, toInvesting: split.investing)
    }

    func breakEvenReturn(_ plan: UserPlan) -> Decimal? {
        engineInput(plan, scenario: .typical).flatMap(BreakEven.annualReturn)
    }

    func checklist(_ plan: UserPlan, for target: SplitTarget) -> ChoiceChecklist? {
        guard let input = engineInput(plan, scenario: .typical) else { return nil }
        let months = CoastlineEngine.ProjectionEngine.project(input).months
        let fee = FeeAssumption(
            annualFee: input.annualFee,
            fundType: plan.investments.fundType ?? .indexETF,
            setByUser: plan.assumptions.annualFee != nil
        )
        switch target {
        case .everyMonth:
            let payments = months.first { $0.monthIndex == 1 }?.payments ?? .none
            return ChoiceChecklist(
                mode: .everyMonth,
                month: YearMonth(year: engineStart.year, month: engineStart.month),
                loanPayments: payments.loans.map { payment in
                    ChecklistLoanPayment(
                        loanID: payment.id,
                        minimum: payment.minimum,
                        extra: payment.extra,
                        total: payment.total
                    )
                },
                investing: payments.invested,
                investingRisesWithInflation: plan.assumptions.contributionsRiseWithInflation,
                fee: fee
            )
        case .lumpSum(let id):
            guard let lump = input.lumpSums.first(where: { $0.id == id }) else { return nil }
            let payment = months
                .first { $0.monthIndex > 0 && $0.month == lump.month }?
                .payments.lumpSums.first { $0.id == id }
            return ChoiceChecklist(
                mode: .oneTime,
                month: YearMonth(year: lump.month.year, month: lump.month.month),
                loanPayments: (payment?.loans ?? []).map { amount in
                    ChecklistLoanPayment(loanID: amount.id, minimum: 0, extra: amount.amount, total: amount.amount)
                },
                investing: payment?.invested ?? 0,
                investingRisesWithInflation: false,
                fee: fee
            )
        }
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

        let start = engineStart
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
            return CoastlineEngine.LumpSum(id: lump.id, amount: lump.amount, month: month, loanShare: lump.loanShare)
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
                fundType: (plan.investments.fundType ?? .indexETF).engineFundType
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
                annualFee: plan.assumptions.annualFee
            ),
            scenario: scenario,
            budget: CoastlineEngine.Budget(
                categories: plan.budget.categories.map { category in
                    CoastlineEngine.BudgetCategory(amount: category.amount, role: engineRole(category.role))
                },
                emergencyFundIsFull: plan.budget.emergencyFundIsFull
            ),
            freedPaymentAnswers: Dictionary(
                plan.loans.compactMap { loan in loan.freedPaymentAnswer.map { (loan.id, engineAnswer($0)) } },
                uniquingKeysWith: { first, _ in first }
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
            monthsUntilCoastFire: result.coastFireDate.map { max($0.months(since: engineStart), 0) },
            coastFireDateIfFreedMoneyInvested: calendarDate(result.coastFireDateIfFreedMoneyInvested),
            loanPayoffDate: calendarDate(result.loanPayoffDate),
            loanPayoffs: result.loanPayoffs.map { payoff in
                PlannedPayoff(
                    loanID: payoff.id,
                    month: YearMonth(year: payoff.month.year, month: payoff.month.month),
                    payment: payoff.payment
                )
            },
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

    private var engineStart: CoastlineEngine.YearMonth {
        CoastlineEngine.YearMonth(year: start.year, month: clampedMonth(start.month))
    }

    private func engineAnswer(_ answer: FreedPaymentAnswer) -> CoastlineEngine.FreedPaymentAnswer {
        switch answer {
        case .invest: .invest
        case .keep: .keep
        }
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

extension FundType {
    /// The engine's fee for this fund type, used when the user has not set a fee.
    var defaultAnnualFee: Decimal {
        engineFundType.defaultAnnualFee
    }

    fileprivate var engineFundType: CoastlineEngine.FundType {
        switch self {
        case .indexETF: .indexETF
        case .mutualFund: .mutualFund
        }
    }
}
