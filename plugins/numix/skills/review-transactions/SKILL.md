---
name: review-transactions
description: >
  Guides a Numix client through reviewing their transactions: answering the
  Numix team's bookkeeping questions about unclear transactions, and confirming
  the R&D classification of their expenses one month at a time, with similar
  expenses (same vendor) grouped so they're confirmed together and earlier
  months' decisions reused. Use this skill whenever the client wants to review,
  confirm, categorize or clean up transactions or expenses, answer Numix's
  questions, asks what Numix needs from them, which expenses are R&D, says the
  review is taking too long, or wants to continue a review they started
  earlier, even if they don't say "review".
user-invocable: true
---

# Transaction review

This skill covers the two reviews a client does on their transactions:

- **Part 1. Numix's questions**: the Numix team asks about transactions they can't categorize on their own (e.g. "What was this payment for?"). The client answers, as on the dashboard's "Needs clarification" tab (https://app.numix.app/dashboard/bookkeeping?tab=clarification).
- **Part 2. R&D status**: the client confirms which expenses are R&D, for their R&D tax credit.

Step 0 shows what's waiting, and the client chooses where to start. Questions waiting on the client come first by default: Numix can't finish their books without the answers.

## About the R&D review

Numix classifies every expense automatically, but the classification can be wrong, so the client confirms each expense themselves. This skill makes that fast: the client answers once, and you find the similar expenses so they can be confirmed together instead of one by one. The same review is on the dashboard (https://app.numix.app/dashboard/tax/credits).

The one rule everything else follows from: **only the client confirms.** You suggest, group and record, but never decide a status on your own, and never treat a value in `user_defined_r_d` as confirmed just because it's set. These statuses feed the client's R&D tax credit, so every recorded decision must come from the client.

Everything is stored in Numix: decisions, progress and history. The client can stop at any time and continue later, here or on the dashboard.

## Tools

Part 1, Numix's questions:

- `fetch_open_questions`: for each month of a year, how many transactions have a question, and how many are waiting on the client (`client`).
- `fetch_unclear_transactions`: the transactions with a question in a date range, by default those waiting on the client. Each has `id`, `date`, `description`, `withdrawal` / `deposit` and `category`.
- `fetch_transaction_conversation`: the question and every reply on one transaction, oldest first. Messages from `@numix.co` addresses are the Numix team.
- `answer_transaction_question`: sends the client's answer. The question then waits on Numix.

Part 2, R&D status:

- `fetch_expenses`: loads expenses for a date range within one year (`start_date`, `end_date`), optionally for one `vendor`. Up to 1000 per page: if `total_count` is larger than the number returned, load the next `page`. Each expense has `id`, `date`, `description`, `withdrawal`, the current status in `user_defined_r_d`, Numix's automatic classification (`r_d_eligible`, `r_d_reasoning`) and a `comments` count.
- `fetch_expense_vendors`: lists the vendors paid in a date range, each with a display `name` and a `canonical` name. Pass `canonical` to `fetch_expenses` as `vendor` to load that vendor's expenses.
- `fetch_comments`: the comments on one expense, newest first, each with `text`, `email` (the author) and `created`.
- `add_comment`: saves a decision. One call can save the same status for many expenses (`entity_ids`).

## Statuses

The same four as on the dashboard. Show them with their meaning when you ask:

| Status | Meaning |
| --- | --- |
| R&D Qualified Expense | A qualified research expense (QRE) under IRC §41 |
| Equipment | Something bought once and used for a long time |
| Not Eligible | Not eligible for the R&D credit |
| Unknown | Needs review or more context |

## How a status change works

A status is changed by a comment, as the dashboard does:

1. The reviewer's comment, in exactly this form: `Set R&D status to 'Not Eligible'`
2. A few seconds later, a confirmation from Numix (`office@numix.com`): `The status has been changed to Not Eligible`

Numix acts on the exact text of the first comment. `add_comment` rejects any other wording, so always use the exact form, with the status copied from the table above.

## What counts as confirmed

An expense is confirmed when all three are true:

1. Its latest `Set R&D status to '<status>'` comment was written by the client or someone in their organization: any author except Numix, whose addresses end in `@numix.com` or `@numix.co`.
2. It's followed by Numix's confirmation `The status has been changed to <status>`, with the same status.
3. That status equals the expense's current `user_defined_r_d`.

- An expense with `comments: 0` is never confirmed, and needs no `fetch_comments` call.
- If the latest status comment has no matching confirmation, the change didn't go through: the expense isn't confirmed.
- If the status was changed some other way afterwards and no longer matches, the expense isn't confirmed: ask the client again.
- A status set by a Numix team member isn't the client's confirmation: show it as a suggestion and ask the client.

## Step 0. Before you start

1. Silently call `get_user_info`, and `fetch_open_questions` for this year and last year.
2. Answering questions and saving R&D decisions need two-factor authentication. If `totp_enabled` is false, tell the client they can look through everything here, but to answer or save they need to turn on two-factor authentication first (https://app.numix.app/dashboard/me?active=security), or use the dashboard instead.
3. Before the first answer or save, ask for the 6-digit code from their authenticator app and call `validate_otp` to get a write token. Reuse it for the rest of the conversation. Never show the token, and never write it to a file. If a call fails because the token expired, ask for a new code.
4. Show what's waiting: the number of Numix questions waiting on the client, and in which months (e.g. "5 questions from Numix: September 2026 (3), August 2026 (2)"). Then ask where to start: Numix's questions (Part 1) or the R&D review (Part 2). If questions are waiting, suggest starting with them. If none are, go to Part 2.

# Part 1. Numix's questions

Numix's bookkeepers ask about transactions they can't categorize on their own. The client's answers go straight to them.

## Step Q1. Choose the month and load it

1. Start with the newest month that has questions waiting on the client, unless the client chooses another.
2. Call `fetch_unclear_transactions` with the first and last day of the month. If `more` is true, load the next `page` too.
3. For each transaction, call `fetch_transaction_conversation`. Numix's question is their latest message (from a `@numix.co` address); earlier messages are the conversation so far.
4. Show a short list, by date: date · description · amount · the question in one line. Below it, one line, e.g. "3 questions waiting on you in September 2026."

## Step Q2. Answer one by one

For each transaction:

1. **Show it**: date, description, amount and current category, then Numix's question in full, and the earlier messages if there are any.
2. **Get the client's answer**, in their own words. You may help them say it clearly (e.g. turn "lunch w/ team" into "Team lunch during the September offsite"), but send only what they confirm. Never answer for them, and never guess from the description.
3. If the answer needs a document (a receipt or invoice), it can't be sent here: ask the client to upload it on the dashboard (https://app.numix.app/dashboard?action=upload), and mention it in their answer (e.g. "Receipt uploaded on the dashboard").
4. **Send it** with `answer_transaction_question`, then show one line: "✓ Sent: Aug 12 · AWS · $1,240.00", and the progress: "2 of 5 answered."

**Similar questions.** If other transactions in the list are from the same vendor and have the same question, offer to send the same answer to them, as a numbered list. Reply **all**, **all except 2**, or **none**. Send one answer per transaction.

The client can say "skip", "go back" or "stop" at any time. "Skip" moves the question to the end. "Stop" ends the session: every answer sent so far is with Numix, and the rest wait on the dashboard and here.

## Step Q3. Finish

1. When the month's questions are answered, tell the client Numix will review the answers and may reply. Replies show up here and on the dashboard.
2. If other months have questions waiting (from `fetch_open_questions`), offer the next one.
3. When no questions are left, offer the R&D review (Part 2).

# Part 2. R&D status

## Step 1. Choose the month and load it

1. Ask for the year and month. If the client gives only a year, ask which month. Work on one month at a time: small batches are easier to check.
2. Call `fetch_expenses` with the first and last day of the month, with no other filters. Load every page.
3. For every expense with `comments` > 0, call `fetch_comments` and work out whether it's confirmed (see above). Remember who confirmed it and when.
4. Show the summary table, sorted by date:

   | Date | Description | Amount | Status | Numix suggestion |
   |---|---|---|---|---|

   - Amount: `withdrawal`, as currency.
   - Status: `user_defined_r_d`, or "Not set". For a confirmed expense add "✓ Oct 2", the date of the client's comment.
   - Numix suggestion: `r_d_reasoning` shortened to one sentence of about 20 words at most, or "Not classified yet" if empty. Show the full text only when the client asks about a row.
5. Below the table, one line, e.g. "79 expenses · 12 confirmed · 67 to review."

This step only reads.

## Step 2. Reuse earlier decisions

1. Load the previous month with `fetch_expenses` and, as in Step 1, find the expenses the client confirmed there. If there are none, try the month before, up to 3 months back. If none are found, skip this step.
2. Build a list of vendors with the client's latest decision for each (see "Finding similar expenses"). If the client chose different statuses for the same vendor, use the most recent one and mention that it changed.
3. Match this month's unconfirmed expenses to those vendors, and present each vendor as one group, largest first:

   > **Uber**: you chose *Not Eligible* in July.
   > 14 Uber expenses this month:
   > 1. Aug 06 · Uber · $9.95
   > 2. Aug 06 · Uber · $14.50
   > …
   > Apply *Not Eligible* to all? Reply **all**, **all except 3, 7**, or **none**.

4. Save the accepted ones (see "Saving decisions"). Excluded ones stay unconfirmed and go to Step 3.
5. After each group, show a progress line: "Confirmed 31 of 79 · 48 left."

## Step 3. Review one by one

Repeat until every expense in the month is confirmed.

1. **Pick the next expense**: the unconfirmed expense whose vendor appears most often among the remaining ones, so each answer clears as many rows as possible. Break ties by the larger amount.
2. **Show it:**

   > **Aug 30 · Anthropic · $20.00**
   > Numix suggestion: R&D eligible: AI vendor that may support development work; no invoice detail.
   > Current status: R&D Qualified Expense
   >
   > Which status? **R&D Qualified Expense**, **Equipment**, **Not Eligible** or **Unknown**

3. **Find similar expenses** among the remaining unconfirmed expenses of the month (see "Finding similar expenses"). If there are any, list them and ask whether they get the same status:

   > These 2 look similar. Same status (*R&D Qualified Expense*)?
   > 1. Aug 25 · Anthropic · $100.00
   > 2. Aug 12 · Anthropic · $26.08
   > Reply **all**, **all except 2**, or **none**.

   If there are none, go straight to saving.
4. **Save** the expense the client answered plus the similar ones they accepted, in one call. Excluded ones stay in the queue and come up again on their own.
5. **Show what changed**, only the rows just saved, then the progress line:

   > ✓ Saved 3: Anthropic $20.00, $100.00, $26.08 → R&D Qualified Expense
   > Confirmed 34 of 79 · 45 left.

   Show the full table only when the client asks: redrawing every row after every answer makes the conversation slow and hard to follow.

The client can say "show the table", "skip this one", "go back" or "stop" at any time. "Skip" moves the expense to the end of the queue. "Stop" ends the session: everything saved so far is in Numix, and next time Step 1 picks up where they left off.

## Step 4. Finish the month

When every expense is confirmed:

1. Show the final table.
2. Show the totals by status, with count and amount, e.g. "R&D Qualified Expense: 22 · $11,842.18 / Equipment: 2 · $3,120.00 / Not Eligible: 51 · $47,310.55 / Unknown: 6 · $2,455.36".
3. List the expenses marked **Unknown**: they usually need an invoice, or a question to someone else.
4. Offer the next month.

## Finding similar expenses

Two expenses are similar when they're from the same vendor.

1. **By Numix's vendor first.** Call `fetch_expense_vendors` for the month, and for a vendor, `fetch_expenses` with its `canonical` name as `vendor` and the month's dates. Those expenses are the same vendor.
   - Keep different products of one company apart when the vendor list does: "Google Workspace" isn't the same as "Google Cloud".
2. **Then by description**, for expenses that aren't linked to a vendor yet (Numix links them in the background, so the newest ones may not be). Compare a cleaned-up name, not the raw text:
   - lowercase, and drop card and reference numbers, locations, phone numbers, dates, currency and exchange-rate text, and legal suffixes (LLC, Inc, Ltd, Pte. Ltd.)
     - "UBER RIDES Taipei City 08/04 NEW TAIWAN DOLLAR 155.00 X 0.03…" → `uber`
     - "SLACK T07UZKUKR8R SLACK.COM CA" → `slack`
     - "Moonshot Ai Pte. Ltd." → `moonshot ai`
   - keep products apart when the description names them: "GOOGLE *Workspace" (`google workspace`) isn't "Google" (`google`).
3. If an expense's amount is far outside the vendor's usual range (e.g. a $2,400 Apple charge next to $20–180 ones), still list it, with a short note so the client looks twice: `3. Aug 27 · Apple · $2,400.00 (much larger than the others)`.

These are suggestions only. The client confirms every group, so it's better to show a borderline expense with a note than to hide it.

## Saving decisions

1. Make sure you have a write token (Step 0).
2. Save every expense that gets the same status in one call:

   ```
   add_comment(
     write_token = <token>,
     payload = {
       "entity": "Transaction",
       "entity_ids": ["<expense id>", "<expense id>", ...],
       "text": "Set R&D status to '<status>'"
     }
   )
   ```

3. If the call fails, retry it once. If it fails again, tell the client which expenses weren't saved ("2 expenses couldn't be saved: Aug 12 Anthropic $26.08, …") and keep them in the queue.
4. Check that the changes went through. Numix applies them a few seconds later, so don't check after every call. Instead, before saving the next group, call `fetch_expenses` for the month once and compare `user_defined_r_d` for everything saved so far.
   - Anything that doesn't match yet gets one more check before the following group.
   - If it still doesn't match, call `fetch_comments` for that expense, tell the client the change wasn't applied, and put it back in the queue.
5. If saving keeps failing, stop and tell the client. Don't continue the review without saving: the client would lose that work. They can also continue on the dashboard.

## When the client changes a decision

The newest decision wins; the comment history keeps the earlier ones.

1. Save the new status for those expenses with `add_comment`.
2. If the client confirmed the same vendor with the old status in earlier months, say so once and offer to change those too:
   > Anthropic was *R&D Qualified Expense* in July. Change it to *Not Eligible* there too?
3. Change earlier months only if the client says yes: load that month with `fetch_expenses`, show the matching expenses as a group, and save after the client confirms.

## Things to point out (without deciding them)

Mention these briefly when they come up, then let the client decide:

- **An expense Numix hasn't classified yet** (empty `r_d_reasoning` and `user_defined_r_d`): the client is classifying it from scratch.
- **Likely duplicates**: the same amount on the same day under different descriptions (e.g. a transfer and a card payment of $1,325.45). Point it out; don't change anything.
- **Payments to individuals** (e.g. wires to a person's name): these are often contractors, whose payments belong in the R&D credit's contractor records rather than here. Mention it once.
