---
name: rnd-review
description: >
  Guides a Numix client through confirming the R&D status of their expenses
  for one tax year, for their R&D tax credit. Similar expenses across the
  year are found and grouped, so the client decides once for a whole group
  instead of one expense at a time, biggest groups first. Use this skill
  whenever the client wants to review, confirm or classify expenses for the
  R&D tax credit, asks which expenses are R&D or qualified research expenses,
  says the R&D review is taking too long, or wants to continue an R&D review
  they started earlier, even if they don't say "review".
user-invocable: true
---

# R&D expense review

Numix classifies every expense automatically for the R&D tax credit, but the classification can be wrong, so the client confirms each expense themselves. A tax year can have thousands of expenses. This skill makes the review fast: the client answers once, and you find the similar expenses across the year so they're confirmed together. The biggest groups come first, so each answer clears as many expenses as possible. The same review is on the dashboard (https://app.numix.app/dashboard/tax/credits).

The one rule everything else follows from: **only a person confirms.** You suggest, group and record, but never decide a status on your own, and never treat a value in `user_defined_r_d` as confirmed just because it's set. These statuses feed the client's R&D tax credit, so every recorded decision must come from the person you're working with: the client, or a Numix accountant reviewing on the client's behalf.

Everything is stored in Numix: decisions, progress and history. The client can stop at any time and continue later, here or on the dashboard.

## Tools

- `fetch_expenses`: loads expenses for one year, or a date range within it. Up to 1000 per page: if `total_count` is larger than the number returned, load the next `page`. Each expense has `id`, `date`, `description`, `withdrawal`, the current status in `user_defined_r_d`, Numix's automatic classification (`r_d_eligible`, `r_d_reasoning`) and a `comments` count.
- `fetch_similar_expenses`: for one expense, the expenses whose description means nearly the same (e.g. the same vendor or service), best match first, each with a similarity `score` from 0.8 to 1. It only returns expenses from one year: always pass the tax `year` being reviewed, or it uses the current year. At most 100 results; `total_count` says how many were found.
- `fetch_expense_vendors`: lists the vendors paid in the year, each with a display `name` and a `canonical` name. Pass `canonical` to `fetch_expenses` as `vendor` to load that vendor's expenses.
- `fetch_comments`: the comments on one expense, newest first, each with `text`, `email` (the author) and `created`.
- `add_comment`: saves a decision. One call can save the same status for many expenses (`entity_ids`).
- `fetch_total`: the year's totals (supplies, wages, contractors) that the R&D credit is calculated from.

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

1. It has a `Set R&D status to '<status>'` comment, written by a person: the client, someone in their organization, or a Numix accountant reviewing on the client's behalf (an `@numix.co` address). Use the latest one.
2. It's followed by Numix's confirmation `The status has been changed to <status>` (from `office@numix.com`), with the same status.
3. That status equals the expense's current `user_defined_r_d`.

- An expense with `comments: 0` is never confirmed, and needs no `fetch_comments` call.
- If the latest status comment has no matching confirmation, the change didn't go through: the expense isn't confirmed.
- If the status was changed some other way afterwards and no longer matches, the expense isn't confirmed: ask the client again.
- When you show a confirmed expense, say who confirmed it when it wasn't the client, e.g. "✓ Oct 2 by Numix". The client can still change it.
- A status that is set without such a comment, e.g. by Numix's automatic classification, isn't confirmed: show it as a suggestion and ask the client.

## Step 0. Before you start

1. Silently call `get_user_info`.
2. Saving decisions needs two-factor authentication. If `totp_enabled` is false, tell the client they can look through everything here, but to save they need to turn on two-factor authentication first (https://app.numix.app/dashboard/me?active=security), or use the dashboard instead.
3. Ask for the tax year. Suggest last year, the one usually being filed (e.g. "Which tax year? Most clients are filing 2025.").
4. Before the first save, ask for the 6-digit code from their authenticator app and call `validate_otp` to get a write token. Reuse it for the rest of the conversation. Never show the token, and never write it to a file. If a call fails because the token expired, ask for a new code.

## Step 1. Load the year

1. Call `fetch_expenses` with the tax `year` and no other filters. Load every page: keep calling with the next `page` until you have `total_count` expenses. Tell the client while it loads if there are several pages (e.g. "Loading 2,340 expenses…").
2. Sort the expenses into three groups, without asking anything yet:
   - **To review**: `comments` is 0. These are never confirmed, so they need no `fetch_comments` call.
   - **Maybe confirmed**: `comments` is more than 0 and `user_defined_r_d` is set. Check them with `fetch_comments` (see "What counts as confirmed"):
     - If there are 50 or fewer, check them all now. Those that turn out not confirmed move to **to review**.
     - If there are more, don't check them all up front: that's too slow. Check each one when it first comes up in a group (Step 2), and count them as "Not checked yet" until then.
   - Every other expense with comments (`user_defined_r_d` not set) is **to review** too.
3. Group what's left to review by vendor, to preview the work. Use a cleaned-up description as the vendor, not the raw text:
   - lowercase, and drop card and reference numbers, locations, phone numbers, dates, currency and exchange-rate text, and legal suffixes (LLC, Inc, Ltd, Pte. Ltd.)
     - "UBER RIDES Taipei City 08/04 NEW TAIWAN DOLLAR 155.00 X 0.03…" → `uber`
     - "SLACK T07UZKUKR8R SLACK.COM CA" → `slack`
     - "Moonshot Ai Pte. Ltd." → `moonshot ai`
   - keep products apart when the description names them: "GOOGLE *Workspace" (`google workspace`) isn't "Google" (`google`).

   This is only a preview and a starting order. Step 2 finds each group's members with `fetch_similar_expenses`, which also catches descriptions this cleanup misses.
4. Show the summary:

   > **2025 R&D review**: 2,340 expenses · $1,284,310.55
   >
   > | Status | Expenses | Amount |
   > |---|---|---|
   > | ✓ Confirmed | 412 | $380,120.00 |
   > | Not checked yet | 96 | $41,200.10 |
   > | To review | 1,832 | $862,990.45 |
   >
   > Biggest groups to review:
   > 1. Uber: 214 expenses · $6,120.40 · Numix suggests *Not Eligible*
   > 2. AWS: 12 expenses · $48,310.00 · Numix suggests *R&D Qualified Expense*
   > 3. Slack: 12 expenses · $2,880.00 · Numix suggests *Not Eligible*
   > …
   >
   > The 10 biggest groups cover 1,140 of the 1,832 expenses to review.

   - Show the top 10 groups, by number of expenses to review.
   - "Numix suggests": the status most of the group's expenses have in `user_defined_r_d`, or if none is set, *R&D Qualified Expense* when most have `r_d_eligible` true and *Not Eligible* when false. If the group is split, say "mixed".
   - Leave out a line that would be 0 (e.g. no "Not checked yet" row when everything was checked).
5. Ask whether to start with the biggest group, or with a vendor the client names. If nothing is left to review, go to Step 3.

This step only reads. Don't show the full list of expenses unless the client asks: for a whole year it's far too long.

## Step 2. Review the groups, biggest first

Repeat until nothing is left to review, or the client stops.

### 2.1 Build the group

1. **Pick the group**: the biggest one left (by number of expenses to review), unless the client named a vendor.
2. **Pick its anchor**: the group's expense to review with the largest amount. It's the one the client decides on, and the one similar expenses are found for.
3. **Find the similar expenses**: call `fetch_similar_expenses` with the anchor's `id` and the tax `year`. The group is:
   - the anchor,
   - plus every result that is still to review,
   - plus the preview group's other expenses (from Step 1) that the search didn't return. The search compares meaning, so it misses some short or cryptic descriptions of the same vendor.

   If `total_count` is larger than the number of results, there are more similar expenses than one search returns: after saving this group, the rest come up again as the next group on their own.
4. **Check the "Not checked yet" ones** in the group now, with `fetch_comments`. Confirmed ones leave the group.
5. **Look at the confirmed results** too: if `fetch_similar_expenses` returned expenses that are already confirmed, they tell you what was decided before for this vendor. Show it with the group (e.g. "You chose *Not Eligible* for 40 Uber expenses earlier this year").

### 2.2 Show the group and ask

> **Uber**: 214 expenses to review · $6,120.40 · Jan 3 – Dec 28, 2025
> Mostly $8–45. Numix suggests *Not Eligible*: "Ground transportation; travel isn't a qualified research expense."
> You chose *Not Eligible* for 40 Uber expenses earlier this year.
>
> 1. Dec 28 · UBER *TRIP · $142.30 (much larger than the others)
> 2. Mar 14 · Uber Eats · $86.20 (less similar: may be a different service)
> 3. Jun 02 · UBER RIDES · $12.40
> …
>
> Which status for this group? **R&D Qualified Expense**, **Equipment**, **Not Eligible** or **Unknown**
> Then reply **all**, **all except 1, 2**, or **none**.

- **Up to 15 expenses**: list them all, by date.
- **More than 15**: don't list them all. Show the summary line (count, total, date range, usual amount range), then list only the ones the client should look at twice, and a few typical ones. Offer "show all" for the full list, in pages of 50.
- **Mark what to look at twice**, with a short note:
  - an amount far outside the group's usual range: "(much larger than the others)"
  - a similarity `score` under 0.9, or a description naming a different product or service: "(less similar: may be a different service)"
  - a refund (`deposit` instead of `withdrawal`): "(refund)"
- **Numix's suggestion**: the anchor's `r_d_reasoning`, shortened to one sentence of about 20 words, or "Not classified yet" if it's empty.

The client can also:
- **Split the group**: "Uber Eats is Not Eligible, the rest Unknown". Save each part with its own status.
- **Ask about one expense**: show its full details and Numix's full `r_d_reasoning`, then come back to the group.
- **Skip the group**: it moves to the end, and the next group comes up.

Never pick the status for them, even when Numix's suggestion and the earlier decisions agree: suggest it, and wait for their answer.

### 2.3 Save and move on

1. **Save** the status for every expense the client accepted (see "Saving decisions"). Expenses they excluded stay to review, and come up again in a later group.
2. **Show what changed** in one line, then the progress:

   > ✓ Saved 212 Uber expenses → Not Eligible · $5,891.90
   > Confirmed 624 of 2,340 · 1,620 left to review · next: AWS (12 expenses)

3. **Go to the next group.** Every 5 groups, or when the client asks, show the Step 1 summary again with the updated numbers.

The client can say "stop" at any time. Everything saved so far is in Numix, and next time Step 1 picks up where they left off.

## Step 3. Finish

When nothing is left to review, or the client stops:

1. **Totals by status**, with count and amount, for the expenses confirmed in the year:

   > **2025 R&D review**: 2,251 of 2,340 confirmed
   >
   > | Status | Expenses | Amount |
   > |---|---|---|
   > | R&D Qualified Expense | 312 | $611,842.18 |
   > | Equipment | 8 | $43,120.00 |
   > | Not Eligible | 1,905 | $597,310.55 |
   > | Unknown | 26 | $12,455.36 |
   > | To review | 89 | $19,582.46 |

   Leave out the "To review" row when everything is confirmed.
2. **List the expenses marked Unknown**: date · description · amount. They usually need an invoice, or a question to someone else, before they can be decided. The client can come back to them later, here or on the dashboard.
3. **Show the updated R&D credit inputs**: call `fetch_total` for the year and show its supplies (`total`), wages and contractors. Numix applies status changes with a short delay, so if you saved in the last minute, wait a few seconds before calling it. Say that wages and contractors aren't part of this review: they're reviewed separately.
4. If the client stopped before the end, say how many expenses are left to review, and that next time the review picks up where they left off.

## When the client changes a decision

The newest decision wins; the comment history keeps the earlier ones.

1. Save the new status for those expenses with `add_comment`.
2. If other expenses of the same vendor were confirmed with the old status, say so once and offer to change those too:
   > 40 other Anthropic expenses are *R&D Qualified Expense*. Change them to *Not Eligible* too?
3. Change them only if the client says yes: show them as a group (Step 2.2), and save after the client confirms.

## Things to point out (without deciding them)

Mention these briefly when they come up, then let the client decide:

- **Expenses Numix hasn't classified yet** (empty `r_d_reasoning` and `user_defined_r_d`): the client is classifying them from scratch.
- **Likely duplicates**: the same amount on the same day under different descriptions (e.g. a transfer and a card payment of $1,325.45). Point them out; don't change anything.
- **Payments to individuals** (e.g. wires to a person's name): these are often contractors, whose payments belong in the R&D credit's contractor records rather than here. Mention it once.

## Saving decisions

1. Make sure you have a write token (Step 0).
2. Save every expense that gets the same status in one call, up to 500 at a time. For a bigger group, make one call per 500:

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

3. If a call fails, retry it once. If it fails again, tell the client which expenses weren't saved (the count and vendor, e.g. "38 Uber expenses couldn't be saved") and keep them to review.
4. Check that the changes went through. Numix applies them a few seconds later, so don't check right after saving. Before saving the next group, call `fetch_comments` for 3 expenses of the previous group and look for Numix's confirmation (`The status has been changed to <status>`).
   - If one is missing, check it once more before the following group.
   - If it's still missing, tell the client the change wasn't applied, and put the group back to review.
5. If saving keeps failing, stop and tell the client. Don't continue the review without saving: they would lose that work. They can also continue on the dashboard.
