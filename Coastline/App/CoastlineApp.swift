import SwiftUI

@main
struct CoastlineApp: App {
    @State private var model: AppModel

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
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}
