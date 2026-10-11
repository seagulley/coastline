import SwiftUI

/// What the user confirmed in Compare, with the engine's projection from before and after.
struct Choice {
    var summary: String
    var before: Projection
    var after: Projection
    /// The engine's payments for the saved plan. Nil when the plan cannot be projected.
    var checklist: ChoiceChecklist?
    /// The saved plan's loans, for naming them in the steps.
    var loans: [Loan]
}

/// Opens after I'll do this is confirmed. Lists the steps the user takes, and shows how the choice moved the
/// Coast FIRE date. The app does not make any payment itself.
struct AfterChoosingView: View {
    let choice: Choice
    /// Steps the user ticked off. Kept only while this screen is open.
    @State private var done: Set<Int> = []

    var body: some View {
        List {
            Section("Your choice") {
                Text(choice.summary)
            }
            if let checklist = choice.checklist {
                Section {
                    ForEach(Array(Self.steps(checklist, loans: choice.loans).enumerated()), id: \.offset) { index, step in
                        Button {
                            if done.contains(index) {
                                done.remove(index)
                            } else {
                                done.insert(index)
                            }
                        } label: {
                            Label(step, systemImage: done.contains(index) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(.primary)
                        }
                        .accessibilityAddTraits(done.contains(index) ? .isSelected : [])
                    }
                } header: {
                    Text("Your steps")
                } footer: {
                    Text("Coastline does not move any money. Make these payments with your bank and investment account.")
                }
            }
            Section("Coast FIRE date, typical market") {
                LabeledContent("Before", value: date(choice.before.scenario(.typical)?.coastFireDate))
                LabeledContent("After", value: date(choice.after.scenario(.typical)?.coastFireDate))
            }
            Section("After, good to bad market") {
                LabeledContent("Good market", value: date(choice.after.scenario(.good)?.coastFireDate))
                LabeledContent("Bad market", value: date(choice.after.scenario(.bad)?.coastFireDate))
            }
            if let fee = choice.checklist?.fee {
                Section {
                    LabeledContent("Fund fee", value: Self.feeText(fee))
                } footer: {
                    Text("The projection subtracts this fee from every return. Change it in Change assumptions.")
                }
            }
            Section {
                Text("Saved on this device.")
            }
        }
        .navigationTitle("After choosing")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// One sentence per payment, loans first, then investing.
    static func steps(_ checklist: ChoiceChecklist, loans: [Loan]) -> [String] {
        let month = PlanFormatting.monthAndYear(checklist.month)
        let account = "your \(checklist.fee.fundType.lowercaseName), such as in a TFSA"
        var steps = checklist.loanPayments.map { payment in
            let name = loanName(payment.loanID, in: loans)
            switch checklist.mode {
            case .everyMonth:
                if payment.extra == 0 {
                    return "Pay the \(PlanFormatting.currency(payment.minimum)) minimum on \(name) each month."
                }
                if payment.minimum == 0 {
                    return "Pay \(PlanFormatting.currency(payment.total)) a month on \(name)."
                }
                return "Pay \(PlanFormatting.currency(payment.total)) a month on \(name): "
                    + "the \(PlanFormatting.currency(payment.minimum)) minimum plus "
                    + "\(PlanFormatting.currency(payment.extra)) extra."
            case .oneTime:
                return "In \(month), put \(PlanFormatting.currency(payment.total)) of the one-time money toward \(name)."
            }
        }
        if checklist.investing > 0 {
            switch checklist.mode {
            case .everyMonth:
                let raise = checklist.investingRisesWithInflation ? " Raise it with inflation each year." : ""
                steps.append("Invest \(PlanFormatting.currency(checklist.investing)) a month in \(account).\(raise)")
            case .oneTime:
                steps.append(
                    "In \(month), invest \(PlanFormatting.currency(checklist.investing)) of the one-time money in \(account)."
                )
            }
        }
        if steps.isEmpty {
            steps.append("No payments to make for this choice.")
        }
        return steps
    }

    /// "0.20%, index ETF default", or "0.35%, set by you".
    static func feeText(_ fee: FeeAssumption) -> String {
        let rate = PlanFormatting.rate(fee.annualFee, minimumFractionDigits: 2)
        return fee.setByUser ? "\(rate), set by you" : "\(rate), \(fee.fundType.lowercaseName) default"
    }

    /// The loan's name, or "your loan" when it is the only one, or "loan 2" by its place in the list.
    static func loanName(_ id: UUID, in loans: [Loan]) -> String {
        guard let index = loans.firstIndex(where: { $0.id == id }) else { return "your loan" }
        if let name = loans[index].name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        return loans.count == 1 ? "your loan" : "loan \(index + 1)"
    }

    private func date(_ date: CalendarDate?) -> String {
        date.map(PlanFormatting.monthAndYear) ?? "Not reached before retirement"
    }
}
