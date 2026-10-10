import SwiftUI

/// The assumptions behind Compare's numbers, opened by Change assumptions.
struct AssumptionsSheet: View {
    let plan: UserPlan
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Yearly returns, before fees") {
                    LabeledContent("Good market", value: PlanFormatting.rate(plan.assumptions.goodAnnualReturn))
                    LabeledContent("Typical market", value: PlanFormatting.rate(plan.assumptions.typicalAnnualReturn))
                    LabeledContent("Bad market", value: PlanFormatting.rate(plan.assumptions.badAnnualReturn))
                }
                Section {
                    LabeledContent("Prime rate", value: rate(plan.assumptions.primeRate))
                    LabeledContent("Inflation", value: rate(plan.assumptions.inflation))
                    LabeledContent("Yearly fund fee", value: rate(plan.assumptions.annualFee))
                }
                Section {
                    LabeledContent("Risk tolerance", value: months(plan.assumptions.riskToleranceMonths))
                } footer: {
                    Text("A split can be recommended when its bad-market Coast FIRE date is at most this much later than the safest split.")
                }
            }
            .navigationTitle("Assumptions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func rate(_ value: Decimal?) -> String {
        value.map(PlanFormatting.rate) ?? "Not set"
    }

    private func months(_ count: Int) -> String {
        count == 1 ? "1 month" : "\(count) months"
    }
}
