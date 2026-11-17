# Numix

Work with your [Numix](https://app.numix.app) financial data from your AI assistant. The plugin connects to the Numix MCP server (`https://mcp.numix.app/mcp`) and works in Claude and ChatGPT.

## What you can do

- **Onboarding**: see where you left off, fill in your company details, connections and documents, attach files, and submit your onboarding
- **Tasks**: see what's left to do on Numix, with due dates and progress
- **Transactions**: review bank transactions, find unmatched ones, answer open questions, and add comments
- **Financial health**: cash on hand, net burn and runway, with monthly history
- **R&D tax credit**: review qualified research expenses, wages and contractors, calculate the credit, and generate pre-filled Forms 6765 and 3523
- **Expense claims**: submit a claim with its receipts and track your claims
- **Documents**: invoices, receipts, bank statements and tax forms
- **QuickBooks**: chart of accounts, balance sheets, vendors, purchase orders and journal entries from your connected QuickBooks account
- **Integrations**: list your connections, and set up the banks, payroll and accounting software you use

## Guided workflows

The plugin includes six guided workflows. Ask for them in your own words, or run them directly:

- **Onboarding** (`/numix:onboarding` in Claude): set up your Numix account step by step, as on the dashboard: company details, the banks, payroll and accounting software you use, your documents, then review and send. Your progress is saved as you go, so you can continue later here or on the dashboard.
- **R&D tax credit** (`/numix:calculate-rd-credit` in Claude): estimate your federal and California R&D credit for a tax year. The assistant goes through your expenses, wages, contractors, prior research expenses and gross receipts with you, calculates the credit, prepares pre-filled Forms 6765 and 3523, and sends it to the Numix team for review.
- **Transaction review** (`/numix:review-transactions` in Claude): answer the Numix team's questions about unclear transactions, a month at a time.
- **R&D expense review** (`/numix:rnd-review` in Claude): confirm which of your expenses for a tax year are R&D. Similar expenses across the year are grouped, biggest groups first, so you decide once for a whole group instead of one expense at a time.
- **Financial overview** (`/numix:financial-overview` in Claude): see your cash on hand, net burn and runway at a glance, then go deeper: monthly income and expenses, trends, cash by account, a summary for any months, what happens to runway if spending changes, and why a month moved, from that month's transactions.
- **Expense claim** (`/numix:claim-expense` in Claude): get reimbursed for a purchase. Tell the assistant the details or share your receipts, review the claim, and submit it.

## Getting started

1. You need a Numix account. Sign up or sign in at [app.numix.app](https://app.numix.app).
2. Install the plugin. In Claude, add Numix from the directory, or in Claude Code run:

   ```
   /plugin install numix --marketplace Numix-Solutions/numix_plugins
   ```

   The first time a Numix tool runs, your assistant asks you to sign in to Numix in your browser.
3. Ask, for example: "What are my open tasks in Numix?" or "Show my cash, burn and runway".

## Security

- You sign in with your Numix account (OAuth). The assistant only sees your own organization's data.
- Actions that change your data, such as submitting an expense claim or your onboarding, need a 6-digit code from your authenticator app. Turn on two-factor authentication in the Numix dashboard first: [Settings › Security](https://app.numix.app/dashboard/me?active=security).
- Saving your onboarding progress doesn't need a code: nothing is sent to Numix until you submit it.
- Your full EIN is never shown to the assistant.

## Where your data goes

- **Numix MCP server** (`https://mcp.numix.app/mcp`): every tool call. It reads from and writes to your Numix account.
- **Numix file storage on Amazon S3** (`*.s3.amazonaws.com`): files you share for onboarding (e.g. your EIN letter, financial documents) and receipts for expense claims. The assistant uploads each file with a `curl` command to a one-time upload link that the Numix MCP server creates for your account, valid for 5 minutes. Files are only uploaded when you ask to attach or read one.

- **Your bank's connector, if you've turned one on in the same chat** (e.g. Mercury): only while you answer Numix's questions about your transactions, and only after you agree. The assistant reads the matching transactions there to help you answer; it never changes anything in your bank. Nothing from your bank goes to Numix except the answers you confirm.

The plugin sends data nowhere else, and stores nothing on your computer. Numix keeps your records for as long as you have an account; see our [Privacy Policy](https://www.numix.co/privacy-policy).

Read our [Privacy Policy](https://www.numix.co/privacy-policy).

## Test it locally

Claude Code:

```bash
claude --plugin-dir ./plugins/numix
```

## Support

Questions or problems: contact your Numix team, or write to us from the [Numix dashboard](https://app.numix.app).
