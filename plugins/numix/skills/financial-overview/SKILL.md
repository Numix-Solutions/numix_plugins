---
name: financial-overview
description: >
  Gives a Numix client a clear picture of their company's current finances:
  cash on hand, net burn or profit, runway and the projected cash-out month,
  then goes deeper on request: monthly income and expenses, trends, cash by
  account, a summary for chosen months, what-if scenarios for runway, and why
  a month moved, from that month's transactions. Use this skill whenever the
  client asks how their company is doing financially, about cash, burn,
  runway, profit, revenue, expenses, margins or spending trends, how long
  their money will last, or what happens if spending changes, even if they
  don't say "financial overview".
user-invocable: true
---

# Financial overview

This skill explains the client's current finances from Numix's Financial Health report, the same numbers as the dashboard's Financial Health cards (https://app.numix.app/dashboard) and the Bookkeeping overview. It starts with a short snapshot, then goes as deep as the client wants.

The rules everything else follows from:

- **Only the report's numbers.** Every amount, month and percentage you give comes from the tools, or is calculated from them in a way you can show. Never estimate, round up a trend into a forecast, or fill a missing month.
- **Always say how fresh it is.** The report is a snapshot: give its date (`fetched_at`) with the first numbers you show.
- **Explain, don't advise.** Describe what the numbers show and what moved them. Don't give investment, tax, legal or fundraising advice, and don't tell the client what to cut or whether to raise money. If they ask, say it's a decision for them and their advisors (their Numix team can help with the bookkeeping side), and offer the numbers that would inform it.
- **This skill only reads.** Nothing here changes the client's data.

## Tools

- `fetch_financial_health`: the Financial Health report. Cached; refreshed automatically when older than 24 hours. Pass `refresh=true` only when the client asks for the latest numbers: it takes several seconds.
- `fetch_transactions`: the client's bank transactions for a date range (`start_date`, `end_date`), 100 per page (`page`). Used to explain why a month moved (Step 3).
- `list_integrations`: the client's connections (banks, accounting software), with `type` and `status`. Used when the report is missing or incomplete.
- `get_user_info`: the signed-in user, if you need their name.

## Reading the report

`fetch_financial_health` returns `fetched_at` (when the report was computed), `cached`, and `report`:

| Field | Meaning |
| --- | --- |
| `report.as_of` | The date the numbers are as of |
| `report.currency` | Currency of every amount, e.g. USD |
| `report.period` | `start`, `end` and `months`: the months the history covers |
| `report.metrics.cash_on_hand.value` | Cash on hand now, all accounts together |
| `report.metrics.cash_on_hand.inputs.accounts` | Per account: `name`, `account_number` (masked, e.g. "****1234"), `balance`, `currency` |
| `report.metrics.cash_on_hand.history` | Per month (`YYYY-MM`, oldest first): `cash` at the end of the month |
| `report.metrics.net_burn.value` | Net burn of the latest month (`net_burn.month`) |
| `report.metrics.net_burn.history` | Per month: `total_income`, `total_expenses`, `net_operating_income`, `net_income`, `net_burn` |
| `report.metrics.runway.value_months` | Months of runway, or null |
| `report.metrics.runway.inputs.avg_net_burn_3m` | Average net burn of the last 3 months: what runway is based on |
| `report.metrics.runway.history` | Per month: `cash`, `avg_net_burn_3m`, `runway_months` |
| `report.notes` | Notes from Numix about the data, e.g. a missing source. Mention them |

**Signs and special values**, the same as the dashboard:

- `net_burn` **positive** = the company spent more than it earned (burned cash). **Negative** = it earned more than it spent (profit). Say "net burn of $42,000" or "net profit of $8,500", never "net burn of −$8,500".
- `runway.value_months` **null** = the 3-month average burn is zero or negative: the company isn't burning cash, so runway doesn't apply. Say "Not burning cash: runway doesn't apply", never "0 months".
- Runway = cash on hand ÷ 3-month average net burn. The projected cash-out month = today plus the runway, rounded down to whole months.

**Formatting**: amounts in the report's currency with thousands separators and no cents above $1,000 (e.g. "$1,284,310"); months as "Mar 2026"; runway to one decimal ("14.2 months").

## Step 0. Load the report

1. Silently call `fetch_financial_health`.
2. If it fails, or the report has no metrics:
   - Call `list_integrations` and look for active bank or accounting connections.
   - If there are none, tell the client the Financial Health report needs a connected bank account or accounting software, and where to connect them: https://app.numix.app/dashboard/settings/connections. Stop here.
   - If they have connections, the report isn't ready yet (it's built from the connected data). Tell the client it couldn't be loaded right now, and to try again later or ask their Numix team.
3. If the result has `refresh_failed: true`, the latest numbers couldn't be generated: say the report shown is from `fetched_at`.

## Step 1. The snapshot

Show the three numbers the dashboard shows, then one line of context. Keep it short: the client asks for more if they want it.

> **Your finances** (as of Nov 14, 2026)
>
> | | |
> |---|---|
> | Cash on hand | **$1,284,310** · ▲ 3.2% vs last month |
> | Net burn (3-month avg) | **$86,450** a month |
> | Runway | **14.9 months** · projected cash-out Jan 2028 |
>
> Burn was higher in September ($112,300) and has come down since.

- **Cash on hand**: `cash_on_hand.value`, and its change vs the previous month in `cash_on_hand.history` (the second-to-last month): "▲ 3.2% vs last month" or "▼ 1.4% vs last month". Leave the change out if there's only one month of history.
- **Net burn or net profit (3-month avg)**: `runway.inputs.avg_net_burn_3m`. Positive: "Net burn (3-month avg)" and the amount. Negative or zero: "Net profit (3-month avg)" and the amount without the sign.
- **Runway**: `runway.value_months` with the projected cash-out month, or "Not burning cash: runway doesn't apply".
- **One line of context**, only if the history supports it: the biggest change in the last 3 months (a month with unusually high or low burn, or cash rising or falling month after month). If nothing stands out, skip it.
- Mention any `report.notes`.

Then offer what's next, in one line: "I can show the monthly breakdown, cash by account, a summary for any months, or what happens to runway if spending changes."

## Step 2. Go deeper

Answer what the client asks, with the view that fits. Each view uses the report already loaded: don't call `fetch_financial_health` again unless the client asks for the latest numbers. Show one view at a time, and after it, one line offering a related one.

### 2.1 Monthly breakdown

For "show me the months", "how have we been doing", or anything about income and expenses over time. One row per month in `net_burn.history`, newest first:

> | Month | Income | Expenses | Net | Cash at month end |
> |---|---|---|---|---|
> | Oct 2026 | $41,200 | $118,900 | −$77,700 | $1,284,310 |
> | Sep 2026 | $38,500 | $150,800 | −$112,300 | $1,362,010 |
> | … | | | | |

- Income: `total_income`. Expenses: `total_expenses`. Net: income − expenses, as in 2.4 and on the dashboard (negative is a loss, positive a profit: here the sign is shown, because it's a column of results, not a burn figure). Cash: the same month's `cash` from `cash_on_hand.history`, or "–" if that month is missing.
- If the client asks about accounting profit, `net_income` is the month's net income from the books, which can differ from income − expenses (e.g. depreciation or other non-cash items). Show it as its own column only then.
- Below the table, one line with the totals for the whole period (`report.period`).

### 2.2 Trends

For "is our burn going up?", "how is revenue growing?" or "what changed?". Compare like with like, and show the numbers behind each statement:

- **Burn**: the average net burn of the last 3 months against the 3 months before (e.g. "Average burn $86,450 in Aug–Oct, down from $97,200 in May–Jul: 11% lower"). Only with at least 6 months of history; otherwise compare month by month.
- **Income and expenses**: month-over-month change for the latest month, and the direction over the period (rising, falling, or no clear direction when it goes up and down).
- **Highest and lowest months**: the month with the highest burn and the one with the lowest, with their amounts.
- **Cash**: how many months in a row cash has risen or fallen, from `cash_on_hand.history`.

Say "no clear trend" when the months go up and down. Don't project trends forward: that's what the what-if view (2.5) is for, and it states its assumptions.

### 2.3 Cash by account

For "where is our cash?" or "which accounts?". From `cash_on_hand.inputs.accounts`, largest balance first:

> | Account | Balance |
> |---|---|
> | Mercury Checking ****9012 | $1,102,400 |
> | Mercury Savings ****7654 | $181,910 |
> | **Total** | **$1,284,310** |

- Account numbers are already masked: show them exactly as given, never ask for or guess the rest.
- If an account's `currency` differs from `report.currency`, show its own currency and say the total converts it.
- If the accounts don't add up to `cash_on_hand.value`, say so in one line rather than adjusting anything.

### 2.4 A summary for chosen months

For "how did Q3 go?", "what were our revenue and expenses this year?" or "summarize March". Ask for the months if the client didn't say, and only use months inside `report.period`: if they ask for months outside it, say which months the report covers.

> **Jul – Sep 2026**
>
> | | |
> |---|---|
> | Revenue | $118,400 |
> | Expenses | $402,100 |
> | Net profit | −$283,700 (net margin −239.6%) |
>
> **Cash**: $1,628,900 at the start → $1,362,010 at the end (−$266,890).
> Income and expenses explain −$283,700 of it; the other +$16,810 is from timing, investing or financing (e.g. loan or card repayments, transfers, money raised).

- Revenue: the sum of `total_income`. Expenses: the sum of `total_expenses`. Net profit: revenue − expenses, and the net margin = net profit ÷ revenue (leave the margin out when revenue is 0).
- **The cash bridge**: opening cash is the `cash` of the month **before** the first chosen month; closing cash is the `cash` of the last chosen month. "Other" = closing − opening − net profit. Leave the bridge out when the opening month isn't in `cash_on_hand.history`.
- These are the same numbers as the dashboard's Bookkeeping overview, for the same months.

### 2.5 What if spending changes?

For "what if we cut burn by 20%?", "what if we hire someone at $15k a month?" or "what if we spend $200k on equipment?". Start from cash on hand and the 3-month average net burn, the same as the dashboard's "What if burn changes?":

- **Burn changes by a percentage**: adjusted burn = average burn + |average burn| × the percentage. So +20% means 20% more burn (or 20% less profit), and −20% means 20% less burn.
- **A new monthly cost or income** (a hire, a contract, a new customer): adjusted burn = average burn + the monthly cost (or − the monthly income).
- **A one-time payment or inflow**: change cash on hand by that amount, burn stays the same.
- Runway = cash ÷ adjusted burn, and the cash-out month as in Step 1. If the adjusted burn is zero or negative, the company isn't burning cash at that level: runway doesn't apply.

Show the scenario next to today, and state the assumptions:

> | | Today | Burn −20% |
> |---|---|---|
> | Monthly net burn | $86,450 | $69,160 |
> | Runway | 14.9 months | 18.6 months |
> | Projected cash-out | Jan 2028 | Jun 2028 |
>
> Assumes cash on hand stays at $1,284,310 to start, and the new burn applies from now on, every month.

For "what if burn goes up or down?", without a number, show −30%, −10%, +10% and +30% side by side.

### 2.6 How it's calculated

When the client asks where a number comes from, explain it with their own numbers:

- **Cash on hand**: the balances of their connected bank accounts on `report.as_of` (list them as in 2.3).
- **Net burn**: expenses − income for the month. Positive is burn, negative is profit.
- **Runway**: cash on hand ÷ the average net burn of the last 3 months, e.g. "$1,284,310 ÷ $86,450 = 14.9 months".
- The data comes from their connected bank accounts and accounting software, and the report is refreshed at least once a day when they use it.

## Step 3. Why did a month move?

For "why did expenses jump in March?", "what drove the burn in September?" or "why did revenue drop?". The report gives the totals; the client's bank transactions show what's behind them.

### 3.1 Pick the months

1. **The month to explain**: the one the client named. If they didn't name one but Step 1 or 2 pointed one out (e.g. the highest-burn month), use that and say so.
2. **The month to compare with**: the month before, unless the client names another (e.g. "compared to the same month last year"). Say which one you compare with.
3. From the report, give the change you're explaining first, e.g. "Expenses were $150,800 in September, up $32,100 (27%) from $118,700 in August."

### 3.2 Load the transactions

1. Call `fetch_transactions` with the first and last day of each month, `page_size` 100. The transactions are in `data`, each with `date`, `description`, `withdrawal` (money out), `deposit` (money in) and `category`.
2. A page with 100 transactions may have more after it: load the next `page` until one returns fewer than 100. Tell the client while it loads if it takes several pages.
3. If a month has more than 2,000 transactions, stop and ask whether to continue or narrow it down (e.g. only payments over $1,000, with `term`, or one vendor).

### 3.3 Find what changed

Work on money out for an expenses or burn question, money in for an income or revenue question.

1. **Set aside money that isn't income or spending**, and list it separately instead of mixing it in:
   - transfers between the client's own accounts (e.g. "Transfer to Savings ****7654", the same amount out of one account and into another on the same day);
   - credit card payments (the card's purchases are already counted where they happened);
   - loans, repayments and money raised, when the description or `category` says so.
2. **Group by vendor**, using a cleaned-up description: lowercase, and drop card and reference numbers, locations, dates, currency and exchange-rate text, and legal suffixes (LLC, Inc, Ltd), so "AMZN Mktp US*2K4…" and "Amazon.com*RT2…" are both `amazon`. Keep products apart when the description names them ("Google Workspace" isn't "Google Cloud").
3. **Compare the two months, vendor by vendor**, and find the biggest differences:
   - **new**: a vendor with payments this month and none in the comparison month;
   - **gone**: the other way round, e.g. a usual payment that didn't happen;
   - **bigger or smaller**: the same vendor, a different total;
   - **one-off**: a single payment that's large for this client (e.g. a yearly subscription, equipment, a tax payment).
4. Also total by `category` when the categories are filled in: it often explains the change in one line (e.g. "Contractors +$24,000").

### 3.4 Show it

> **Why expenses rose in September** (vs August)
> Expenses were $150,800, up $32,100 (27%).
>
> | What changed | Sep | Aug | Change |
> |---|---|---|---|
> | Acme Design LLC (new) | $18,000 | – | +$18,000 |
> | AWS | $21,400 | $14,900 | +$6,500 |
> | Gusto payroll | $78,200 | $74,100 | +$4,100 |
> | Figma (yearly plan) | $3,600 | – | +$3,600 |
> | WeWork (no payment) | – | $2,900 | −$2,900 |
>
> These 5 explain $29,300 of the $32,100. The rest is many smaller differences.
> Not counted: $50,000 moved to Savings ****7654 on Sep 3 (a transfer between your accounts).

- Up to 5 rows, the biggest changes first, in the direction of the overall change. Add the largest change the other way if it's big enough to matter.
- Say how much of the change the rows explain, as above.
- **Bank and report totals won't match exactly.** The report comes from the client's books, which can record things in a different month than the bank (e.g. an invoice paid later, a yearly plan spread over 12 months), and the bank shows transfers and card payments that the books don't count as spending. If they're far apart, say so in one line, without trying to reconcile them.
- Offer next steps in one line: the transactions behind one row, another month, or the monthly breakdown (2.1).

This step only reads. If a transaction looks wrong (a duplicate, the wrong category, a personal expense), mention it and suggest the client ask their Numix team. Don't change anything here.

## Refreshing the report

If the client asks for the latest numbers, or the report is more than a few days old and they're about to rely on it (e.g. for a what-if), call `fetch_financial_health` with `refresh=true`. Tell them it takes a few seconds, then show what changed since the previous report in one line (e.g. "Cash is now $1,291,020, up $6,710 since the report from Nov 12").
