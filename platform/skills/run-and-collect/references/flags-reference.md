# Flags Reference (FB s06)

Full CLI flag list for `dotnet run -- <verb> [config] [flags]`.

## Selection flags
| Flag | Description |
|---|---|
| `--assertion-categories` | filter assertions by category |
| `-a / --assertion-names <names>` | filter assertions by name |
| `-c / --cases <folder>` | one execution per case file in folder |
| `--cases-name-patterns-ignore` | ignore case name patterns |
| `-n / --cases-names <names>` | filter by case name |
| `--cases-names-ignore` | ignore specific case names |
| `--session-categories` | filter sessions by category |
| `-i / --session-names <names>` | filter sessions by name |

## Config merge flags
| Flag | Description |
|---|---|
| `-w / --with-files <file>` | merge overwrite YAML file (applied in order) |
| `-f / --with-folders <folder>` | merge all YAMLs in folder (alpha then folder order) |
| `-r / --overwrite-arguments Path:To:Key=Value` | inline override |
| `-p / --push-references KW Ref.yaml [overrides]` | push reference (KW must NOT end `.yml`/`.yaml`) |
| `--resolve-cases-last` | default false |
| `--no-env` | default false; disable env-var substitution |

## Results flags (run/assert/execute only)
| Flag | Description |
|---|---|
| `-e / --empty-results-directory` | clear allure-results before run |
| `-s / --serve-results [dir]` | serve allure; bare → `allure-results`; value → named dir |

## Logging flags
| Flag | Description |
|---|---|
| `-l / --logger-level` | Verbose\|Debug\|Information(default)\|Warning\|Error\|Fatal |
| `-g / --logger-configuration-file <path>` | custom logger config |
| `--send-logs` | send logs to elastic |
| `--elastic-uri/username/password` | elastic config |
| `--disable-elastic-defaults` | disable elastic defaults |

## Runtime flags
| Flag | Description |
|---|---|
| `--no-process-exit` | do not call `Environment.Exit` (use in test hosts) |

## execute-specific
```yaml
# executable.yaml
Commands:
  - Command: "run test.qaas.yaml"
    Id: smoke
    Parallel: false
```
Select with `-c / --command-ids-to-run`.
