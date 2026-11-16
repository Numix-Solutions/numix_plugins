---
name: review-transactions
description: >
  Guides a Numix client through answering the Numix team's bookkeeping
  questions about unclear transactions, as on the dashboard's "Needs
  clarification" tab, a month at a time, with the same answer offered for
  same-vendor transactions that have the same question. Use this skill
  whenever the client wants to answer Numix's questions, asks what Numix
  needs from them, wants to explain or clarify transactions for their books,
  or wants to continue answering questions they started earlier. For the R&D
  status of expenses, use the rnd-review skill instead.
user-invocable: true
---

# Transaction review

The Numix team asks about transactions they can't categorize on their own (e.g. "What was this payment for?"). The client answers, as on the dashboard's "Needs clarification" tab (https://app.numix.app/dashboard/bookkeeping?tab=clarification). Numix can't finish the client's books without the answers.

The client's answers go straight to Numix's bookkeepers. Send only what the client says or confirms: never answer for them, and never guess from the description.

## Tools

- `fetch_open_questions`: for each month of a year, how many transactions have a question, and how many are waiting on the client (`client`).
- `fetch_unclear_transactions`: the transactions with a question in a date range, by default those waiting on the client. Each has `id`, `date`, `description`, `withdrawal` / `deposit` and `category`.
- `fetch_transaction_conversation`: the question and every reply on one transaction, oldest first. Messages from `@numix.co` addresses are the Numix team.
- `answer_transaction_question`: sends the client's answer. The question then waits on Numix.

## Step 0. Before you start

1. Silently call `get_user_info`, and `fetch_open_questions` for this year and last year.
2. Answering needs two-factor authentication. If `totp_enabled` is false, tell the client they can look through the questions here, but to answer they need to turn on two-factor authentication first (https://app.numix.app/dashboard/me?active=security), or use the dashboard instead.
3. Before the first answer, ask for the 6-digit code from their authenticator app and call `validate_otp` to get a write token. Reuse it for the rest of the conversation. Never show the token, and never write it to a file. If a call fails because the token expired, ask for a new code.
4. Show what's waiting: the number of questions waiting on the client, and in which months (e.g. "5 questions from Numix: September 2026 (3), August 2026 (2)"). If none are waiting, tell the client there's nothing to answer right now.

## Step 1. Choose the month and load it

1. Start with the newest month that has questions waiting on the client, unless the client chooses another.
2. Call `fetch_unclear_transactions` with the first and last day of the month. If `more` is true, load the next `page` too.
3. For each transaction, call `fetch_transaction_conversation`. Numix's question is their latest message (from a `@numix.co` address); earlier messages are the conversation so far.
4. Show a short list, by date: date · description · amount · the question in one line. Below it, one line, e.g. "3 questions waiting on you in September 2026."

## Step 2. Answer one by one

For each transaction:

1. **Show it**: date, description, amount and current category, then Numix's question in full, and the earlier messages if there are any.
2. **Get the client's answer**, in their own words. You may help them say it clearly (e.g. turn "lunch w/ team" into "Team lunch during the September offsite"), but send only what they confirm.
3. If the answer needs a document (a receipt or invoice), it can't be sent here: ask the client to upload it on the dashboard (https://app.numix.app/dashboard?action=upload), and mention it in their answer (e.g. "Receipt uploaded on the dashboard").
4. **Send it** with `answer_transaction_question`, then show one line: "✓ Sent: Aug 12 · AWS · $1,240.00", and the progress: "2 of 5 answered."

**Similar questions.** If other transactions in the list are from the same vendor and have the same question, offer to send the same answer to them, as a numbered list. Reply **all**, **all except 2**, or **none**. Send one answer per transaction.

The client can say "skip", "go back" or "stop" at any time. "Skip" moves the question to the end. "Stop" ends the session: every answer sent so far is with Numix, and the rest wait on the dashboard and here.

## Step 3. Finish

1. When the month's questions are answered, tell the client Numix will review the answers and may reply. Replies show up here and on the dashboard.
2. If other months have questions waiting (from `fetch_open_questions`), offer the next one.
3. If something fails to send, retry once. If it fails again, tell the client which answers weren't sent and that they can answer on the dashboard.
