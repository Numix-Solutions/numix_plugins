---
name: onboarding
description: >
  Guides a new client through their Numix onboarding, step by step: confirming
  company details, choosing their banks, payroll and accounting software,
  sharing documents and the state of their books, then reviewing and submitting
  everything to Numix. Picks up where the client left off, including progress
  made on the Numix dashboard. Use this skill whenever a client wants to start,
  continue or finish onboarding, set up their Numix account, asks "what do you
  need from me to get started", or has an open "Finish onboarding" task.
user-invocable: true
---

# Onboarding

This skill walks a client through the four onboarding steps of the Numix dashboard (https://app.numix.app/dashboard/onboarding), in the same order:

1. **Company details**: legal name, entity type, EIN, address and contact person
2. **Financial connections**: banks and cards, payroll, accounting software
3. **Documents & history**: company documents, prior tax returns and the state of the books
4. **Review & send**: check everything and submit it to Numix

Follow every step in order. Never skip a step, and never call a tool that saves or submits before the client has given or confirmed the information.

## Important considerations

- **Progress is saved as a draft.** `update_onboarding` and `attach_onboarding_file` save the client's progress; nothing is sent to Numix until Step 4 (`submit_onboarding`). The client can stop at any time and continue later, here or on the dashboard: both use the same draft.
- **One place at a time.** The dashboard auto-saves too. If the client has the onboarding open on the dashboard while you work here, the next save on either side can overwrite the other. Ask them to close the dashboard's onboarding page while you continue here.
- **Only save what the client told you.** Never invent, guess or "fill in" a value, and never save a field the client didn't give or confirm. Empty fields are normal in a draft.
- **The EIN is masked.** `get_current_onboarding` only shows the last 4 digits (e.g. `**-***6789`). Never send the masked value back, never guess the full number, and never show a full EIN in the chat. Only send `ein` when the client typed the full 9 digits, or confirmed the EIN on file or on their EIN letter (Step 1).
- **Submitting needs two-factor authentication and the account owner.** Saving progress doesn't, but `submit_onboarding` requires a 6-digit code from the client's authenticator app, and only the account owner can submit. Team members can fill everything in and then ask the owner to submit.
- **Files over 2 MB can't be uploaded from here.** The client attaches them on the dashboard's documents step (https://app.numix.app/dashboard/onboarding?step=documents); they then show up here too.
- **Uploads may be blocked by the client's app.** Files are uploaded with a bash command to the host in the upload link's `url` (e.g. `numix-onboarding.s3.amazonaws.com`, or `numix-extract.s3.amazonaws.com` for the EIN letter in Step 1). If the command fails without an HTTP status (the host can't be reached or is blocked), the client's AI app may block network access to that host. Tell them the host and ask them to add it to the allowed domains in their app's settings, with steps for the app and version they use. Then generate a new link and try again.
- **Interactive forms with a table fallback.** Where a step asks for several fields, display an interactive form if your client supports it; otherwise show a structured table in the chat and ask for the values.
- If a tool keeps failing, don't loop: tell the client what went wrong and point them to support at office@numix.co.

## Step 0. Welcome and pick up where the client left off

1. Silently call `get_user_info`, `get_company_info` and `get_current_onboarding`.
2. Welcome the client by name and company. Explain in a few sentences what onboarding covers (the four steps above), that progress is saved as they go, and that nothing is sent to Numix until they review and submit it at the end.
3. Check where they are, using the `get_current_onboarding` result:
   - **`found: false`**: they haven't started. Go to Step 1.
   - **`remaining_steps` is empty**: the onboarding was already submitted. Tell the client, offer a short summary of what was sent, and end the process unless they explicitly want to change and resubmit something.
   - **Otherwise**: show a short checklist of the four steps, marking the ones in `completed` as done, and continue with the first step in `remaining_steps`. If the client wants to revisit a completed step, do that first.
4. Check `totp_enabled` in the `get_user_info` response. If it's not enabled, tell the client now (so it isn't a surprise at the end) that they can fill everything in, but need to turn on two-factor authentication before submitting: https://app.numix.app/dashboard/me?active=security.
5. Remind them to close the onboarding page on the dashboard while you work here.

Do not proceed until the client is ready to continue.

## Step 1. Company details

Collect the company's legal details, the main contact and the business address. Numix already has some of this from the client's agreement, so most of it is a review.

### 1.1 Prepare the starting values

- **Company**: if `get_current_onboarding` returned a `company` section, start from it: that's what the client saved before. Otherwise start from `get_company_info`, as the dashboard does:
  - `legal_company_name` and `entity_type` as on file
  - `ein`: the EIN on file, unless it's empty or `n/a`
  - `country`: "United States"
  - `address` on file is one line: split it into `street`, `suite`, `city`, `state` and `zip` where you can, and let the client confirm
- **Main contact**: if the onboarding has a `contact` section, start from it. Otherwise use the name and email from `get_user_info`.

Never show a full EIN in the chat: show only the last 4 digits (e.g. `**-***6789`), whichever source it came from.

### 1.2 Offer the EIN letter

Ask whether the client has their IRS EIN confirmation letter (CP 575 or 147C): Numix can read the company details from it. If they share it:

1. Call `generate_extraction_upload_link` with the file name, and upload the file as the tool describes (the file must be 2 MB or less).
2. Call `get_extraction_result` with the `execution_id`. While the status is `PENDING` or `RUNNING`, wait a few seconds and call it again, for about a minute at most.
3. When it `SUCCEEDED` with an `output`, use `business_name`, `ein_raw`, `entity_type` and `address` in place of the starting values for those fields. Keep the starting value for any field the letter didn't give.

If the upload host is blocked, follow "Uploads may be blocked by the client's app" in the important considerations. If the upload isn't possible (the file is over 2 MB, or you can't run the upload command), or the extraction failed or found nothing, read the letter yourself if the client shared it in the chat; otherwise continue with the starting values.

Map the entity type as written on the letter:

| On the letter | `entity_type` |
| --- | --- |
| C Corp, C Corporation, Corporation | `c_corp` |
| S Corp, S Corporation | `s_corp` |
| LLC (single-member or multi-member) | `llc` |
| Partnership | `partnership` |
| Sole Proprietor, Sole Proprietorship | `sole_proprietorship` |

Tell the client which fields came from the letter. Also tell them they can attach the same letter as their EIN confirmation document in Step 3, so they don't have to look for it twice.

If they don't have it, continue with the starting values.

### 1.3 Review the details with the client

Display an interactive form, or a table in the chat, with three sections. Mark the values that came from the agreement or the letter, and the required fields (*):

**Company information**

| Field | Saved as | Rules |
| --- | --- | --- |
| Legal company name* | `company.legal_company_name` | As registered |
| Business structure* | `company.entity_type` | One of: C-Corp (`c_corp`), S-Corp (`s_corp`), LLC (`llc`), Partnership (`partnership`), Sole Proprietorship (`sole_proprietorship`) |
| EIN (tax ID)* | `company.ein` | Exactly 9 digits, written `XX-XXXXXXX`. If the client doesn't have it yet, set `company.ein_later` to true instead |

**Main contact**

| Field | Saved as | Rules |
| --- | --- | --- |
| Name* | `contact.name` | The person Numix contacts about the company |
| Email* | `contact.email` | A valid email address |

Tell the client that changing the main contact only changes who Numix contacts about the company, not their account: they still sign in with their current email.

**Business address**

| Field | Saved as | Rules |
| --- | --- | --- |
| Country | `company.country` | "United States" unless the client says otherwise |
| Street address* | `company.street` | |
| Apartment, suite, etc. | `company.suite` | Optional |
| City* | `company.city` | |
| State* | `company.state` | In the United States, the 2-letter code (e.g. `CA`, `TX`); elsewhere, the state or province as written |
| ZIP code* | `company.zip` | Postal code outside the United States |

Let the client correct anything, then read the final values back and get their confirmation.

### 1.4 Save

1. Call `update_onboarding` with the confirmed `company` and `contact` values. Include the values taken from the agreement or the letter once the client has confirmed them: they aren't in the draft yet.
   - Send `ein` only if the client confirmed or typed a full 9-digit EIN. If the onboarding already had a masked EIN and the client didn't change it, leave `ein` out: the saved one is kept.
   - If the client chose to add the EIN later, send `ein_later: true` and no `ein`.
2. Check that every required field (*) is filled, and the EIN is either 9 digits or `ein_later` is true:
   - **All filled**: call `update_onboarding` with `complete_steps: ["company"]`, tell the client the step is done, and go to Step 2.
   - **Something is missing**: list what's missing. The progress is saved, so the client can find the missing details and continue later. Don't mark the step done and don't go to Step 2 until it's complete: the onboarding can't be submitted without the company step.

## Step 2. Financial connections

Find out where the company's money moves: the banks and cards it uses, who runs payroll and where the books are kept. Nothing is connected in this step: the client only tells Numix what they use. How to connect each one comes after the onboarding is submitted.

Start from the `connections` section of `get_current_onboarding` if there is one, and show the client what's already saved.

### 2.1 Banks and cards

Ask which banks and cards the company uses. They can pick any number of these:

| Bank or card | Key | How transactions can be synced |
| --- | --- | --- |
| Chase (Business) | `chase` | Plaid or manual upload |
| Chase Commercial / J.P. Morgan | `chase_commercial` | Manual upload |
| Wells Fargo | `wells_fargo` | Plaid or manual upload |
| U.S. Bank | `us_bank` | Plaid or manual upload |
| Mercury | `mercury` | Plaid or manual upload |
| Bank of America | `bank_of_america` | Plaid or manual upload |
| Silicon Valley Bank (SVB) | `svb` | Manual upload |
| American Express | `amex` | Manual upload |
| Brex | `brex` | Manual upload |
| Ramp | `ramp` | Manual upload |
| Capital One | `capital_one` | Manual upload |
| East West Bank | `east_west` | Manual upload |
| Rho | `rho` | Manual upload |
| Thread Bank (Every) | `thread` | Manual upload |
| Grasshopper | `grasshopper` | Manual upload |

For any bank or card not in the list, add `other` to the keys, and put their names in `other_banks`, separated by commas (e.g. "First Republic, Citi"). Their transactions are synced by manual upload.

After the client picks, show a short table of their banks and cards with how each one's transactions can be synced (the last column above).

### 2.2 Payroll

Ask whether the company runs payroll (`payroll.runs`):

- **Through a payroll provider** (`provider`): ask which one (`payroll.provider`): Gusto (`gusto`), Rippling (`rippling`), Deel (`deel`), ADP (`adp`), Paychex (`paychex`), Justworks (`justworks`), or another provider (`other`, with its name in `payroll.other_provider`).
- **No payroll** (`none`): no provider. Send `provider` and `other_provider` as empty strings.

### 2.3 Accounting software

Ask where the books are today (`accounting.books`):

- **In accounting software** (`software`): ask which one (`accounting.provider`): QuickBooks (`quickbooks`), Xero (`xero`), NetSuite (`netsuite`), Sage Intacct (`sage_intacct`), or other software (`other`, with its name in `accounting.other_provider`).
  - For QuickBooks, tell the client they'll connect it themselves from Connections on the dashboard (https://app.numix.app/dashboard/settings/connections) once onboarding is done. Nothing else to do here.
- **Starting fresh** (`fresh`): no software. Send `provider` and `other_provider` as empty strings.

### 2.4 Save

1. Read the client's choices back to them as a summary (banks and cards with how they sync, payroll, accounting) and get their confirmation.
2. Call `update_onboarding` once, with the `connections` the client confirmed and `complete_steps: ["accounts"]`.
   - `banks` replaces the whole saved list: always send the complete list, including banks that were saved before and the client kept.
   - Use the keys from the tables above, never the display names. For a bank, provider or software not in the lists, use `other` and its name.
3. Tell the client the step is done, and go to Step 3.

Nothing in this step is required: if the client doesn't know something yet, they can skip it and the step is still marked done, as on the dashboard. Mention that they can come back and change it any time before submitting.

## Step 3. Documents & history

Collect the company's documents, its tax history and where its books stand. Numix uses them to verify the company details and to pick up the bookkeeping.

Start from the `documents` section of `get_current_onboarding` if there is one, and show the client what's already saved, including the files attached so far (by name).

### Attaching a file

Use this procedure for every file in this step:

1. Call `generate_onboarding_upload_link` with the file name, and upload the file as the tool describes. The file must be 2 MB or less.
2. When the upload returned HTTP 204, call `attach_onboarding_file` with the `key`, the document kind and the file size in bytes.
3. Tell the client the file is attached.

If the client attaches several files, upload them all in one command that prints one status line per file, then attach each uploaded file. Attach at most 10 files of each kind, as on the dashboard.

If the upload host is blocked, follow "Uploads may be blocked by the client's app" in the important considerations. If a file is over 2 MB, or you can't run the upload command, or the upload fails twice, don't retry: ask the client to attach it on the dashboard's documents step (https://app.numix.app/dashboard/onboarding?step=documents). It then shows up here too.

To remove an attached file (e.g. the client attached the wrong one), confirm which file by its name and kind, then call `remove_onboarding_file` with its `id` (from `get_current_onboarding` or `attach_onboarding_file`).

### 3.1 Company documents

These help Numix verify the company information. Ask the client to attach:

| Document | Kind | What it is |
| --- | --- | --- |
| Formation documents | `formation` | Articles of incorporation, organization or equivalent |
| EIN confirmation | `ein_confirmation` | The IRS letter confirming the company's tax ID (CP 575 or 147C) |

If the client shared their EIN letter in Step 1, offer to attach that same file as the EIN confirmation, rather than asking for it again.

### 3.2 Tax history

Ask whether the company has filed a tax return before (`documents.tax_filed`):

- **Yes, we have prior tax returns** (`yes`): ask them to attach their most recent returns (kind `tax_returns`). Numix confirms later which years are needed, so the latest ones are enough to start.
- **No, we haven't filed yet** (`no`): nothing to attach.

### 3.3 Bookkeeping history

Ask about the current state of the books (`documents.books_state`):

- **Up to date** (`up_to_date`) or **Behind, needs catching up** (`behind`): ask
  - which month the books were last completed through (`documents.books_through`, e.g. "December 2025")
  - for their existing bookkeeping records (kind `bookkeeping`), for example their latest balance sheet and profit & loss
- **We haven't kept books yet** (`none`): nothing else to ask. Send `books_through` as an empty string.

### 3.4 Save

1. Attach the files as the client shares them (see "Attaching a file" above); each one is saved straight away.
2. Read the answers back to the client: tax history, the state of the books and the month they were completed through, and the files attached for each kind. Get their confirmation.
3. Call `update_onboarding` once, with the confirmed `documents` answers (`tax_filed`, `books_state`, `books_through`) and `complete_steps: ["documents"]`.
4. Tell the client the step is done, and go to Step 4.

Nothing in this step is required, as on the dashboard: if the client doesn't have a document at hand, they can skip it and attach it later, here or on the dashboard, any time before submitting. Tell them which documents are still missing, so they know what to look for.

## Step 4. Review & send

Show the client everything they're about to send, submit it to Numix, and set up the connections they selected.

### 4.1 Review the summary

Call `get_current_onboarding` again: the client may have changed something on the dashboard since. Show a short summary, one line per step, as the dashboard does:

| Step | Summary |
| --- | --- |
| Company details | Legal company name · business structure (e.g. "Acme Inc · C-Corp") |
| Financial connections | Number of banks and cards (each name in `other_banks` counts as one; `other` itself doesn't) · payroll provider, or "No payroll" · accounting software, or "Starting fresh books" (e.g. "4 banks · Gusto · QuickBooks") |
| Documents & history | Number of attached files · "Prior returns" or "No prior returns" · "Books up to date", "Books behind" or "No books yet" (e.g. "3 files · Prior returns · Books behind") |

Write "Not started yet" for a step with nothing saved. Then:

- Offer to show the full details of any step, and to change anything before sending. To change something, go back to that step, then return here.
- Mention anything still missing that would help Numix, e.g. documents they haven't attached yet. It doesn't block sending: they can share it later.
- **The company step must be done** (in `completed`) before sending, as on the dashboard. If it isn't, tell the client to finish their company details first, and go back to Step 1.

### 4.2 Send to Numix

1. Ask the client for explicit confirmation that everything is correct and they want to send it to Numix. Do not proceed without it.
2. Get a write session token, if you don't have one in this conversation yet:
   - If `totp_enabled` (from `get_user_info`) is false, the client can't send it from here yet: they need to turn on two-factor authentication first (https://app.numix.app/dashboard/me?active=security). Their progress is saved: they can come back after, or send it from the dashboard's review step (https://app.numix.app/dashboard/onboarding?step=review). End the process.
   - Otherwise ask for the 6-digit code from their authenticator app, and call `validate_otp`. Never guess or reuse a code, and if a code is rejected, ask the client for a new one rather than retrying.
3. Call `submit_onboarding` with the write token.
   - **Only the account owner can send it.** If the tool says so, tell the client: their team member who owns the account needs to review and send it. Everything they filled in is saved, so the owner only has to send it. End the process.
   - On any other error, tell the client it couldn't be sent, and try once more. If it fails again, point them to the dashboard's review step or support (office@numix.co).

### 4.3 Set up the connections

Once the onboarding is sent, create an integration for each bank, card, payroll provider and accounting software the client selected in Step 2, as the dashboard does. They then appear under Connections on the dashboard, ready for the client to connect. If the client selected nothing in Step 2, skip this.

Build the list from the `connections` section, using these rules, then call `create_integrations` with `source: "onboarding"` and the same write token (at most 25 integrations per call):

| Selected | `type` | `key` | `name` | `description` |
| --- | --- | --- | --- | --- |
| Bank synced through Plaid: `chase`, `wells_fargo`, `us_bank`, `mercury`, `bank_of_america` | `plaid` | the bank's key | the bank's name from the Step 2 table | "Connect your <name> accounts through Plaid." |
| Any other bank in the list | `manual_bank` | the bank's key | the bank's name | "Invite onboarding@numix.co to <name> as a view-only user, or upload your statements." |
| Each name in `other_banks` | `manual_bank` | the name in lowercase, with every run of other characters replaced by `_`, and no `_` at either end (e.g. "First Republic" → `first_republic`) | the name as typed | Same as above |
| Payroll Gusto or Deel (only if `payroll.runs` is `provider`) | `gusto` or `deel` | `gusto` or `deel` | Gusto or Deel | "Connect <name> from Settings › Connections." |
| Any other payroll provider | `manual_payroll` | the provider's key, or for `other` the provider's name as a key (as above) | the provider's name, or `other_provider` | "Invite onboarding@numix.co to <name> with read-only access to your payroll reports." |
| QuickBooks (only if `accounting.books` is `software`) | `qbo` | `quickbooks` | QuickBooks | "Connect QuickBooks from Settings › Connections." |
| Any other accounting software | `manual_accounting` | the software's key, or for `other` the software's name as a key (as above) | the software's name, or `other_provider` | "Invite onboarding@numix.co to <name> with read-only access to your books." |

Leave out the `other` key itself, and any `other` provider or software without a name. Each type and key appears once.

The onboarding is already sent at this point, whatever happens here. If `create_integrations` fails, try once more; if it fails again, tell the client the onboarding was sent but their connections couldn't be set up, and they can add them from Connections on the dashboard (https://app.numix.app/dashboard/settings/connections).

### 4.4 What's next

Tell the client:

- Numix has received their information. The team will review everything and reach out if they need anything else.
- The next step is to connect their tools, so Numix can start working: on the dashboard under Connections (https://app.numix.app/dashboard/settings/connections), as listed by the integrations just created. For manual ones, they invite onboarding@numix.co with read-only access, as each one describes.
- Numix also created tasks for connecting each one. Offer to show them with `fetch_tasks`.

This ends the onboarding.
