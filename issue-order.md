# Issue order

The order to complete the [Coastline issues](https://github.com/seagulley/coastline/issues), and which ones can proceed at the same time.

Finish each wave before the next. Issues in the same wave can be worked on together. Working alone, take a wave in the order listed.

Waves 1–5 are the MVP. Waves 6–8 are Version 2. Wave 9 is Later.

---

## Wave 1 — Decisions that change the build

Do these together, and finish them before the engine.

- [#10](https://github.com/seagulley/coastline/issues/10) Decide: simulate in nominal dollars
- [#13](https://github.com/seagulley/coastline/issues/13) Decide: is the priority profile in the MVP?

[#10](https://github.com/seagulley/coastline/issues/10) is the rule the monthly step implements. [#13](https://github.com/seagulley/coastline/issues/13) decides whether loan-payoff suggestions in the MVP use current budget proportions only. The design already allows that path without a priority profile.

These three can also be decided now. They do not block starting the scaffold or the engine:

- [#11](https://github.com/seagulley/coastline/issues/11) Decide: default good, typical, and bad return rates — close before Setup is finished
- [#12](https://github.com/seagulley/coastline/issues/12) Decide: default risk tolerance — close before the recommendation is finished
- [#14](https://github.com/seagulley/coastline/issues/14) Decide: app display name — close before Home shows the final name

---

## Wave 2 — Foundation

Together, after wave 1:

- [#1](https://github.com/seagulley/coastline/issues/1) Scaffold the iOS app and on-device storage
- [#2](https://github.com/seagulley/coastline/issues/2) Build the projection engine

The scaffold and the engine are independent. The engine is pure calculation and can be built and tested on its own. Working alone, create the app target first so the engine has a place to live, then build the engine.

The ⓘ copy for [#9](https://github.com/seagulley/coastline/issues/9) is drafted in `assumption-explanations.md`. Wiring that copy into screens waits until those screens exist.

---

## Wave 3 — Scenarios and the recommendation

- [#3](https://github.com/seagulley/coastline/issues/3) Run good, typical, and bad scenarios and recommend a split

Starts once [#2](https://github.com/seagulley/coastline/issues/2) is done. Close [#12](https://github.com/seagulley/coastline/issues/12) before calling this done, so the recommendation has a default risk tolerance.

Two engine changes from decisions already recorded in `design.md` (not filed as issues yet) land before this is done. #3 can start without them. Both move every Coast FIRE date the recommendation compares:

- Freed payments with no budget: invest all of a freed payment when there is no budget. Once no loan is left, invest any money still headed to loans instead of dropping it. Without this, every loan-heavy candidate loses money after payoff and the recommendation can never favor paying debt.
- Fees: the Coast FIRE check uses the return after fees, the same return the balance grows at.

---

## Wave 4 — Screens that show a projection

Together, after wave 3. Each one needs the app shell, the engine, and the three scenarios.

- [#4](https://github.com/seagulley/coastline/issues/4) Setup flow — also needs the default returns from [#11](https://github.com/seagulley/coastline/issues/11) and the fee defaults by fund type. No budget step.
- [#5](https://github.com/seagulley/coastline/issues/5) Home screen — use the working name until [#14](https://github.com/seagulley/coastline/issues/14) is decided. Includes the loan-payoff Coming up item and its invest-it / keep-it sheet.
- [#6](https://github.com/seagulley/coastline/issues/6) Compare debt versus investing

Setup, Home, and Compare read the same engine results and do not depend on each other. Home's Adjust button opens Compare, so the handoff is done when both exist.

The loan-payoff item needs a per-loan answer (invest it or keep it) saved in the plan, and an engine input that takes one answer per loan. Notifications ([#21](https://github.com/seagulley/coastline/issues/21)) add a push for the same item later.

---

## Wave 5 — After a choice

Together, after Compare:

- [#7](https://github.com/seagulley/coastline/issues/7) Change assumptions
- [#8](https://github.com/seagulley/coastline/issues/8) After-choosing checklist
- [#9](https://github.com/seagulley/coastline/issues/9) Explain each assumption in plain language — wire the drafted copy into Setup and Change assumptions

Change assumptions and the checklist both hang off Compare and do not depend on each other. The break-even line and the checklist amounts come from the engine.

Both use the fund-type fee default unless the user set a fee. Change assumptions is where the user overrides it and resets it.

---

## Wave 6 — Version 2 foundation

Together, after the MVP. Close [#22](https://github.com/seagulley/coastline/issues/22) before building the rate-drop path.

- [#22](https://github.com/seagulley/coastline/issues/22) Decide: flex order for money returned after a rate drop
- [#15](https://github.com/seagulley/coastline/issues/15) Track CIBC prime after Bank of Canada announcements
- [#17](https://github.com/seagulley/coastline/issues/17) Flex rules for where extra money comes from
- [#18](https://github.com/seagulley/coastline/issues/18) Priority profile
- [#19](https://github.com/seagulley/coastline/issues/19) Travel fund
- [#20](https://github.com/seagulley/coastline/issues/20) Chatbot that only calls the engine

Prime tracking, flex rules, and the priority profile are independent of each other. The travel fund and the chatbot only need the MVP engine, so they can keep going alongside wave 7.

---

## Wave 7 — Budget suggestions

- [#16](https://github.com/seagulley/coastline/issues/16) Suggest budget changes, applied only after approval

This waits for prime tracking ([#15](https://github.com/seagulley/coastline/issues/15)), flex rules ([#17](https://github.com/seagulley/coastline/issues/17)), the priority profile ([#18](https://github.com/seagulley/coastline/issues/18)), and the rate-drop decision ([#22](https://github.com/seagulley/coastline/issues/22)). Suggestions draw from those rules, and a rate change is one of the triggers.

[#19](https://github.com/seagulley/coastline/issues/19) and [#20](https://github.com/seagulley/coastline/issues/20) can still be in progress during this wave.

---

## Wave 8 — Notifications

- [#21](https://github.com/seagulley/coastline/issues/21) Notifications

Notifications tell the user about Coming up items and about suggestion triggers. Finish Home, prime tracking, and budget suggestions first. A notification still leads to a suggestion that needs approval.

---

## Wave 9 — Later

Together, after Version 2:

- [#23](https://github.com/seagulley/coastline/issues/23) Swap in Monte Carlo or historical replay
- [#24](https://github.com/seagulley/coastline/issues/24) Sync accounts
- [#25](https://github.com/seagulley/coastline/issues/25) Track taxes and TFSA/RRSP room
- [#26](https://github.com/seagulley/coastline/issues/26) Integrate with CashOnly

These four do not depend on each other. Two of them can start earlier without waiting for the rest of Version 2:

- [#23](https://github.com/seagulley/coastline/issues/23) can start once scenarios ([#3](https://github.com/seagulley/coastline/issues/3)) expose a swappable scenario source. It changes the engine only.
- [#24](https://github.com/seagulley/coastline/issues/24) and [#25](https://github.com/seagulley/coastline/issues/25) can start once the engine inputs from [#2](https://github.com/seagulley/coastline/issues/2) are stable. Room tracking also uses the recommendation from [#3](https://github.com/seagulley/coastline/issues/3).
- [#26](https://github.com/seagulley/coastline/issues/26) waits for flex rules ([#17](https://github.com/seagulley/coastline/issues/17)), because it supplies the budget proportions those rules read. It can proceed alongside the other Later issues after that.

---

## What each issue waits for

| Issue | Wait for | Can proceed with |
| --- | --- | --- |
| [#10](https://github.com/seagulley/coastline/issues/10) Nominal dollars | — | [#13](https://github.com/seagulley/coastline/issues/13) |
| [#13](https://github.com/seagulley/coastline/issues/13) Priority profile in the MVP? | — | [#10](https://github.com/seagulley/coastline/issues/10) |
| [#11](https://github.com/seagulley/coastline/issues/11) Default returns | — | Anything, until Setup is finished |
| [#12](https://github.com/seagulley/coastline/issues/12) Default risk tolerance | — | Anything, until the recommendation is finished |
| [#14](https://github.com/seagulley/coastline/issues/14) Display name | — | Anything, until Home shows the final name |
| [#1](https://github.com/seagulley/coastline/issues/1) App scaffold | — | [#2](https://github.com/seagulley/coastline/issues/2), the open decisions, drafting [#9](https://github.com/seagulley/coastline/issues/9) |
| [#2](https://github.com/seagulley/coastline/issues/2) Projection engine | [#10](https://github.com/seagulley/coastline/issues/10), [#13](https://github.com/seagulley/coastline/issues/13) | [#1](https://github.com/seagulley/coastline/issues/1), [#11](https://github.com/seagulley/coastline/issues/11), [#12](https://github.com/seagulley/coastline/issues/12), [#14](https://github.com/seagulley/coastline/issues/14), drafting [#9](https://github.com/seagulley/coastline/issues/9) |
| [#3](https://github.com/seagulley/coastline/issues/3) Scenarios and recommendation | [#2](https://github.com/seagulley/coastline/issues/2). Before finishing: close [#12](https://github.com/seagulley/coastline/issues/12), and land the no-budget freed-payment and after-fee Coast FIRE engine changes | — |
| [#4](https://github.com/seagulley/coastline/issues/4) Setup | [#1](https://github.com/seagulley/coastline/issues/1), [#2](https://github.com/seagulley/coastline/issues/2), [#3](https://github.com/seagulley/coastline/issues/3), [#11](https://github.com/seagulley/coastline/issues/11), fee defaults by fund type in the engine | [#5](https://github.com/seagulley/coastline/issues/5), [#6](https://github.com/seagulley/coastline/issues/6) |
| [#5](https://github.com/seagulley/coastline/issues/5) Home | [#1](https://github.com/seagulley/coastline/issues/1), [#2](https://github.com/seagulley/coastline/issues/2), [#3](https://github.com/seagulley/coastline/issues/3). [#14](https://github.com/seagulley/coastline/issues/14) before the final name. Per-loan freed-payment answers in the plan and engine before the payoff item | [#4](https://github.com/seagulley/coastline/issues/4), [#6](https://github.com/seagulley/coastline/issues/6) |
| [#6](https://github.com/seagulley/coastline/issues/6) Compare | [#1](https://github.com/seagulley/coastline/issues/1), [#2](https://github.com/seagulley/coastline/issues/2), [#3](https://github.com/seagulley/coastline/issues/3) | [#4](https://github.com/seagulley/coastline/issues/4), [#5](https://github.com/seagulley/coastline/issues/5) |
| [#7](https://github.com/seagulley/coastline/issues/7) Change assumptions | [#2](https://github.com/seagulley/coastline/issues/2), [#6](https://github.com/seagulley/coastline/issues/6) | [#8](https://github.com/seagulley/coastline/issues/8), wiring [#9](https://github.com/seagulley/coastline/issues/9) |
| [#8](https://github.com/seagulley/coastline/issues/8) After-choosing checklist | [#2](https://github.com/seagulley/coastline/issues/2), [#6](https://github.com/seagulley/coastline/issues/6) | [#7](https://github.com/seagulley/coastline/issues/7), wiring [#9](https://github.com/seagulley/coastline/issues/9) |
| [#9](https://github.com/seagulley/coastline/issues/9) Assumption explanations | Draft anytime. Wire after [#4](https://github.com/seagulley/coastline/issues/4) and [#7](https://github.com/seagulley/coastline/issues/7) | Draft with wave 2. Wire with [#7](https://github.com/seagulley/coastline/issues/7) and [#8](https://github.com/seagulley/coastline/issues/8) |
| [#15](https://github.com/seagulley/coastline/issues/15) Prime tracking | MVP engine ([#2](https://github.com/seagulley/coastline/issues/2)) | [#17](https://github.com/seagulley/coastline/issues/17), [#18](https://github.com/seagulley/coastline/issues/18), [#19](https://github.com/seagulley/coastline/issues/19), [#20](https://github.com/seagulley/coastline/issues/20), [#22](https://github.com/seagulley/coastline/issues/22) |
| [#17](https://github.com/seagulley/coastline/issues/17) Flex rules | MVP | [#15](https://github.com/seagulley/coastline/issues/15), [#18](https://github.com/seagulley/coastline/issues/18), [#19](https://github.com/seagulley/coastline/issues/19), [#20](https://github.com/seagulley/coastline/issues/20), [#22](https://github.com/seagulley/coastline/issues/22) |
| [#18](https://github.com/seagulley/coastline/issues/18) Priority profile | [#13](https://github.com/seagulley/coastline/issues/13) decided, MVP | [#15](https://github.com/seagulley/coastline/issues/15), [#17](https://github.com/seagulley/coastline/issues/17), [#19](https://github.com/seagulley/coastline/issues/19), [#20](https://github.com/seagulley/coastline/issues/20), [#22](https://github.com/seagulley/coastline/issues/22) |
| [#19](https://github.com/seagulley/coastline/issues/19) Travel fund | [#2](https://github.com/seagulley/coastline/issues/2) | The rest of Version 2 |
| [#20](https://github.com/seagulley/coastline/issues/20) Chatbot | [#2](https://github.com/seagulley/coastline/issues/2), [#3](https://github.com/seagulley/coastline/issues/3) | The rest of Version 2 |
| [#22](https://github.com/seagulley/coastline/issues/22) Rate-drop flex order | — | Wave 6. Finish before the rate-drop path in [#16](https://github.com/seagulley/coastline/issues/16) |
| [#16](https://github.com/seagulley/coastline/issues/16) Budget suggestions | [#15](https://github.com/seagulley/coastline/issues/15), [#17](https://github.com/seagulley/coastline/issues/17), [#18](https://github.com/seagulley/coastline/issues/18), [#22](https://github.com/seagulley/coastline/issues/22) | [#19](https://github.com/seagulley/coastline/issues/19), [#20](https://github.com/seagulley/coastline/issues/20) |
| [#21](https://github.com/seagulley/coastline/issues/21) Notifications | [#5](https://github.com/seagulley/coastline/issues/5), [#15](https://github.com/seagulley/coastline/issues/15), [#16](https://github.com/seagulley/coastline/issues/16) | — |
| [#23](https://github.com/seagulley/coastline/issues/23) Monte Carlo or historical replay | [#3](https://github.com/seagulley/coastline/issues/3) | [#24](https://github.com/seagulley/coastline/issues/24), [#25](https://github.com/seagulley/coastline/issues/25), and Version 2 if pulled forward |
| [#24](https://github.com/seagulley/coastline/issues/24) Account sync | [#2](https://github.com/seagulley/coastline/issues/2) | [#23](https://github.com/seagulley/coastline/issues/23), [#25](https://github.com/seagulley/coastline/issues/25), [#26](https://github.com/seagulley/coastline/issues/26) |
| [#25](https://github.com/seagulley/coastline/issues/25) Taxes and TFSA/RRSP room | [#2](https://github.com/seagulley/coastline/issues/2), [#3](https://github.com/seagulley/coastline/issues/3) | [#23](https://github.com/seagulley/coastline/issues/23), [#24](https://github.com/seagulley/coastline/issues/24), [#26](https://github.com/seagulley/coastline/issues/26) |
| [#26](https://github.com/seagulley/coastline/issues/26) CashOnly | [#2](https://github.com/seagulley/coastline/issues/2), [#17](https://github.com/seagulley/coastline/issues/17) | [#23](https://github.com/seagulley/coastline/issues/23), [#24](https://github.com/seagulley/coastline/issues/24), [#25](https://github.com/seagulley/coastline/issues/25) |
