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

    init(store: any PlanStore, engine: any ProjectionEngine, storageProblem: String? = nil) {
        self.store = store
        self.engine = engine

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
    /// Only called after the user confirms the choice. Returns the projection from before and after.
    @discardableResult
    func choose(
        loanShare: Decimal,
        for target: SplitTarget,
        in plan: UserPlan,
        at date: Date = Date()
    ) throws -> (before: Projection, after: Projection) {
        let before = projection
        var chosen = plan.applyingLoanShare(loanShare, to: target)
        chosen.chosenPlan = ChosenPlan(
            mode: target.mode,
            loanShare: loanShare,
            chosenAt: date,
            lumpSumID: target.lumpSumID
        )
        try apply(chosen)
        return (before, projection)
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
