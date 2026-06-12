# Install — QaaS for Claude Code

The QaaS platform ships as a **native Claude Code plugin**. Installing it adds skills,
subagents, slash commands, an offline Fact Base, and an airgap-safe `curl` docs fetcher to
Claude Code. **The only thing you ever configure is one environment variable:
`QAAS_DOCS_URL`** (where your QaaS docs live). No PowerShell, no setup scripts, no WebFetch.

There are three ways to install, in order of preference. Pick one.

---

## Option A — Zero commands (open the repo)

If you open **this repository** in Claude Code, the plugin auto-installs. The committed
[`.claude/settings.json`](./.claude/settings.json) registers the marketplace and enables the
`qaas` plugin for the workspace:

```jsonc
{
  "extraKnownMarketplaces": {
    "qaas-copilot": { "source": { "source": "github", "repo": "eldarush/qaas-copilot" } }
  },
  "enabledPlugins": { "qaas@qaas-copilot": true }
}
```

Launch Claude Code in the repo folder and approve the plugin when prompted. That's the one
button. To get the same behaviour in **your own** project, copy that `.claude/settings.json`
into your repo root and commit it — everyone who opens the repo gets QaaS automatically.

---

## Option B — One command (connected machine)

From inside Claude Code:

```
/plugin marketplace add eldarush/qaas-copilot
/plugin install qaas@qaas-copilot
```

The first line registers the marketplace from GitHub; the second installs the plugin. Restart
Claude Code if it asks. Done.

---

## Option C — Airgapped (no GitHub, no internet)

On a connected machine, clone the repo and copy it to your airgapped host (USB, internal git,
artifact share — whatever you use):

```bash
git clone https://github.com/eldarush/qaas-copilot.git
# copy the qaas-copilot/ folder to the airgapped machine, e.g. /opt/qaas-copilot
```

On the airgapped host, add the marketplace **from the local path** and install:

```
/plugin marketplace add /opt/qaas-copilot
/plugin install qaas@qaas-copilot
```

Then point the plugin at your **internal** docs mirror (the one config knob):

```bash
export QAAS_DOCS_URL="http://docs.internal.example.com"     # Linux/macOS
# setx QAAS_DOCS_URL "http://docs.internal.example.com"     # Windows (new shells)
```

Everything else — the 20 skills, 4 subagents, 5 commands, and the full offline Fact Base — is
bundled inside the plugin and needs no network. `QAAS_DOCS_URL` defaults to
`https://docs.qaas.online`; set it once to your mirror and you are done.

> **Plug-and-play promise:** the *only* value you change for a new environment is
> `QAAS_DOCS_URL`. The plugin carries its own drift-corrected knowledge offline, so even with
> no docs server reachable it still works from the bundled Fact Base.

---

## What you get

| Capability | How it shows up in Claude Code |
|---|---|
| Always-on QaaS expertise | `qaas-overview` skill auto-loads each session (constitution + 29 drift traps + skill index) |
| 19 task skills | model-invoked by description: plan, scaffold, author YAML, pick generators/assertions, author hooks, run, diagnose, build mocker images, offline packaging, verify-done, validate-compatibility, analyze SUT repos/charts/tests, document test projects |
| 4 subagents | `qaas-planner`, `qaas-test-author`, `qaas-debugger`, `qaas-analyst` |
| `/qaas:docs <path>` | fetch a live docs page over `curl` from `$QAAS_DOCS_URL` |
| `/qaas:fact <slice>` | print an offline Fact Base slice (`s00`–`s16`) — no network |
| `/qaas:new-test <goal>` | full plan → author → run → verify workflow |
| `/qaas:diagnose <evidence>` | root-cause a failing run from logs/exit codes |
| `/qaas:verify` | fail-closed completion gate before claiming "done" |

---

## Verify the install

In Claude Code:

```
/help                      # the /qaas:* commands should be listed
/qaas:fact s13             # prints the doc-drift traps from the offline Fact Base
/qaas:docs llms.txt        # streams the live docs index from $QAAS_DOCS_URL
```

If `/qaas:fact` prints content, the plugin is loaded. If `/qaas:docs` returns text, your
`QAAS_DOCS_URL` is reachable. (Docs fetch failing is non-fatal — the Fact Base covers the
core; fix `QAAS_DOCS_URL` when convenient.)

---

## Update / uninstall

```
/plugin marketplace update qaas-copilot     # pull the latest catalog
/plugin install qaas@qaas-copilot           # reinstall to update
/plugin uninstall qaas@qaas-copilot         # remove
```

---

## Notes

- **One env var only.** `QAAS_DOCS_URL` is the single knob. Everything else is bundled.
- **No PowerShell, no scripts.** The plugin is pure data — skills, commands, agents, and the
  Fact Base. Nothing to execute at install time.
- **Docs over curl, never WebFetch.** `/qaas:docs` shells out to `curl -fsSL`, so it works
  behind corporate proxies and on airgapped LANs with an internal mirror.
- **NuGet / Docker / model endpoints** are environment concerns, not plugin concerns — see
  [AIRGAP.md](./AIRGAP.md) for the offline NuGet feed, base images, and local-model gateway.

