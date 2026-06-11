---
name: analyze-existing-tests
version: 1.0.0
description: Build a behavioral inventory of existing tests and a coverage-gap diff against the SUT surface catalog.
when_to_use: User provides paths to existing tests (QaaS YAML or other frameworks) and optionally sut-profile.md; you need to know what is already tested and what gaps remain.
inputs:
  - test_paths: paths to existing test files (*.qaas.yaml, *.mocker.yaml, or other framework tests)
  - sut_profile: path to qaas-analysis/sut-profile.md (output of analyze-sut-repo)
outputs:
  - test_inventory: qaas-analysis/test-inventory.md
  - coverage_gaps: qaas-analysis/coverage-gaps.md
fact_base_slices: [s00, s09, s10, s13, s16]
references: []
contract:
  done_rubric:
    - 'Every inventory row cites test file:line — uncited rows forbidden'
    - 'Each row contains all 6 fields: test_name, sut, inputs, mocked_deps, assertions, integration_surface'
    - 'Gap classification: every gap labelled create | repair | update'
    - 'coverage-gaps.md cross-references sut-profile.md surface catalog'
  failure_modes:
    - 'Inventory rows without file:line citations — constitutional violation'
    - 'Gap classification missing — gaps only labelled "missing" without create/repair/update'
    - 'sut-profile.md not read before gap analysis — gaps claimed without SUT baseline'
  escalation: 'NEEDS_CLARIFICATION: test paths not provided or sut-profile.md missing'
---

## When to use

Invoke after `analyze-sut-repo` when the user wants to understand existing test coverage.
Delegate all file reads to the `qaas-analyst` subagent (Article XII).

## Steps

### 1. Delegate to qaas-analyst

Invoke `qaas-analyst` with the test paths and sut-profile.md. It runs steps 2–4 and returns
structured summaries + COMPLETE artifact bodies. The analyst is read-only: YOU (the invoking
agent) write the bodies to `qaas-analysis/test-inventory.md` and `qaas-analysis/coverage-gaps.md`.

### 2. Build the behavioral inventory (per test)

For each test file, produce one inventory row:

```
{
  test_name:          "<name from YAML or test class>",
  sut:                "<component/endpoint being tested>",
  inputs:             "<data sources or message types>",
  mocked_deps:        "<mocker stubs or mock frameworks used>",
  assertions:         "<assertion types and expected outcomes>",
  integration_surface: "<protocol: HTTP/RabbitMQ/Kafka/gRPC, route/queue name>"
}
```

Every row MUST cite the source: `(file:line)`. Rows without citations are forbidden.

### 3. Diff inventory against SUT surface catalog

Read `sut-profile.md` `## Publish/consume points` and `## Protocols`.
For each SUT surface entry, check whether the inventory covers it.

Classify each gap as exactly one of:
- **create** — no test exists for this surface; a new test must be created
- **repair** — a test exists but it is broken (wrong assertions, wrong keys per s13)
- **update** — a test exists but it does not cover new SUT behavior

### 4. Output format

**qaas-analysis/test-inventory.md** — one table row per test with all 6 fields + citation.

**qaas-analysis/coverage-gaps.md** — sections:
```
## Create (new tests needed)
## Repair (existing tests need fixing)
## Update (existing tests need extension)
## Covered (surfaces with adequate tests)
```

Each gap entry: `- <surface> — <reason> (create/repair/update)`.

## Citations

- CONSTITUTION X (grounded sources — every row from file:line)
- CONSTITUTION XI (never fill gaps — unknown surfaces → numbered questions)
- CONSTITUTION XII (delegate to qaas-analyst)
- FB s09 (assertion catalog for identifying assertion gaps)
- FB s16 (hook discovery protocol)

## Traps

- **Skipping sut-profile.md** — gap analysis without SUT baseline produces invented gaps
- **Uncited inventory rows** — every row must have file:line; never infer from memory
- **Vague gap labels** — must be exactly create/repair/update, not "missing" or "incomplete"
- **Delegate inline reads** — multi-file test suites must be read in qaas-analyst context
