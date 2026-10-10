import Foundation

/// The four Setup topics, in order. There is no budget step.
enum SetupStep: Int, CaseIterable, Hashable {
    case aboutYou
    case loans
    case investments
    case goal

    var title: String {
        switch self {
        case .aboutYou: "About you"
        case .loans: "Loans"
        case .investments: "Current investments"
        case .goal: "Coast FIRE goal"
        }
    }

    var next: SetupStep? {
        SetupStep(rawValue: rawValue + 1)
    }
}

/// Typical values Setup starts with when the user does not know a number. The user can keep or change each one.
enum SetupDefaults {
    static let retirementAge = 65
    /// The common planning rate for yearly retirement withdrawals.
    static let withdrawalRate = planDecimal("0.04")
    /// The Bank of Canada's inflation target.
    static let inflation = planDecimal("0.02")
    /// Used to estimate a loan's minimum payment until the user enters one from a statement.
    static let repaymentTermYears = 10
}

/// What the user has typed into Setup, kept as text until `plan(updating:)` turns it into a `UserPlan`.
struct SetupDraft: Equatable {
    var currentAge = ""
    /// On top of minimum loan payments.
    var monthlyAmount = ""
    var loans: [LoanDraft] = []
    var primeRatePercent = ""
    var investmentBalance = ""
    var fundType: FundType?
    var retirementAge = String(SetupDefaults.retirementAge)
    /// Today's dollars.
    var yearlySpending = ""
    var withdrawalRatePercent = SetupNumber.percentText(SetupDefaults.withdrawalRate)
    var inflationPercent = SetupNumber.percentText(SetupDefaults.inflation)

    init() {}

    /// Starts from a saved plan, so running Setup again shows what was entered before.
    init(plan: UserPlan, today: Date = Date()) {
        if let age = plan.goal.currentAge { currentAge = String(age) }
        if let amount = plan.money.monthlyAmount { monthlyAmount = SetupNumber.text(amount) }
        loans = plan.loans.map { LoanDraft(loan: $0, today: today) }
        if let prime = plan.assumptions.primeRate { primeRatePercent = SetupNumber.percentText(prime) }
        if let balance = plan.investments.balance { investmentBalance = SetupNumber.text(balance) }
        fundType = plan.investments.fundType
        if let age = plan.goal.retirementAge { retirementAge = String(age) }
        if let spending = plan.goal.yearlyRetirementSpending { yearlySpending = SetupNumber.text(spending) }
        if let rate = plan.goal.withdrawalRate { withdrawalRatePercent = SetupNumber.percentText(rate) }
        if let inflation = plan.assumptions.inflation { inflationPercent = SetupNumber.percentText(inflation) }
    }

    /// Prime is asked only when a loan's rate follows it.
    var needsPrimeRate: Bool {
        loans.contains { $0.rateType == .floating }
    }

    /// What still needs an answer before leaving this step. Empty when the step is complete.
    func issues(for step: SetupStep) -> [String] {
        var issues: [String] = []
        switch step {
        case .aboutYou:
            if SetupNumber.age(currentAge) == nil {
                issues.append("Enter your age.")
            }
            if SetupNumber.amount(monthlyAmount) == nil {
                issues.append("Enter how much you can put toward loans and investing each month. It can be 0.")
            }
        case .loans:
            if loans.contains(where: { !$0.issues.isEmpty }) {
                issues.append("Finish the details for each loan.")
            }
            if needsPrimeRate, SetupNumber.percent(primeRatePercent) == nil {
                issues.append("Enter the prime rate your floating-rate loan follows.")
            }
        case .investments:
            if SetupNumber.amount(investmentBalance) == nil {
                issues.append("Enter how much you have invested now. It can be 0.")
            }
            if fundType == nil {
                issues.append("Choose a fund type.")
            }
        case .goal:
            if let retirement = SetupNumber.age(retirementAge) {
                if let current = SetupNumber.age(currentAge), retirement <= current {
                    issues.append("Retirement age must be later than your current age.")
                }
            } else {
                issues.append("Enter a retirement age.")
            }
            if SetupNumber.positiveAmount(yearlySpending) == nil {
                issues.append("Enter your yearly spending in retirement.")
            }
            if SetupNumber.percent(withdrawalRatePercent).map({ $0 > 0 && $0 <= 1 }) != true {
                issues.append("Enter a withdrawal rate above 0%.")
            }
            if SetupNumber.percent(inflationPercent) == nil {
                issues.append("Enter an inflation rate.")
            }
        }
        return issues
    }

    /// The plan Setup saves. Anything Setup does not ask about stays as it is in `base`, such as
    /// return rates, a fee the user set, and a chosen split. Nil until every step is complete.
    func plan(updating base: UserPlan) -> UserPlan? {
        guard
            SetupStep.allCases.allSatisfy({ issues(for: $0).isEmpty }),
            let currentAge = SetupNumber.age(currentAge),
            let monthlyAmount = SetupNumber.amount(monthlyAmount),
            let investmentBalance = SetupNumber.amount(investmentBalance),
            let fundType,
            let retirementAge = SetupNumber.age(retirementAge),
            let yearlySpending = SetupNumber.positiveAmount(yearlySpending),
            let withdrawalRate = SetupNumber.percent(withdrawalRatePercent),
            let inflation = SetupNumber.percent(inflationPercent)
        else {
            return nil
        }
        let enteredLoans = self.loans.compactMap(\.loan)
        guard enteredLoans.count == self.loans.count else { return nil }

        var plan = base
        plan.loans = enteredLoans
        plan.money.monthlyAmount = monthlyAmount
        plan.investments = Investments(balance: investmentBalance, fundType: fundType)
        plan.goal = CoastFireGoal(
            currentAge: currentAge,
            retirementAge: retirementAge,
            yearlyRetirementSpending: yearlySpending,
            withdrawalRate: withdrawalRate
        )
        plan.assumptions.inflation = inflation
        if needsPrimeRate {
            plan.assumptions.primeRate = SetupNumber.percent(primeRatePercent)
        }
        return plan
    }
}

/// One loan as typed into Setup.
struct LoanDraft: Identifiable, Equatable {
    enum RateType: String, CaseIterable {
        case fixed
        case floating
    }

    var id = UUID()
    var name = ""
    var balance = ""
    var rateType: RateType = .fixed
    /// The annual rate for a fixed loan, or the margin over prime for a floating one, in percent.
    var ratePercent = ""
    var disbursement: Loan.Disbursement = .afterJuly12023
    var interestHasStarted = true
    var interestStart = Date()
    /// From a statement. Left blank, the payment is estimated from the repayment term.
    var minimumPayment = ""
    var repaymentTermYears = String(SetupDefaults.repaymentTermYears)
    var interestMethod: Loan.InterestMethod = .dailyAccrualMonthlyApplication

    init() {}

    init(loan: Loan, today: Date = Date()) {
        id = loan.id
        name = loan.name ?? ""
        balance = SetupNumber.text(loan.balance)
        switch loan.rate {
        case .fixed(let annualRate):
            rateType = .fixed
            ratePercent = SetupNumber.percentText(annualRate)
        case .floating(let margin):
            rateType = .floating
            ratePercent = SetupNumber.percentText(margin)
        }
        disbursement = loan.disbursement
        if let start = loan.interestStart.flatMap(Self.date), start > today {
            interestHasStarted = false
            interestStart = start
        }
        if let minimum = loan.minimumPayment {
            minimumPayment = SetupNumber.text(minimum)
        }
        if let term = loan.repaymentTermMonths, term % 12 == 0 {
            repaymentTermYears = String(term / 12)
        }
        interestMethod = loan.interestMethod
    }

    var title: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Loan" : trimmed
    }

    var usesEstimatedMinimum: Bool {
        minimumPayment.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var issues: [String] {
        var issues: [String] = []
        if SetupNumber.positiveAmount(balance) == nil {
            issues.append("Enter the balance.")
        }
        switch rateType {
        case .fixed:
            if SetupNumber.percent(ratePercent).map({ $0 >= 0 }) != true {
                issues.append("Enter the interest rate.")
            }
        case .floating:
            if SetupNumber.percent(ratePercent) == nil {
                issues.append("Enter the margin over prime. It can be 0 or negative.")
            }
        }
        if usesEstimatedMinimum {
            if SetupNumber.years(repaymentTermYears) == nil {
                issues.append("Enter the minimum payment, or the years left to repay.")
            }
        } else if SetupNumber.amount(minimumPayment) == nil {
            issues.append("Enter the minimum payment as an amount.")
        }
        return issues
    }

    var loan: Loan? {
        guard issues.isEmpty,
              let balance = SetupNumber.positiveAmount(balance),
              let rate = SetupNumber.percent(ratePercent)
        else {
            return nil
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return Loan(
            id: id,
            name: trimmedName.isEmpty ? nil : trimmedName,
            balance: balance,
            disbursement: disbursement,
            rate: rateType == .fixed ? .fixed(annualRate: rate) : .floating(marginOverPrime: rate),
            interestStart: interestHasStarted ? nil : Self.calendarDate(interestStart),
            minimumPayment: usesEstimatedMinimum ? nil : SetupNumber.amount(minimumPayment),
            repaymentTermMonths: SetupNumber.years(repaymentTermYears).map { $0 * 12 },
            interestMethod: interestMethod
        )
    }

    private static func calendarDate(_ date: Date) -> CalendarDate {
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        return CalendarDate(year: parts.year ?? 2026, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    private static func date(_ date: CalendarDate) -> Date? {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: date.year, month: date.month, day: date.day))
    }
}

/// Reads numbers typed into Setup and writes saved numbers back as text. Percent fields hold "6.5" for 6.5%.
enum SetupNumber {
    static func decimal(_ text: String, locale: Locale = .current) -> Decimal? {
        let decimalSeparator = locale.decimalSeparator ?? "."
        let groupingSeparator = locale.groupingSeparator ?? ","
        var cleaned = text
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "%", with: "")
            .filter { !$0.isWhitespace }
        if !groupingSeparator.isEmpty, groupingSeparator != decimalSeparator {
            cleaned = cleaned.replacingOccurrences(of: groupingSeparator, with: "")
        }
        cleaned = cleaned.replacingOccurrences(of: decimalSeparator, with: ".")
        guard cleaned.range(of: #"^-?(\d+\.?\d*|\.\d+)$"#, options: .regularExpression) != nil else {
            return nil
        }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Zero or more.
    static func amount(_ text: String) -> Decimal? {
        decimal(text).flatMap { $0 >= 0 ? $0 : nil }
    }

    static func positiveAmount(_ text: String) -> Decimal? {
        decimal(text).flatMap { $0 > 0 ? $0 : nil }
    }

    /// "6.5" becomes 0.065.
    static func percent(_ text: String) -> Decimal? {
        decimal(text).map { $0 / 100 }
    }

    static func age(_ text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespaces)).flatMap { (1...120).contains($0) ? $0 : nil }
    }

    static func years(_ text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespaces)).flatMap { (1...50).contains($0) ? $0 : nil }
    }

    static func text(_ value: Decimal, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 10
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? NSDecimalNumber(decimal: value).stringValue
    }

    /// 0.065 becomes "6.5".
    static func percentText(_ rate: Decimal, locale: Locale = .current) -> String {
        text(rate * 100, locale: locale)
    }
}
