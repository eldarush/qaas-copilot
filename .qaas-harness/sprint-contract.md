# Sprint Contract — sprint 2
Date: 2026-06-11 | Stories: S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11 | Status: AGREED
Repos in scope: qaas-skills (`platform/**`, `plugins/qaas/**`, `README.md`, `INSTALL.md`, `CLAUDE.md`, `.claude-plugin/marketplace.json`) | Evidence level required: build

Verification shells: [PS] PowerShell from repo root; [B] Git Bash from repo root.

## USER ADDENDUM (binding, supersedes any softer wording below)
- The runtime model operates on **QaaS docs + ready NuGets ONLY** — no QaaS source code, no
  internet, no web search. User-provided SUT repos/charts/tests exist on disk ONLY when the user
  supplies them; otherwise even those are absent and every SUT fact must come from the user.
- **Self-doubt posture**: plugin content must instruct the model to assume its own beliefs about
  QaaS are wrong until confirmed by docs/FB, to question the user MORE than seems necessary, and
  to prefer asking over proceeding. The new articles (NEVER-FILL-GAPS et al.) and the 14-input
  interview must carry this tone explicitly: "When in doubt, doubt yourself — ask."

## Hard sync rules
- Synced skills/slices are edited under `platform/` first, then `[PS] powershell -NoProfile -File .\platform\harness\sync-plugin.ps1`.
- Plugin-only assets are edited directly under `plugins/qaas/`: `skills/qaas-overview`, `skills/validate-compatibility`, `agents/*`, `commands/*`.
- Final state must be platform↔plugin diff-clean for all synced assets only (all `platform/factbase/*.md` and all `platform/skills/*/`).

## Story S1: Add `s16` docs-navigation slice + discovery-before-denial
Definition of done:
1. `s16` exists in both trees, is ≤6144 bytes, and is a real index not a stub — verify: `[B] test -f platform/factbase/s16-docs-navigation.md && test -f plugins/qaas/factbase/s16-docs-navigation.md && test "$(wc -c < platform/factbase/s16-docs-navigation.md)" -le 6144 && test "$(grep -c '^| ' plugins/qaas/factbase/s16-docs-navigation.md)" -ge 75 && grep -qi "discovery-before-denial" plugins/qaas/factbase/s16-docs-navigation.md && grep -q "author-custom-hook" plugins/qaas/factbase/s16-docs-navigation.md && grep -q "availableProbes" plugins/qaas/factbase/s16-docs-navigation.md` → expect: exit 0.
2. Both Fact Base indexes advertise `s16` and synced copy is identical — verify: `[B] grep -qE "s16.*docs-navigation" platform/factbase/index.md && grep -qE "s16.*docs-navigation" plugins/qaas/factbase/index.md && diff platform/factbase/s16-docs-navigation.md plugins/qaas/factbase/s16-docs-navigation.md` → expect: exit 0 and `diff` prints nothing.

## Story S2: Relabel `s09`–`s12` as snapshot fallback
Definition of done:
1. All four plugin slices carry the exact snapshot banner and live-docs-first wording — verify: `[B] test "$(grep -l "SNAPSHOT at Runner 4.5.1 / Mocker 2.4.1" plugins/qaas/factbase/s09-assertions-catalog.md plugins/qaas/factbase/s10-generators-catalog.md plugins/qaas/factbase/s11-probes-catalog.md plugins/qaas/factbase/s12-processors-catalog.md | wc -l)" = 4 && grep -q "fetch live docs first" plugins/qaas/factbase/s12-processors-catalog.md` → expect: exit 0.
2. Catalog payloads remain intact and synced — verify: `[B] test "$(grep -c '^| ' plugins/qaas/factbase/s10-generators-catalog.md)" = 13 && for n in 09 10 11 12; do diff platform/factbase/s${n}-* plugins/qaas/factbase/s${n}-* || exit 1; done` → expect: exit 0 and no `diff` output.

## Story S3: Make `pick-generator` and `pick-assertion` docs-first
Definition of done:
1. Both skills now depend on `s16`, point to live docs, and keep family-specific docs paths — verify: `[B] grep -q "s16" plugins/qaas/skills/pick-generator/SKILL.md && grep -q "s16" plugins/qaas/skills/pick-assertion/SKILL.md && grep -q "availableGenerators" plugins/qaas/skills/pick-generator/SKILL.md && grep -q "availableAssertions" plugins/qaas/skills/pick-assertion/SKILL.md && grep -q "/qaas:docs" plugins/qaas/skills/pick-generator/SKILL.md && grep -q "/qaas:docs" plugins/qaas/skills/pick-assertion/SKILL.md` → expect: exit 0.
2. Both files stay within contract shape/line cap and sync clean — verify: `[B] test "$(awk 'END{print NR}' plugins/qaas/skills/pick-generator/SKILL.md)" -le 150 && test "$(awk 'END{print NR}' plugins/qaas/skills/pick-assertion/SKILL.md)" -le 150 && test "$(grep -cE 'done_rubric|failure_modes|escalation' plugins/qaas/skills/pick-generator/SKILL.md)" -ge 3 && test "$(grep -cE 'done_rubric|failure_modes|escalation' plugins/qaas/skills/pick-assertion/SKILL.md)" -ge 3 && diff platform/skills/pick-generator/SKILL.md plugins/qaas/skills/pick-generator/SKILL.md && diff platform/skills/pick-assertion/SKILL.md plugins/qaas/skills/pick-assertion/SKILL.md` → expect: exit 0.

## Story S4: Add constitutional articles X–XIII + reinforce Article 9
Definition of done:
1. The four new article names propagate to all three constitutional surfaces — verify: `[B] for f in plugins/qaas/skills/qaas-overview/SKILL.md platform/CONSTITUTION.md CLAUDE.md; do grep -q "GROUNDED-SOURCES" "$f" && grep -q "NEVER-FILL-GAPS" "$f" && grep -q "DELEGATE-TO-SUBAGENTS" "$f" && grep -q "VALIDATE-BEFORE-DELIVER" "$f" || exit 1; done` → expect: exit 0.
2. Article count, quadruple check, and reachability-before-mocker text are explicit — verify: `[B] grep -q "XIII." platform/CONSTITUTION.md && grep -qi "quadruple" plugins/qaas/skills/qaas-overview/SKILL.md && grep -qi "real endpoint.*reachable" plugins/qaas/skills/qaas-overview/SKILL.md` → expect: exit 0.
3. USER ADDENDUM tone present: `[B] grep -qi "doubt" plugins/qaas/skills/qaas-overview/SKILL.md` → expect: exit 0 (self-doubt instruction present in the Constitution section).

## Story S5: Add `analyze-sut-repo`
Definition of done:
1. Skill exists with full contract, fixed output artifact, and citation discipline — verify: `[B] test -f plugins/qaas/skills/analyze-sut-repo/SKILL.md && test "$(grep -cE 'name:|version:|description:|when_to_use:|inputs:|outputs:|fact_base_slices:|references:|done_rubric|failure_modes|escalation' plugins/qaas/skills/analyze-sut-repo/SKILL.md)" -ge 11 && grep -q "file:line" plugins/qaas/skills/analyze-sut-repo/SKILL.md && grep -q "sut-profile.md" plugins/qaas/skills/analyze-sut-repo/SKILL.md` → expect: exit 0.
2. Skill includes the required grounded repo-analysis markers, line cap, and sync parity — verify: `[B] grep -q "ReceiveEndpoint" plugins/qaas/skills/analyze-sut-repo/SKILL.md && grep -q "@KafkaListener" plugins/qaas/skills/analyze-sut-repo/SKILL.md && grep -qi "qaas-analyst" plugins/qaas/skills/analyze-sut-repo/SKILL.md && grep -q "NEEDS_CLARIFICATION" plugins/qaas/skills/analyze-sut-repo/SKILL.md && test "$(awk 'END{print NR}' plugins/qaas/skills/analyze-sut-repo/SKILL.md)" -le 150 && diff platform/skills/analyze-sut-repo/SKILL.md plugins/qaas/skills/analyze-sut-repo/SKILL.md` → expect: exit 0.

## Story S6: Add `analyze-helm-k8s`
Definition of done:
1. Skill exists with full contract and runtime-config output — verify: `[B] test -f plugins/qaas/skills/analyze-helm-k8s/SKILL.md && test "$(grep -cE 'name:|version:|description:|when_to_use:|inputs:|outputs:|fact_base_slices:|references:|done_rubric|failure_modes|escalation' plugins/qaas/skills/analyze-helm-k8s/SKILL.md)" -ge 11 && grep -q "runtime-config.md" plugins/qaas/skills/analyze-helm-k8s/SKILL.md` → expect: exit 0.
2. Helm-first/fallback/secret handling is explicit, line-capped, and synced — verify: `[B] grep -q "helm template" plugins/qaas/skills/analyze-helm-k8s/SKILL.md && grep -q "secretKeyRef" plugins/qaas/skills/analyze-helm-k8s/SKILL.md && grep -qiE "fall back|fallback" plugins/qaas/skills/analyze-helm-k8s/SKILL.md && grep -q "NEEDS_CLARIFICATION" plugins/qaas/skills/analyze-helm-k8s/SKILL.md && test "$(awk 'END{print NR}' plugins/qaas/skills/analyze-helm-k8s/SKILL.md)" -le 150 && diff platform/skills/analyze-helm-k8s/SKILL.md plugins/qaas/skills/analyze-helm-k8s/SKILL.md` → expect: exit 0.

## Story S7: Add `analyze-existing-tests`
Definition of done:
1. Skill exists with full contract and both output artifacts — verify: `[B] test -f plugins/qaas/skills/analyze-existing-tests/SKILL.md && test "$(grep -cE 'name:|version:|description:|when_to_use:|inputs:|outputs:|fact_base_slices:|references:|done_rubric|failure_modes|escalation' plugins/qaas/skills/analyze-existing-tests/SKILL.md)" -ge 11 && grep -q "test-inventory.md" plugins/qaas/skills/analyze-existing-tests/SKILL.md && grep -q "coverage-gaps.md" plugins/qaas/skills/analyze-existing-tests/SKILL.md` → expect: exit 0.
2. Inventory schema, gap classification, SUT cross-reference, line cap, and sync parity are explicit — verify: `[B] grep -q "integration_surface" plugins/qaas/skills/analyze-existing-tests/SKILL.md && grep -qE "create.*repair.*update|create/repair/update" plugins/qaas/skills/analyze-existing-tests/SKILL.md && grep -q "sut-profile.md" plugins/qaas/skills/analyze-existing-tests/SKILL.md && grep -qi "qaas-analyst" plugins/qaas/skills/analyze-existing-tests/SKILL.md && test "$(awk 'END{print NR}' plugins/qaas/skills/analyze-existing-tests/SKILL.md)" -le 150 && diff platform/skills/analyze-existing-tests/SKILL.md plugins/qaas/skills/analyze-existing-tests/SKILL.md` → expect: exit 0.

## Story S8: Add `document-test-project`
Definition of done:
1. Skill exists with full contract and README output target — verify: `[B] test -f plugins/qaas/skills/document-test-project/SKILL.md && test "$(grep -cE 'name:|version:|description:|when_to_use:|inputs:|outputs:|fact_base_slices:|references:|done_rubric|failure_modes|escalation' plugins/qaas/skills/document-test-project/SKILL.md)" -ge 11 && grep -q "README.md" plugins/qaas/skills/document-test-project/SKILL.md` → expect: exit 0.
2. Required README sections, exact run command, line cap, and sync parity are explicit — verify: `[B] grep -q "mermaid" plugins/qaas/skills/document-test-project/SKILL.md && grep -q "dotnet run -- run" plugins/qaas/skills/document-test-project/SKILL.md && grep -q "## Troubleshooting" plugins/qaas/skills/document-test-project/SKILL.md && test "$(awk 'END{print NR}' plugins/qaas/skills/document-test-project/SKILL.md)" -le 150 && diff platform/skills/document-test-project/SKILL.md plugins/qaas/skills/document-test-project/SKILL.md` → expect: exit 0.

## Story S9: Add `qaas-analyst` subagent
Definition of done:
1. Plugin-only agent exists, is read-only, and exposes only allowed tools — verify: `[B] test -f plugins/qaas/agents/qaas-analyst.md && grep -q "^name: qaas-analyst$" plugins/qaas/agents/qaas-analyst.md && grep -q "^tools: .*Read.*Grep.*Glob.*Bash" plugins/qaas/agents/qaas-analyst.md && ! grep -q "^tools: .*Write" plugins/qaas/agents/qaas-analyst.md` → expect: exit 0.
2. Agent references all three analysis skills, status vocabulary, and line cap — verify: `[B] grep -q "analyze-sut-repo" plugins/qaas/agents/qaas-analyst.md && grep -q "analyze-helm-k8s" plugins/qaas/agents/qaas-analyst.md && grep -q "analyze-existing-tests" plugins/qaas/agents/qaas-analyst.md && grep -qE "DONE_WITH_CONCERNS|NEEDS_CLARIFICATION" plugins/qaas/agents/qaas-analyst.md && test "$(awk 'END{print NR}' plugins/qaas/agents/qaas-analyst.md)" -le 80` → expect: exit 0.

## Story S10: Deepen planner interview + analysis-first routing
Definition of done:
1. Planner interview grows to ≥14 blocking inputs and names the new analysis facts — verify: `[B] test "$(grep -cE '^[[:space:]]*[0-9]+\.' plugins/qaas/agents/qaas-planner.md)" -ge 14 && grep -qi "SUT repo" plugins/qaas/agents/qaas-planner.md && grep -qi "transformation contract" plugins/qaas/agents/qaas-planner.md && grep -qi "logs/metrics" plugins/qaas/agents/qaas-planner.md && grep -qi "latency" plugins/qaas/agents/qaas-planner.md && grep -qi "hermetic" plugins/qaas/agents/qaas-planner.md` → expect: exit 0.
2. Planner, command, and planning skill all route analysis first and preserve stop semantics — verify: `[B] grep -qiE "analysis-first|analyze first|qaas-analyst" plugins/qaas/agents/qaas-planner.md && grep -qiE "analysis-first|analyze first|qaas-analyst" plugins/qaas/commands/new-test.md && grep -qiE "qaas-analyst|sut-profile.md|runtime-config.md|coverage-gaps.md" plugins/qaas/skills/plan-test-sprint/SKILL.md && grep -q "MOCK_REQUIRED" plugins/qaas/commands/new-test.md && grep -q "NEEDS_CLARIFICATION" plugins/qaas/commands/new-test.md` → expect: exit 0.
3. Edited files stay within caps and synced where applicable — verify: `[B] test "$(awk 'END{print NR}' plugins/qaas/agents/qaas-planner.md)" -le 80 && test "$(awk 'END{print NR}' plugins/qaas/skills/plan-test-sprint/SKILL.md)" -le 150 && diff platform/skills/plan-test-sprint/SKILL.md plugins/qaas/skills/plan-test-sprint/SKILL.md` → expect: exit 0.
4. USER ADDENDUM tone: interview text instructs over-questioning/self-doubt — `[B] grep -qiE "doubt|over-question|more questions than" plugins/qaas/agents/qaas-planner.md` → expect: exit 0.

## Story S11: Update counts, cross-doc consistency, and final sync
Definition of done:
1. Stale counts are gone and README advertises the v2 totals — verify: `[B] ! grep -RqlE "16 skills|15 task skills|3 subagents" README.md INSTALL.md CLAUDE.md plugins/ && grep -q "20 skills" README.md && grep -q "4 subagents" README.md && grep -qE "s00–s16|s00-s16" README.md` → expect: exit 0.
2. `qaas-overview` lists all four new skills and repo totals match spec — verify: `[B] test "$(grep -cE 'analyze-sut-repo|analyze-helm-k8s|analyze-existing-tests|document-test-project' plugins/qaas/skills/qaas-overview/SKILL.md)" -ge 4 && test "$(find plugins/qaas/skills -mindepth 1 -maxdepth 1 -type d | wc -l)" = 20 && test "$(find plugins/qaas/agents -mindepth 1 -maxdepth 1 -type f -name '*.md' | wc -l)" = 4 && test "$(find plugins/qaas/factbase -maxdepth 1 -type f -name 's*.md' | wc -l)" = 17` → expect: exit 0.
3. Plugin manifests remain valid JSON and mention updated counts — verify: `[PS] $p=Get-Content 'plugins/qaas/.claude-plugin/plugin.json' -Raw | ConvertFrom-Json; $m=Get-Content '.claude-plugin/marketplace.json' -Raw | ConvertFrom-Json; if(($p.description -match '20 skills') -and (($m.metadata.description + ' ' + $m.plugins[0].description) -match '4 subagents|20 skills')){exit 0}else{exit 1}` → expect: exit 0.

## Global no-regressions gates (apply to all stories)
1. Final sync must be run and all synced assets must be clean — verify: `[PS] powershell -NoProfile -File .\platform\harness\sync-plugin.ps1` → expect: output contains `[sync] done.`; then `[B] for f in platform/factbase/*.md; do diff "$f" "plugins/qaas/factbase/$(basename "$f")" || exit 1; done; for d in platform/skills/*; do diff -ru "$d" "plugins/qaas/skills/$(basename "$d")" || exit 1; done` → expect: exit 0.
2. Existing 16-skill surface keeps contract/frontmatter shape, and slash-command surface stays unchanged at 5 commands — verify: `[B] for f in plugins/qaas/skills/*/SKILL.md; do case "$f" in */qaas-overview/*) grep -q "^name: qaas-overview$" "$f" ;; *) test "$(grep -cE 'name:|version:|description:|when_to_use:|inputs:|outputs:|fact_base_slices:|references:|done_rubric|failure_modes|escalation' "$f")" -ge 11 ;; esac || exit 1; done && test "$(find plugins/qaas/commands -maxdepth 1 -type f -name '*.md' | wc -l)" = 5 && for f in diagnose.md docs.md fact.md new-test.md verify.md; do test -f "plugins/qaas/commands/$f" || exit 1; done` → expect: exit 0.
3. `s13` must remain byte-unchanged in both trees — verify: `[B] git diff --quiet -- platform/factbase/s13-doc-drift.md plugins/qaas/factbase/s13-doc-drift.md` → expect: exit 0.
4. No `weak` / `weak model` phrasing may exist anywhere under `plugins/` — verify: `[B] ! grep -riq "weak" plugins/` → expect: exit 0.

## Rubric thresholds
Correctness / Completeness / Craft / Robustness all ≥ 7/10.

## Out of scope
Public-repo export to `qaas-copilot`; tree-sitter/PageRank tooling; any `s13` content change; any `sprint.json` schema / `platform/PROTOCOL.md` change; root README "weak" wording outside `plugins/`; any repo outside `qaas-skills`.

## Forbidden moves
- No weakening/removing verification text, counts checks, or existing command/skill/agent surfaces to make grep/diff pass.
- No swallowing exceptions, no stubs/placeholders/TODO content, no fake or uncited facts, no silent guessing in analysis outputs.
- No editing synced assets only under `plugins/qaas/skills` or `plugins/qaas/factbase`; source-of-truth is `platform/` for synced content.
- No scope creep outside listed files/repos; plugin content remains bash/curl-only (maintainer sync stays PowerShell-only).

## Negotiation log
- Generator objected that S1–S11 was large; tightened by compressing to decisive mechanical evidence only, preserving the mandated S1→S11 dependency order.
- Evaluator objected that `s16` and analysis skills could be gamed with tiny stubs; tightened with row-count/content-marker checks, fixed artifact names, line caps, and sync parity.
- Generator objected that Windows verification could drift from plugin constraints; tightened by separating [PS] maintainer sync/json checks from [B] plugin-content verification, while forbidding PowerShell inside plugin content.
- Evaluator objected that regressions were implicit; tightened with explicit global gates for sync-clean parity, unchanged 5-command public surface, `s13` byte identity, existing skill frontmatter shape, and zero `weak` phrasing under `plugins/`.
- ORCHESTRATOR ADDENDUM (post-agreement, from the user): docs+NuGets-only runtime; self-doubt/over-questioning posture mandatory in Constitution + interview (S4 criterion 3, S10 criterion 4 added).
