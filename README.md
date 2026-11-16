# numix_plugins

The Numix plugin for AI assistants: one package that works in **Claude** (Claude Code, Claude apps) and **ChatGPT / Codex**. It connects the assistant to the Numix MCP server and adds skills that walk clients through Numix workflows, such as onboarding and expense claims.

What the plugin does for clients is described in [plugins/numix/README.md](plugins/numix/README.md).

## Layout

```text
.claude-plugin/marketplace.json  Marketplace for Claude Code (lists plugins/numix)
.agents/plugins/marketplace.json Marketplace for ChatGPT and Codex (lists plugins/numix)
LICENSE                          MIT
plugins/numix/
├── .claude-plugin/plugin.json   Claude manifest
├── plugin.json                  OpenAI manifest (portable format, settings under extensions.com.openai)
├── .mcp.json                    MCP server for Claude
├── mcp.json                     MCP server for OpenAI (OAuth with dynamic client registration)
├── skills/                      Skills, one folder per skill, shared by both platforms
│   ├── onboarding/SKILL.md
│   ├── claim-expense/SKILL.md
│   ├── calculate-rd-credit/SKILL.md
│   ├── review-transactions/SKILL.md
│   └── rnd-review/SKILL.md
├── assets/                      Icon and logo
└── README.md                    Client-facing description
```

Each platform reads only its own files, so they live side by side:

| | Claude | OpenAI |
| --- | --- | --- |
| Manifest | `.claude-plugin/plugin.json` | `plugin.json` |
| MCP server | `.mcp.json` (`type: http`) | `mcp.json` (`type: streamable-http`) |
| Skills | `skills/<name>/SKILL.md` | `skills/<name>/SKILL.md` |

Keep the shared fields (`name`, `version`, `description`, `author`, `homepage`, `keywords`) the same in both manifests, and bump `version` in both for every release.

Both MCP configs point to the production server, `https://mcp.numix.app/mcp`, which is built from the `mcp_server` repository.

## Skills

| Skill | What it does |
| --- | --- |
| `onboarding` | Walks a new client through the four onboarding steps of the dashboard (company details, financial connections, documents & history, review & send), picks up where they left off, submits it and sets up their connections |
| `claim-expense` | Creates and submits one expense claim, entered by hand or read from receipts, with the files attached |
| `calculate-rd-credit` | Estimates the R&D tax credit for one tax year: collects and confirms expenses, wages, contractors, prior research expenses and gross receipts, calculates the federal and California credits, generates Forms 6765 and 3523, and submits it to the Numix team |
| `review-transactions` | Answers the Numix team's bookkeeping questions about unclear transactions (the dashboard's "Needs clarification" tab), a month at a time |
| `rnd-review` | Confirms the R&D status of the client's expenses for one tax year: finds similar expenses across the year with `fetch_similar_expenses` and reviews them as groups, biggest first |

## Test it locally

**Claude Code**

```bash
claude --plugin-dir ./plugins/numix
```

The first time a Numix tool runs, you sign in to Numix in your browser.

**ChatGPT desktop / Codex**: this repository is a marketplace (`.agents/plugins/marketplace.json`). Add it, then install Numix from it:

```bash
codex plugin marketplace add ./
```

To turn it on for one project only, add this to the project's `.codex/config.toml` (trusted projects only):

```toml
[plugins."numix@numix"]
enabled = true
```

After changing the plugin, run `codex plugin marketplace upgrade numix` and restart the ChatGPT desktop app. There's no `onboardingSkill` in `plugin.json` on purpose: ChatGPT would offer it as "Set up Numix" on every install, and our `onboarding` skill is the Numix client onboarding, which most clients finished long ago. See [Package your plugin](https://developers.openai.com/plugins/build/plugins).

## Validate

```bash
claude plugin validate ./plugins/numix
```

`Validation passed` means the plugin loads in Claude. The command also lists what Anthropic's plugin directory would refuse; run it with `--profile directory` to fail on those.

## Writing skills

A skill is a `SKILL.md` that the assistant follows to run a workflow with the Numix MCP tools. Skills don't run code of their own: the MCP server does the work, and the skill is the conversation and the business rules.

- **Frontmatter**: `name` (kebab-case, the same as the folder), `description` (what the skill does and when to use it: this is how the assistant decides to load it) and `user-invocable: true`.
- **Steps in strict order**, with gates: the assistant doesn't save or submit before the client has given or confirmed the information.
- **Tools by their exact names** in backticks, e.g. `get_current_onboarding`. The contract between a skill and the MCP server is only this text: when a tool is renamed or changes behaviour, search the skills for it.
- **Resumable**: read the saved state first (e.g. `get_current_onboarding`) and continue where the client left off.
- **Writes need two-factor authentication**: check `totp_enabled` from `get_user_info` early, and get a write token with `validate_otp` before the tool that needs it. Draft saves (onboarding) don't need one.
- **Uploads** use a presigned link from the MCP server and a `curl` command, 2 MB at most; larger files go through the Numix web apps. If the client's app blocks the upload host, the skill asks them to allow it.
- **Provider-neutral wording**: write "the assistant" or "you", never "Claude" or "ChatGPT", and nothing that only one platform supports. OpenAI's review asks for this.
- **Mirror the web apps**: the onboarding skill follows the dashboard (`numix_client`, `/dashboard/onboarding`), the R&D credit skill follows the dashboard's R&D credit pages (`/dashboard/tax/credits`), and the claim skill follows the claims app (`reimbursement`). When those change, update the skill.

## Publishing

- **Anthropic's directory**: submit at [claude.ai/directory/manage](https://claude.ai/directory/manage) as a **Plugin bundle** (repository `Numix-Solutions/numix_plugins`, plugin path `plugins/numix`, branch `main`). The repository must be public before the listing goes live. The MCP server is listed separately as an **MCP connector**; pair the two listings. Every merge to `main` becomes a new version, so bump `version` in both manifests.
- **License**: MIT (`LICENSE` at the repository root, `license` in both manifests).
- **OpenAI**: build the upload with `scripts/build-openai-zip.sh` (writes `dist/numix-<version>.zip` from `HEAD`; its `mcp.json` adds the OAuth sign-in settings that the portal reads and Codex rejects), and upload it at [platform.openai.com/plugins](https://platform.openai.com/plugins). The MCP server must be in the first upload: it can't be added to an existing skills-only draft. Submit through the plugin submission portal, **With MCP** (our server is a remote HTTPS endpoint), together with the skills. Approved plugins are listed in the directory shared by ChatGPT and Codex. Before submitting:
  - the MCP server needs the `openid` and `email` OAuth scopes and a UserInfo endpoint that returns `email` and `email_verified: true`
  - verify the domain: serve the portal's token at `https://mcp.numix.app/.well-known/openai-apps-challenge`
  - `termsOfServiceURL` points to the privacy policy for now: replace it with a terms of service page when there is one
  - keep the plugin free of lifecycle hooks: plugins with hooks aren't eligible for the directory
