import Foundation
import Observation

/// Loads the on-device plan and asks the projection engine for results.
/// Views read `plan` and `projection`. They do not calculate either one.
@MainActor
@Observable
final class AppModel {
    private let store: any PlanStore
    private let engine: any ProjectionEngine

    private(set) var plan: UserPlan
    private(set) var projection: Projection
    private(set) var hasStoredPlan: Bool
    private(set) var storageError: String?

    init(store: any PlanStore, engine: any ProjectionEngine, storageProblem: String? = nil) {
        self.store = store
        self.engine = engine

        if let storageProblem {
            plan = .empty
            hasStoredPlan = false
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
        projection = engine.project(loaded)
    }

    /// Writes the plan on this device, then refreshes the projection from the engine.
    func apply(_ plan: UserPlan) throws {
        try store.save(plan)
        self.plan = plan
        hasStoredPlan = true
        storageError = nil
        projection = engine.project(plan)
    }
}
