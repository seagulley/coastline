import Foundation

/// One candidate split and its good, typical, and bad outcomes.
public struct SplitOutcome: Hashable, Sendable {
    /// Fraction of the varied money (the monthly amount or one lump sum) sent to extra loan payments, from 0 to 1.
    public var loanShare: Decimal
    public var outcomes: ScenarioOutcomes

    public init(loanShare: Decimal, outcomes: ScenarioOutcomes) {
        self.loanShare = loanShare
        self.outcomes = outcomes
    }

    public var typicalCoastFireDate: YearMonth? { outcomes.typical.coastFireDate }
    public var badCaseCoastFireDate: YearMonth? { outcomes.bad.coastFireDate }
}

public struct Recommendation: Hashable, Sendable {
    public var recommended: SplitOutcome
    /// The candidate with the earliest bad-case Coast FIRE date.
    public var safest: SplitOutcome
    /// Every candidate, lowest loan share first.
    public var candidates: [SplitOutcome]
    public var riskToleranceMonths: Int
    /// How much sooner the recommendation reaches Coast FIRE than the safest option in a typical market.
    /// Nil when either one does not reach it before retirement.
    public var typicalMonthsSooner: Int?
    /// How far the recommendation's bad-case Coast FIRE date trails the safest option.
    /// Nil when either one does not reach it before retirement.
    public var badCaseMonthsBehind: Int?
    /// One sentence explaining the choice, generated from the comparison with the safest option.
    public var reason: String

    public init(
        recommended: SplitOutcome,
        safest: SplitOutcome,
        candidates: [SplitOutcome],
        riskToleranceMonths: Int,
        typicalMonthsSooner: Int?,
        badCaseMonthsBehind: Int?,
        reason: String
    ) {
        self.recommended = recommended
        self.safest = safest
        self.candidates = candidates
        self.riskToleranceMonths = riskToleranceMonths
        self.typicalMonthsSooner = typicalMonthsSooner
        self.badCaseMonthsBehind = badCaseMonthsBehind
        self.reason = reason
    }
}

/// The balanced recommendation rule. Candidates are loan shares from 0% to 100% in 10% steps.
/// Compare's slider can still ask a `ScenarioSource` for any other split.
public enum Recommender {
    /// A candidate stays eligible when its bad-case Coast FIRE date is at most this many months after the safest option.
    public static let defaultRiskToleranceMonths = 12

    public static let candidateLoanShares: [Decimal] = (0...10).map { Decimal($0) / 10 }

    /// The loan share of `target` and `input.scenario` are replaced for each candidate and scenario.
    /// Every other split in `input` stays as given.
    public static func recommend(
        _ input: ProjectionInput,
        target: SplitTarget = .monthly,
        riskToleranceMonths: Int = defaultRiskToleranceMonths,
        scenarios: any ScenarioSource = FixedReturnScenarios()
    ) -> Recommendation {
        let tolerance = max(riskToleranceMonths, 0)
        let candidates = candidateLoanShares.map { share in
            SplitOutcome(
                loanShare: share,
                outcomes: scenarios.outcomes(for: input.applyingLoanShare(share, to: target))
            )
        }

        let safest = earliest(candidates, by: \.badCaseCoastFireDate)
        let allowed = candidates.filter { candidate in
            guard let safestDate = safest.badCaseCoastFireDate else { return true }
            guard let date = candidate.badCaseCoastFireDate else { return false }
            return date <= safestDate.adding(months: tolerance)
        }
        let recommended = earliest(allowed, by: \.typicalCoastFireDate)

        let typicalMonthsSooner = monthsBetween(recommended.typicalCoastFireDate, safest.typicalCoastFireDate)
        let badCaseMonthsBehind = monthsBetween(safest.badCaseCoastFireDate, recommended.badCaseCoastFireDate)
        return Recommendation(
            recommended: recommended,
            safest: safest,
            candidates: candidates,
            riskToleranceMonths: tolerance,
            typicalMonthsSooner: typicalMonthsSooner,
            badCaseMonthsBehind: badCaseMonthsBehind,
            reason: reason(
                recommended: recommended,
                safest: safest,
                candidates: candidates,
                tolerance: tolerance,
                typicalMonthsSooner: typicalMonthsSooner,
                badCaseMonthsBehind: badCaseMonthsBehind
            )
        )
    }

    /// Earliest date wins and a date that is never reached comes last.
    /// Ties go to the higher loan share, because the loan's return is guaranteed.
    private static func earliest(
        _ candidates: [SplitOutcome],
        by date: KeyPath<SplitOutcome, YearMonth?>
    ) -> SplitOutcome {
        candidates.min { left, right in
            switch (left[keyPath: date], right[keyPath: date]) {
            case let (left?, right?) where left != right:
                return left < right
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                return left.loanShare > right.loanShare
            }
        }!
    }

    private static func monthsBetween(_ earlier: YearMonth?, _ later: YearMonth?) -> Int? {
        guard let earlier, let later else { return nil }
        return later.months(since: earlier)
    }

    private static func reason(
        recommended: SplitOutcome,
        safest: SplitOutcome,
        candidates: [SplitOutcome],
        tolerance: Int,
        typicalMonthsSooner: Int?,
        badCaseMonthsBehind: Int?
    ) -> String {
        if recommended.loanShare == safest.loanShare {
            guard safest.badCaseCoastFireDate != nil else {
                if recommended.typicalCoastFireDate != nil {
                    return "No split reaches Coast FIRE before retirement in a bad market. This one reaches it soonest in a typical market."
                }
                return "No split reaches Coast FIRE before retirement, so this one puts the most toward the loan, whose return is guaranteed."
            }
            let soonerTypical = candidates.contains { candidate in
                guard let date = candidate.typicalCoastFireDate else { return false }
                guard let recommendedDate = recommended.typicalCoastFireDate else { return true }
                return date < recommendedDate
            }
            if soonerTypical {
                return "Reaches Coast FIRE soonest in a bad market. Splits that are sooner in a typical market trail it by more than \(months(tolerance)) in a bad market."
            }
            return "Reaches Coast FIRE soonest in a bad market, and no split is sooner in a typical market."
        }

        let typical: String
        if let gain = typicalMonthsSooner, gain > 0 {
            typical = "Reaches Coast FIRE \(months(gain)) sooner in a typical market"
        } else {
            typical = "Matches the safest option in a typical market"
        }
        let bad: String
        if let gap = badCaseMonthsBehind {
            bad = gap > 0
                ? "only \(months(gap)) behind the safest option in a bad market"
                : "matches it in a bad market"
        } else {
            bad = "neither reaches Coast FIRE before retirement in a bad market"
        }
        let tiebreak = (typicalMonthsSooner ?? 0) > 0
            ? ""
            : " It puts more toward the loan, whose return is guaranteed."
        return "\(typical), and \(bad).\(tiebreak)"
    }

    private static func months(_ count: Int) -> String {
        count == 1 ? "1 month" : "\(count) months"
    }
}
