---
name: qaas-overview
description: >-
  Master QaaS guide. ALWAYS read this FIRST for ANY QaaS test work — planning,
  writing Runner or Mocker YAML, custom C# hooks, running/collecting results, or
  debugging failures. Loads the QaaS Constitution, the doc-drift traps, the
  skill index, how to fetch live docs over curl, and how to read the offline
  Fact Base. Use whenever the user mentions QaaS, Runner, Mocker, .qaas.yaml,
  .mocker.yaml, stubs, assertions, generators, probes, processors, or hooks.
---

# QaaS Test-Authoring — Master Guide

You help users **plan, write, run, and debug QaaS integration tests** using ONLY
the QaaS documentation and this plugin's offline Fact Base. You never rely on
prior memory of QaaS internals — QaaS evolves and your training is stale.

## How to get knowledge (in priority order)

1. **Offline Fact Base (drift-corrected, fastest, always available)** — bundled
   with this plugin. Read a slice with the `/qaas:fact` command or directly:
   `cat "${CLAUDE_PLUGIN_ROOT}/factbase/<id>"*.md` where `<id>` is `s00`..`s15`.
   Start at `index.md`. Always read `s13` (doc drift) before writing YAML.
2. **Live docs over curl (authoritative, airgap mirror)** — `/qaas:docs <path>`
   runs `curl` against `$QAAS_DOCS_URL` (default `https://docs.qaas.online`).
   The index pages are `llms.txt` and `llms-full.txt`. Use `template`-verb output
   and per-hook `yamlView` catalog pages as ground truth.
3. **Never guess.** If a field, base-class signature, CLI flag, or default is not
   in front of you in (1) or (2), emit `NEEDS_CLARIFICATION: <exactly what is missing>`
   and stop. Do NOT invent names.

## The QaaS Constitution (non-negotiable — supersedes any task text)

1. **DOCS-OR-SILENCE.** Every QaaS field/type/flag/behavior you use must trace to
   a Fact Base slice (`FB §n`) or a docs path in your current context. Otherwise
   stop and ask. Never guess.
2. **DRIFT-AWARE.** Some doc pages are outdated vs the shipped packages. The 13
   traps below are LAB-verified truth. `template` output and `yamlView` pages win.
3. **EVIDENCE-BEFORE-DONE.** Nothing is "done" because you believe it is. A task
   is done only when its verification commands were freshly run and their real
   output (exit codes, bodies, log lines) matches the rubric. Run the build/test.
4. **ONE THING PER TASK.** Each task is one sentence and touches <=5 files. If it
   grows, emit `BLOCKED: needs split`.
5. **HOOKS BY THE RULES.** Custom hook config types are C# `record`s with
   DataAnnotations (`[Required]` on nullable props); `Configuration` is null in
   the constructor; probes are synchronous (no `Task.Run`); processors are
   stateless (shared instance, `static HttpClient`); generators `yield return`.
   Reference the right package: Generators->`QaaS.Common.Generators`,
   Assertions->`QaaS.Common.Assertions`, Processors->`QaaS.Common.Processors`;
   custom hooks need only `QaaS.Runner` / `QaaS.Mocker`.
6. **NO PLACEHOLDERS.** Emit complete final files. Never `TODO`, `TBD`, `...`,
   `<your-value-here>`.
7. **GUARDED ASSERTIONS.** Every HTTP/queue session needs a hermetic output-count
   guard (`HermeticByExpectedOutputCount` / `HermeticByInputOutputPercentage`)
   alongside any content/status assertion. `HttpStatus` passes VACUOUSLY on zero
   outputs.
8. **EXACT CONFIG KEYS.** Unknown keys in `*Configuration` blocks are silently
   ignored — a typo yields a confusing failure, not an error. Copy keys
   character-exact from the catalog page or a golden example.
9. **MOCKER ONLY ON DEMAND.** Author a mocker (`scaffold-mocker-project` /
   `author-mocker-yaml`) ONLY when the goal targets a service with no reachable
   real or stub endpoint. The default workflow is **runner-only**. When target
   reachability is unstated, emit `NEEDS_CLARIFICATION: real endpoint vs mock?`
   and stop. A `MOCK_REQUIRED: yes/no` decision must be declared in the pre-plan
   section before any mocker task is emitted.

**Uncertainty rule:** when in doubt whether a field, version, or feature exists,
run `validate-compatibility` before authoring any file. Never guess.

**Status line (last line of every response):**
`DONE` | `DONE_WITH_CONCERNS: <note>` | `BLOCKED: <reason>` | `NEEDS_CONTEXT: <what>` | `NEEDS_CLARIFICATION: <what>`

## The Doc-Drift Traps (USE THE RIGHT COLUMN)

> These are the most common. The full LAB-verified table is the offline Fact Base **§13
> (`s13-doc-drift.md`) — 19 entries** (incl. Docker base-image, Dockerfile inline-comment, and
> docker-compose internal-dependency-port traps). Read it via `/qaas:fact 13` when you need the rest.

| # | Topic | Docs say (OUTDATED) | Reality (USE THIS) |
|---|---|---|---|
| 1 | Mocker stub config key | `TransactionData:` | `ProcessorConfiguration:` |
| 2 | Runner Storages shape | `StorageConfiguration:{Type:Local,Path:..}` | `- FileSystem: {Path: ./session-data}` |
| 3 | Transactions data | implies optional | `DataSourceNames:` or `DataSourcePatterns:` is REQUIRED |
| 4 | HttpStatus assertion | `ExpectedStatus:` + `OutputName:` | `StatusCode:` + `OutputNames:` (list of strings) |
| 5 | HTTP Route | `Route: /hello` | `Route: hello` (leading slash -> `//hello` -> 404) |
| 5b | HTTP Route **case** | mixed-case e.g. `Route: testRoute` | routes must be ALL-LOWERCASE end-to-end — the mocker lowercases `Path` then builds a case-sensitive regex; the runner sends `Route:` verbatim, so any uppercase -> 404. Lowercase BOTH the mocker `Path:` and runner `Route:` |
| 6 | Missing output | — | Missing outputs crash assertion scans with null-reference errors |
| 7 | Mocker Dockerfile base | `mcr.microsoft.com/dotnet/runtime:10.0` | `mcr.microsoft.com/dotnet/aspnet:10.0` (mocker hosts HTTP) |
| 8 | Built-in hooks assembly | "they just work" | Need explicit NuGet refs: Generators->`QaaS.Common.Generators`, Assertions->`QaaS.Common.Assertions`, Processors->`QaaS.Common.Processors` |
| 9 | Versions (INDEPENDENT) | "2.0.0" / uniform | Runner `4.5.1`, Mocker `2.4.1`, Common.Assertions `3.5.1`, Common.Generators `3.5.1`, Common.Probes `1.5.1`, Common.Processors `1.5.1`, `.NET 10.0.203`. NOT a shared version — Runner's `4.5.1` on a `QaaS.Common.*` ref → `NU1102` |
| 10 | Controller boot log | `Controller channel ready: HelloMocker` | Real log: `Initialized Redis controller for server 'X'...` |
| 11 | Key typos | throws error | silently ignored — keys must be character-exact |
| 12 | Empty outputs | sessions fail | `HttpStatus` passes vacuously on zero outputs — always add a count-guard |
| 13 | Storages required | implies optional | Sessions that persist outputs need a `Storages:` block |

## The 15 task skills (these auto-load by name — do NOT call them as slash commands)

Claude Code loads the matching **skill** automatically from its description when the task fits.
You can also deliberately follow one by name. They are skills, not `/qaas:` commands. Only
`docs`, `fact`, `new-test`, `diagnose`, `verify` are slash commands.

- Plan a sprint → `plan-test-sprint`
- Scaffold projects → `scaffold-runner-project`, `scaffold-mocker-project`
- Author YAML → `author-runner-yaml`, `author-mocker-yaml`, `choose-action-type`,
  `pick-generator`, `pick-assertion`
- Custom C# hooks → `author-custom-hook`
- Run / diagnose → `run-and-collect`, `diagnose-failure`
- Container images → `build-mocker-image`
- Airgap packaging → `offline-packaging`
- Completion gate → `verify-done`
- Compatibility check → `validate-compatibility`

Each skill has a `contract.done_rubric` and `failure_modes`. Obey them.

## Working method for weaker models (question everything, contract-first)

1. **Restate** the goal in ONE sentence. If you cannot, ask.
2. **List assumptions** and number them. Any unverifiable assumption ->
   `NEEDS_CLARIFICATION`. Do not proceed on a guess.
3. **Write a tiny contract**: the exact files you will produce and the exact
   command(s) + expected exit code / output substring that prove each is correct.
4. **Pull facts**: read the needed Fact Base slices (always `s13`) and/or
   `/qaas:docs` pages BEFORE writing anything.
5. **Produce complete files** (no placeholders).
6. **Verify mechanically**: run the build/template/run commands; paste real
   output; compare to the contract. Only then claim done.
7. If verification fails, fix and re-run — do not narrate success without evidence.
