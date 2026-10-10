# Design: Coastline

Personal iOS app that recommends the best money move (pay debt vs. invest) and shows the possible futures behind each choice, measured by Coast FIRE date.

Single user. No accounts. All data stored on device.

The name on the Home screen and under the app icon is Coastline.

---

## Tech

- Platform: iOS
- UI: SwiftUI (native components for MVP; visual polish comes later)
- Charts: Swift Charts
- Storage: local only (on device)

---

## Principles (apply everywhere)

1. **Suggest, never act.** The app never changes budgets, splits, or plans without explicit user approval.
2. **Ranges, not single numbers.** Every projection shows good / typical / bad outcomes.
3. **Coast FIRE date is the unit of value.** Every option shows how it moves the Coast FIRE date.
4. **The engine does all math.** UI (and later a chatbot) only call the engine and display results. No financial math in views.
5. **Display in today's dollars.**
6. **Explain assumptions.** Settings and assumptions get a short plain-language ⓘ explanation. Draft copy is in `assumption-explanations.md`; wire it when Setup and Change assumptions exist.

---

## Scope

### MVP
- Setup
- Projection engine (fixed-rate scenarios)
- Home (Coast FIRE projection)
- Compare (debt vs. invest, monthly split and one-time lump sum)
- Change assumptions
- After-choosing action checklist
- Prime rate entered manually

### Version 2
- Prime rate tracking (CIBC prime, checked after Bank of Canada announcement dates; floating-rate loans only)
- Budget change suggestions (triggered by rate changes, raises, interest start) with one-tap approval
- Priority profile and flex rules
- Travel fund
- Chatbot (calls the engine; never does math itself)
- Notifications (including a push for the loan-payoff Coming up item)

### Later
- Monte Carlo or historical replay scenarios (engine swap, no UI changes)
- Account syncing, taxes, TFSA/RRSP room tracking, integration with CashOnly

### Out of scope
- Spending/budget tracking (belongs in the separate CashOnly app)
- Individual stock picking. Investing help is limited to index funds, ETFs, and mutual funds.

---

## Screens (MVP)

### Setup
- One topic per screen: about you → loans → current investments → Coast FIRE goal.
- Unknown assumptions can use a typical default.
- Ends by showing the Coast FIRE date.
- Shown on first launch, when no plan is saved. Run again from the main screen, starting from the saved answers, with Cancel.
- **About you:** current age, and the monthly amount for extra loan payments and investing, on top of minimum loan payments.
- **Loans:** zero or more. Per loan: optional name, balance, fixed rate or margin over prime, interest method, whether interest has started (or the date it starts), disbursed before or after July 1 2023, and the statement minimum payment. With no statement payment, the minimum is estimated from the years left to repay.
- **Prime rate** is asked on the loans screen only when a loan is floating. It has no default: a typed default would go stale, so the user enters their lender's current prime.
- **Current investments:** balance and fund type. The fee is shown, not edited: the fund-type default (e.g. "0.20%, index ETF default"), or "set by you" once the user overrides it in Change assumptions.
- **Coast FIRE goal:** retirement age, yearly retirement spending (today's dollars), withdrawal rate, and inflation. Return rates are listed, not edited; they change in Change assumptions.
- **Typical defaults**, prefilled so the user can keep them:
  - Retirement age **65**.
  - Withdrawal rate **4%**, the common planning rate.
  - Inflation **2%**, the Bank of Canada target.
  - Years left to repay a loan **10**, used only to estimate a minimum payment until the user enters one from a statement.
  - Interest method daily accrual, monthly application. Disbursed on or after July 1 2023. Interest already started.
- Each screen lists what is missing; Next stays disabled until the screen is complete.
- **Saving:** the plan is saved on the device when the last screen opens. Anything Setup does not ask about stays as saved (return rates, a fee the user set, risk tolerance, a chosen split, budget).
- **Split:** until the user chooses one, Setup stores the engine's recommended split as a suggestion (no chosen plan) and the last screen shows it with its reason. A split the user already chose is kept. With no loans, everything is invested.
- The last screen shows the typical Coast FIRE date, the good-to-bad range, the suggested split, and net worth over time.

### Home
- Primary: Coast FIRE date (e.g. "November 2033"), with "about X years" and likely range below.
- "Coming up" section: only shown when something needs attention (e.g. "Decide on bonus by April 2027").
- Loan payoff: in a loan's projected payoff month, Coming up shows "Your [loan] should be paid off in [month]. Its $X payment is free." Tapping it opens a sheet with two options, each with its Coast FIRE date and good–bad range:
  - **Invest it:** the freed payment is added to monthly investing.
  - **Keep it:** the freed payment leaves the projection, as if spent.
  - Actions: I'll invest it, I'll keep it, Not paid off yet. Nothing changes until the user taps one. Not paid off yet hides the item until next month.
- Current monthly split (extra to loan / investing) with Adjust button.

### Compare
- Mode toggle: **Every month** or **One time** (lump sum).
- Recommendation shown first, with a one-sentence reason.
- Chart: net worth over time per option, shaded good–bad bands, drag to scrub years.
- Compact table, options as columns. Rows: Coast FIRE date (typical), interest paid, bad-case Coast FIRE date.
- Slider for a custom split (loan ↔ invest).
- Actions: Change assumptions, I'll do this.

### Change assumptions (sheet over Compare)
- Good / typical / bad return rates, prime rate, inflation, fees.
- Fee starts at the fund-type default (e.g. "0.20%, index ETF default"). The user can override it and reset it to the default.
- Shows break-even: "Paying the loan wins if markets return less than X% a year." The engine computes it (see Rules: Break-even return).
- Prime rate is typed in, required only when a loan is floating.
- Opens at half height so Compare stays visible. Each valid edit reruns Compare right away.
- Assumptions are settings, not a choice of split. Done saves them on the device, and Home updates. Cancel puts Compare back on the assumptions it had. Swipe-to-dismiss is blocked while there are unsaved edits.
- Done stays disabled while a field needs fixing (e.g. the bad return is above typical, or typical is above good). The break-even is hidden until the fields are valid.
- The split is still saved only through I'll do this.

### After choosing
- Checklist of concrete steps (e.g. loan payment amount, amount to put in TFSA).
- Shows Coast FIRE date change (before → after).
- Fee assumption is the fund-type default (index ETF vs. mutual fund) unless the user set one.

---

## Engine

### Inputs
- **Loans** (per loan): optional name (for display, e.g. the Home payoff item), balance, disbursed before/after July 1 2023, rate type (floating/fixed), rate, interest start date, minimum payment, interest method
- **Money:** monthly amount to allocate, lump sums (amount + month)
- **Split:** % to extra loan payment vs. investing. A lump sum can carry its own split, set by Compare's One time mode; otherwise it follows the monthly split.
- **Investments:** current balance, fund type (sets the default fee)
- **Coast FIRE goal:** current age, retirement age, yearly retirement spending (today's dollars), withdrawal rate
- **Assumptions:** good/typical/bad annual return (defaults 3% / 6.5% / 10%), inflation, prime rate, annual fee (default from fund type: index ETF **0.20%**, mutual fund **2.00%**)
- **Freed payments:** per loan, the user's answer at payoff (invest it / keep it). None until the user answers.

### Outputs (per option, per scenario)
- Month-by-month: loan balances, investment balance, net worth, cumulative interest paid
- Coast FIRE date
- Loan payoff date
- Total interest paid

### Monthly step
```
for each month:
  1. Update rates          floating = prime (+ margin); fixed = unchanged
  2. Accrue loan interest  only if month >= interest start date
                           interest = balance * annualRate * (daysInMonth / 365)
                           (accrues daily, applied monthly; no compounding within a month)
  3. Money arrives         monthly amount + any lump sum this month
  4. Pay loans             minimum, then extra per split; interest first, then principal
  5. Invest                investing amount added to portfolio
  6. Grow investments      portfolio *= (1 + monthlyReturn) for this scenario
  7. Record month          convert balances, net worth, and interest paid to today's dollars; check Coast FIRE reached
```

### Rules
- **Dollars:** simulate in nominal dollars. Loan rates and investment returns are both nominal, and the monthly step does not adjust either one for inflation. Convert to today's dollars only for display and for the Coast FIRE check.

  At month `m` (month 0 is the start of the projection):

  `todayDollars = nominal / (1 + inflation) ^ (m / 12)`

  Balances and net worth use the end-of-month nominal amount. Interest paid is the sum of each month's interest converted from that month. Yearly retirement spending stays in today's dollars and is not inflated inside the simulation.
- **Granularity:** monthly, not per paycheck.
- **Contributions:** monthly investing rises with inflation by default (configurable to flat).
- **Lump sum:** treated as a month with extra money.
- **Future prime rate:** held constant at the current value (MVP).
- **Break-even return:** the yearly market return, before fees, below which an extra dollar does better paying a loan than invested. Extra money pays the highest-rate loan with a balance first, so the break-even is that loan's rate compounded the way the monthly step charges interest over the next 12 months, plus the fee. No loan balance means no break-even.
- **Minimum payment:** user-entered from statement; estimated from balance and repayment term until available.
- **Interest method:** configurable per loan; default = daily accrual, monthly application.
- **Loan payoff:** the priority profile is not in the MVP. Freed payment is suggested in proportion to the current budget (excluding needs, and excluding the emergency fund if it is full). With no budget, which is every MVP plan until CashOnly (Later), the suggestion is to invest all of it. Setup does not ask for a budget.
  - Projections use the suggested split for each loan until the user answers at payoff (Home, Coming up). "Invest it" sends the whole freed payment to investing. "Keep it" sends none of it to loans or investing, so it leaves the projection.
  - Once no loan is left, any money still headed to loans (the extra-to-loan slice, the loan slice of a lump sum, or a loan share of freed payments) is invested instead of dropped.
  - The engine reports the Coast FIRE date for both answers, so the payoff sheet can show them side by side.

### Coast FIRE math
```
realReturn  = (1 + nominalReturn) / (1 + inflation) - 1
fireNumber  = yearlySpending / withdrawalRate                 (today's dollars)
coastNumber = fireNumber / (1 + realReturn) ^ yearsLeft
Coast FIRE reached when invested balance (today's dollars) >= coastNumber
```
`nominalReturn` is that scenario's annual return minus the annual fee, the same return the monthly step grows the balance at. `yearsLeft` is the time remaining until retirement in the month being checked.

### Scenarios (MVP)
- Fixed annual returns: good / typical / bad (user-configurable settings).
- Defaults, used when the user has not set a rate: bad **3%**, typical **6.5%**, good **10%**.
- The rates are compound nominal annual returns, before fees. Fees stay a separate assumption. The monthly step and the Coast FIRE check both subtract the fee from the rate; the check then converts it to a real return.
- Source: the 2026 Projection Assumption Guidelines from FP Canada and the Institute of Financial Planning (nominal returns, before fees).
  - Typical, 6.5%, is the midpoint of the developed-equity assumptions: Canadian equities 6.3%, U.S. equities 6.4%, international developed-market equities 6.6%.
  - Those guidelines put the historical equity risk premium at 3.2 percentage points for U.S. equities. Bad is that premium failing to arrive: 6.5% − 3.2% = 3.3%, rounded to 3%, about the fixed-income assumption of 3.2%. Good is the premium arriving on top of typical: 6.5% + 3.2% = 9.7%, rounded to 10%.
- Each option is simulated once per scenario.
- Must be swappable later for Monte Carlo or historical replay without UI changes. If Monte Carlo is added, use a fixed random seed so results don't jitter as the slider moves.

### Fees
- Default annual fee by fund type, used when the user has not set a fee: index ETF **0.20%**, mutual fund **2.00%**. A fee the user sets overrides the default and stays when the fund type changes.
- The engine owns the default. An unset fee is passed to the engine as unset (not 0), and the engine applies the fund type's default. The plan stores a fee only when the user sets one. With no fund type yet, the index ETF default applies.
- Sources:
  - Index ETF: published MERs of the all-equity asset-allocation ETFs (2026): XEQT 0.20%, ZEQT 0.18%, VEQT 0.24%.
  - Mutual fund: the OSC asset-weighted MER table for Canadian equity mutual funds (getsmarteraboutmoney.ca, Class A), 1.88%–2.21% across the years shown.
- Bank index mutual funds (e.g. about 0.3%) are far below the mutual-fund default. The ⓘ copy tells the user to check their fund's MER and enter it.

### Recommendation rule (balanced)
```
1. Candidates: loan share from 0% to 100% in 10% steps, of the monthly amount (Every month)
   or of one lump sum (One time); every other split stays as planned
2. Simulate every candidate in good / typical / bad scenarios
3. safest = candidate with the earliest bad-case Coast FIRE date
4. allowed = candidates whose bad-case date <= safest.badCaseDate + riskTolerance
5. recommend = allowed candidate with the earliest typical Coast FIRE date
6. Tiebreak: prefer the higher loan share (guaranteed return)
```
- `riskTolerance` is a user setting, in months. The default is 12. A candidate stays eligible when its bad-case Coast FIRE date is at most 12 months later than the safest option.
- The reason text is generated from the comparison, e.g. "Reaches Coast FIRE 5 months sooner in a typical market, and only 2 months behind the safest option in a bad market."

---

## Version 2 design notes

### Budget suggestions and flex rules
- Suggestion only; one-tap approval; nothing applied automatically.
- User-configured flex rules: ordered category list, "take up to $X" per category, locked categories (needs locked; emergency fund locked until goal reached).
- If limits can't cover what's needed, say so and show options.

### Priority profile
- Not in the MVP. Until this exists, loan-payoff suggestions use current budget proportions only, or invest everything when there is no budget.
- Saving ↔ enjoying slider, category ranking, separate risk tolerance setting.
- Later: notice repeated rejected suggestions and ask whether to update priorities.

### Travel fund
- Yearly fund that refills each paycheck; specific trips (name, cost, date) checked against it.
- Shows months/paychecks to fund a trip, or amount per paycheck needed for a target date.
- Shows impact on Coast FIRE date.

### Chatbot
- Translates natural language (expenses, concerns) into engine inputs, runs the engine, explains results. Never computes numbers itself.

---

## Open questions
- Whether money returned after a rate drop follows the same flex order or a separate list
