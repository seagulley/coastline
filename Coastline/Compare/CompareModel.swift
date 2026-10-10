import Foundation
import Observation

/// State for Compare. The engine produces every number; this model only picks which results to show.
@MainActor
@Observable
final class CompareModel {
    struct Option: Identifiable, Equatable {
        enum Kind: Equatable {
            case recommended
            case custom
            case allToLoan
            case allInvested
        }

        var kind: Kind
        var loanShare: Decimal
        var projection: Projection

        var id: Kind { kind }
    }

    /// What the engine needs to rerun. Changing any part reruns the recommendation.
    struct Inputs: Equatable, Sendable {
        var plan: UserPlan
        var target: SplitTarget?
    }

    /// Changes when the slider's split has to be rerun.
    struct CustomSplitKey: Equatable {
        var inputs: Inputs
        var share: Decimal
        var recommendationReady: Bool
    }

    let engine: any ProjectionEngine
    /// The plan Compare starts from. It is not saved until the user confirms a choice.
    let plan: UserPlan

    var mode: AllocationMode = .everyMonth
    /// The one-time amount. Starts from the plan's first lump sum, when it has one.
    var lumpSumAmount: Decimal?
    var lumpSumMonth: YearMonth
    /// The split the user is looking at, from 0 (all invested) to 1 (all to the loan).
    var customShare: Decimal = 0

    private(set) var recommendation: SplitRecommendation?
    private(set) var isLoading = false
    private var recommendationInputs: Inputs?
    private var customProjection: (inputs: Inputs, share: Decimal, projection: Projection)?
    private let lumpSumID: UUID

    init(engine: any ProjectionEngine, plan: UserPlan, startMonth: YearMonth) {
        self.engine = engine
        self.plan = plan
        if let lump = plan.money.lumpSums.first {
            lumpSumID = lump.id
            lumpSumAmount = lump.amount
            lumpSumMonth = lump.month
        } else {
            lumpSumID = UUID()
            lumpSumMonth = startMonth
        }
    }

    /// The plan the options are run on. In One time mode, it carries the one-time amount.
    var comparedPlan: UserPlan {
        guard mode == .oneTime, let amount = lumpSumAmount, amount > 0 else { return plan }
        var compared = plan
        let lump = LumpSum(id: lumpSumID, amount: amount, month: lumpSumMonth, loanShare: nil)
        if let index = compared.money.lumpSums.firstIndex(where: { $0.id == lumpSumID }) {
            compared.money.lumpSums[index] = lump
        } else {
            compared.money.lumpSums.append(lump)
        }
        return compared
    }

    /// Nil in One time mode until there is an amount to split.
    var target: SplitTarget? {
        switch mode {
        case .everyMonth:
            return .everyMonth
        case .oneTime:
            guard let amount = lumpSumAmount, amount > 0 else { return nil }
            return .lumpSum(id: lumpSumID)
        }
    }

    var inputs: Inputs {
        Inputs(plan: comparedPlan, target: target)
    }

    var customSplitKey: CustomSplitKey {
        CustomSplitKey(inputs: inputs, share: customShare, recommendationReady: currentRecommendation != nil)
    }

    /// The recommendation for the current inputs. Nil while a rerun is pending.
    var currentRecommendation: SplitRecommendation? {
        recommendationInputs == inputs ? recommendation : nil
    }

    /// Recommended first, then the slider's split when it differs, then all to the loan and all invested.
    var options: [Option] {
        guard let recommendation = currentRecommendation else { return [] }
        var options = [Option(kind: .recommended, loanShare: recommendation.loanShare, projection: recommendation.projection)]
        let fixed: Set<Decimal> = [recommendation.loanShare, 1, 0]
        if !fixed.contains(customShare), let custom = customProjection,
           custom.inputs == inputs, custom.share == customShare {
            options.append(Option(kind: .custom, loanShare: customShare, projection: custom.projection))
        }
        for (kind, share) in [(Option.Kind.allToLoan, Decimal(1)), (.allInvested, Decimal(0))]
        where share != recommendation.loanShare {
            if let candidate = recommendation.candidates.first(where: { $0.loanShare == share }) {
                options.append(Option(kind: kind, loanShare: share, projection: candidate.projection))
            }
        }
        return options
    }

    /// The option matching the slider, which is what I'll do this chooses.
    var chosenOption: Option? {
        options.first { $0.loanShare == customShare }
    }

    /// Reruns the recommendation for the current inputs and moves the slider to it.
    /// Waits briefly first, so typing an amount does not run the engine for every keystroke.
    func loadRecommendation() async {
        let inputs = inputs
        guard let target = inputs.target else {
            recommendation = nil
            recommendationInputs = inputs
            isLoading = false
            return
        }
        isLoading = true
        try? await Task.sleep(for: .milliseconds(150))
        guard !Task.isCancelled else { return }
        let engine = engine
        let result = await Task.detached(priority: .userInitiated) {
            engine.recommend(inputs.plan, for: target)
        }.value
        guard !Task.isCancelled else { return }
        recommendation = result
        recommendationInputs = inputs
        isLoading = false
        if let result {
            customShare = result.loanShare
        }
    }

    /// Runs the slider's split. Splits on the 10% grid reuse the recommendation's results.
    func loadCustomSplit() async {
        let inputs = inputs
        let share = customShare
        guard let target = inputs.target, let recommendation = currentRecommendation else { return }
        if let candidate = recommendation.candidates.first(where: { $0.loanShare == share }) {
            customProjection = (inputs, share, candidate.projection)
            return
        }
        try? await Task.sleep(for: .milliseconds(120))
        guard !Task.isCancelled else { return }
        let engine = engine
        let projection = await Task.detached(priority: .userInitiated) {
            engine.project(inputs.plan.applyingLoanShare(share, to: target))
        }.value
        guard !Task.isCancelled else { return }
        customProjection = (inputs, share, projection)
    }
}
