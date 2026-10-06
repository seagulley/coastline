# Design: Coastline (working name)

Personal iOS app that recommends the best money move (pay debt vs. invest) and shows the possible futures behind each choice, measured by Coast FIRE date.

Single user. No accounts. All data stored on device.

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
6. **Explain assumptions.** Settings and assumptions get a short plain-language ⓘ explanation.

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
- Notifications

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

### Home
- Primary: Coast FIRE date (e.g. "November 2033"), with "about X years" and likely range below.
- "Coming up" section: only shown when something needs attention (e.g. "Decide on bonus by April 2027").
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
- Shows break-even: "Paying the loan wins if markets return less than X% a year."

### After choosing
- Checklist of concrete steps (e.g. loan payment amount, amount to put in TFSA).
- Shows Coast FIRE date change (before → after).
- Fee assumption depends on fund type (index ETF vs. mutual fund).

---

## Engine

### Inputs
- **Loans** (per loan): balance, disbursed before/after July 1 2023, rate type (floating/fixed), rate, interest start date, minimum payment, interest method
- **Money:** monthly amount to allocate, lump sums (amount + month)
- **Split:** % to extra loan payment vs. investing
- **Investments:** current balance, fund type (for fees)
- **Coast FIRE goal:** current age, retirement age, yearly retirement spending (today's dollars), withdrawal rate
- **Assumptions:** good/typical/bad annual return, inflation, prime rate

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
- **Minimum payment:** user-entered from statement; estimated from balance and repayment term until available.
- **Interest method:** configurable per loan; default = daily accrual, monthly application.
- **Loan payoff:** the priority profile is not in the MVP. Freed payment is suggested in proportion to the current budget (excluding needs, and excluding the emergency fund if it is full). Projections use the suggested split until the user chooses. Also show the Coast FIRE date if all freed money goes to investing (informational, not pressure).

### Coast FIRE math
```
realReturn  = (1 + nominalReturn) / (1 + inflation) - 1
fireNumber  = yearlySpending / withdrawalRate                 (today's dollars)
coastNumber = fireNumber / (1 + realReturn) ^ yearsLeft
Coast FIRE reached when invested balance (today's dollars) >= coastNumber
```
`nominalReturn` is that scenario's annual return. `yearsLeft` is the time remaining until retirement in the month being checked.

### Scenarios (MVP)
- Fixed annual returns: good / typical / bad (user-configurable settings).
- Each option is simulated once per scenario.
- Must be swappable later for Monte Carlo or historical replay without UI changes. If Monte Carlo is added, use a fixed random seed so results don't jitter as the slider moves.

### Recommendation rule (balanced)
```
1. Candidates: loan share from 0% to 100% in 10% steps
2. Simulate every candidate in good / typical / bad scenarios
3. safest = candidate with the earliest bad-case Coast FIRE date
4. allowed = candidates whose bad-case date <= safest.badCaseDate + riskTolerance
5. recommend = allowed candidate with the earliest typical Coast FIRE date
6. Tiebreak: prefer the higher loan share (guaranteed return)
```
- `riskTolerance` is a user setting (in months).
- The reason text is generated from the comparison, e.g. "Reaches Coast FIRE 5 months sooner in a typical market, and only 2 months behind the safest option in a bad market."

---

## Version 2 design notes

### Budget suggestions and flex rules
- Suggestion only; one-tap approval; nothing applied automatically.
- User-configured flex rules: ordered category list, "take up to $X" per category, locked categories (needs locked; emergency fund locked until goal reached).
- If limits can't cover what's needed, say so and show options.

### Priority profile
- Not in the MVP. Until this exists, loan-payoff suggestions use current budget proportions only.
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
- Default values for good / typical / bad return rates
- Default risk tolerance (months)
- Whether money returned after a rate drop follows the same flex order or a separate list
- Display name for the app
