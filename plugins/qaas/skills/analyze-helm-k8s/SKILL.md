---
name: analyze-helm-k8s
version: 1.0.0
description: Derive effective runtime config from Helm charts or K8s manifests; produce runtime-config.md with file:line citations.
when_to_use: User provides Helm chart paths or K8s manifests; you need to extract env vars, ports, broker addresses, and secrets before planning tests.
inputs:
  - chart_paths: paths to Helm chart directories or K8s manifest directories
  - values_files: optional list of values override files (overlay layers)
  - sut_profile: optional path to qaas-analysis/sut-profile.md (for cross-reference)
outputs:
  - runtime_config: qaas-analysis/runtime-config.md
fact_base_slices: [s00, s13, s16]
references: []
contract:
  done_rubric:
    - 'Every derived value cites rendered-manifest path:line or values.yaml:line'
    - 'secretKeyRef/configMapKeyRef values emitted as numbered questions, never invented'
    - 'Multi-layer values pitfall noted when values.yaml read without helm template'
    - 'Cross-reference: chart env vars compared to SUT code reads from sut-profile.md when available'
  failure_modes:
    - 'Reading values.yaml alone without helm template — misses overlay and --set overrides'
    - 'Inventing secret values — constitutional violation (NEVER-FILL-GAPS)'
    - 'Omitting CAUTION note when helm is absent and raw templates are read directly'
  escalation: 'NEEDS_CLARIFICATION: chart path not provided or helm/kubectl not available'
---

## When to use

Invoke after `analyze-sut-repo` (or standalone) when the user provides Helm charts or K8s
manifests. Delegate all file reads to the `qaas-analyst` subagent (Article XII): it returns a
structured summary + the COMPLETE artifact body, and YOU (the invoking agent) write that body
to `qaas-analysis/runtime-config.md` verbatim (the analyst is read-only).

## Steps

### 1. Render the chart with helm template (preferred)

When `helm` is available, render the full manifest with ALL values layers:

```bash
helm template <release-name> <chart-dir> \
  -f values.yaml \
  -f values-<env>.yaml \
  --set key=value \
  --output-dir rendered/
```

Then extract from rendered manifests:

```bash
# env vars
yq '.spec.template.spec.containers[].env[]' rendered/**/*.yaml

# ports
yq '.spec.template.spec.containers[].ports[]' rendered/**/*.yaml

# broker/service addresses from env
grep -rn "RABBIT\|KAFKA\|REDIS\|CONNECTION\|BROKER\|HOST\|PORT" rendered/
```

### 2. Fall back to reading templates + values when helm absent

**CAUTION: raw template reading MISSES overlay values and `--set` overrides.**
When `helm` is absent, read `templates/*.yaml` and all `values.yaml` layers manually:

```bash
# multi-layer values pitfall: defaults → override files → --set; never read values.yaml alone
find . -name "values*.yaml" | sort
grep -rn "env:" templates/
grep -rn "secretKeyRef\|configMapKeyRef" templates/
```

Note every CAUTION in the output: `CAUTION: rendered without helm — overlay values may differ`.

### 3. Handle secrets and configmaps

For every `secretKeyRef` or `configMapKeyRef` found: emit as a numbered question, never
invent the value:

```
Open question N: env var <NAME> references secret <secret-name> key <key>.
  What is the actual value for the test environment?
```

### 4. Cross-reference with SUT code

If `sut-profile.md` is available, grep each chart-discovered env var name against the SUT
source to verify it is actually read (per `analyze-sut-repo` grep checklist).

### 5. Output format — qaas-analysis/runtime-config.md

Sections: `## Env vars`, `## Ports`, `## Broker addresses`, `## Secrets (open questions)`,
`## Cross-reference notes`, `## Unknowns`.

Every value line: `- <KEY>=<value> (rendered/path:line)` or CAUTION note.

## Citations

- CONSTITUTION X (grounded sources — every value from file:line)
- CONSTITUTION XI (never fill gaps — secrets → questions)
- CONSTITUTION XII (delegate to qaas-analyst)
- FB s16 (hook discovery protocol)

## Traps

- **values.yaml alone** — misses overlays and `--set`; always use `helm template` when possible
- **Invented secret values** — emit as open questions, never guess
- **Single values file** — multi-environment charts have multiple overlay files; list all
- **Missing CAUTION** — always note when helm was absent and raw templates were read
