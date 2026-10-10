# ⓘ copy

Plain-language explanations for each editable assumption ([#9](https://github.com/seagulley/coastline/issues/9)). Each note says what the control means, then what happens to the Coast FIRE date when the value goes up or down.

Wire these into Setup and Change assumptions when those screens exist. Until then this file is the copy only.

Change assumptions shows the return rates, prime, inflation, and fees. Withdrawal rate sits with the Coast FIRE goal. Risk tolerance and rising contributions still need a home on a screen; the copy is ready for either Setup or Change assumptions.

Balances, ages, payment amounts, and other facts the user knows about themselves are not assumptions, so they are not in this draft.

---

## Bad return

The yearly return in a weak market, before fees, in ordinary dollars. The bad-case Coast FIRE date uses this rate.

Raising it brings that bad-case date sooner, and can move the recommendation toward investing. The safest split is the one with the earliest Coast FIRE date at this rate. Lowering it pushes the bad-case date later, and can move the recommendation toward paying the loan.

## Typical return

The yearly return in a middle market, before fees, in ordinary dollars. The main Coast FIRE date uses this rate.

Raising it brings that date sooner. Lowering it pushes it later. Among splits that stay inside your risk tolerance in a bad market, the recommendation is the one with the earliest Coast FIRE date at this rate.

## Good return

The yearly return in a strong market, before fees, in ordinary dollars. The optimistic end of the range uses this rate.

Raising it brings that optimistic Coast FIRE date sooner. Lowering it pushes it later. The typical date, the bad-case date, and the recommendation stay on the other two rates.

If you leave the three rates unset, they start at 3% bad, 6.5% typical, and 10% good. Those are planning assumptions for a mix of developed-market stocks, before fees.

## Prime rate

The prime rate a floating-rate loan is priced from. That loan’s interest rate is this prime plus the loan’s margin, and the projection keeps prime at the number you enter.

Raising it charges more interest, so more of each payment covers interest and the balance falls slower. Payoff comes later, and the invested share of that freed payment starts later, which pushes the Coast FIRE date later. Lowering it cuts the interest, frees that money sooner, and brings the Coast FIRE date sooner.

A fixed-rate loan keeps the rate you entered for it, so changing prime leaves that loan alone.

## Inflation

How fast prices rise each year. The Coast FIRE check is in today’s dollars: a future balance is scaled down by inflation, and the return that counts is what remains after inflation.

Raising it makes the same future balance worth less today and raises the amount you need invested, so the Coast FIRE date moves later. Lowering it makes future balances worth more today and lowers that amount, so the date moves sooner.

Your loan rate and the three market returns stay at the numbers you set.

## Fees

The yearly cost of the fund (its MER), taken off the return before the balance grows and before the Coast FIRE check. It starts at the default for your fund type: 0.20% for an index ETF and 2.00% for a mutual fund. If you know your fund's MER, enter it. Bank index mutual funds are often under 0.5%.

Raising the fee leaves less of the market return invested, so the Coast FIRE date moves later. Lowering it leaves more invested, so the date moves sooner.

## Fund type

Index ETF or mutual fund. This sets the starting fee taken off your return. If you entered your own fee, changing the fund type leaves it alone.

Choosing the higher-fee type moves the Coast FIRE date later. Choosing the lower-fee type moves it sooner.

## Withdrawal rate

The share of your investments you plan to spend each year in retirement. Yearly spending divided by this rate is the nest egg Coast FIRE is aiming at.

Raising it shrinks that nest egg, so the Coast FIRE date moves sooner. Lowering it enlarges the nest egg, so the date moves later.

## Risk tolerance

How many months the bad-market Coast FIRE date may fall behind the safest split and still be recommended. The starting value is 12 months.

This setting picks the suggested split. It leaves each split’s own dates as they are. Raising it can switch the suggestion to a split that is sooner in a typical market and later in a bad market. Lowering it can switch the suggestion toward the split with the earliest bad-market date.

## Contributions rise with inflation

This starts on. The monthly amount you invest grows with inflation, so later contributions keep the same buying power.

Turning it on brings the Coast FIRE date sooner than a frozen dollar amount. Turning it off keeps that monthly amount at the same number of dollars, so later contributions buy less and the Coast FIRE date moves later.

## Interest method

How this loan adds interest. The usual method counts each day in the month, then adds the interest once at month end, with no interest on that interest inside the month.

A method that adds more interest slows payoff. The invested share of that freed payment starts later, so the Coast FIRE date moves later. A method that adds less interest frees that money sooner, so the date moves sooner.
