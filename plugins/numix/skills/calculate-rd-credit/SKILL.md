---
name: calculate-rd-credit
description: >
  Guides a client through estimating their R&D tax credit for one tax year:
  verifying company details, reviewing R&D-eligible expenses from their bank
  statements, collecting wages and contractor payments, prior-year qualified
  research expenses and gross receipts, then calculating the federal and
  California credits and generating pre-filled Forms 6765 and 3523. Use this
  skill whenever a client wants to calculate, estimate or prepare their R&D tax
  credit, research credit, Form 6765 or Form 3523, or asks how much R&D credit
  they could get, even if they don't use those exact words.
user-invocable: true
---

# R&D Tax Credit

This skill estimates the client's R&D tax credit for one tax year. It collects every amount the calculation needs, checks each one with the client, and only then calculates the federal credit (IRS Form 6765) and the California credit (Form 3523), and generates both forms pre-filled for review.

Follow every step in order. Never skip a step. Never call `calculate_credit`, generate a form or submit until every amount is collected and confirmed by the client.

## Important considerations

- **One tax year.** At the start, ask which tax year the credit is for, and call it `tax_year`. Use it in every step: amounts are always for `tax_year` unless a step says otherwise (prior years).
- **Saving amounts needs two-factor authentication.** Adding wages and contractors and saving prior QRE, gross receipts and company details are write operations: they need a write session token from `validate_otp` (a 6-digit code from the client's authenticator app). Get one the first time you need it and reuse it for the rest of the conversation.
- **Documents are uploaded on the dashboard.** Bank statements, payroll reports and tax forms are uploaded at https://app.numix.app/dashboard?action=upload, not in this chat. Ask the client to keep that page open. Processing takes time: after an upload, wait 15 to 20 seconds before checking, and check again if it's not there yet. After several tries, point them to support.
- **R&D-qualified expenses.** The client's own review decides: an expense the client marked "R&D Qualified Expense" (`user_defined_r_d`) counts, and one they marked anything else doesn't. An expense the client hasn't reviewed yet (empty `user_defined_r_d`) counts by Numix's automatic classification (`r_d_eligible`) until they review it. The supplies total from `fetch_total` follows this rule, as the dashboard does. Never present the automatic classification as the client's decision: ask them to review those expenses (Step 3).
- **Never estimate an amount.** Every amount comes from the client, their documents, or Numix data they confirmed. If something is missing, ask for it. The only estimate allowed is an R&D percentage for an employee or contractor (Step 4), and only once the client confirms it.
- **The result is an estimate.** Present the credit as an estimate, and the forms as drafts for review: nothing is filed.
- **Never show a full EIN in the chat**: only its last 4 digits (e.g. `**-***6789`).
- **Interactive forms with a table fallback.** Where a step collects several values, display an interactive form if your client supports it; otherwise show a structured table in the chat and ask for the values.
- **Flag unusual values**: $0, or a value very different from other years. Ask the client to confirm it.
- If a tool keeps failing, don't loop: tell the client which step failed, and point them to support at office@numix.co.

## Step 0. Welcome, tax year and what's already on file

1. Silently call `get_user_info` and `get_company_info`, then welcome the client by name and company.
2. Explain that estimating the R&D credit takes several steps: checking company details, then collecting R&D expenses, wages and contractor payments, prior-year research expenses and gross receipts. You'll guide them through each one.
3. Ask which tax year the credit is for. This is `tax_year`.
4. Silently check what's already on file for `tax_year`: `fetch_total` (with `year`), `fetch_wages`, `fetch_contractors`, `fetch_prior_qre` and `fetch_prior_gross_receipts` (each with `year` = `tax_year`), and `fetch_bank_statements`. If there's data, tell the client: "We already have some data on file for [tax_year]. Would you like to continue where you left off, or review everything from the start?" To continue, skip the steps that are complete and confirmed, and start at the first one that isn't.
5. Show the client what they'll need, so they can prepare it:

| Step | What | What the client needs |
| --- | --- | --- |
| 1 | Two-factor authentication | 2FA turned on for their account |
| 2 | Company details | Company name, EIN and address; the EIN confirmation letter if details are wrong |
| 3 | R&D expenses | Bank statements for `tax_year` |
| 4 | Wages and contractors | A payroll report for `tax_year`, or each employee's and contractor's pay and R&D share |
| 5 | Prior research expenses | Qualified research expenses for the 3 years before `tax_year` (from prior Forms 6765), if they claimed the credit before |
| 6 | Gross receipts | Gross receipts for the 4 years before `tax_year`, from their tax returns (Form 1120, 1120-S or 1065) |

Ask whether they're ready. If not, answer their questions and help them prepare first.

## Step 1. Two-factor authentication

Check `totp_enabled` in the `get_user_info` response.

- **Enabled**: continue to Step 2.
- **Not enabled**: explain that saving amounts needs two-factor authentication, and that they turn it on in the dashboard: https://app.numix.app/dashboard/me?active=security. When they say it's done, call `get_user_info` again to check. Don't continue until it's enabled.

## Step 2. Company details

1. Show the company details from `get_company_info`: legal company name, DBA, EIN (last 4 digits only), entity type and address. Ask the client whether they're correct.
2. If something is wrong:
   - **Legal name, DBA, EIN or address**: ask for the correct values, confirm them with the client, then call `update_company_info` with only the fields that change. Call `get_company_info` again and show the result.
   - **Entity type**: it can't be changed here: ask the client to contact office@numix.co.
   - If they have their EIN confirmation letter, they can also upload it on the dashboard (https://app.numix.app/dashboard?action=upload). After 15 to 20 seconds, call `get_company_info` again and check with the client whether the details were updated. If not after several tries, collect the corrections in the chat instead.

Don't continue until the client confirms the company details are correct.

## Step 3. Bank statements and R&D expenses

Numix reads the company's transactions from its bank statements to find R&D-eligible expenses (supplies).

1. Call `fetch_bank_statements` and show which statements are on file for `tax_year`.
2. If statements are missing, ask the client to upload them for the whole of `tax_year`, either:
   - on the dashboard: https://app.numix.app/dashboard?action=upload
   - or by email, to the receipts address in the `get_user_info` response, if there is one. Many files can be sent as one ZIP file.

   Statements from these banks are read automatically: Mercury, Chase, Brex, Silicon Valley Bank, Capital One, Bank of America, U.S. Bank, Ramp and American Express. For another bank, ask the client to contact office@numix.co.

   After the upload, wait 15 to 20 seconds and call `fetch_bank_statements` again. Don't continue until the client confirms all their statements are there.
3. Call `fetch_expenses` with `year` = `tax_year`, and show the client:
   - the number of transactions, and how many the client marked "R&D Qualified Expense"
   - how many they haven't reviewed yet (empty `user_defined_r_d`), and that those count by Numix's automatic classification until they review them
   - the supplies total from `fetch_total` (its `total` value, shown as "Supplies"), and the refunds taken off it (`refunds`) if there are any
   - the R&D-qualified transactions, if they want to see them
4. Tell the client they can review and correct each transaction at https://app.numix.app/dashboard/tax/credits. If they do, call `fetch_expenses` and `fetch_total` again afterwards.

Don't continue until the client confirms the expenses are correct.

## Step 4. Wages and contractors

Wages paid to employees who work on R&D, and payments to contractors who do R&D, count towards the credit by the share of their work that is R&D.

1. Call `fetch_wages` and `fetch_contractors` with `year` = `tax_year`. If there's data, show it and ask whether it's complete and correct. If it is, go to the summary at the end of this step.
2. Explain what to keep in mind:
   - Pay must be for `tax_year` exactly. If the client gives another year's report or amounts, ask for `tax_year`'s.
   - Once added, a person's pay can't be changed or removed from here: only their R&D percentage can (`patch_wages` for employees, `patch_contractor` for contractors). To change anything else, the client contacts office@numix.co. So confirm every row before saving it.
3. Ask how they want to provide it: a payroll report, or by hand.

**R&D percentage.** If the client isn't sure of someone's R&D share, you may suggest one by role, then confirm it with them before saving:

| Role | Suggested R&D share |
| --- | --- |
| Software engineer, engineering | about 80% |
| Product manager | about 60% |
| Sales, marketing | about 10% |

### 4.1 From a payroll report

Reports from Gusto, ADP and Rippling are read automatically, as PDF. For another provider, or if they run payroll by hand, collect the details by hand (4.2), or ask them to contact office@numix.co.

Tell the client how to get the report for the whole of `tax_year`:

- **Gusto**: Reports → select Payroll Summary, Payroll Journal, Contractor Payments and Tax Reports → set the date filter to the year → Generate report → Download as PDF.
- **ADP** (Workforce Now): Reports → Payroll reports → Payroll Summary, Payroll Register or Employee Earnings Report → date range January 1 to December 31 of `tax_year` → Run Report → Export as PDF.
- **Rippling**: Reports → Payroll → Payroll Register → filter the full year of `tax_year` → Run Report → Export as PDF.

Ask them to upload it on the dashboard (https://app.numix.app/dashboard?action=upload). After 15 to 20 seconds, call `fetch_tax_forms` with `type: "payroll_report"`. If it's not there yet, wait and try again.

From the report, list each person with their pay for `tax_year`, and whether they're a W-2 employee or a contractor. If that isn't clear from the report, ask the client. Then collect and save each one as in 4.2, with the values from the report filled in.

### 4.2 By hand

For each person, display a form (or table) and save them one at a time, after the client confirms the row:

**W-2 employee**, saved with `add_wages`:

| Field | Value |
| --- | --- |
| `employee_name` | The employee's name |
| `period_type` | `annually` for the whole year, or `monthly` for one month |
| `period_start`, `period_end` | The period, `YYYY-MM-DD`, within `tax_year` (e.g. `2025-01-01` to `2025-12-31`) |
| `gross_wages` | Gross wages for the period, in US dollars |
| `r_d_percentage` | The share of their work that is R&D, 0 to 100 |

**Contractor**, saved with `add_contractors`:

| Field | Value |
| --- | --- |
| `name` | The contractor's name |
| `year` | `tax_year` |
| `gross_wages` | Amount paid to the contractor in `tax_year`, in US dollars |
| `r_d_percentage` | The share of their work that is R&D, 0 to 100 |

After each save, call `fetch_wages` or `fetch_contractors` to check it, and ask whether there's anyone else to add.

To change an R&D percentage, confirm the new value with the client, then call `patch_wages` with the `id` of the employee's wages record (from `fetch_wages`), or `patch_contractor` with the `id` of the contractor's record (from `fetch_contractors`), and the new `r_d_percentage`.

### 4.3 Summary

Call `fetch_wages`, `fetch_contractors` and `fetch_total` (with `year` = `tax_year`), and show a table of every employee and contractor with their pay and R&D percentage, and the qualified totals (`wages` and `contractors` from `fetch_total`). Tell the client that contractor payments count at 65% in the credit, as the IRS rules require; the calculation applies this itself.

Don't continue until the client confirms the wages and contractors are correct.

## Step 5. Prior qualified research expenses

The calculation compares this year's research expenses with the 3 years before: `tax_year - 1`, `tax_year - 2` and `tax_year - 3`.

1. Call `fetch_prior_qre` with `year` = `tax_year`, and show the amounts for those 3 years if there are any. If all 3 are there and the client confirms them, go to Step 6.
2. Ask whether the company claimed the R&D credit before.
   - **No**: tell the client the calculation will then use the simplified method for a company without prior research expenses, which may give a lower credit than the regular method. Ask them to confirm, then go to Step 6.
   - **Yes**: the amounts are needed for **all 3 years**. Partial prior years aren't supported: if the client can't give all 3, this step is skipped and the simplified method is used. They can provide them in two ways:

### 5.1 From prior Forms 6765

Ask the client to upload their Forms 6765 for those years on the dashboard (https://app.numix.app/dashboard?action=upload). After 15 to 20 seconds, call `fetch_tax_forms` with `type: "form_6765"`. If they're not there yet, wait and try again.

Form 6765 doesn't always show which tax year it's for: ask the client which year each form is for. Show a table of year and qualified research expenses, and get their confirmation.

### 5.2 By hand

Ask for the qualified research expenses of each of the 3 years, and show them back as a table for confirmation.

### 5.3 Save

Call `update_prior_qre` with one entry per year (`year`, `value`). Then call `fetch_prior_qre` and show the result. Don't continue until the client confirms it.

## Step 6. Gross receipts

The calculation needs the company's gross receipts for the 4 years before `tax_year`: `tax_year - 1` to `tax_year - 4`.

1. Call `fetch_prior_gross_receipts` with `year` = `tax_year`, and show the amounts for those 4 years if there are any. If all 4 are there and the client confirms them, go to Step 7.
2. Gross receipts are on the company's income tax returns. Which one depends on the entity type (from `get_company_info`):

| Entity type | Tax return | `fetch_tax_forms` type |
| --- | --- | --- |
| C-Corp | Form 1120 | `form_1120` |
| S-Corp | Form 1120-S | `form_1120s` |
| Partnership, multi-member LLC | Form 1065 | `form_1065` |
| Sole proprietorship, single-member LLC | Schedule C (Form 1040) | Not read automatically: provide by hand (6.2) |

For a sole proprietorship or single-member LLC, gross receipts are on line 1 of Schedule C. Those returns can't be read automatically: collect the amounts by hand (6.2).

The client can provide them in two ways:

### 6.1 From tax returns

Ask the client to upload the returns for those years on the dashboard (https://app.numix.app/dashboard?action=upload). After 15 to 20 seconds, call `fetch_tax_forms` with the type for their entity. If they're not there yet, wait and try again. Read the gross receipts of each year, and show a table of year and amount for confirmation.

### 6.2 By hand

Ask for the gross receipts of each of the 4 years. If the company didn't exist yet in a year, it's $0 for that year: confirm that with the client. Show them back as a table for confirmation.

### 6.3 Save

Call `update_gross_receipts` with one entry per year (`year`, `value`). Then call `fetch_prior_gross_receipts` and show the result. Don't continue until the client confirms it.

## Step 7. Calculate the credit

1. Collect the confirmed amounts, fresh:
   - `fetch_total` with `year` = `tax_year`: `total` (supplies), `wages` and `contractors`
   - `fetch_prior_qre` with `year` = `tax_year`: the 3 years before `tax_year`, if all 3 were provided
   - `fetch_prior_gross_receipts` with `year` = `tax_year`: the 4 years before `tax_year`
2. Show the client a summary: supplies, qualified wages, qualified contractor payments, prior research expenses by year (or "not claimed before") and gross receipts by year. Ask them to confirm everything. If they want to change something, go back to that step, then return here.
3. Call `calculate_credit` with:
   - `year`: `tax_year`
   - `qre`: `total` (supplies), `wages` and `contractors`, exactly as `fetch_total` returned them (the calculation applies the 65% for contractors itself)
   - `prior_qre`: the 3 years before `tax_year`, keyed by year (e.g. `{"2024": 120000, "2023": 95000, "2022": 80000}`), or `{}` if the client didn't claim the credit before
   - `gross_receipts`: the 4 years before `tax_year`, keyed by year

   The tool only uses those years, whatever else you pass.
4. Show the estimated federal credit (`credit_irs`) and California credit (`credit_california`), and which method each used if the result says so. Present them as estimates.

## Step 8. Generate the forms

1. Ask whether the client wants the pre-filled forms: Form 6765 (federal) and, if the company files in California, Form 3523.
2. Ask whether the company makes the section 280C election (a reduced credit, so the company doesn't have to reduce its deduction for research expenses). If they don't know, it's "no", and their accountant can change it before filing.
3. Call `generate_form_6765` and `generate_form_3523` with the same `year`, `qre`, `prior_qre` and `gross_receipts` as `calculate_credit`, plus `company_name` (the legal company name), `ein` (from `get_company_info`; never show it in the chat) and `election_280c`.
4. Share the links. Tell the client the forms are drafts for review: nothing has been filed.

## Step 9. Submit to Numix

1. Ask the client whether they want to submit their R&D credit to the Numix team now. The team reviews the amounts and the forms, and contacts them if anything else is needed. Ask whether they have any comments for the team.
2. When they confirm, call `submit_rd_credit` with the write token, the same `year`, `qre`, `prior_qre` and `gross_receipts` as `calculate_credit`, `company_name`, `ein`, and their `comments`.
3. Tell the client it was submitted, and that the Numix team will be in touch. Their data stays saved on Numix, so they can come back to it any time.

If the client doesn't want to submit yet, tell them their data is saved, and they can submit later, here or from the R&D credit summary on the dashboard (https://app.numix.app/dashboard/tax/credits).
