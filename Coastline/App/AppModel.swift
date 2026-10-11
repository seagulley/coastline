import Foundation
import Observation

/// Loads the on-device plan and asks the projection engine for results.
/// Views read `plan` and `projection`. They do not calculate either one.
@MainActor
@Observable
final class AppModel {
    private let store: any PlanStore
    let engine: any ProjectionEngine

    private(set) var plan: UserPlan
    private(set) var projection: Projection
    private(set) var hasStoredPlan: Bool
    private(set) var usingStarterPlan: Bool
    private(set) var storageError: String?
    /// The month Home treats as now when deciding what is coming up.
    let currentMonth: YearMonth

    init(
        store: any PlanStore,
        engine: any ProjectionEngine,
        storageProblem: String? = nil,
        currentMonth: YearMonth = .current()
    ) {
        self.store = store
        self.engine = engine
        self.currentMonth = currentMonth

        if let storageProblem {
            plan = .empty
            hasStoredPlan = false
            usingStarterPlan = false
            storageError = storageProblem
            projection = engine.project(.empty)
            return
        }

        let loaded: UserPlan
        do {
            if let stored = try store.load() {
                loaded = stored
                hasStoredPlan = true
                storageError = nil
            } else {
                loaded = .empty
                hasStoredPlan = false
                storageError = nil
            }
        } catch {
            loaded = .empty
            hasStoredPlan = false
            storageError = "The saved plan could not be read."
        }
        plan = loaded
        projection = .empty
        usingStarterPlan = false
        showProjection(for: loaded)
    }

    /// Writes the plan on this device, then refreshes the projection from the engine.
    func apply(_ plan: UserPlan) throws {
        try store.save(plan)
        self.plan = plan
        hasStoredPlan = true
        storageError = nil
        showProjection(for: plan)
    }

    /// Saves what Setup collected. Until the user chooses a split, the plan uses the engine's
    /// recommended split as a suggestion, which is returned for display. With no loans, everything is invested.
    @discardableResult
    func finishSetup(_ entered: UserPlan) throws -> SplitRecommendation? {
        var plan = entered
        var recommendation: SplitRecommendation?
        if plan.chosenPlan == nil {
            if plan.loans.isEmpty {
                plan.split.loanShare = 0
            } else if let recommended = engine.recommend(plan) {
                plan.split.loanShare = recommended.loanShare
                recommendation = recommended
            }
        }
        try apply(plan)
        return recommendation
    }

    /// The plan behind `projection`: the saved plan, or the starter plan when the saved one cannot be projected.
    var shownPlan: UserPlan {
        usingStarterPlan ? .starter : plan
    }

    /// Saves the plan on screen, with its current split recorded as the chosen plan.
    /// Only called when the user explicitly asks to save.
    func saveShownPlan(at date: Date = Date()) throws {
        var shown = shownPlan
        shown.chosenPlan = ChosenPlan(
            mode: .everyMonth,
            loanShare: shown.split.loanShare ?? 0,
            chosenAt: date
        )
        try apply(shown)
    }

    /// Saves `plan` with `loanShare` applied to `target` and recorded as the chosen plan.
    /// Only called after the user confirms the choice. Returns the projection from before and after,
    /// and the engine's checklist for the saved plan.
    @discardableResult
    func choose(
        loanShare: Decimal,
        for target: SplitTarget,
        in plan: UserPlan,
        at date: Date = Date()
    ) throws -> (before: Projection, after: Projection, checklist: ChoiceChecklist?) {
        let before = projection
        var chosen = plan.applyingLoanShare(loanShare, to: target)
        chosen.chosenPlan = ChosenPlan(
            mode: target.mode,
            loanShare: loanShare,
            chosenAt: date,
            lumpSumID: target.lumpSumID
        )
        try apply(chosen)
        return (before, projection, engine.checklist(chosen, for: target))
    }

    /// Saves assumptions the user changed in Change assumptions. The rest of the saved plan stays as it is.
    func saveAssumptions(_ assumptions: Assumptions) throws {
        var updated = plan
        updated.assumptions = assumptions
        try apply(updated)
    }

    /// This month's split of the saved plan's monthly money, from the engine.
    var monthlySplit: MonthlySplit? {
        engine.monthlySplit(plan)
    }

    /// Loans the engine projects to be paid off by this month that the user has not answered for yet.
    /// A loan hidden with Not paid off yet comes back the month after.
    var payoffItems: [PayoffItem] {
        guard !usingStarterPlan, let typical = projection.scenario(.typical) else { return [] }
        return plan.loans.compactMap { loan in
            guard loan.freedPaymentAnswer == nil,
                  loan.payoffItemHiddenUntil.map({ currentMonth >= $0 }) ?? true,
                  let payoff = typical.loanPayoffs.first(where: { $0.loanID == loan.id }),
                  payoff.month <= currentMonth
            else { return nil }
            return PayoffItem(loanID: loan.id, loanName: loan.name, month: payoff.month, payment: payoff.payment)
        }
    }

    /// Good, typical, and bad results for each answer to a payoff item. Runs off the main thread.
    func payoffChoice(for loanID: UUID) async -> PayoffChoice {
        let engine = engine
        let invest = plan.answeringPayoff(of: loanID, with: .invest)
        let keep = plan.answeringPayoff(of: loanID, with: .keep)
        return await Task.detached(priority: .userInitiated) {
            PayoffChoice(invest: engine.project(invest), keep: engine.project(keep))
        }.value
    }

    /// Saves the user's answer for one loan. Only called when the user taps I'll invest it or I'll keep it.
    func answerPayoff(of loanID: UUID, with answer: FreedPaymentAnswer) throws {
        try apply(plan.answeringPayoff(of: loanID, with: answer))
    }

    /// Not paid off yet: hides the loan's payoff item until next month. The projection does not change.
    func hidePayoffItem(of loanID: UUID) throws {
        var updated = plan
        guard let index = updated.loans.firstIndex(where: { $0.id == loanID }) else { return }
        updated.loans[index].payoffItemHiddenUntil = currentMonth.next
        try apply(updated)
    }

    /// Shows the engine result for the saved plan. When that plan cannot be projected,
    /// shows the starter plan's good, typical, and bad scenarios instead.
    private func showProjection(for plan: UserPlan) {
        let projected = engine.project(plan)
        if !projected.scenarios.isEmpty {
            projection = projected
            usingStarterPlan = false
            return
        }
        let starter = engine.project(.starter)
        if !starter.scenarios.isEmpty {
            projection = starter
            usingStarterPlan = true
        } else {
            projection = projected
            usingStarterPlan = false
        }
    }
}

/// A Coming up item: a loan the engine projects to be paid off, waiting for the user to confirm.
struct PayoffItem: Identifiable, Equatable {
    var loanID: UUID
    var loanName: String?
    var month: YearMonth
    var payment: Decimal

    var id: UUID { loanID }
}

/// The projection for each answer to a payoff item.
struct PayoffChoice: Equatable, Sendable {
    var invest: Projection
    var keep: Projection
}

extension UserPlan {
    func answeringPayoff(of loanID: UUID, with answer: FreedPaymentAnswer) -> UserPlan {
        var plan = self
        if let index = plan.loans.firstIndex(where: { $0.id == loanID }) {
            plan.loans[index].freedPaymentAnswer = answer
        }
        return plan
    }
}
