import SwiftUI

/// Change assumptions, opened from Compare. Each valid edit reruns Compare's options right away.
/// Done saves the assumptions on this device. Cancel puts Compare back on the assumptions it had.
struct AssumptionsSheet: View {
    let model: CompareModel
    let save: (Assumptions) throws -> Void

    @State private var draft: AssumptionsDraft
    @State private var saveError: String?
    @Environment(\.dismiss) private var dismiss
    private let original: Assumptions

    init(model: CompareModel, save: @escaping (Assumptions) throws -> Void) {
        self.model = model
        self.save = save
        original = model.plan.assumptions
        _draft = State(initialValue: AssumptionsDraft(assumptions: model.plan.assumptions))
    }

    var body: some View {
        NavigationStack {
            Form {
                breakEvenSection

                Section("Yearly returns, before fees") {
                    RateField("Good market", text: $draft.goodReturnPercent, keyboard: .numbersAndPunctuation, info: .goodReturn)
                    RateField("Typical market", text: $draft.typicalReturnPercent, keyboard: .numbersAndPunctuation, info: .typicalReturn)
                    RateField("Bad market", text: $draft.badReturnPercent, keyboard: .numbersAndPunctuation, info: .badReturn)
                }

                Section {
                    RateField("Prime rate", text: $draft.primeRatePercent, prompt: "e.g. 4.95", info: .primeRate)
                    RateField("Inflation", text: $draft.inflationPercent, keyboard: .numbersAndPunctuation, info: .inflation)
                } footer: {
                    Text("Type in your lender's current prime rate. The projection keeps it at this number.")
                }

                Section {
                    RateField("Yearly fund fee", text: $draft.feePercent, prompt: SetupNumber.percentText(defaultFee), info: .fee)
                    if !draft.usesDefaultFee {
                        Button("Reset to \(fundType.lowercaseName) default") {
                            draft.useDefaultFee()
                        }
                    }
                } footer: {
                    Text(feeText)
                }

                Section {
                    LabeledContent {
                        Text(months(model.plan.assumptions.riskToleranceMonths))
                    } label: {
                        InfoLabel("Risk tolerance", info: .riskTolerance)
                    }
                } footer: {
                    Text("A split can be recommended when its bad-market Coast FIRE date is at most this much later than the safest split.")
                }

                if !issues.isEmpty || saveError != nil {
                    Section {
                        ForEach(issues, id: \.self) { Text($0) }
                        if let saveError {
                            Text(saveError)
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Change assumptions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        model.useAssumptions(original)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: done)
                        .disabled(edited == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(draft != AssumptionsDraft(assumptions: original))
        .onChange(of: draft) {
            saveError = nil
            if let edited {
                model.useAssumptions(edited)
            }
        }
    }

    @ViewBuilder
    private var breakEvenSection: some View {
        Section("Break-even") {
            if !issues.isEmpty {
                Text("Fix the fields below to see the break-even return.")
                    .foregroundStyle(.secondary)
            } else if let breakEven = model.breakEvenReturn {
                Text("Paying the loan wins if markets return less than \(PlanFormatting.rate(breakEven)) a year.")
            } else {
                Text("There is no loan balance to pay, so there is no break-even return.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var needsPrimeRate: Bool {
        model.plan.loans.contains { loan in
            if case .floating = loan.rate { return true }
            return false
        }
    }

    private var issues: [String] {
        draft.issues(needsPrimeRate: needsPrimeRate)
    }

    private var edited: Assumptions? {
        draft.assumptions(updating: original, needsPrimeRate: needsPrimeRate)
    }

    /// With no fund type yet, the index ETF default applies.
    private var fundType: FundType {
        model.plan.investments.fundType ?? .indexETF
    }

    private var defaultFee: Decimal {
        fundType.defaultAnnualFee
    }

    private var feeText: String {
        let defaultRate = PlanFormatting.rate(defaultFee, minimumFractionDigits: 2)
        guard !draft.usesDefaultFee else {
            return "\(defaultRate), \(fundType.lowercaseName) default. Enter your fund's MER to use it instead."
        }
        return "Set by you. Reset to use the \(fundType.lowercaseName) default, \(defaultRate)."
    }

    private func done() {
        guard let edited else { return }
        do {
            try save(edited)
            model.useAssumptions(edited)
            dismiss()
        } catch {
            saveError = "The assumptions could not be saved on this device."
        }
    }

    private func months(_ count: Int) -> String {
        count == 1 ? "1 month" : "\(count) months"
    }
}

/// A labelled percent field typed as text, such as "6.5".
private struct RateField: View {
    let title: String
    @Binding var text: String
    let prompt: String
    let keyboard: UIKeyboardType
    let info: AssumptionInfo

    init(
        _ title: String,
        text: Binding<String>,
        prompt: String = "%",
        keyboard: UIKeyboardType = .decimalPad,
        info: AssumptionInfo
    ) {
        self.title = title
        _text = text
        self.prompt = prompt
        self.keyboard = keyboard
        self.info = info
    }

    var body: some View {
        LabeledContent {
            TextField(prompt, text: $text)
                .multilineTextAlignment(.trailing)
                .keyboardType(keyboard)
        } label: {
            InfoLabel("\(title) (%)", info: info)
        }
    }
}
