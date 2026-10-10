import SwiftUI

@main
struct CoastlineApp: App {
    @State private var model: AppModel
    @State private var showingSetup: Bool

    init() {
        let store: any PlanStore
        let storageProblem: String?
        do {
            store = try FilePlanStore.applicationSupport()
            storageProblem = nil
        } catch {
            store = MemoryPlanStore()
            storageProblem = "On-device storage is unavailable."
        }
        let model = AppModel(
            store: store,
            engine: PlanProjectionEngine(),
            storageProblem: storageProblem
        )
        _model = State(initialValue: model)
        _showingSetup = State(initialValue: !model.hasStoredPlan)
    }

    var body: some Scene {
        WindowGroup {
            if showingSetup {
                SetupFlow(model: model, canCancel: model.hasStoredPlan) {
                    showingSetup = false
                }
            } else {
                HomeView(model: model) {
                    showingSetup = true
                }
            }
        }
    }
}
