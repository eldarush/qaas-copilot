## 6. TASK: CLI usage (verbs, flags, exit codes) (02, [LAB] L2)

Pattern: `dotnet run <dotnet-params> -- <verb> [config] [flags]`. Verbs: **run / act / assert /
execute / template**.

| Verb | Purpose | Results flags (`-e`,`-s`)? |
|---|---|---|
| `run` | sessions + assertions end-to-end | yes |
| `act` | run sessions, persist SessionData, **no** assertions | no |
| `assert` | replay assertions on stored SessionData (no protocol calls) | yes |
| `execute` | run a YAML list of commands sequentially | yes (`--empty-allure-directory`) |
| `template` | print fully-resolved config (defaults+merges); **schema oracle** | no |

Default config positional = `test.qaas.yaml` (`execute` default `executable.yaml`).

### Flags (run; act/assert/template inherit except results flags) (02)
Selection: `--assertion-categories`, `-a/--assertion-names`, `-c/--cases <folder>`,
`--cases-name-patterns-ignore`, `-n/--cases-names`, `--cases-names-ignore`, `--session-categories`,
`-i/--session-names`.
Config: `-w/--with-files` (in order), `-f/--with-folders` (alpha then folder order),
`-r/--overwrite-arguments Path:To:Key=Value`, `-p/--push-references KeyWord Ref.yaml [overrides]`
(KeyWord must NOT end .yml/.yaml), `--resolve-cases-last`(false), `--no-env`(false).
Results: `-e/--empty-results-directory`, `-s/--serve-results [dir]` (bare→`allure-results`; value
e.g. `allure-report`→that dir; needs Allure CLI in PATH).
Logging: `-l/--logger-level` (Verbose|Debug|Information(default)|Warning|Error|Fatal),
`-g/--logger-configuration-file`, `--send-logs`, `--elastic-uri/username/password`,
`--disable-elastic-defaults`. Runtime: `--no-process-exit`.

`execute` file: `Commands:[{Command: "run test.qaas.yaml", Id: smoke, Parallel: false}]`; select with
`-c/--command-ids-to-run`.

### Exit codes ([LAB] L1/L2, 02)
- `0` — help/version, successful `act`/`template`, or run where **every** assertion passed.
- `1` — CLI parse failure, **invalid configuration** (`FTL Runner execution configuration is invalid`
  + numbered issues with YAML paths; no test runs), or ≥1 failed assertion.
- `>1` — `execute` sums child exit codes across multiple failing executions.
- `-532462766` — DI crash after a **missing hook** FTL. [LAB]
- Parallelism: no CLI flag; configure in YAML `Parallel:{Parallelism:N}` or `PublisherBuilder
  .WithParallelism(int)`.

### No-leading-slash / two-phase pattern
```bash
dotnet run -- act test.qaas.yaml      # capture once → session-data/<Session>.json
dotnet run -- assert test.qaas.yaml   # iterate assertions offline (mocker can be stopped) [LAB L3]
```

---

