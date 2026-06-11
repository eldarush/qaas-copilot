---
name: plan-test-sprint
version: 1.0.0
description: Decompose a user testing goal into a validated sprint.json with priority-ordered, mechanically-verifiable tasks.
when_to_use: User describes a system to test (e.g. "test service X consuming from RabbitMQ exchange A and calling REST API B"); produce sprint.json for the harness loop.
inputs:
  - user_goal: one-sentence description of what must be tested
  - protocols: list of protocols involved (HTTP, RabbitMQ, Kafka, etc.)
  - analysis_artifacts: optional paths to qaas-analysis/sut-profile.md, qaas-analysis/runtime-config.md, qaas-analysis/coverage-gaps.md
outputs:
  - sprint.json
fact_base_slices: [s00, s01, s02, s06, s09, s10, s13, s14]
references: []
contract:
  done_rubric:
    - 'Every task has verify[] with >=1 entry containing expectExitCode or expectOutputContains'
    - 'Priority N task depends only on tasks with priority < N'
    - 'goalOneSentence is exactly one sentence'
    - 'Canonical dep order obeyed: scaffold(1) -> yaml(2) -> run/verify(3)'
    - 'MOCK_REQUIRED: yes/no declared before tasks; no mocker tasks when no'
  failure_modes:
    - 'Task description is a file reference, not self-contained text (PROTOCOL §3)'
    - 'verify[] entries missing expectExitCode AND expectOutputContains — harness cannot gate'
    - 'Priority inversion: T-003 at priority 2 depends on T-004 at priority 3'
    - 'goalOneSentence is multiple sentences'
    - 'failureModes do not cite FB s13 rows'
  escalation: 'NEEDS_CLARIFICATION: protocol list unknown | BLOCKED: goal spans >5 files per task'
---

## When to use

Call this skill when a user provides a testing goal and you must produce a `sprint.json` for
`loop.ps1`. This skill **only plans** — no code/YAML is written here.
Emit `NEEDS_CLARIFICATION: goal is ambiguous` if the goal cannot be stated in one sentence.

## Steps

### 0. Consume analysis artifacts (when available)

When `sut-profile.md`, `runtime-config.md`, or `coverage-gaps.md` are provided:
- Read them to extract protocols, endpoints, env config, and gap classifications
- Use them as planning inputs; cite artifact path:line in task descriptions
- Only ask residual questions that the artifacts do not answer

### 1. State the goal in one sentence

Record as `goalOneSentence`. Extract: (a) system-under-test, (b) protocol(s), (c) observable outcomes.

### 1b. Declare MOCK_REQUIRED (Article 9 — mocker only on demand)

Before mapping tasks, declare `MOCK_REQUIRED: yes/no` in the plan preamble. Default is **no**
(runner-only): the runner calls a real reachable SUT directly. Only `yes` when a dependency the
SUT calls must be simulated, or no real endpoint is reachable from the test host. If
reachability is unknown, emit `NEEDS_CLARIFICATION: is a real endpoint reachable, or must we mock?`
— never assume. When `MOCK_REQUIRED: no`, the sprint contains NO mocker tasks (no
scaffold-mocker-project, no author-mocker-yaml).

### 2. Map protocols → session types (FB s02)

| Protocol / intent | Session type | Skill |
|---|---|---|
| HTTP call to SUT or mocker | Transaction (Http) | author-runner-yaml |
| Produce to message broker | Publisher | author-runner-yaml |
| Consume from broker/table | Consumer | author-runner-yaml |
| Verify HTTP response status | Assertion: HttpStatus + hermetic guard | author-runner-yaml |
| Setup/teardown infra (queues, buckets) | Probe | author-runner-yaml |
| Mock HTTP/gRPC server needed | Mocker YAML | author-mocker-yaml |

### 3. Canonical dependency order (PROTOCOL §3)

1. **Scaffold** — runner csproj + mocker csproj
2. **Author custom hooks** (only if needed) — `.cs` classes
3. **Author YAML** — runner YAML + mocker YAML
4. **Run/Verify** — `dotnet run -- run`

### 3b. Custom hooks check

Built-in hook names: Generators (s10), Assertions (s09), Processors (s12), Probes (s11).
Any other name is a custom hook — add `author-custom-hook` at priority 2.

### 4. Author each task object

Every task MUST have: `id`, `title` (gerund, ≤8 words), `priority`, `dependsOn`, `skill`,
`files.create/edit`, `description` (fully self-contained, no "see T-001"), `acceptanceCriteria`,
`factBaseSlices`, `verify[]` (each with `cmd` + `expectExitCode` or `expectOutputContains`),
`failureModes` (cite FB s13#N), `rubric`, `passes: false`, `iterations: 0`, `notes: ""`.

### 4b. Verify-command traps

- Never start `cmd` with `#` — comments silently exit 0 in PowerShell
- Live run needs mocker in ONE cmd (start + wait-port + run + stop)
- PORT CONTRACT: probe port == mocker `Servers.Http.Port` == runner `Http.Port` (one literal, FB s13#16)

### 5. Validate before emitting

- `goalOneSentence` is exactly one sentence
- Every task has ≥1 `verify[]` entry with a mechanical expectation
- No task at priority N depends on task at priority ≥ N
- `failureModes` cite FB s13 rows where applicable
- No raw `"` inside description/cmd strings

## Citations

- PROTOCOL §3 (sprint.json schema, verify[] rules, priority constraint)
- FB s00 (mental model), FB s02 (session types), FB s06 (CLI exit codes)
- FB s13 (drift traps — cite row numbers in failureModes)
- FB s14.1–s14.2 (golden examples as verify baselines)

## Traps

- **Priority inversion** — harness deadlocks if a task depends on one with higher priority number
- **description references another task** — generator context is isolated; must be self-contained
- **verify[] prose only** — must have `cmd` + mechanical expectation
- **goal is two sentences** — rewrite with semicolon or demote second part to `nonGoals`
