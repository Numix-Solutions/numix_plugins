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

The plugin includes four guided workflows. Ask for them in your own words, or run them directly:

- **Onboarding** (`/numix:onboarding` in Claude): set up your Numix account step by step, as on the dashboard: company details, the banks, payroll and accounting software you use, your documents, then review and send. Your progress is saved as you go, so you can continue later here or on the dashboard.
- **R&D tax credit** (`/numix:calculate-rd-credit` in Claude): estimate your federal and California R&D credit for a tax year. The assistant goes through your expenses, wages, contractors, prior research expenses and gross receipts with you, calculates the credit, prepares pre-filled Forms 6765 and 3523, and sends it to the Numix team for review.
- **Transaction review** (`/numix:review-transactions` in Claude): answer the Numix team's questions about unclear transactions, and confirm which of your expenses are R&D, a month at a time. Expenses from the same vendor are grouped so you confirm them together, and your decisions from earlier months are suggested again.
- **Expense claim** (`/numix:claim-expense` in Claude): get reimbursed for a purchase. Tell the assistant the details or share your receipts, review the claim, and submit it.

## Getting started

1. You need a Numix account. Sign up or sign in at [app.numix.app](https://app.numix.app).
2. Install the plugin. The first time a Numix tool runs, your assistant asks you to sign in to Numix in your browser.
3. Ask, for example: "What are my open tasks in Numix?" or "Show my cash, burn and runway".

## Security

- You sign in with your Numix account (OAuth). The assistant only sees your own organization's data.
- Actions that change your data, such as submitting an expense claim or your onboarding, need a 6-digit code from your authenticator app. Turn on two-factor authentication in the Numix dashboard first: [Settings › Security](https://app.numix.app/dashboard/me?active=security).
- Saving your onboarding progress doesn't need a code: nothing is sent to Numix until you submit it.
- Your full EIN is never shown to the assistant.

Read our [Privacy Policy](https://www.numix.co/privacy-policy).

## Test it locally

Claude Code:

```bash
claude --plugin-dir ./plugins/numix
```

## Support

Questions or problems: contact your Numix team, or write to us from the [Numix dashboard](https://app.numix.app).
