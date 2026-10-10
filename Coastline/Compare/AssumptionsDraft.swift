import Foundation

/// What the user has typed into Change assumptions, kept as text. Percent fields hold "6.5" for 6.5%.
struct AssumptionsDraft: Equatable {
    var goodReturnPercent: String
    var typicalReturnPercent: String
    var badReturnPercent: String
    var primeRatePercent: String
    var inflationPercent: String
    /// Empty uses the fund type's default fee.
    var feePercent: String

    init(assumptions: Assumptions) {
        goodReturnPercent = SetupNumber.percentText(assumptions.goodAnnualReturn)
        typicalReturnPercent = SetupNumber.percentText(assumptions.typicalAnnualReturn)
        badReturnPercent = SetupNumber.percentText(assumptions.badAnnualReturn)
        primeRatePercent = assumptions.primeRate.map { SetupNumber.percentText($0) } ?? ""
        inflationPercent = assumptions.inflation.map { SetupNumber.percentText($0) } ?? ""
        feePercent = assumptions.annualFee.map { SetupNumber.percentText($0) } ?? ""
    }

    var usesDefaultFee: Bool {
        feePercent.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Reset: the fee goes back to the fund type's default.
    mutating func useDefaultFee() {
        feePercent = ""
    }

    /// What needs fixing before the assumptions can be used. Prime is required only when a loan follows it.
    func issues(needsPrimeRate: Bool) -> [String] {
        var issues: [String] = []
        let returns = [
            ("good", goodReturnPercent),
            ("typical", typicalReturnPercent),
            ("bad", badReturnPercent),
        ]
        for (name, text) in returns where Self.rate(text) == nil {
            issues.append("Enter the \(name) market return.")
        }
        if let good = Self.rate(goodReturnPercent),
           let typical = Self.rate(typicalReturnPercent),
           let bad = Self.rate(badReturnPercent),
           !(bad <= typical && typical <= good) {
            issues.append("The bad return can't be above typical, and typical can't be above good.")
        }
        if primeRatePercent.trimmingCharacters(in: .whitespaces).isEmpty {
            if needsPrimeRate {
                issues.append("Enter the prime rate your floating-rate loan follows.")
            }
        } else if SetupNumber.percent(primeRatePercent).map({ $0 >= 0 }) != true {
            issues.append("Enter the prime rate as a percent, such as 4.95.")
        }
        if Self.rate(inflationPercent) == nil {
            issues.append("Enter an inflation rate.")
        }
        if !usesDefaultFee, SetupNumber.percent(feePercent).map({ $0 >= 0 && $0 < 1 }) != true {
            issues.append("Enter the fee as a percent, such as 0.2, or reset it to the default.")
        }
        return issues
    }

    /// `base` with the typed values. Nil while anything needs fixing.
    func assumptions(updating base: Assumptions, needsPrimeRate: Bool) -> Assumptions? {
        guard
            issues(needsPrimeRate: needsPrimeRate).isEmpty,
            let good = Self.rate(goodReturnPercent),
            let typical = Self.rate(typicalReturnPercent),
            let bad = Self.rate(badReturnPercent),
            let inflation = Self.rate(inflationPercent)
        else {
            return nil
        }
        var assumptions = base
        assumptions.goodAnnualReturn = good
        assumptions.typicalAnnualReturn = typical
        assumptions.badAnnualReturn = bad
        assumptions.inflation = inflation
        assumptions.primeRate = SetupNumber.percent(primeRatePercent)
        assumptions.annualFee = usesDefaultFee ? nil : SetupNumber.percent(feePercent)
        return assumptions
    }

    /// A yearly rate above -100%. Returns and inflation can be negative.
    private static func rate(_ text: String) -> Decimal? {
        SetupNumber.percent(text).flatMap { $0 > -1 ? $0 : nil }
    }
}
