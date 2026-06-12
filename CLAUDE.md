# QaaS Claude Code Master Guide

This guide governs all interactions within this workspace when using **Claude Code**. It ensures 100% correct, docs-grounded, and airgap-compliant QaaS test development.

> **The product is the `qaas` plugin** under `plugins/qaas/` (skills, subagents, slash
> commands, offline Fact Base). End users install it via the marketplace — see
> [INSTALL.md](./INSTALL.md). This `CLAUDE.md` mirrors the always-on `qaas-overview` skill, so
> opening this repo in Claude Code gives the same guidance the plugin injects.

---

## 1. Core Commands

When the `qaas` plugin is installed, use its native slash commands (no PowerShell, curl-based):

* **Fetch live QaaS docs (airgap-safe curl, not WebFetch)**: `/qaas:docs <path>`
  (e.g. `/qaas:docs runner/configuration`, `/qaas:docs llms.txt`). Honors `$QAAS_DOCS_URL`.
* **Read the offline Fact Base**: `/qaas:fact <slice>` (e.g. `/qaas:fact s13` for drift traps).
* **Author a test end-to-end**: `/qaas:new-test <goal>`.
* **Diagnose a failing run**: `/qaas:diagnose <evidence>`.
* **Completion gate**: `/qaas:verify`.
* **Build / run locally**: `dotnet build`, `dotnet test`.

The single configuration knob for any environment is **`QAAS_DOCS_URL`** (default
`https://docs.qaas.online`); point it at your local mirror in airgapped setups.

---

## 2. QaaS Test-Authoring Constitution

Every code change or test written must adhere to these non-negotiable articles:

1. **DOCS-OR-SILENCE (NON-NEGOTIABLE)**: Every QaaS field, type, flag, or behavior you use must be explicitly backed by the offline Fact Base (`/qaas:fact sNN`, bundled in `plugins/qaas/factbase/`) or retrieved live via `/qaas:docs`. If it is not in front of you, stop and ask the user. Never guess names, signatures, or defaults.
2. **DRIFT-AWARE**: The official docs are outdated in several places. Refer to the **Doc Drift Table** below to avoid common traps.
3. **EVIDENCE-BEFORE-DONE**: A task is never done because you believe it is. Verification is strictly empirical: execute build/test commands and match real output against the sprint rubric.
4. **ONE THING PER TASK**: Keep scope surgical. If a task spans >5 files or cannot be stated in one sentence, split it.
5. **HOOKS BY THE RULES**: Custom hook C# records require explicit `[Required]` DataAnnotations. The constructor must allow `Configuration = null`. Probes must be synchronous (no `Task.Run`). Processors must be stateless.
6. **NO PLACEHOLDERS**: Always emit complete, final files. Never use `TODO`, `TBD`, `...`, or placeholder strings like `<value>`.
7. **GUARDED ASSERTIONS**: Every HTTP or message session assertion must carry a hermetic output-count guard (`HermeticByExpectedOutputCount` or `HermeticByInputOutputPercentage`) alongside standard content checks. `HttpStatus` passes vacuously if zero outputs arrive!
8. **EXACT CONFIG KEYS**: Typos in `*Configuration` blocks are silently ignored by the scanner. Copy keys character-exact from reference catalog files.
9. **MOCKER ONLY ON DEMAND**: Author a mocker only when the goal targets a service with no reachable real or stub endpoint. Default is runner-only. When target reachability is unstated, emit `NEEDS_CLARIFICATION: real endpoint vs mock?`. Analysis output MUST state whether a real endpoint is reachable; mocker is authorized only when no real endpoint is reachable.
10. **GROUNDED-SOURCES ONLY**: Allowed sources are QaaS docs (via `/qaas:docs` or the offline Fact Base), user-provided repos/files on disk, and command output from the user's machine. NO web search. NO memory of QaaS internals — the runtime has QaaS docs + ready NuGets ONLY; no QaaS source code, no internet. Assume your own beliefs about QaaS are wrong until confirmed by docs/FB.
11. **NEVER-FILL-GAPS**: Any missing fact becomes a numbered question. Silence is never consent. Never guess to keep momentum. Prefer asking over proceeding. Every unknown emits `NEEDS_CLARIFICATION: <what>` and stops that step.
12. **DELEGATE-TO-SUBAGENTS**: Repo/chart/test analysis runs in subagent context (`qaas-analyst`) returning a structured summary. Large file reads stay out of main context. Do not read multi-file repos inline — delegate.
13. **VALIDATE-BEFORE-DELIVER**: Before any final artifact, run the quadruple check: (1) citation check — every QaaS field traces to docs/FB; (2) drift check — verify against s13; (3) template/build oracle; (4) live run OR explicit `DONE_WITH_CONCERNS`.

---

## 3. Doc-Drift & Outdated Docs Reference (Top Traps)

> The complete, authoritative drift table lives in the Fact Base, **§13 (`plugins/qaas/factbase/s13-doc-drift.md`) — 29 LAB-verified entries**. The most common ones are reproduced here.

Use this table as your source of truth when writing configurations:

| # | Topic | Docs say (OUTDATED) | Reality (USE THIS) |
|---|---|---|---|
| **1** | Mocker stub config key | `TransactionData:` | **`ProcessorConfiguration:`** |
| **2** | Runner Storages shape | `StorageConfiguration:{Type:Local,Path:..}` | **`- FileSystem: {Path: ./session-data}`** |
| **3** | Transactions data | implies optional | **`DataSourceNames:` or `DataSourcePatterns:` is REQUIRED** |
| **4** | HttpStatus assertion | `ExpectedStatus:` + `OutputName:` | **`StatusCode:` + `OutputNames:` (list of strings)** |
| **5** | HTTP Route | `Route: /hello` | **`Route: hello`** (leading slash → `//hello` → 404) |
| **5b** | HTTP Route **case** | mixed-case routes e.g. `Route: testRoute` | **routes must be ALL-LOWERCASE end-to-end** — the mocker lowercases `Path` then builds a case-sensitive regex (no `IgnoreCase`); the runner sends `Route:` verbatim, so any uppercase → 404 → `HttpStatus` fails. Lowercase BOTH the mocker `Path:` and runner `Route:`. |
| **6** | Missing output | — | Missing outputs crash assertion scans with null reference exceptions. |
| **7** | Mocker Dockerfile base | `mcr.microsoft.com/dotnet/runtime:10.0` | **`mcr.microsoft.com/dotnet/aspnet:10.0`** (since mocker hosts HTTP) |
| **8** | Built-in hooks assembly | implies they just work | Requires explicit NuGet references: Generators→`QaaS.Common.Generators`, Assertions→`QaaS.Common.Assertions`, Processors→`QaaS.Common.Processors`. |
| **9** | Current Versions (INDEPENDENT per package) | "2.0.0" | **Runner 4.5.1 / Mocker 2.4.1 / Common.Assertions 3.5.1 / Common.Generators 3.5.1 / Common.Probes 1.5.1 / Common.Processors 1.5.1**, `.NET 10.0.203`. They are NOT one shared version — putting `4.5.1` on a `QaaS.Common.*` ref → `NU1102 Unable to find package`. |
| **10** | Controller boot log | `Controller channel ready: HelloMocker` | Real log contains: `Initialized Redis controller for server 'X'...` |
| **11** | Key Typos | throws error on typo | Typo keys are **silently ignored**; ensure keys are character-exact. |
| **12** | Empty Outputs | empty sessions fail | **HttpStatus passes vacuously** on zero outputs; always add count-guards. |

---

## 4. QaaS Skills Integration (19 Task Guides)

When the plugin is installed, these 19 task skills auto-load by description — Claude Code invokes
the right one for the task. They live under `plugins/qaas/skills/<name>/SKILL.md`. Each carries
an execution blueprint, done-rubric, and failure-mode checklist:

1. **`plan-test-sprint`**: Map out goal to priority-ordered `sprint.json`.
2. **`scaffold-runner-project`**: Scaffolds Runner `.csproj` + NuGet configurations.
3. **`scaffold-mocker-project`**: Scaffolds Mocker `.csproj` with ASP.NET base.
4. **`author-runner-yaml`**: Formulates `*.qaas.yaml` (sessions, asserts, storage).
5. **`author-mocker-yaml`**: Formulates `*.mocker.yaml` (servers, stubs, processors).
6. **`choose-action-type`**: Maps intent to Transaction/Publisher/Consumer/Probe.
7. **`pick-generator`**: Selection and layout of the 11 built-in generators.
8. **`pick-assertion`**: Selection and layout of the 11 built-in assertions.
9. **`author-custom-hook`**: Template structures for compilation-ready C# hooks.
10. **`run-and-collect`**: CLI flags, Allure output collection, and execution.
11. **`diagnose-failure`**: Error signatures and quick-fix mapping index.
12. **`build-mocker-image`**: Custom Docker multi-stage mocker images.
13. **`offline-packaging`**: Securing private Artifactory routing and NuGet configurations.
14. **`verify-done`**: Unified fail-closed completion checklist before task completion.
15. **`validate-compatibility`**: Validate every QaaS field/version against Fact Base; reject deprecated drift-left-column forms and non-existent features.
16. **`analyze-sut-repo`**: Extract endpoints, schemas, env config, and transformation contracts from SUT source repos with file:line citations.
17. **`analyze-helm-k8s`**: Derive effective runtime config from Helm charts / K8s manifests using full values-layer resolution.
18. **`analyze-existing-tests`**: Inventory existing tests and produce a coverage-gap diff (create/repair/update) against the SUT surface catalog.
19. **`document-test-project`**: Produce a structured README for a finished QaaS test project.

---

## 5. Coding Style & Best Practices

* **Zero Placeholders**: Do not shorten code block replacements with comments or placeholders. Write full blocks.
* **C# Records**: Custom configuration types should use immutable records with required properties.
* **Hermetic Runs**: Use unique port mappings and dynamic ports to prevent execution conflicts.
* **Deterministic Tests**: Add delay offsets or check-retry mechanisms for async messaging tests rather than simple Sleep statements.

