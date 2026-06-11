# QaaS Copilot Master Guide

This guide is for working on the plugin itself. The product is `plugins/qaas/`; install it through Claude Code and use the docs mirror pointed to by `QAAS_DOCS_URL`.

## Core commands

- `/qaas:docs <path>` — fetch live docs with curl
- `/qaas:fact <slice>` — read the offline Fact Base
- `/qaas:new-test <goal>` — plan and author a test
- `/qaas:diagnose <evidence>` — diagnose a failure
- `/qaas:verify` — fail-closed completion gate

## Rules

1. DOCS-OR-SILENCE — cite the Fact Base or docs before using any QaaS field, flag, version, or behavior.
2. DRIFT-AWARE — prefer the Fact Base drift table and `template` output over outdated docs.
3. EVIDENCE-BEFORE-DONE — do not claim success without a real build, template run, or live execution.
4. ONE THING PER TASK — keep changes surgical.
5. MOCKER ONLY ON DEMAND — default to runner-only unless the goal explicitly needs a mock.
6. VALIDATE COMPATIBILITY — use the compatibility skill before authoring any uncertain QaaS field or version.
7. GROUNDED-SOURCES ONLY — QaaS docs, the Fact Base, user-provided repos/files, and local command output. No web. `file:line` citations count from line 1 of that file.
8. NEVER-FILL-GAPS — every missing fact becomes a numbered question; fetch-before-ask (if a named docs page or FB slice has the fact, retrieve it first; ask the user only for facts no document answers).
9. DELEGATE ANALYSIS — repo/chart/test analysis runs in the read-only `qaas-analyst` subagent; the invoker writes the artifact.
10. VALIDATE-BEFORE-DELIVER — citation check, drift check, `template` oracle, live run (or explicit `DONE_WITH_CONCERNS`).

## Drift table

The authoritative drift table is `plugins/qaas/factbase/s13-doc-drift.md` with 19 entries. Use it before writing YAML, csproj, or Dockerfiles.

## Working method

- Restate the goal in one sentence.
- Ask blocking questions before planning.
- Decide runner-only vs mock-required first.
- Validate uncertain facts before writing.
- Run template/build/live execute before saying done.

## Notes

This repo is intentionally user-facing: it contains the plugin, the docs, and the install/run guidance. It does not include the maintainer evaluation harness.
