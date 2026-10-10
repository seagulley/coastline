import SwiftUI

/// What to do with a paid-off loan's payment. Shows the engine's Coast FIRE date and range for each answer.
/// Nothing is saved until the user taps one of the three actions.
struct PayoffSheet: View {
    let model: AppModel
    let item: PayoffItem
    @Environment(\.dismiss) private var dismiss
    @State private var choice: PayoffChoice?
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(HomeView.payoffSentence(item))
                } footer: {
                    Text("The app cannot see your loan balance. Confirm once the last payment has gone through.")
                }

                option(
                    "Invest it",
                    detail: "Add the \(PlanFormatting.currency(item.payment)) to what you invest every month.",
                    projection: choice?.invest
                )
                option(
                    "Keep it",
                    detail: "Spend it or use it elsewhere. It leaves the projection.",
                    projection: choice?.keep
                )

                Section {
                    Button("I'll invest it") { answer(.invest) }
                    Button("I'll keep it") { answer(.keep) }
                    Button("Not paid off yet") { hide() }
                    if let saveError {
                        Text(saveError)
                    }
                } footer: {
                    Text("Not paid off yet hides this until next month.")
                }
            }
            .navigationTitle("Paid off?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                choice = await model.payoffChoice(for: item.loanID)
            }
        }
    }

    private func option(_ title: String, detail: String, projection: Projection?) -> some View {
        Section(title) {
            Text(detail)
                .foregroundStyle(.secondary)
            if let projection {
                if let typical = projection.scenario(.typical) {
                    LabeledContent("Coast FIRE", value: date(typical))
                    LabeledContent("Good to bad", value: "\(date(projection.scenario(.good))) – \(date(projection.scenario(.bad)))")
                } else {
                    Text("No projection for this plan.")
                }
            } else {
                ProgressView()
            }
        }
    }

    private func date(_ scenario: ScenarioProjection?) -> String {
        scenario?.coastFireDate.map(PlanFormatting.shortMonthAndYear) ?? "Not reached"
    }

    private func answer(_ answer: FreedPaymentAnswer) {
        save { try model.answerPayoff(of: item.loanID, with: answer) }
    }

    private func hide() {
        save { try model.hidePayoffItem(of: item.loanID) }
    }

    private func save(_ change: () throws -> Void) {
        do {
            try change()
            dismiss()
        } catch {
            saveError = "Your answer could not be saved."
        }
    }
}
