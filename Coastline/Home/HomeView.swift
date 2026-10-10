import SwiftUI

/// Home: the Coast FIRE date, anything that needs a decision, and the current monthly split.
/// Every date and amount comes from the engine through `AppModel`.
struct HomeView: View {
    @Bindable var model: AppModel
    let runSetup: () -> Void
    @State private var openPayoff: PayoffItem?

    var body: some View {
        NavigationStack {
            List {
                CoastFireSection(projection: model.usingStarterPlan ? .empty : model.projection)

                let items = model.payoffItems
                if !items.isEmpty {
                    Section("Coming up") {
                        ForEach(items) { item in
                            Button {
                                openPayoff = item
                            } label: {
                                Text(Self.payoffSentence(item))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }

                Section("Every month") {
                    if let split = model.monthlySplit {
                        LabeledContent("Extra to loans", value: Self.splitAmount(split.toLoan, share: split.loanShare))
                        LabeledContent("Investing", value: Self.splitAmount(split.toInvesting, share: split.investShare))
                    } else {
                        Text("No monthly amount yet. Add one in Setup.")
                    }
                    NavigationLink("Adjust") {
                        CompareView(app: model, showSplit: true)
                    }
                }

                if model.usingStarterPlan || model.storageError != nil {
                    Section {
                        if let storageError = model.storageError {
                            Text(storageError)
                        }
                        if model.usingStarterPlan {
                            Text("The saved plan cannot be projected yet. Finish Setup to see your Coast FIRE date.")
                        }
                    }
                }
            }
            .navigationTitle("Coastline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Setup", action: runSetup)
                }
            }
            .sheet(item: $openPayoff) { item in
                PayoffSheet(model: model, item: item)
            }
        }
    }

    static func payoffSentence(_ item: PayoffItem) -> String {
        "Your \(loanName(item)) should be paid off in \(PlanFormatting.monthAndYear(item.month)). "
            + "Its \(PlanFormatting.currency(item.payment)) payment is free."
    }

    static func loanName(_ item: PayoffItem) -> String {
        guard let name = item.loanName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return "loan"
        }
        return name
    }

    private static func splitAmount(_ amount: Decimal, share: Decimal) -> String {
        "\(PlanFormatting.currency(amount)) · \(PlanFormatting.percent(share))"
    }
}

/// The typical Coast FIRE date, how far away it is, and the good-to-bad range.
struct CoastFireSection: View {
    let projection: Projection

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("Coast FIRE")
                    .font(.headline)
                if let typical = projection.scenario(.typical) {
                    Text(typical.coastFireDate.map(PlanFormatting.monthAndYear) ?? "Not before retirement")
                        .font(.largeTitle.bold())
                    if let months = typical.monthsUntilCoastFire {
                        Text(PlanFormatting.timeAway(months: months))
                    }
                    Text("Likely between \(date(.good)) and \(date(.bad)).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No projection yet. Finish Setup to see your date.")
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func date(_ scenario: ReturnScenario) -> String {
        projection.scenario(scenario)?.coastFireDate.map(PlanFormatting.monthAndYear) ?? "not before retirement"
    }
}
