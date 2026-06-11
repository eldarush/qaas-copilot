---
description: Diagnose a failing QaaS test from its exit code, allure results, and logs using the error-signature table.
argument-hint: "<paste the exit code / error text, or the path to allure-results>"
---
A QaaS test is failing. Evidence from the user:

> $ARGUMENTS

Use the `diagnose-failure` skill and the QaaS Fact Base. Do not speculate beyond
the evidence.

1. Read the error-signature table: `/qaas:fact s07` (artifacts & diagnosis) and
   `/qaas:fact s13` (doc-drift traps — the most common root causes).
2. Map the exact symptom (exit code, `broken` vs `failed` assertion, null-reference
   on a missing output, FTL config-invalid, `not found in` package errors) to its
   cause in the table.
3. State the single most-likely root cause and cite the Fact Base row that backs
   it. If the evidence is insufficient, say exactly which artifact you need
   (e.g. `allure-results/*-result.json`, the runner stdout, the mocker boot log).
4. Give the precise fix (exact key/line to change), then the command to re-run and
   the expected output that will prove the fix worked.
5. Do not claim it is fixed until a fresh run is shown green. End with a status line.
