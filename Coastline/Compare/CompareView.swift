import SwiftUI

/// Compare paying the loan with investing, every month or for one lump sum.
/// Nothing is saved until the user confirms I'll do this.
struct CompareView: View {
    let app: AppModel
    /// Scrolls to the split slider once the comparison is ready. Set by Home's Adjust.
    var showSplit = false
    @State private var model: CompareModel
    @State private var scrolledToSplit = false
    @State private var showingAssumptions = false
    @State private var confirming = false
    @State private var choice: Choice?
    @State private var showingChoice = false
    @State private var chooseError: String?
    @FocusState private var editingAmount: Bool

    init(app: AppModel, showSplit: Bool = false) {
        self.app = app
        self.showSplit = showSplit
        let today = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: Date())
        let startMonth = YearMonth(year: today.year ?? 2026, month: today.month ?? 1)
        _model = State(initialValue: CompareModel(engine: app.engine, plan: app.shownPlan, startMonth: startMonth))
    }

    var body: some View {
        ScrollViewReader { proxy in
            list
                .onChange(of: model.currentRecommendation != nil, initial: true) { _, ready in
                    guard showSplit, ready, !scrolledToSplit else { return }
                    scrolledToSplit = true
                    withAnimation {
                        proxy.scrollTo(Self.splitSectionID, anchor: .center)
                    }
                }
        }
    }

    private static let splitSectionID = "split"

    private var list: some View {
        List {
            Section {
                Picker("Compare", selection: $model.mode) {
                    Text("Every month").tag(AllocationMode.everyMonth)
                    Text("One time").tag(AllocationMode.oneTime)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            if model.mode == .oneTime {
                Section("One-time money") {
                    TextField("Amount, such as a bonus", value: $model.lumpSumAmount, format: .currency(code: "CAD"))
                        .keyboardType(.decimalPad)
                        .focused($editingAmount)
                    DatePicker("Month", selection: lumpSumDate, displayedComponents: .date)
                }
            }

            if let recommendation = model.currentRecommendation {
                Section("Recommendation") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Self.splitSentence(recommendation.loanShare, mode: model.mode))
                            .font(.headline)
                        Text(recommendation.reason)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }

                Section("Net worth, in today's dollars") {
                    CompareChart(options: model.options)
                }

                Section("Side by side") {
                    CompareTable(options: model.options)
                }

                Section("Your split") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Self.splitSentence(model.customShare, mode: model.mode))
                        Slider(value: sliderShare, in: 0...1) {
                            Text("Share to the loan")
                        } minimumValueLabel: {
                            Text("Invest")
                        } maximumValueLabel: {
                            Text("Loan")
                        }
                        .accessibilityValue("\(PlanFormatting.percent(model.customShare)) to the loan")
                    }
                }
                .id(Self.splitSectionID)
            } else if model.isLoading {
                Section {
                    ProgressView("Comparing splits")
                }
            } else if model.target == nil {
                Section {
                    Text("Enter the one-time amount to compare paying the loan with investing it.")
                }
            } else {
                Section {
                    Text("No comparison yet. The plan needs your age, goal, and inflation first.")
                }
            }

            Section {
                Button("I'll do this") {
                    confirming = true
                }
                .disabled(model.chosenOption == nil)
                Button("Change assumptions") {
                    showingAssumptions = true
                }
                if let chooseError {
                    Text(chooseError)
                }
            }
        }
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: model.inputs) {
            await model.loadRecommendation()
        }
        .task(id: model.customSplitKey) {
            await model.loadCustomSplit()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    editingAmount = false
                }
            }
        }
        .confirmationDialog("Use this split?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Yes, I'll do this") {
                choose()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(Self.splitSentence(model.customShare, mode: model.mode)) Your plan changes only after you confirm.")
        }
        .sheet(isPresented: $showingAssumptions) {
            AssumptionsSheet(model: model, save: app.saveAssumptions)
        }
        .navigationDestination(isPresented: $showingChoice) {
            if let choice {
                AfterChoosingView(choice: choice)
            }
        }
    }

    private func choose() {
        guard let target = model.target else { return }
        let share = model.customShare
        do {
            let result = try app.choose(loanShare: share, for: target, in: model.comparedPlan)
            choice = Choice(
                summary: Self.splitSentence(share, mode: model.mode),
                before: result.before,
                after: result.after
            )
            chooseError = nil
            showingChoice = true
        } catch {
            chooseError = "The choice could not be saved."
        }
    }

    /// The slider moves in whole percents, so it can land between the recommendation's 10% steps.
    private var sliderShare: Binding<Double> {
        Binding(
            get: { NSDecimalNumber(decimal: model.customShare).doubleValue },
            set: { value in
                model.customShare = Decimal(Int((min(max(value, 0), 1) * 100).rounded())) / 100
            }
        )
    }

    private var lumpSumDate: Binding<Date> {
        Binding(
            get: { PlanFormatting.firstDay(of: model.lumpSumMonth) ?? Date() },
            set: { date in
                let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: date)
                if let year = parts.year, let month = parts.month {
                    model.lumpSumMonth = YearMonth(year: year, month: month)
                }
            }
        )
    }

    static func splitSentence(_ share: Decimal, mode: AllocationMode) -> String {
        let money = mode == .everyMonth ? "Every month" : "Of the one-time money"
        switch share {
        case 0:
            return "\(money), invest all of it and pay only the loan minimums."
        case 1:
            return "\(money), put all of it toward the loan."
        default:
            return "\(money), put \(PlanFormatting.percent(share)) toward the loan and invest the rest."
        }
    }
}

extension CompareModel.Option {
    var title: String {
        switch kind {
        case .recommended: "Recommended"
        case .custom: "Your split"
        case .allToLoan: "All to loan"
        case .allInvested: "All invested"
        }
    }
}

/// Options as columns. Rows: typical Coast FIRE date, interest paid, and bad-market Coast FIRE date.
private struct CompareTable: View {
    let options: [CompareModel.Option]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    ForEach(options) { option in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(option.title)
                                .font(.caption.weight(.semibold))
                            Text("\(PlanFormatting.percent(option.loanShare)) to loan")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Divider()
                row("Coast FIRE, typical") { option in
                    date(option.projection.scenario(.typical)?.coastFireDate)
                }
                row("Interest paid") { option in
                    option.projection.scenario(.typical)?.totalInterestPaid.map(PlanFormatting.wholeCurrency) ?? "None"
                }
                row("Coast FIRE, bad market") { option in
                    date(option.projection.scenario(.bad)?.coastFireDate)
                }
            }
            .font(.caption)
            .padding(.vertical, 4)
        }
    }

    private func row(_ label: String, value: @escaping (CompareModel.Option) -> String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            ForEach(options) { option in
                Text(value(option))
                    .monospacedDigit()
            }
        }
    }

    private func date(_ date: CalendarDate?) -> String {
        date.map(PlanFormatting.shortMonthAndYear) ?? "Not reached"
    }
}
