# Install — QaaS Copilot for Claude Code

The plugin installs as a native Claude Code marketplace entry. The only thing you configure per environment is `QAAS_DOCS_URL`.

## Option A — Zero commands
Open this repo in Claude Code. The committed `.claude/settings.json` registers `qaas-copilot` and enables the plugin for the workspace.

## Option B — One command
Inside Claude Code:

```text
/plugin marketplace add eldarush/qaas-copilot
/plugin install qaas@qaas-copilot
```

## Option C — Airgapped
Copy the repo to your internal host, then install from the local path:

```text
/plugin marketplace add /opt/qaas-copilot
/plugin install qaas@qaas-copilot
```

Set the docs mirror:

```bash
export QAAS_DOCS_URL="http://docs.internal.example.com"
```

## What you get

| Capability | Included |
|---|---|
| Always-on QaaS guidance | `qaas-overview` master skill |
| Task skills | 15 skills for planning, authoring, running, diagnosing, containers, airgap, compatibility |
| Subagents | planner, test author, debugger |
| Commands | `/qaas:docs`, `/qaas:fact`, `/qaas:new-test`, `/qaas:diagnose`, `/qaas:verify` |

## Verify the install

```text
/qaas:fact s13
/qaas:docs llms.txt
```

If `/qaas:fact` prints content and `/qaas:docs` returns text, the plugin is loaded and your docs mirror works.

## Notes

- One env var only: `QAAS_DOCS_URL`.
- Docs fetch uses `curl`, not WebFetch.
- The plugin is self-contained under `plugins/qaas/`.
- No maintainer harness or evaluation corpus is included in this repo.
