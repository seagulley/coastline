import SwiftUI

/// Shell until Setup and Home exist. It shows the engine's good, typical, and bad scenarios.
struct RootView: View {
    @Bindable var model: AppModel
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Good, typical, and bad. Calculated by the projection engine.")
                    if model.usingStarterPlan {
                        Text("Starter plan, until a plan is saved on this device.")
                    }
                }

                if model.projection.scenarios.isEmpty {
                    Section("Projection") {
                        Text("No projection yet.")
                    }
                } else {
                    Section {
                        ProjectionSummary(projection: model.projection)
                    }
                    if model.projection.scenarios.contains(where: { !$0.months.isEmpty }) {
                        Section("Net worth") {
                            ProjectionChart(projection: model.projection)
                                .frame(height: 180)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        }
                    }
                }

                Section("On this device") {
                    Text("Saved on this device only. There is no account.")
                    if let storageError = model.storageError {
                        Text(storageError)
                    } else if model.hasStoredPlan {
                        Text("A plan is saved on this device.")
                    } else {
                        Text("Nothing is saved yet.")
                    }
                    if let chosen = model.plan.chosenPlan, model.hasStoredPlan {
                        Text("Chosen split: \(PlanFormatting.percent(chosen.loanShare)) extra to the loan, every month")
                    }
                    if model.usingStarterPlan || !model.hasStoredPlan {
                        Button("Save this plan on this device") {
                            do {
                                try model.saveShownPlan()
                                saveError = nil
                            } catch {
                                saveError = "The plan could not be saved."
                            }
                        }
                        .disabled(model.projection.scenarios.isEmpty)
                    }
                    if let saveError {
                        Text(saveError)
                    }
                }
            }
            .navigationTitle("Coastline")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ProjectionSummary: View {
    let projection: Projection

    var body: some View {
        ForEach(orderedScenarios, id: \.scenario) { scenario in
            VStack(alignment: .leading, spacing: 2) {
                Text(scenario.scenario.title)
                    .font(.headline)
                Text("Coast FIRE \(scenario.coastFireDate.map(PlanFormatting.monthAndYear) ?? "not reached")")
                Text("Loan payoff \(scenario.loanPayoffDate.map(PlanFormatting.monthAndYear) ?? "not reached")")
                if let interest = scenario.totalInterestPaid {
                    Text("Interest paid \(PlanFormatting.currency(interest))")
                }
                if let investedFreedPayments = scenario.coastFireDateIfFreedMoneyInvested,
                   investedFreedPayments != scenario.coastFireDate {
                    Text("If freed payments are invested \(PlanFormatting.monthAndYear(investedFreedPayments))")
                }
            }
            .font(.subheadline)
            .accessibilityElement(children: .combine)
        }
    }

    private var orderedScenarios: [ScenarioProjection] {
        ReturnScenario.allCases.compactMap { scenario in
            projection.scenarios.first { $0.scenario == scenario }
        }
    }
}
