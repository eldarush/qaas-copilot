---
description: Run the fail-closed QaaS completion gate — execute every verify step and emit a PASS/FAIL verdict with evidence.
argument-hint: "[optional: path to the runner project or sprint task]"
---
Run the QaaS completion gate for: ${ARGUMENTS:-the current task}.

Use the `verify-done` skill. This is mechanical — belief is not evidence.

1. Collect the task's `verify[]` steps (or the standard gate: `dotnet build -c
   Release`, `dotnet run -- template <file>`, then the live run).
2. Execute EACH step now. Capture the real exit code and the real stdout/stderr.
3. For each step, compare against its expectation (`expectExitCode` and/or
   `expectOutputContains`). Mark PASS/FAIL with the actual evidence quoted.
4. Confirm the anti-vacuous guard: the run produced the expected NUMBER of outputs
   (a `HermeticByExpectedOutputCount` / `HermeticByInputOutputPercentage` guard
   is present and satisfied). A green `HttpStatus` with zero outputs is a FAIL.
5. Emit a final verdict JSON: `{ "verdict": "PASS"|"FAIL", "steps": [...], "notes": "..." }`
   then a status line. If any step was not actually executed, the verdict is FAIL.
