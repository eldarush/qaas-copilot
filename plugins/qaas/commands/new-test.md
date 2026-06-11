---
description: Drive a full QaaS test from a one-sentence goal — plan, scaffold, author YAML, run, and verify with evidence.
argument-hint: "<one-sentence testing goal>  e.g. test the payment-status GET endpoint returns 200 with a body"
---
The user wants a new QaaS test for this goal:

> $ARGUMENTS

Follow the QaaS Constitution and the contract-first method. Do NOT write any file
until you have pulled the facts you need.

1. **Ask ALL blocking questions as a numbered list** before taking any other action.
   Do not proceed until answered (or the user explicitly accepts the conservative
   defaults for each item):
   1. Protocol — HTTP / RabbitMQ / Kafka / gRPC?
   2. Target endpoint / route — exact URL path or queue name?
   3. Is a local mock required, or is there a real/stub endpoint reachable?
      (`MOCK_REQUIRED: yes/no` — see MOCKER ONLY ON DEMAND constitutional article)
   4. Expected HTTP status code and/or response body / message content?
   5. Expected number of outputs the session must produce?
   6. Any async timing / polling delay needed?
   If any answer is missing, emit `NEEDS_CLARIFICATION: <item>` and stop.

1.5. **Mock decision** — Based on the answer to question 3 above, set
   `MOCK_REQUIRED: yes/no`. If `no` (runner-only default), skip all mocker steps
   (scaffold-mocker-project, author-mocker-yaml) in the plan below. Do not scaffold
   a mocker without an explicit "yes" from the user.

2. **Plan** with the `plan-test-sprint` skill: produce a numbered task list whose
   canonical order is scaffold -> runner YAML -> datasources -> sessions ->
   assertions -> run/verify (add mocker steps only if MOCK_REQUIRED: yes). State,
   per task, the exact verify command and its expected exit code / output substring
   (the done-contract).
3. **Pull facts** before writing: read Fact Base `s13` (always) plus the slices
   for the task at hand (`/qaas:fact s02` runner, `/qaas:fact s03` mocker,
   `/qaas:fact s09` assertions, `/qaas:fact s04` hooks). Fetch live docs with
   `/qaas:docs` only when a detail is missing.
4. **Implement** each task with the matching skill (`scaffold-runner-project`,
   `scaffold-mocker-project`, `author-runner-yaml`, `author-mocker-yaml`,
   `pick-assertion`, `pick-generator`, `author-custom-hook`). Emit complete files
   — no placeholders. Apply the drift table and the hermetic count-guard rule.
5. **Run & verify** with `run-and-collect`: actually execute `dotnet build`, the
   `template` verb, and the live run. Paste the real exit codes and output.
6. **Gate** with the `verify-done` skill before claiming success. End with a
   status line. If anything is unproven, say `DONE_WITH_CONCERNS:` and list what
   still needs a live run — never claim a green you did not observe.
