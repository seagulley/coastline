import SwiftUI

/// Shell until Setup and Home exist. It shows stored state and engine output only.
struct RootView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Saved on this device only. There is no account.")
                }

                Section("Plan") {
                    if let storageError = model.storageError {
                        Text(storageError)
                    } else if model.hasStoredPlan {
                        Text("A plan is saved on this device.")
                    } else {
                        Text("Nothing is saved yet.")
                    }
                }

                Section("Projection") {
                    if model.projection.scenarios.isEmpty {
                        Text("No projection yet.")
                    } else {
                        ProjectionSummary(projection: model.projection)
                        if model.projection.scenarios.contains(where: { !$0.months.isEmpty }) {
                            ProjectionChart(projection: model.projection)
                                .frame(height: 220)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        }
                    }
                }
            }
            .navigationTitle("Coastline")
        }
    }
}

private struct ProjectionSummary: View {
    let projection: Projection

    var body: some View {
        ForEach(projection.scenarios, id: \.scenario) { scenario in
            VStack(alignment: .leading, spacing: 4) {
                Text(scenario.scenario.title)
                    .font(.headline)
                LabeledContent("Coast FIRE") {
                    Text(scenario.coastFireDate.map(PlanFormatting.monthAndYear) ?? "Not reached")
                }
                LabeledContent("Loan payoff") {
                    Text(scenario.loanPayoffDate.map(PlanFormatting.monthAndYear) ?? "Not reached")
                }
                if let interest = scenario.totalInterestPaid {
                    LabeledContent("Interest paid") {
                        Text(PlanFormatting.currency(interest))
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}
