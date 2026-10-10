import Foundation

struct NominalMonth {
    var monthIndex: Int
    var month: YearMonth
    var loanBalances: [LoanBalance]
    var investments: Decimal
    var cumulativeInterest: Decimal
    var interestAccrued: Decimal
}

struct NominalSimulator {
    struct LoanState {
        var id: UUID
        var balance: Decimal
        var rate: LoanRate
        var annualRate: Decimal
        var interestStart: YearMonth
        var minimumPayment: Decimal
        var interestMethod: InterestMethod
        var order: Int
        var countsTowardPayoff: Bool
        /// Where this loan's minimum payment goes once the loan is repaid.
        var freedShares: FreedShares
    }

    private var loans: [LoanState]
    private let start: YearMonth
    private let monthlyAmount: Decimal
    private let loanShare: Decimal
    private let contributionsGrowWithInflation: Bool
    private let lumpsByMonth: [YearMonth: [LumpSum]]
    private var investments: Decimal
    private let inflation: Decimal
    private let primeRate: Decimal
    private let growthFactor: Decimal
    private let horizonMonths: Int

    private var recurringLoanExtra: Decimal = 0
    private var recurringInvest: Decimal = 0
    private var freedLoanIDs: Set<UUID> = []
    private var payoffMonthIndex: [UUID: Int] = [:]

    init(
        start: YearMonth,
        loans: [NominalSimulator.LoanState],
        monthlyAmount: Decimal,
        loanShare: Decimal,
        contributionsGrowWithInflation: Bool,
        lumpSums: [LumpSum],
        investments: Decimal,
        inflation: Decimal,
        primeRate: Decimal,
        growthFactor: Decimal,
        horizonMonths: Int
    ) {
        self.start = start
        self.loans = loans
        self.monthlyAmount = max(monthlyAmount, 0)
        self.loanShare = min(max(loanShare, 0), 1)
        self.contributionsGrowWithInflation = contributionsGrowWithInflation
        self.investments = max(investments, 0)
        self.inflation = inflation
        self.primeRate = primeRate
        self.growthFactor = growthFactor
        self.horizonMonths = max(horizonMonths, 0)

        var lumps: [YearMonth: [LumpSum]] = [:]
        for lump in lumpSums where lump.amount > 0 {
            lumps[lump.month, default: []].append(lump)
        }
        self.lumpsByMonth = lumps
    }

    mutating func run() -> (months: [NominalMonth], payoffMonthIndex: [UUID: Int]) {
        var months = [record(monthIndex: 0, month: start, interestAccrued: 0, cumulativeInterest: 0)]
        var cumulativeInterest: Decimal = 0

        if horizonMonths == 0 {
            return (months, payoffMonthIndex)
        }

        for monthIndex in 1...horizonMonths {
            let month = start.adding(months: monthIndex - 1)
            let accrued = step(monthIndex: monthIndex, month: month)
            cumulativeInterest = Cents.round(cumulativeInterest + accrued)
            months.append(
                record(
                    monthIndex: monthIndex,
                    month: month,
                    interestAccrued: accrued,
                    cumulativeInterest: cumulativeInterest
                )
            )
        }
        return (months, payoffMonthIndex)
    }

    /// One month in nominal dollars. Returns interest accrued this month.
    private mutating func step(monthIndex: Int, month: YearMonth) -> Decimal {
        // 1. Update rates. 2. Accrue interest.
        var interestAccrued: Decimal = 0
        for index in loans.indices {
            loans[index].annualRate = loans[index].rate.annualRate(prime: primeRate)
            guard month >= loans[index].interestStart else { continue }
            let interest = accruedInterest(for: loans[index], days: month.days)
            interestAccrued = Cents.round(interestAccrued + interest)
            loans[index].balance = Cents.round(loans[index].balance + interest)
        }

        // 3. Money arrives. Investing rises with inflation; the loan slice and lump sums stay nominal.
        let elapsedMonths = monthIndex - 1
        let (monthlyLoan, monthlyInvest) = Allocation.split(monthlyAmount, loanShare: loanShare)
        let investScale = contributionsGrowWithInflation
            ? TodayDollars.inflationFactor(inflation: inflation, monthIndex: elapsedMonths)
            : Decimal(1)
        var investPool = Cents.round(monthlyInvest * investScale) + recurringInvest
        var userExtra = monthlyLoan
        var freedExtra = recurringLoanExtra

        for lump in lumpsByMonth[month] ?? [] {
            let share = lump.loanShare ?? loanShare
            let (lumpLoan, lumpInvest) = Allocation.split(lump.amount, loanShare: share)
            userExtra = Cents.round(userExtra + lumpLoan)
            investPool = Cents.round(investPool + lumpInvest)
        }

        // 4. Minimums, then extra. Interest was already added to the balance, so payments reduce it first.
        for index in loans.indices where loans[index].balance > 0 {
            let due = loans[index].balance
            let minimum = loans[index].minimumPayment
            let paid = pay(min(minimum, due), at: index)
            if loans[index].balance == 0 {
                let unused = Cents.round(minimum - paid)
                let freed = loans[index].freedShares.allocate(unused)
                freedExtra = Cents.round(freedExtra + freed.loans)
                investPool = Cents.round(investPool + freed.investing)
            }
        }

        // Money headed to loans is invested once no loan is left to take it.
        investPool = Cents.round(investPool + applyWaterfall(userExtra))
        investPool = Cents.round(investPool + applyWaterfall(freedExtra))

        // 5. Invest. 6. Grow.
        let grown = (investments + investPool) * growthFactor
        investments = Cents.round(grown)

        // Freed minimums start next month, once the payoff month is over.
        for loan in loans where loan.balance == 0 && loan.countsTowardPayoff {
            if payoffMonthIndex[loan.id] == nil {
                payoffMonthIndex[loan.id] = monthIndex
            }
            guard !freedLoanIDs.contains(loan.id) else { continue }
            let freed = loan.freedShares.allocate(loan.minimumPayment)
            recurringLoanExtra = Cents.round(recurringLoanExtra + freed.loans)
            recurringInvest = Cents.round(recurringInvest + freed.investing)
            freedLoanIDs.insert(loan.id)
        }

        return interestAccrued
    }

    private func accruedInterest(for loan: LoanState, days: Int) -> Decimal {
        switch loan.interestMethod {
        case .dailyAccrualMonthlyApplication:
            return Cents.round(loan.balance * loan.annualRate * Decimal(days) / 365)
        case .monthlyNominal:
            return Cents.round(loan.balance * loan.annualRate / 12)
        }
    }

    /// Pays loans highest rate first. Returns what is left once every loan is repaid.
    private mutating func applyWaterfall(_ amount: Decimal) -> Decimal {
        var remaining = max(amount, 0)
        let indexes = loans.indices
            .filter { loans[$0].balance > 0 }
            .sorted { left, right in
                if loans[left].annualRate != loans[right].annualRate {
                    return loans[left].annualRate > loans[right].annualRate
                }
                return loans[left].order < loans[right].order
            }
        for index in indexes {
            if remaining <= 0 { break }
            remaining = Cents.round(remaining - pay(remaining, at: index))
        }
        return remaining
    }

    private mutating func pay(_ amount: Decimal, at index: Int) -> Decimal {
        let applied = min(max(amount, 0), loans[index].balance)
        loans[index].balance = Cents.round(loans[index].balance - applied)
        return applied
    }

    private func record(
        monthIndex: Int,
        month: YearMonth,
        interestAccrued: Decimal,
        cumulativeInterest: Decimal
    ) -> NominalMonth {
        NominalMonth(
            monthIndex: monthIndex,
            month: month,
            loanBalances: loans.map { LoanBalance(id: $0.id, balance: $0.balance) },
            investments: investments,
            cumulativeInterest: cumulativeInterest,
            interestAccrued: interestAccrued
        )
    }
}
