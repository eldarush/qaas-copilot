# G01 — plan-http-smoke (planning)

**Complex system simulated:** A new team onboarding to QaaS asks for the canonical first test:
HTTP smoke against an internal *quotes* service. The planner must turn the goal into a
machine-executable sprint plan — without writing any YAML itself.

**Weak-model job:** use the `plan-test-sprint` skill to emit `planned/sprint.json` with 3 tasks
(scaffold → author YAML → run e2e), canonical priorities, self-contained descriptions, mechanical
verify gates, and FB s13 trap citations in failureModes.

- Category: planning
- Infra: none
- Live gate: `eval\infra\validate-sprint.ps1` — structural PROTOCOL §3 validation (exit 0)
- Judged on: dependency sanity, self-containedness, verify[] mechanics, drift-trap awareness
