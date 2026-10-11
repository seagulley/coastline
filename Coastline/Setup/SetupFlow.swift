import SwiftUI

/// One topic per screen: about you, loans, current investments, Coast FIRE goal.
/// Ends by saving the plan on this device and showing the Coast FIRE date from the engine.
struct SetupFlow: View {
    let model: AppModel
    /// False the first time, when there is no plan to go back to.
    let canCancel: Bool
    let onFinish: () -> Void

    @State private var draft: SetupDraft
    @State private var path: [SetupScreen] = []
    @State private var recommendation: SplitRecommendation?
    @State private var saveError: String?
    @State private var editingLoan: LoanEdit?

    init(model: AppModel, canCancel: Bool, onFinish: @escaping () -> Void) {
        self.model = model
        self.canCancel = canCancel
        self.onFinish = onFinish
        _draft = State(initialValue: SetupDraft(plan: model.plan))
    }

    var body: some View {
        NavigationStack(path: $path) {
            stepForm(.aboutYou)
                .toolbar {
                    if canCancel {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel", action: onFinish)
                        }
                    }
                }
                .navigationDestination(for: SetupScreen.self) { screen in
                    switch screen {
                    case .step(let step):
                        stepForm(step)
                    case .result:
                        SetupResultView(model: model, recommendation: recommendation, onDone: onFinish)
                    }
                }
        }
        .sheet(item: $editingLoan) { edit in
            LoanEditor(loan: edit.loan, isNew: edit.isNew) { saved in
                if let index = draft.loans.firstIndex(where: { $0.id == saved.id }) {
                    draft.loans[index] = saved
                } else {
                    draft.loans.append(saved)
                }
            }
        }
    }

    private func stepForm(_ step: SetupStep) -> some View {
        let issues = draft.issues(for: step)
        return Form {
            switch step {
            case .aboutYou:
                AboutYouStep(draft: $draft)
            case .loans:
                LoansStep(draft: $draft) { loan, isNew in
                    editingLoan = LoanEdit(loan: loan, isNew: isNew)
                }
            case .investments:
                InvestmentsStep(draft: $draft, feeText: feeText)
            case .goal:
                GoalStep(draft: $draft, assumptions: model.plan.assumptions)
            }

            Section {
                Button(step.next == nil ? "See my Coast FIRE date" : "Next") {
                    advance(from: step)
                }
                .disabled(!issues.isEmpty)
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(issues, id: \.self) { Text($0) }
                    if step.next == nil, let saveError {
                        Text(saveError)
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(step.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .status) {
                Text("Step \(step.rawValue + 1) of \(SetupStep.allCases.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
    }

    private var feeText: String? {
        if let fee = model.plan.assumptions.annualFee {
            return "\(PlanFormatting.rate(fee, minimumFractionDigits: 2)), set by you"
        }
        guard let fundType = draft.fundType else { return nil }
        return "\(PlanFormatting.rate(fundType.defaultAnnualFee, minimumFractionDigits: 2)), \(fundType.lowercaseName) default"
    }

    private func advance(from step: SetupStep) {
        if let next = step.next {
            path.append(.step(next))
            return
        }
        guard let plan = draft.plan(updating: model.plan) else { return }
        do {
            recommendation = try model.finishSetup(plan)
            saveError = nil
            path.append(.result)
        } catch {
            saveError = "The plan could not be saved on this device."
        }
    }
}

private enum SetupScreen: Hashable {
    case step(SetupStep)
    case result
}

private struct LoanEdit: Identifiable {
    var loan: LoanDraft
    var isNew: Bool

    var id: UUID { loan.id }
}

private struct AboutYouStep: View {
    @Binding var draft: SetupDraft

    var body: some View {
        Section {
            NumberField("Your age", text: $draft.currentAge, prompt: "Age", keyboard: .numberPad)
        }
        Section {
            NumberField("Each month", text: $draft.monthlyAmount, prompt: "$0")
        } header: {
            Text("Money for loans and investing")
        } footer: {
            Text("How much you can put toward extra loan payments and investing each month, on top of your minimum loan payments.")
        }
    }
}

private struct LoansStep: View {
    @Binding var draft: SetupDraft
    /// Opens the loan editor. True when the loan is new.
    let edit: (LoanDraft, Bool) -> Void

    var body: some View {
        Section {
            ForEach(draft.loans) { loan in
                Button {
                    edit(loan, false)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loan.title)
                            .foregroundStyle(.primary)
                        Text(summary(loan))
                            .font(.footnote)
                            .foregroundStyle(loan.issues.isEmpty ? Color.secondary : Color.red)
                    }
                }
            }
            .onDelete { draft.loans.remove(atOffsets: $0) }

            Button("Add a loan") {
                edit(LoanDraft(), true)
            }
        } footer: {
            Text(draft.loans.isEmpty ? "No loans? Leave this empty and continue." : "Swipe left on a loan to remove it.")
        }

        if draft.needsPrimeRate {
            Section {
                NumberField("Prime rate (%)", text: $draft.primeRatePercent, prompt: "e.g. 4.95", info: .primeRate)
            } footer: {
                Text("Your lender's current prime rate. The projection keeps it at this number.")
            }
        }
    }

    private func summary(_ loan: LoanDraft) -> String {
        guard loan.issues.isEmpty,
              let balance = SetupNumber.positiveAmount(loan.balance),
              let rate = SetupNumber.percent(loan.ratePercent)
        else {
            return "Details needed"
        }
        let rateText: String
        switch loan.rateType {
        case .fixed:
            rateText = "\(PlanFormatting.rate(rate)) fixed"
        case .floating:
            let sign = rate < 0 ? "−" : "+"
            rateText = "prime \(sign) \(PlanFormatting.rate(abs(rate)))"
        }
        return "\(PlanFormatting.currency(balance)) at \(rateText)"
    }
}

private struct LoanEditor: View {
    @State var loan: LoanDraft
    let isNew: Bool
    let onSave: (LoanDraft) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Name") {
                        TextField("Optional", text: $loan.name)
                            .multilineTextAlignment(.trailing)
                    }
                    NumberField("Balance", text: $loan.balance, prompt: "$0")
                }

                Section("Interest rate") {
                    Picker("Rate type", selection: $loan.rateType) {
                        Text("Fixed").tag(LoanDraft.RateType.fixed)
                        Text("Floating").tag(LoanDraft.RateType.floating)
                    }
                    .pickerStyle(.segmented)
                    if loan.rateType == .fixed {
                        NumberField("Annual rate (%)", text: $loan.ratePercent, prompt: "e.g. 5.5")
                    } else {
                        NumberField(
                            "Margin over prime (%)",
                            text: $loan.ratePercent,
                            prompt: "e.g. 1 or -0.5",
                            keyboard: .numbersAndPunctuation
                        )
                    }
                    LabeledContent {
                        Picker("Interest method", selection: $loan.interestMethod) {
                            Text("Daily, added monthly").tag(Loan.InterestMethod.dailyAccrualMonthlyApplication)
                            Text("Monthly").tag(Loan.InterestMethod.monthlyNominal)
                        }
                        .labelsHidden()
                    } label: {
                        InfoLabel("Interest method", info: .interestMethod)
                    }
                }

                Section {
                    Toggle("Interest has started", isOn: $loan.interestHasStarted)
                    if !loan.interestHasStarted {
                        DatePicker("Interest starts", selection: $loan.interestStart, displayedComponents: .date)
                    }
                    Picker("First paid out", selection: $loan.disbursement) {
                        Text("Before July 1, 2023").tag(Loan.Disbursement.beforeJuly12023)
                        Text("July 1, 2023 or later").tag(Loan.Disbursement.afterJuly12023)
                    }
                }

                Section {
                    NumberField("Minimum payment", text: $loan.minimumPayment, prompt: "From statement")
                    if loan.usesEstimatedMinimum {
                        NumberField(
                            "Years left to repay",
                            text: $loan.repaymentTermYears,
                            prompt: "Years",
                            keyboard: .numberPad
                        )
                    }
                } footer: {
                    if loan.usesEstimatedMinimum {
                        Text("No statement yet? The minimum payment is estimated from the years left to repay. \(SetupDefaults.repaymentTermYears) years is a common term.")
                    }
                }

                if !loan.issues.isEmpty {
                    Section {
                        ForEach(loan.issues, id: \.self) { Text($0) }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(isNew ? "Add a loan" : loan.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Done") {
                        onSave(loan)
                        dismiss()
                    }
                    .disabled(!loan.issues.isEmpty)
                }
            }
        }
    }
}

private struct InvestmentsStep: View {
    @Binding var draft: SetupDraft
    let feeText: String?

    var body: some View {
        Section {
            NumberField("Invested now", text: $draft.investmentBalance, prompt: "$0")
        } footer: {
            Text("The total in your investment accounts today.")
        }
        Section {
            LabeledContent {
                Picker("Fund type", selection: $draft.fundType) {
                    Text("Choose").tag(FundType?.none)
                    Text(FundType.indexETF.title).tag(FundType?.some(.indexETF))
                    Text(FundType.mutualFund.title).tag(FundType?.some(.mutualFund))
                }
                .labelsHidden()
            } label: {
                InfoLabel("Fund type", info: .fundType)
            }
            if let feeText {
                LabeledContent {
                    Text(feeText)
                } label: {
                    InfoLabel("Fee", info: .fee)
                }
            }
        } footer: {
            Text("Fund type sets the starting yearly fee. You can change the fee later in Change assumptions.")
        }
    }
}

private struct GoalStep: View {
    @Binding var draft: SetupDraft
    let assumptions: Assumptions

    var body: some View {
        Section {
            NumberField("Retirement age", text: $draft.retirementAge, prompt: "Age", keyboard: .numberPad)
        } footer: {
            Text("\(SetupDefaults.retirementAge) is typical. Keep it or change it.")
        }
        Section {
            NumberField("Yearly spending", text: $draft.yearlySpending, prompt: "$0")
        } footer: {
            Text("What you expect to spend each year in retirement, in today's dollars.")
        }
        Section {
            NumberField("Withdrawal rate (%)", text: $draft.withdrawalRatePercent, prompt: "%", info: .withdrawalRate)
            NumberField("Inflation (%)", text: $draft.inflationPercent, prompt: "%", info: .inflation)
        } header: {
            Text("Assumptions")
        } footer: {
            Text(
                "Starts at a \(PlanFormatting.rate(SetupDefaults.withdrawalRate)) withdrawal rate and "
                    + "\(PlanFormatting.rate(SetupDefaults.inflation)) inflation. "
                    + "Market returns start at \(PlanFormatting.rate(assumptions.badAnnualReturn)) bad, "
                    + "\(PlanFormatting.rate(assumptions.typicalAnnualReturn)) typical, and "
                    + "\(PlanFormatting.rate(assumptions.goodAnnualReturn)) good, before fees."
            )
        }
    }
}

/// The last Setup screen. Shows what the engine projected for the saved plan.
private struct SetupResultView: View {
    let model: AppModel
    let recommendation: SplitRecommendation?
    let onDone: () -> Void

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Coast FIRE")
                        .font(.headline)
                    Text(scenario(.typical)?.coastFireDate.map(PlanFormatting.monthAndYear) ?? "Not before retirement")
                        .font(.largeTitle.bold())
                    Text("In a typical market.")
                        .foregroundStyle(.secondary)
                    Text("Likely range: \(dateText(.good)) to \(dateText(.bad)).")
                        .font(.subheadline)
                }
                .accessibilityElement(children: .combine)
            }

            if let recommendation {
                Section("Suggested split") {
                    Text("\(PlanFormatting.percent(recommendation.loanShare)) of your monthly money to extra loan payments, the rest invested.")
                    Text(recommendation.reason)
                        .foregroundStyle(.secondary)
                }
            }

            if model.projection.scenarios.contains(where: { !$0.months.isEmpty }) {
                Section("Net worth") {
                    ProjectionChart(projection: model.projection)
                        .frame(height: 180)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
            }

            Section {
                Text("Saved on this device only. Nothing is chosen until you pick a split.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Your Coast FIRE date")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: onDone)
            }
        }
    }

    private func scenario(_ scenario: ReturnScenario) -> ScenarioProjection? {
        guard !model.usingStarterPlan else { return nil }
        return model.projection.scenarios.first { $0.scenario == scenario }
    }

    private func dateText(_ which: ReturnScenario) -> String {
        scenario(which)?.coastFireDate.map(PlanFormatting.monthAndYear) ?? "not before retirement"
    }
}

/// A labelled field for a number typed as text.
private struct NumberField: View {
    let title: String
    @Binding var text: String
    let prompt: String
    let keyboard: UIKeyboardType
    let info: AssumptionInfo?

    init(
        _ title: String,
        text: Binding<String>,
        prompt: String,
        keyboard: UIKeyboardType = .decimalPad,
        info: AssumptionInfo? = nil
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
            if let info {
                InfoLabel(title, info: info)
            } else {
                Text(title)
            }
        }
    }
}

extension FundType {
    var title: String {
        switch self {
        case .indexETF: "Index ETF"
        case .mutualFund: "Mutual fund"
        }
    }

    var lowercaseName: String {
        switch self {
        case .indexETF: "index ETF"
        case .mutualFund: "mutual fund"
        }
    }
}
