import SwiftUI

/// The plain-language ⓘ note for each editable assumption: what the control means,
/// then what happens to the Coast FIRE date when the value goes up or down.
enum AssumptionInfo: CaseIterable {
    case badReturn
    case typicalReturn
    case goodReturn
    case primeRate
    case inflation
    case fee
    case fundType
    case withdrawalRate
    case riskTolerance
    case contributionsRiseWithInflation
    case interestMethod

    var title: String {
        switch self {
        case .badReturn: "Bad return"
        case .typicalReturn: "Typical return"
        case .goodReturn: "Good return"
        case .primeRate: "Prime rate"
        case .inflation: "Inflation"
        case .fee: "Fees"
        case .fundType: "Fund type"
        case .withdrawalRate: "Withdrawal rate"
        case .riskTolerance: "Risk tolerance"
        case .contributionsRiseWithInflation: "Contributions rise with inflation"
        case .interestMethod: "Interest method"
        }
    }

    var paragraphs: [String] {
        switch self {
        case .badReturn:
            [
                "The yearly return in a weak market, before fees, in ordinary dollars. The bad-case Coast FIRE date uses this rate.",
                "Raising it brings that bad-case date sooner, and can move the recommendation toward investing. The safest split is the one with the earliest Coast FIRE date at this rate. Lowering it pushes the bad-case date later, and can move the recommendation toward paying the loan.",
                Self.defaultReturns,
            ]
        case .typicalReturn:
            [
                "The yearly return in a middle market, before fees, in ordinary dollars. The main Coast FIRE date uses this rate.",
                "Raising it brings that date sooner. Lowering it pushes it later. Among splits that stay inside your risk tolerance in a bad market, the recommendation is the one with the earliest Coast FIRE date at this rate.",
                Self.defaultReturns,
            ]
        case .goodReturn:
            [
                "The yearly return in a strong market, before fees, in ordinary dollars. The optimistic end of the range uses this rate.",
                "Raising it brings that optimistic Coast FIRE date sooner. Lowering it pushes it later. The typical date, the bad-case date, and the recommendation stay on the other two rates.",
                Self.defaultReturns,
            ]
        case .primeRate:
            [
                "The prime rate a floating-rate loan is priced from. That loan's interest rate is this prime plus the loan's margin, and the projection keeps prime at the number you enter.",
                "Raising it charges more interest, so more of each payment covers interest and the balance falls slower. Payoff comes later, and the invested share of that freed payment starts later, which pushes the Coast FIRE date later. Lowering it cuts the interest, frees that money sooner, and brings the Coast FIRE date sooner.",
                "A fixed-rate loan keeps the rate you entered for it, so changing prime leaves that loan alone.",
            ]
        case .inflation:
            [
                "How fast prices rise each year. The Coast FIRE check is in today's dollars: a future balance is scaled down by inflation, and the return that counts is what remains after inflation.",
                "Raising it makes the same future balance worth less today and raises the amount you need invested, so the Coast FIRE date moves later. Lowering it makes future balances worth more today and lowers that amount, so the date moves sooner.",
                "Your loan rate and the three market returns stay at the numbers you set.",
            ]
        case .fee:
            [
                "The yearly cost of the fund (its MER), taken off the return before the balance grows and before the Coast FIRE check. It starts at the default for your fund type: \(Self.fee(.indexETF)) for an index ETF and \(Self.fee(.mutualFund)) for a mutual fund. If you know your fund's MER, enter it. Bank index mutual funds are often under 0.5%.",
                "Raising the fee leaves less of the market return invested, so the Coast FIRE date moves later. Lowering it leaves more invested, so the date moves sooner.",
            ]
        case .fundType:
            [
                "Index ETF or mutual fund. This sets the starting fee taken off your return. If you entered your own fee, changing the fund type leaves it alone.",
                "Choosing the higher-fee type moves the Coast FIRE date later. Choosing the lower-fee type moves it sooner.",
            ]
        case .withdrawalRate:
            [
                "The share of your investments you plan to spend each year in retirement. Yearly spending divided by this rate is the nest egg Coast FIRE is aiming at.",
                "Raising it shrinks that nest egg, so the Coast FIRE date moves sooner. Lowering it enlarges the nest egg, so the date moves later.",
            ]
        case .riskTolerance:
            [
                "How many months the bad-market Coast FIRE date may fall behind the safest split and still be recommended. The starting value is \(Assumptions.defaults.riskToleranceMonths) months.",
                "This setting picks the suggested split. It leaves each split's own dates as they are. Raising it can switch the suggestion to a split that is sooner in a typical market and later in a bad market. Lowering it can switch the suggestion toward the split with the earliest bad-market date.",
            ]
        case .contributionsRiseWithInflation:
            [
                "This starts on. The monthly amount you invest grows with inflation, so later contributions keep the same buying power.",
                "Turning it on brings the Coast FIRE date sooner than a frozen dollar amount. Turning it off keeps that monthly amount at the same number of dollars, so later contributions buy less and the Coast FIRE date moves later.",
            ]
        case .interestMethod:
            [
                "How this loan adds interest. The usual method counts each day in the month, then adds the interest once at month end, with no interest on that interest inside the month.",
                "A method that adds more interest slows payoff. The invested share of that freed payment starts later, so the Coast FIRE date moves later. A method that adds less interest frees that money sooner, so the date moves sooner.",
            ]
        }
    }

    private static var defaultReturns: String {
        let defaults = Assumptions.defaults
        return "If you leave the three rates unset, they start at \(PlanFormatting.rate(defaults.badAnnualReturn)) bad, "
            + "\(PlanFormatting.rate(defaults.typicalAnnualReturn)) typical, and \(PlanFormatting.rate(defaults.goodAnnualReturn)) good. "
            + "Those are planning assumptions for a mix of developed-market stocks, before fees."
    }

    private static func fee(_ fundType: FundType) -> String {
        PlanFormatting.rate(fundType.defaultAnnualFee, minimumFractionDigits: 2)
    }
}

/// An ⓘ button that shows an assumption's note in a popover.
struct InfoButton: View {
    let info: AssumptionInfo
    @State private var isShowing = false

    init(_ info: AssumptionInfo) {
        self.info = info
    }

    var body: some View {
        Button {
            isShowing = true
        } label: {
            Image(systemName: "info.circle")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("About \(info.title.lowercased())")
        .popover(isPresented: $isShowing) {
            VStack(alignment: .leading, spacing: 10) {
                Text(info.title)
                    .font(.headline)
                ForEach(info.paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
                }
            }
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)
            .padding()
            .frame(idealWidth: 340)
            .presentationCompactAdaptation(.popover)
        }
    }
}

/// A form row whose title has an ⓘ button beside it.
struct InfoLabel: View {
    let title: String
    let info: AssumptionInfo

    init(_ title: String, info: AssumptionInfo) {
        self.title = title
        self.info = info
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .fixedSize()
            InfoButton(info)
        }
    }
}
