---
name: claim-expense
description: >
  Guides a client through creating and submitting one expense claim on the
  Numix platform: collecting the expense type, date, amount and description,
  attaching receipts or invoices, and submitting it for reimbursement. Use this
  skill whenever a client wants to file an expense claim, get reimbursed for a
  purchase, submit a receipt for reimbursement, or asks "how do I get paid back
  for this", even if they don't use the words "reimbursement" or "expense claim".
user-invocable: true
---

# Expense Claim

This skill helps a client create one expense claim on the Numix platform: collecting its details, attaching the receipts or invoices, and submitting it with `create_expense_claim`. The same claims are on the Numix claims app (https://claims.numix.app/claims).

Follow every step in order. Never skip a step, and never submit before the client has confirmed the claim.

## Important considerations

- **One claim at a time.** To start another claim, finish (submit) the current one first. Claims aren't saved as drafts: a claim that isn't submitted is lost when the conversation ends.
- **A claim has:** an expense type, the date of the expense, a description, the total amount in US dollars, and at least one attached file (receipt or invoice).
- **Several receipts in one claim only in automatic mode** (Step 2b): the claim's amount is then the sum of all of them. In manual mode (Step 2a) a claim is a single expense.
- **Amounts are in US dollars.** If a receipt is in another currency, convert it at the current exchange rate, tell the client the rate you used, and let them confirm or correct the amount.
- **Submitting needs two-factor authentication**: a 6-digit code from the client's authenticator app.
- **Files over 2 MB can't be uploaded from here.** The client attaches them on the claims app (https://claims.numix.app/claims) instead.
- Only use what the client gave you or what's on their receipts. Never invent or guess a value.
- If a tool keeps failing, don't loop: tell the client what went wrong and point them to support at office@numix.co.

## Step 0. Welcome

1. Silently call `get_user_info` and `get_company_info`. If the user isn't found, tell the client and end the process.
2. Welcome the client, and show who the claim will be submitted for: their name, email and company.
3. Check `totp_enabled` in the `get_user_info` response. If it's not enabled, tell the client that submitting a claim needs two-factor authentication, which they turn on in the dashboard (https://app.numix.app/dashboard/me?active=security), and end the process: don't collect details or upload files they can't submit.

## Step 1. Explain the process and choose manual or automatic

Tell the client how this works, in your own words:

- This creates one expense claim.
- There are two ways to fill it in:
  - **Manual**: they tell you the details themselves, and attach their receipt or invoice as proof. The files aren't read.
  - **Automatic**: they attach their receipts, and you read the details from them. One claim can cover several receipts.
- A claim needs an expense type (Travel, Supplies or Other), the date, the amount, a description and the attached files.

Ask which way they want before doing anything else.

## Step 2a. Manual entry

Ask for these one at a time:

| Field | Saved as | Rules |
| --- | --- | --- |
| Expense type | `expense_type` | `travel`, `supplies` or `other` (shown to the client as Travel, Supplies, Other) |
| Expense date | `expense_date` | The date of the expense, `YYYY-MM-DD` |
| Amount | `total_amount` | Total to be reimbursed, in US dollars, at least $1.00 |
| Description | `description` | What the expense was for, at most 512 characters |

Then ask the client to attach their receipt or invoice. Upload each file as described in "Uploading a file" below. Don't read or analyze the files in manual mode. After each upload, ask whether they want to attach another file, until they say no.

## Step 2b. Automatic entry (from receipts)

Ask the client to attach their receipts first. For each file:

1. Upload it as described in "Uploading a file" below.
2. Read its expense type, date, amount (and currency) and what it's for.
3. If something can't be read from a receipt, ask the client for just that value for that receipt. Don't hold up the other receipts.

When every receipt is read, combine them into one claim:

- **Expense type**: `travel` or `supplies` if all receipts are of that type; otherwise `other`.
- **Expense date**: the latest date among the receipts that have one.
- **Amount**: the sum of all receipts, in US dollars (convert other currencies as described above).
- **Description**: a short summary of what the receipts cover, at most 512 characters.

Show the client a summary: each receipt with its date and amount, and the combined claim. Ask whether it's right. If they want changes, apply them and show the summary again.

## Uploading a file

1. **Give the file a unique name**: the upload is stored under its file name, so two files with the same name (e.g. two `receipt.pdf`) would overwrite each other. Use today's date, 6 random letters or digits and the original name, e.g. `20261114-k3f9q2-receipt.pdf`. Keep the original extension. Supported: PDF, JPEG, PNG, HEIC, GIF, WEBP.
2. Call `generate_reimbursement_link` with the unique name. It returns a presigned POST URL and its form fields.
3. Upload the file in one bash command that checks the size and uploads:
   - If the file is over 2 MB, don't upload it: ask the client to attach it on the claims app (https://claims.numix.app/claims) once the claim is submitted.
   - Otherwise: `curl -s -S -o /dev/null -w "%{http_code}" -F "<name>=<value>" ... -F "file=@<path>" <url>`, with every form field, and the file last.
   - Only report the HTTP status code, not curl's output.
4. If the status code is 2xx, add the unique name to the claim's `attached_files`. Don't re-check the upload: a 2xx response is enough.
5. If the command fails without an HTTP status (e.g. the host can't be reached or is blocked), the client's AI app may block network access to the upload host. Tell them the host (from the URL, e.g. `numix-reimb.s3.amazonaws.com`) and ask them to add it to the allowed domains in their app's settings, with steps for the app and version they use. Then generate a new link and try again.

If the client attaches several files at once, upload them all in one command that prints one status line per file.

## Step 3. Review and confirm

Show the client the whole claim: expense type, date, amount, description and the attached files (by their original names). Ask them to confirm it. If they want changes, let them change any field or attach other files, then show the claim again. Don't submit until they explicitly confirm.

## Step 4. Submit

1. If you don't have a write session token from earlier in this conversation, ask the client for the 6-digit code from their authenticator app and call `validate_otp` with it. Never make up a code or a token. If `validate_otp` fails, tell the client its message and ask for a new code once; if it says verification is locked, stop and tell the client to try again later.
2. Call `create_expense_claim` with the write token and the confirmed claim:
   - `expense_type`, `expense_date`, `description`, `total_amount`
   - `attached_files`: the unique names of all uploaded files
3. Tell the client the claim was submitted. If some files were over 2 MB, remind them to attach those on the claims app (https://claims.numix.app/claims).
4. Call `list_user_expense_claims` and show the client their claims, with the status of each.

If the client wants to submit another expense, start again from Step 1 with a new claim: don't carry anything over from the claim just submitted.
