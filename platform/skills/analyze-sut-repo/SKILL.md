---
name: analyze-sut-repo
version: 1.0.0
description: Extract test-relevant facts from a user-provided SUT source repository; produce a structured sut-profile.md with file:line citations.
when_to_use: User provides a path to a SUT source repository; you need to identify protocols, endpoints, message schemas, env config, and transformation contracts before planning tests.
inputs:
  - repo_paths: one or more local paths to SUT source repositories
outputs:
  - sut_profile: qaas-analysis/sut-profile.md
fact_base_slices: [s00, s13, s16]
references: []
contract:
  done_rubric:
    - 'Every fact in sut-profile.md carries a file:line citation — uncited facts forbidden'
    - 'Output artifact written to qaas-analysis/sut-profile.md with all required sections'
    - 'Reachability statement present (Article IX): whether a real endpoint is reachable'
    - 'Open questions numbered — no invented values for unknowns'
  failure_modes:
    - 'Asserting a route/schema/env-var without a file:line citation — constitutional violation'
    - 'Inventing transformation contracts without reading handler code'
    - 'Claiming a protocol is absent without running the grep checklist'
  escalation: 'NEEDS_CLARIFICATION: repo path not provided or not readable'
---

## When to use

Invoke before `plan-test-sprint` when the user provides SUT source paths. Delegate all
file reads to the `qaas-analyst` subagent (DELEGATE-TO-SUBAGENTS, Article XII). Do NOT
read multi-file repos inline in the main context.

## Steps

### 1. Delegate to qaas-analyst

Invoke `qaas-analyst` with the repo paths. It runs the staged exploration below and returns
a structured summary + the COMPLETE artifact body. The analyst is read-only: YOU (the
invoking agent) write the returned body to `qaas-analysis/sut-profile.md` verbatim.

### 2. Staged exploration (run in qaas-analyst context)

Run in order — each stage builds on the previous:

1. **Entrypoints** — find project files, startup classes, `Program.cs`, `Startup.cs`
2. **Routes/endpoints** — run the grep checklist below
3. **Handlers** — read the handler method bodies for each discovered route
4. **Schemas/DTOs** — find request/response models; record field names and types
5. **Env config** — find all environment variable reads (grep checklist below)
6. **Transformation contracts** — for each handler, document input→output mapping
7. **Logs/metrics** — find structured log calls and metric emitter calls

### 3. Multi-language grep checklist

Run these greps from the repo root. Each match → record `file:line`:

**ASP.NET / .NET:**
```bash
grep -rn "\[Route\]\|\[HttpGet\]\|\[HttpPost\]\|MapGet\|MapPost\|MapControllers" --include="*.cs"
grep -rn "ReceiveEndpoint\|Publish<\|AddConsumer<" --include="*.cs"
grep -rn "QueueDeclare\|BasicPublish\|BasicConsume" --include="*.cs"
grep -rn "GetEnvironmentVariable\|IConfiguration\[" --include="*.cs"
grep -rn "\.proto\|MapGrpcService" --include="*.cs" --include="*.proto"
```

**Spring / Java / Kotlin:**
```bash
grep -rn "@KafkaListener\|KafkaTemplate\|@RequestMapping\|@GetMapping\|@PostMapping"
grep -rn "os\.environ\|process\.env" --include="*.py" --include="*.js" --include="*.ts"
```

### 4. Output format — qaas-analysis/sut-profile.md

Write the artifact with these exact sections:

```
## Protocols
## Message schemas/DTOs
## Env config
## Publish/consume points
## Transformation contracts
## Logs/metrics
## Open questions
```

Every fact line: `- <finding> (file:line)`. Unknowns: numbered `Open questions`.

**Line-number discipline**: a citation's line number counts from line 1 OF THAT SOURCE FILE —
never from your prompt/context document. Sanity-check every number against the file's total
length (a 50-line Program.cs cannot have a `:641` citation). When you cannot re-open the file
to count, cite the file WITHOUT a line number rather than guessing one.

**Mandatory reachability statement** (Article IX): conclude with one of:
- `REACHABILITY: real endpoint reachable at <address>` — runner-only plan
- `REACHABILITY: no reachable endpoint found — MOCK_REQUIRED: yes`

## Citations

- CONSTITUTION IX (mocker restraint — reachability statement mandatory)
- CONSTITUTION X (grounded sources — every fact from file:line)
- CONSTITUTION XI (never fill gaps — unknowns → numbered questions)
- CONSTITUTION XII (delegate to qaas-analyst for file reads)
- FB s16 (hook discovery protocol)

## Traps

- **Uncited facts** — any claim without `file:line` is a constitutional violation
- **Context-relative line numbers** — citing the position in your prompt instead of the
  source file (impossible numbers like `Program.cs:641` for a 50-line file) = fabrication
- **Invented transformation contracts** — read the handler body; do not assume
- **Missing grep steps** — run ALL checklist items; absence only valid after running
- **Inline repo reads** — delegate to `qaas-analyst`; keep main context clean
