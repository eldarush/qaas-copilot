# D03 — route-leading-slash (diagnose)

**Complex system simulated:** An *orders status* service test suite written by a departed
teammate suddenly "stopped working" (it never worked). The suite times out: the runner gets 404s
from the mocker, the HttpStatus assertion goes broken/failed. Root cause is the classic doc-drift
bug — `Route: /status` (leading slash) in the runner YAML produces `//status` → 404 (FB s13#5).

**Weak-model job (single task):** run the seeded suite, read the failure evidence, diagnose the
root cause, apply the minimal fix (`Route: status`), write `DIAGNOSIS.md` citing the fact-base
row, and prove the suite green end-to-end against the real seeded mocker on port 8093.

- Category: diagnose
- Infra: none (mocker is part of the seed; verify step runs it live)
- Seed: complete Runner/ + Mocker/ pair, runner YAML deliberately broken
- Live gates: e2e run exit 0 after fix; DIAGNOSIS.md cites s13#5; fix is minimal (Route only)
