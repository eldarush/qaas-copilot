---
name: document-test-project
version: 1.0.0
description: Produce a structured README.md for a finished QaaS test project so others understand what is tested and how to run it.
when_to_use: A QaaS test project (runner YAML + optional mocker YAML + csproj) is complete; user wants a README for the project.
inputs:
  - project_dir: path to the finished test project directory
  - sut_profile: optional path to qaas-analysis/sut-profile.md (for topology section)
outputs:
  - readme: <project_dir>/README.md
fact_base_slices: [s00, s02, s06, s07, s13]
references: []
contract:
  done_rubric:
    - 'README contains all 6 required sections with correct headings'
    - 'How-to-run section uses exact dotnet run -- run <file>.qaas.yaml command'
    - 'Every QaaS field name in README cites docs/FB — no invented commands or flags'
    - 'Troubleshooting section points to /qaas:diagnose and FB s07'
  failure_modes:
    - 'Invented CLI flags not in FB s06 — constitutional violation'
    - 'Missing hermetic-guard explanation in Assertions section'
    - 'Topology section describes components not in sut-profile.md or YAML — uncited claim'
  escalation: 'NEEDS_CLARIFICATION: project directory not provided or YAML files not found'
---

## When to use

Call after all test YAML and C# hooks are authored and verified green. Read the project
YAML files to produce an accurate README — do not invent content.

## Steps

### 1. Read the project files

Read all `*.qaas.yaml` and `*.mocker.yaml` files in the project. If `sut-profile.md` is
available, read its `## Protocols` and `## Topology` sections.

### 2. Produce README.md with these exact sections

#### `## What is tested`

One paragraph: the SUT component(s), protocol(s), and observable behavior the tests verify.
Every claim cites the YAML or sut-profile.md.

#### `## Topology`

Mermaid diagram (when relationships are clear) or a bullet list of components.
Example:

```mermaid
graph LR
  Runner -->|HTTP GET /api/order| SUT
  SUT -->|publishes| RabbitMQ
  Runner -->|consumes| RabbitMQ
```

#### `## How to run`

Exact commands (FB s06):

```bash
# Build
dotnet build -c Release

# Verify YAML template
dotnet run -- template <file>.qaas.yaml

# Live run (start mocker first if MOCK_REQUIRED: yes)
dotnet run -- run <file>.qaas.yaml
```

#### `## Data sources`

Table of data source names, generator types, and file paths. Cite YAML line for each.

#### `## Assertions`

Table: `| Assertion name | Type | What it verifies |`. Note the hermetic guard present
(FB s13#13 — HttpStatus passes vacuously without it).

#### `## Troubleshooting`

- Run `/qaas:diagnose <evidence>` with the failing run output.
- Read FB s07 for the error-signature triage table and allure artifact layout.
- Common issues: missing PackageReference (FB s13#8), wrong Route (FB s13#5),
  vacuous pass (FB s13#13).

### 3. Validate before emitting

- Every CLI command matches FB s06 (no invented verbs or flags)
- Every QaaS field name has a `(FB sNN)` or `(docs/...)` citation
- No `TODO` or placeholder content

## Citations

- FB s06 (CLI verbs: build, template, run, act, assert)
- FB s07 (diagnosis artifacts, error table)
- FB s02 (runner YAML structure, session types)
- FB s13#8, s13#13 (PackageReference, vacuous pass)

## Traps

- **Invented CLI flags** — only use verbs/flags documented in FB s06
- **Missing ## Troubleshooting** — required section; point to `/qaas:diagnose` and FB s07
- **Mermaid without basis** — only draw topology if sut-profile.md or YAML provides the data
- **Uncited field names** — every `*.Configuration` key in the README needs a FB/docs cite
