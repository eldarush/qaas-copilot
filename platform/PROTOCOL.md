# Platform Protocol v1.0

The machine contract between the harness, agents, and skills. Everything here is normative.

## 1. File-emission format (generator output)

The generator emits complete files using exact markers (weak-model friendly, no JSON escaping):

```
===FILE: Runner/test.qaas.yaml===
MetaData:
  Team: Smoke
  System: Demo
===END FILE===
```

- Path is relative to the sprint `artifacts/` directory. Forward or back slashes accepted.
- Content between the marker lines is written verbatim (UTF-8, no BOM).
- Multiple files per response allowed. Anything outside marker pairs is commentary (logged, not written).
- The LAST line of every generator response is a status code (see §2).

## 2. Status codes (last line of every agent response)

`DONE` | `DONE_WITH_CONCERNS: <note>` | `BLOCKED: <reason>` | `NEEDS_CONTEXT: <what>` |
`NEEDS_CLARIFICATION: <what>`

Harness behavior: `DONE`/`DONE_WITH_CONCERNS` → verify; `BLOCKED`/`NEEDS_CLARIFICATION` → halt task,
surface to human; `NEEDS_CONTEXT` → re-assemble with the named slice added (once), else halt.

## 3. sprint.json schema

```json
{
  "sprintId": "S01",
  "feature": "one-line feature name",
  "goalOneSentence": "...",
  "nonGoals": ["..."],
  "factBaseSlices": ["s02","s13","s14"],
  "tasks": [
    {
      "id": "T-001",
      "title": "Author hello.mocker.yaml",
      "priority": 1,
      "dependsOn": [],
      "skill": "author-mocker-yaml",
      "files": { "create": ["Mocker/hello.mocker.yaml"], "edit": [] },
      "description": "FULL self-contained task text pasted into the generator prompt.",
      "acceptanceCriteria": ["human-readable bullet per criterion"],
      "factBaseSlices": ["s03","s12","s13"],
      "docPages": [],
      "verify": [
        { "cwd": "Mocker", "cmd": "dotnet build -c Release", "expectExitCode": 0 },
        { "cmd": "curl.exe -s -w \"%{http_code}\" http://127.0.0.1:8080/hello",
          "expectOutputContains": "200" }
      ],
      "rubric": ["1-5 graded criteria for the evaluator (non-quantifiable parts only)"],
      "failureModes": ["known traps, cite FB §13#n"],
      "passes": false,
      "iterations": 0,
      "notes": ""
    }
  ]
}
```

Rules:
- `verify[]` is the MECHANICAL done-gate. Fields: `cwd` (relative to artifacts dir, optional),
  `cmd` (PowerShell command line), `expectExitCode` (int, optional), `expectOutputContains`
  (string, optional), `expectOutputNotContains` (string, optional), `timeoutSec` (default 300).
  All present expectations must hold for the step to pass.
- `passes` flips true ONLY via the harness after verify (+ evaluator when enabled) pass.
- A task at priority N must not depend on a task at priority > N.
- `description` is self-contained: the generator sees nothing else about the feature.

## 4. STATE.md format

```markdown
---
sprint: S01
feature: HTTP smoke test
status: planning|executing|verifying|done|paused|needs_human
current_task: T-002
tasks_total: 6
tasks_done: 1
last_activity: 2026-06-10T17:00:00Z
stopped_at: "free text: where exactly work stopped"
---
## Blockers
(none)
```

## 5. progress.txt format

```
## Codebase Patterns        <- injected at TOP of every generator context (keep <= 30 lines)
- PATTERN: Route values never start with '/' (FB s13#5)

## Task log                 <- append-only, NOT injected
[2026-06-10T17:02Z] T-001 PASS iter=1 — mocker yaml green; learned: ...
```

## 6. Evaluator verdict format (last fenced json block of evaluator response)

```json
{
  "verdict": "PASS|FAIL",
  "scores": { "correctness": 5, "driftAvoidance": 5, "citations": 4, "completeness": 5 },
  "findings": [
    { "severity": "blocker|major|minor", "file": "Mocker/hello.mocker.yaml",
      "issue": "...", "suggestedFix": "..." }
  ],
  "learnings": ["<= 3 bullets for progress.txt patterns"]
}
```
Verdict PASS requires: all mechanical verify steps passed AND no blocker findings AND all rubric
scores >= 4.

## 7. Context assembly order (generator)

1. `agents/generator.md` (persona)
2. `CONSTITUTION.md`
3. `## Codebase Patterns` section of `progress.txt`
4. STATE.md
5. The full task JSON (pretty-printed) + sprint `goalOneSentence` + `nonGoals`
6. Fact Base slices (task-level `factBaseSlices`, else sprint-level)
7. Doc pages listed in `docPages` (docs-mirror relative paths)
8. Feedback file `feedback/<taskId>-iter<N>.md` if present (evaluator findings from prior iteration)

Budget: total assembled context <= 120,000 chars (~30k tokens), leaving >= 95k tokens headroom.
`assemble-context.ps1` fails loudly if over budget — fix by narrowing slices, never by trimming
the CONSTITUTION or the task.

## 8. Skill format

```
platform/skills/<skill-name>/
├── SKILL.md          # <= 200 lines incl. frontmatter
└── references/       # optional, loaded on demand
```

SKILL.md frontmatter (YAML):

```yaml
---
name: author-mocker-yaml
version: 1.0.0
description: one sentence.
when_to_use: trigger conditions.
inputs: [named inputs]
outputs: [exact artifacts]
fact_base_slices: [s03, s12, s13, s14]
references: [references/x.md]
contract:
  done_rubric:
    - 'dotnet run -- template <cfg> => exit 0'
  failure_modes:
    - 'TransactionData instead of ProcessorConfiguration (FB s13#1)'
  escalation: 'NEEDS_CLARIFICATION: <field> | BLOCKED: <reason>'
---
```

Body sections in order: `## When to use`, `## Steps`, `## Citations`, optional `## Traps`.
Every QaaS claim carries `(FB sNN)` or `(docs/<path>)`. No uncited claims.
