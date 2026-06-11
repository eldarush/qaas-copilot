# QaaS Copilot

A native Claude Code plugin for QaaS testing and debugging using only the QaaS docs and the bundled Fact Base. The only environment knob is `QAAS_DOCS_URL`.

## Install

### Zero commands
Open this repo in Claude Code and approve the plugin when prompted. The committed `.claude/settings.json` registers the marketplace and enables `qaas@qaas-copilot`.

### One command
Inside Claude Code:

```text
/plugin marketplace add eldarush/qaas-copilot
/plugin install qaas@qaas-copilot
```

### Airgapped
Copy the repo to your internal host, then install from the local path:

```text
/plugin marketplace add /opt/qaas-copilot
/plugin install qaas@qaas-copilot
```

Set the docs mirror once:

```bash
export QAAS_DOCS_URL="http://docs.internal.example.com"
```

## What you get

| Surface | What it does |
|---|---|
| `qaas-overview` | Always-on master skill with docs-first rules and drift traps |
| 15 task skills | runner, mocker, hooks, run/diagnose, container, airgap, compatibility |
| 3 subagents | planner, test author, debugger |
| `/qaas:docs <path>` | Fetch docs over curl from `$QAAS_DOCS_URL` |
| `/qaas:fact <slice>` | Read the offline Fact Base (`s00`–`s15`) |
| `/qaas:new-test <goal>` | Plan, author, run, verify |
| `/qaas:diagnose <evidence>` | Root-cause a failing run |
| `/qaas:verify` | Fail-closed completion gate |

## Working method

1. State the goal in one sentence.
2. Ask blocking questions.
3. Decide runner-only vs mock-required.
4. Validate every fact against the docs or Fact Base.
5. Run `template`, build, and live execute before claiming done.

## Repo layout

- `.claude/` — Claude Code marketplace settings
- `.claude-plugin/` — plugin catalog
- `plugins/qaas/` — the shipped plugin
- `README.md`, `INSTALL.md`, `AIRGAP.md`, `CLAUDE.md` — user-facing docs
- `LICENSE` — MIT
- `EXPORT-MANIFEST.md` — included/excluded export map
