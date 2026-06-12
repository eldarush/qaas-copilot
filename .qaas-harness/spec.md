# Spec: v2 — docs-first knowledge + SUT analysis capabilities
Generated: 2026-06-12 | Planner model: claude-opus-4.8 | Status: draft

## Problem Statement
The QaaS plugin (`plugins/qaas/`) embeds full hook config-key tables in the catalog skills
(`pick-generator`, `pick-assertion`) and Fact Base slices `s09`–`s12`. These are pinned to one
QaaS version (Runner 4.5.1 / Mocker 2.4.1). When a user's QaaS version differs, the plugin
suggests removed hooks/flags or omits new ones, and — worse — confidently claims a hook "doesn't
exist". Separately, the plugin can only author tests from facts the user types; it cannot read the
user's System-Under-Test (SUT) source repos, Helm/K8s manifests, or pre-existing tests to derive
those facts itself. v2 (a) makes hook knowledge docs-first (live docs are truth; factbase becomes
a version-stamped offline fallback; absence is proven by listing, never asserted), (b) adds four
grounded analysis capabilities (SUT repo, Helm/K8s, existing tests, project documentation), and
(c) deepens the planner interview and the Constitution so the model never fills gaps silently and
always re-verifies before delivering.

## Goals / Non-Goals
**Goals**
- De-hardcode catalogs: lightweight NAME INDEX for navigation; REQUIRE fetching the hook's docs
  page for exact config keys before authoring; `s09`–`s12` relabeled as version-stamped snapshot
  fallback; discovery-before-denial protocol; route truly-absent capabilities to `author-custom-hook`.
- Add `analyze-sut-repo`, `analyze-helm-k8s`, `analyze-existing-tests`, `document-test-project`
  skills, all producing structured artifacts with `file:line` citations; uncited facts forbidden;
  unknowns become numbered questions, never guesses.
- Add `qaas-analyst` subagent so heavy repo/chart/test reads run in isolated context and only a
  structured summary returns to the main context.
- Extend the planner interview to 14 numbered blocking inputs; analysis runs FIRST, then only the
  questions analysis could not answer are asked (with citations of what was found).
- Add four constitutional articles (GROUNDED-SOURCES, NEVER-FILL-GAPS, DELEGATE-TO-SUBAGENTS,
  VALIDATE-BEFORE-DELIVER) and reinforce Article 9 (mocker restraint) in analysis flows.
- Update all surface counts (README / INSTALL / CLAUDE / plugin.json / marketplace) and keep
  `platform/` ↔ `plugins/qaas/` synced via `platform/harness/sync-plugin.ps1`.

**Non-Goals**
- No export to the public repo `C:\Users\eldar\.copilot\repos\qaas-copilot` (separate later step;
  copy list given under Risks so the next sprint knows what to mirror).
- No new live-docs page authoring; we consume the existing mirror structure only.
- No deletion of `s09`–`s12` (relabel only). No change to `s13` drift content (it stays hardcoded
  truth, not a catalog).
- No tree-sitter/PageRank tooling build (research describes it; v2 uses grep checklists + subagent
  reads — no new binaries shipped in an airgapped plugin).
- No PowerShell in plugin content (bash/curl only; `sync-plugin.ps1` is maintainer-only tooling).

## Open Questions  (autopilot: conservative default applied, not blocking)
1. Should `analyze-sut-repo` ship per-language grep cheat-sheets inline or as a `references/` file?
   **Default:** inline a compact multi-language grep checklist in SKILL body (kept ≤150 lines);
   no `references/` dir to avoid sync edge cases.
2. New navigation slice id — `s16`? **Default:** yes, `s16-docs-navigation.md` (next free id).
3. One combined analyst subagent or three? **Default:** one `qaas-analyst` subagent that runs any
   of the analysis skills in isolated context (matches "DELEGATE-TO-SUBAGENTS" without proliferating
   agents; current agent count stays low).
4. Where do SUT-profile / inventory artifacts get written? **Default:** plugin instructs the model
   to write them to the user's working dir as `qaas-analysis/<name>.md` (relative, no /tmp), never
   inside the plugin. Filenames fixed: `sut-profile.md`, `runtime-config.md`, `test-inventory.md`,
   `coverage-gaps.md`, and the project `README.md`.

## Affected Repos  (repo → why)
- `qaas-skills` (this repo) ONLY. All work is in `platform/` (source) and `plugins/qaas/`
  (synced mirror) plus root docs (`README.md`, `INSTALL.md`, `CLAUDE.md`) and
  `.claude-plugin/marketplace.json` / `plugins/qaas/.claude-plugin/plugin.json` count fields.
- The 18-repo QaaS ecosystem is NOT touched — this is plugin maintainer work.

## Architecture Notes  (existing patterns to follow, with file citations)
- **Skill front-matter contract** is fixed by `platform/PROTOCOL.md:133-164`: frontmatter keys
  `name, version, description, when_to_use, inputs, outputs, fact_base_slices, references, contract{done_rubric, failure_modes, escalation}`;
  body sections in order `## When to use`, `## Steps`, `## Citations`, optional `## Traps`; every
  QaaS claim carries `(FB sNN)` or `(docs/<path>)`; SKILL.md ≤200 lines (v2 tightens to ≤150).
- **Sync model**: `platform/harness/sync-plugin.ps1:12-30` mirrors `platform/factbase/*.md` →
  `plugins/qaas/factbase/` and every `platform/skills/<name>/` → `plugins/qaas/skills/`. Plugin-only
  skills (`qaas-overview`, `validate-compatibility`) have NO platform source and are preserved.
  **Rule for v2: write new skills/slices under `platform/` first, then run sync.** Plugin-only
  skills are edited directly in `plugins/qaas/skills/`.
- **Constitution lives in THREE places that must stay consistent**:
  `plugins/qaas/skills/qaas-overview/SKILL.md:32-68` (9 articles, plugin-only master),
  `platform/CONSTITUTION.md:1-56` (articles I–IX), and the mirror in `CLAUDE.md:33+`. New articles
  must be added to all three.
- **Catalog skill shape** to preserve: `plugins/qaas/skills/pick-generator/SKILL.md:33-48` and
  `pick-assertion/SKILL.md:35+` use a decision table (intent → hook name → key config). v2 keeps the
  selection table (judgment, not version-fragile) but replaces the "key config" column content with
  "fetch exact keys from `<docs path>`; snapshot in FB `sNN` as fallback".
- **Docs fetch** is `plugins/qaas/commands/docs.md:9` — `curl` against `${QAAS_DOCS_URL}`; index
  pages `llms.txt` / `llms-full.txt`. Mirror catalog paths (per request context):
  `assertions/availableAssertions/<Name>/configuration/`,
  `generators/availableGenerators/<Name>/configuration/`,
  `probes/availableProbes/<Name>/configuration/`,
  `processors/availableProcessors/<Name>/configuration/`,
  `qaas/userInterfaces/runner/configurationSections/...`,
  `mocker/userInterfaces/mocker/configurationSections/...`, plus `_generated/schemas/`.
- **Drift table is canonical truth**: `qaas-overview/SKILL.md:79-95` (13 shown of 19) +
  `s13-doc-drift.md`. These STAY hardcoded. Version pins (FB s13#9): Runner `4.5.1`, Mocker `2.4.1`,
  Common.Assertions/Generators `3.5.1`, Common.Probes/Processors `1.5.1`, .NET `10.0.203`.
- **Planner gate** is `plugins/qaas/agents/qaas-planner.md:14-29` (6 blocking inputs) mirrored in
  `plugins/qaas/commands/new-test.md:12-22`. Extend both.
- **FB index** `plugins/qaas/factbase/index.md` (+ `platform/factbase/index.md`) lists every slice
  with size; add the `s16` row in both.
- **Counts to update**: `README.md:14` ("16 skills, 3 subagents, 5 commands"), `README.md:51`
  ("15 task skills" table + line 42-44), `README.md:133-137` layout block, `CLAUDE.md` skill
  references, `INSTALL.md`, `plugins/qaas/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`.
- **Status-line vocabulary** (PROTOCOL.md:24): `DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
  | NEEDS_CLARIFICATION`. New skills must use these verbatim in escalation.
- **Language gotcha**: root `README.md:3,112` currently says "weak"; the no-"weak model" gate
  applies to `plugins/` content only — do not introduce "weak"/"weak model" into any file under
  `plugins/`. (Existing root README "weak" wording is out of scope to fix here.)

## Stories
(Ordered: catalog/docs redesign + navigation slice land first because the analysis & planner
stories reference the docs-first protocol and the navigation slice.)

### S1: Add navigation-index Fact Base slice `s16` + discovery-before-denial protocol  (repo: qaas-skills, depends-on: none)
As a model authoring YAML, I want a lightweight hook NAME INDEX with exact docs paths and a
discovery protocol, so that I navigate to live config keys and never claim a hook is absent without
listing the live catalog.
**Files create:** `platform/factbase/s16-docs-navigation.md` (≤6KB). **Files edit:**
`platform/factbase/index.md` and `plugins/qaas/factbase/index.md` (add `s16` row).
Then run `platform/harness/sync-plugin.ps1` to produce `plugins/qaas/factbase/s16-docs-navigation.md`.
**Content requirements of `s16`:**
- A NAME INDEX (one row per hook) for all four families: `assertion | generator | probe | processor`,
  columns `Name | one-line purpose | exact docs path`. Probe rows must include the 43 probes
  (incl. `Os*` kubernetes probes). Paths use the templates in Architecture Notes
  (e.g. `generators/availableGenerators/<Name>/configuration/`).
- Pointers to `qaas/userInterfaces/runner/configurationSections/...` and
  `mocker/userInterfaces/mocker/configurationSections/...` yamlView pages and `_generated/schemas/`.
- A **DISCOVERY-BEFORE-DENIAL protocol** (numbered): (1) check this name index; (2) if the needed
  capability is not listed, fetch the family catalog index page via `/qaas:docs <family>/available<Family>/`
  and list what exists — never assert absence first; (3) if a matching hook exists, fetch its
  `.../configuration/` page for exact keys BEFORE authoring; (4) if truly absent after listing,
  route to `author-custom-hook` to write a new C# hook; (5) snapshot slices `s09`–`s12` are the
  OFFLINE FALLBACK only — banner-stamped to the snapshot version.
- A one-line rule: "`s13` drift traps stay authoritative even over live docs (corrections, not catalogs)."
**Acceptance criteria:**
1. `test -f platform/factbase/s16-docs-navigation.md && test -f plugins/qaas/factbase/s16-docs-navigation.md`.
2. `wc -c < platform/factbase/s16-docs-navigation.md` ≤ `6144`.
3. `grep -c "availableProbes" plugins/qaas/factbase/s16-docs-navigation.md` ≥ `1`; file contains the
   string `discovery-before-denial` (case-insensitive) and `author-custom-hook`.
4. Both `index.md` files contain a row matching `s16` and `docs-navigation`.
5. `diff platform/factbase/s16-docs-navigation.md plugins/qaas/factbase/s16-docs-navigation.md` exits 0.
**Out of scope:** editing pick-* skills (S3); relabeling catalogs (S2).

### S2: Relabel catalog slices `s09`–`s12` as version-stamped snapshot fallback  (repo: qaas-skills, depends-on: S1)
As a model, I want each catalog slice to declare it is a snapshot, so that I prefer live docs and
treat embedded keys as fallback only.
**Files edit:** `platform/factbase/s09-assertions-catalog.md`, `s10-generators-catalog.md`,
`s11-probes-catalog.md`, `s12-processors-catalog.md` (top-of-file banner). Run sync to mirror to
`plugins/qaas/factbase/`. (4 platform files + sync = ≤8 effective.)
**Content requirements:** Prepend each file with a single banner line, verbatim form:
`> SNAPSHOT at Runner 4.5.1 / Mocker 2.4.1 — fetch live docs first (see FB s16); verify against your docs when reachable.`
Do NOT delete or alter any existing table rows.
**Acceptance criteria:**
1. `grep -l "SNAPSHOT at Runner 4.5.1 / Mocker 2.4.1" plugins/qaas/factbase/s09-assertions-catalog.md plugins/qaas/factbase/s10-generators-catalog.md plugins/qaas/factbase/s11-probes-catalog.md plugins/qaas/factbase/s12-processors-catalog.md` lists all 4 files.
2. `grep -c "fetch live docs first" plugins/qaas/factbase/s12-processors-catalog.md` ≥ 1.
3. The 11-generator table in `s10` still has 11 data rows (`grep -c "^| " s10` unchanged vs pre-edit ± banner).
4. `s13-doc-drift.md` is byte-identical to its pre-S2 state (`git diff --quiet -- platform/factbase/s13-doc-drift.md` for this story).
5. Each edited slice still synced: `diff platform/factbase/sNN... plugins/qaas/factbase/sNN...` exits 0 for NN in 09..12.
**Out of scope:** pick-* skill edits (S3).

### S3: Make `pick-generator` & `pick-assertion` docs-first  (repo: qaas-skills, depends-on: S1, S2)
As a model, I want the catalog skills to send me to live docs for exact keys while keeping their
selection tables, so that key columns never go stale.
**Files edit:** `platform/skills/pick-generator/SKILL.md`, `platform/skills/pick-assertion/SKILL.md`;
run sync → `plugins/qaas/skills/pick-generator/SKILL.md`, `.../pick-assertion/SKILL.md`. (2 + sync.)
**Content requirements:**
- Keep the intent→hook-name decision table. Replace the "Key config fields" column with the
  instruction: `fetch exact keys from <docs path>; FB s10/s09 snapshot is fallback`. Include the
  exact docs-path template per family.
- Add a `## Steps` step ordering: (1) select hook from table; (2) fetch `.../configuration/` page via
  `/qaas:docs`; (3) if unreachable, use FB `s09`/`s10` snapshot (note version); (4) if hook not in
  table, run the `s16` discovery protocol before claiming absence.
- Update `fact_base_slices` front-matter to include `s16` (e.g. `[s10, s13, s16]`).
- Keep `done_rubric` but reword the "exist verbatim in FB" line to "exist verbatim in the fetched
  docs page OR the FB snapshot fallback".
- Files stay ≤150 lines; front-matter contract shape unchanged; no "weak" wording.
**Acceptance criteria:**
1. `grep -q "s16" plugins/qaas/skills/pick-generator/SKILL.md && grep -q "s16" plugins/qaas/skills/pick-assertion/SKILL.md`.
2. Each file contains the substring `availableGenerators` or `availableAssertions` respectively and `/qaas:docs`.
3. `awk 'END{print NR}' plugins/qaas/skills/pick-generator/SKILL.md` ≤ 150 (same for pick-assertion).
4. Front-matter still contains all 9 contract keys (`grep -c "done_rubric\|failure_modes\|escalation"` ≥ 3).
5. `diff` platform vs plugin copies of both skills exits 0.
**Out of scope:** adding pick-probe/pick-processor skills (none exist; not in scope).

### S4: Add four constitutional articles + reinforce mocker restraint  (repo: qaas-skills, depends-on: none)
As the always-on guide, I want new non-negotiable articles, so the model is grounded, never fills
gaps, delegates heavy reads, and re-verifies before delivering.
**Files edit:** `plugins/qaas/skills/qaas-overview/SKILL.md` (articles list, currently 9 → 13),
`platform/CONSTITUTION.md` (articles I–IX → I–XIII), `CLAUDE.md` (§2 article list). (3 files.)
**Content requirements (add as articles 10–13 / X–XIII, same imperative tone):**
- **GROUNDED-SOURCES ONLY** — allowed sources are: QaaS docs (`/qaas:docs` or factbase), user-provided
  repos/files, and command output from the user's machine. NO web search. NO memory of QaaS internals.
- **NEVER-FILL-GAPS** — any missing fact becomes a numbered question; silence is never consent;
  never guess to keep momentum.
- **DELEGATE-TO-SUBAGENTS** — repo/chart/test analysis runs in subagent context (Task/Explore /
  `qaas-analyst`) and returns a structured summary; large file reads stay out of main context.
- **VALIDATE-BEFORE-DELIVER** — before any final artifact, run the quadruple check: (1) citation
  check (every QaaS field traces to docs/FB), (2) drift check (s13), (3) template/build oracle,
  (4) live run OR explicit `DONE_WITH_CONCERNS`.
- Reinforce Article 9 (mocker restraint): a sentence that analysis output MUST state whether a real
  endpoint is reachable; mocker only when not.
**Acceptance criteria:**
1. `grep -c "GROUNDED-SOURCES\|NEVER-FILL-GAPS\|DELEGATE-TO-SUBAGENTS\|VALIDATE-BEFORE-DELIVER" plugins/qaas/skills/qaas-overview/SKILL.md` = 4.
2. Same 4 strings present in `platform/CONSTITUTION.md` and `CLAUDE.md`.
3. `platform/CONSTITUTION.md` contains roman `XIII.` (article count reached 13).
4. `grep -qi "quadruple" plugins/qaas/skills/qaas-overview/SKILL.md`.
5. No new occurrence of `weak` in any edited `plugins/` file (`grep -c weak plugins/qaas/skills/qaas-overview/SKILL.md` = 0).
**Out of scope:** the analyst subagent itself (S9).

### S5: Add `analyze-sut-repo` skill  (repo: qaas-skills, depends-on: S4)
As a planner, I want to extract test-relevant facts from user-provided SUT source, so I can plan
tests without asking the user everything.
**Files create:** `platform/skills/analyze-sut-repo/SKILL.md` (≤150 lines); run sync →
`plugins/qaas/skills/analyze-sut-repo/SKILL.md`. (1 + sync.)
**Content requirements:**
- Full front-matter contract shape. `inputs`: one or more repo paths. `outputs`: `qaas-analysis/sut-profile.md`.
- `## Steps` = staged exploration: entrypoints → routes → handlers → schemas/DTOs → env-var config →
  transformation logic (input→output contracts) → logs/metrics emitted. Include a compact
  multi-language grep checklist (ASP.NET attributes/`MapGet`; MassTransit `ReceiveEndpoint`/`Publish<`;
  raw AMQP `QueueDeclare`/`BasicPublish`; Spring `@KafkaListener`; gRPC `.proto`/`MapGrpcService`;
  env reads `GetEnvironmentVariable`/`IConfiguration[`).
- **Citation discipline (constitutional):** every extracted fact in `sut-profile.md` carries a
  `file:line` citation; uncited facts forbidden; unknowns become numbered questions, never guesses.
- Mandate delegation to `qaas-analyst` subagent for the file reads (DELEGATE-TO-SUBAGENTS).
- Output a fixed `sut-profile.md` structure: sections `## Protocols`, `## Message schemas/DTOs`,
  `## Env config`, `## Publish/consume points`, `## Transformation contracts`, `## Logs/metrics`,
  `## Open questions`.
- `done_rubric` includes "every fact line contains `path:line`"; `escalation: NEEDS_CLARIFICATION`.
- No PowerShell; bash/grep only. No "weak" wording.
**Acceptance criteria:**
1. `test -f plugins/qaas/skills/analyze-sut-repo/SKILL.md`.
2. Front-matter has all 9 contract keys; `grep -q "file:line" SKILL.md`.
3. `grep -q "sut-profile.md" SKILL.md` and `grep -q "ReceiveEndpoint" SKILL.md` and `grep -q "@KafkaListener" SKILL.md`.
4. `grep -qi "qaas-analyst" SKILL.md` (delegation) and `grep -q "NEEDS_CLARIFICATION" SKILL.md`.
5. `awk 'END{print NR}'` ≤ 150; `diff` platform vs plugin exits 0; `grep -c weak SKILL.md` = 0.
**Out of scope:** Helm (S6), existing tests (S7).

### S6: Add `analyze-helm-k8s` skill  (repo: qaas-skills, depends-on: S4)
As a planner, I want effective runtime config derived from Helm charts / K8s manifests, so test
config matches the deployed component.
**Files create:** `platform/skills/analyze-helm-k8s/SKILL.md`; sync. (1 + sync.)
**Content requirements:**
- Front-matter contract. `outputs`: `qaas-analysis/runtime-config.md`.
- Steps: prefer `helm template <release> <chart> -f <values layers> --output-dir <dir>` when `helm`
  is available; extract env vars/ports/broker addresses with `yq`; fall back to reading
  templates+`values.yaml` layers with explicit CAUTION notes when helm absent. Note multi-layer
  values pitfall (defaults → overlay → `--set`; never read `values.yaml` alone).
- `secretKeyRef`/`configMapKeyRef` values are placeholders-to-ask-about (emit as numbered questions,
  not invented values).
- **Cross-reference:** chart-provided env vars vs code reads (grep the var name in SUT source per S5).
- Citations: every derived value cites the rendered manifest path:line or `chart values.yaml:line`.
- bash only (helm/yq/kubectl); no PowerShell; no "weak" wording.
**Acceptance criteria:**
1. `test -f plugins/qaas/skills/analyze-helm-k8s/SKILL.md`.
2. `grep -q "helm template" SKILL.md` and `grep -q "secretKeyRef" SKILL.md` and `grep -q "runtime-config.md" SKILL.md`.
3. `grep -qi "fall back\|fallback" SKILL.md` (template-absent path) and `grep -q "NEEDS_CLARIFICATION" SKILL.md`.
4. Front-matter has all 9 contract keys; `awk 'END{print NR}'` ≤ 150.
5. `diff` platform vs plugin exits 0; `grep -c weak SKILL.md` = 0.
**Out of scope:** running helm in CI; this skill only instructs the model.

### S7: Add `analyze-existing-tests` skill  (repo: qaas-skills, depends-on: S5)
As a planner, I want an inventory of existing tests and a coverage-gap diff against the SUT profile,
so I create/repair/update the right tests.
**Files create:** `platform/skills/analyze-existing-tests/SKILL.md`; sync. (1 + sync.)
**Content requirements:**
- Front-matter contract. `inputs`: paths to existing tests (QaaS YAML or other frameworks) + the
  `sut-profile.md` from S5. `outputs`: `qaas-analysis/test-inventory.md`, `qaas-analysis/coverage-gaps.md`.
- Steps: per-test behavioral inventory JSON-ish rows — `{test_name, sut, inputs, mocked_deps,
  assertions, integration_surface}`; then diff inventory against the SUT surface catalog; classify
  each gap as **create | repair | update**.
- Citations: each inventory row cites the test `file:line`.
- Delegate reads to `qaas-analyst`. Unknowns → numbered questions.
**Acceptance criteria:**
1. `test -f plugins/qaas/skills/analyze-existing-tests/SKILL.md`.
2. `grep -q "integration_surface" SKILL.md`; `grep -qE "create.*repair.*update|create/repair/update" SKILL.md`.
3. `grep -q "test-inventory.md" SKILL.md` and `grep -q "coverage-gaps.md" SKILL.md`.
4. Front-matter has all 9 contract keys; references `sut-profile.md`; `awk 'END{print NR}'` ≤ 150.
5. `diff` platform vs plugin exits 0; `grep -c weak SKILL.md` = 0.
**Out of scope:** auto-generating the missing tests (that's the existing author skills' job).

### S8: Add `document-test-project` skill  (repo: qaas-skills, depends-on: S4)
As a maintainer of a finished test project, I want a structured README, so others understand what
is tested and how to run it.
**Files create:** `platform/skills/document-test-project/SKILL.md`; sync. (1 + sync.)
**Content requirements:**
- Front-matter contract. `inputs`: the finished test project dir (+ optional `sut-profile.md`).
  `outputs`: the project's `README.md`.
- Steps produce a README with fixed sections: `## What is tested`, `## Topology` (mermaid allowed),
  `## How to run` (exact `dotnet run -- run <file>.qaas.yaml` command), `## Data sources`,
  `## Assertions` (table), `## Troubleshooting` (point to `/qaas:diagnose`, FB s07).
- Every QaaS field stated in the README cites docs/FB; no invented commands.
**Acceptance criteria:**
1. `test -f plugins/qaas/skills/document-test-project/SKILL.md`.
2. `grep -q "mermaid" SKILL.md` and `grep -q "dotnet run -- run" SKILL.md` and `grep -q "## Troubleshooting" SKILL.md`.
3. Front-matter has all 9 contract keys; `awk 'END{print NR}'` ≤ 150.
4. `diff` platform vs plugin exits 0; `grep -c weak SKILL.md` = 0.
**Out of scope:** generating diagrams from live cluster state.

### S9: Add `qaas-analyst` subagent  (repo: qaas-skills, depends-on: S5, S6, S7)
As the main agent, I want a read-only analyst subagent, so heavy SUT/chart/test reads happen in an
isolated context and only a structured summary returns.
**Files create:** `plugins/qaas/agents/qaas-analyst.md` (≤80 lines, plugin-only — agents are not
synced by `sync-plugin.ps1`). **Files edit:** `README.md` subagent count (handled in S11; this
story only creates the agent file). (1 file here.)
**Content requirements:**
- Front-matter `name: qaas-analyst`, `description:` (when to invoke), `tools: Read, Grep, Glob, Bash`
  (read-only + bash for `helm template`/`yq`; NO Write/Edit).
- Body: runs `analyze-sut-repo` / `analyze-helm-k8s` / `analyze-existing-tests` in its own context;
  returns ONLY a structured summary + the artifact path; obeys GROUNDED-SOURCES + NEVER-FILL-GAPS;
  every fact carries `file:line`; ends with a status-line from the PROTOCOL vocabulary.
- ≤80 lines; no "weak" wording; no PowerShell.
**Acceptance criteria:**
1. `test -f plugins/qaas/agents/qaas-analyst.md`.
2. Front-matter `tools:` line contains `Read` and `Grep` and NOT `Write` (`grep "^tools:" | grep -vq Write`).
3. `grep -q "analyze-sut-repo" file` and references all three analysis skills.
4. `awk 'END{print NR}'` ≤ 80; `grep -c weak` = 0.
5. Status-line vocabulary present (`grep -q "NEEDS_CLARIFICATION\|DONE_WITH_CONCERNS"`).
**Out of scope:** count updates in README (S11).

### S10: Deepen the planner interview + analysis-first routing  (repo: qaas-skills, depends-on: S5, S6, S7, S9)
As a planner, I want a long numbered interview that runs analysis first and only asks what analysis
could not answer, so no fact is guessed.
**Files edit:** `plugins/qaas/agents/qaas-planner.md`, `plugins/qaas/commands/new-test.md`,
`platform/skills/plan-test-sprint/SKILL.md` (+ sync of plan-test-sprint). (3 + sync.)
**Content requirements:**
- Extend the blocking-input list from 6 to 14, adding: SUT repo paths?; chart/manifests available?;
  existing tests available?; which component(s)/data flows in scope?; expected transformation
  contract per flow?; logs/metrics to verify?; delay/latency tolerances?; hermetic expectations?
- Add an **analysis-first routing rule**: when the user provides repos/charts/tests, FIRST invoke
  `qaas-analyst` (running `analyze-sut-repo` / `analyze-helm-k8s` / `analyze-existing-tests`), THEN
  ask only the residual questions, each annotated with what analysis already found (with citations).
- Keep `INTERROGATE FIRST` gate and `NEEDS_CLARIFICATION`/STOP semantics. Keep mocker `MOCK_REQUIRED`
  declaration, now informed by the reachability finding from analysis (Article 9 reinforcement).
- `new-test.md` question list (currently 6) updated to mirror the 14 and the analysis-first step.
- Files stay within line caps (agent ≤80; skill ≤150). No "weak" wording.
**Acceptance criteria:**
1. `qaas-planner.md` lists ≥14 numbered interview inputs (`grep -cE "^[0-9]+\." or numbered block` ≥ 14 in the interview section); contains `SUT repo`, `transformation contract`, `logs/metrics`, `latency`, `hermetic`.
2. `grep -qi "analysis.first\|analyze first\|qaas-analyst" qaas-planner.md` and same in `new-test.md`.
3. `new-test.md` still emits `MOCK_REQUIRED` and `NEEDS_CLARIFICATION`.
4. `qaas-planner.md` ≤80 lines; `plan-test-sprint` SKILL ≤150 lines and `diff` platform vs plugin exits 0.
5. `grep -c weak` = 0 across the three edited plugin files.
**Out of scope:** changing `sprint.json` schema (PROTOCOL.md unchanged).

### S11: Update counts & cross-doc consistency + final sync  (repo: qaas-skills, depends-on: S1-S10)
As a maintainer, I want every surface count and doc table to reflect the new skills/subagent, so the
plugin self-describes accurately.
**Files edit:** `README.md`, `INSTALL.md`, `CLAUDE.md`, `plugins/qaas/.claude-plugin/plugin.json`,
`.claude-plugin/marketplace.json`, `plugins/qaas/skills/qaas-overview/SKILL.md` (skill index list).
Run `platform/harness/sync-plugin.ps1` once more as the final reconciliation. (≤6 files + sync.)
**Content requirements:**
- New totals: task skills 15 → 19 (added `analyze-sut-repo`, `analyze-helm-k8s`,
  `analyze-existing-tests`, `document-test-project`); total skills 16 → 20; subagents 3 → 4
  (added `qaas-analyst`); commands unchanged (5); Fact Base slices `s00`–`s16` (16 → 17 slices).
- Update README §"What you get" table, the task-skill table (add 4 rows), the layout block
  ("16 skills" → "20 skills", "3 subagents" → "4 subagents", "s00–s15" → "s00–s16"), the one-knob
  callout, INSTALL.md any count mentions, CLAUDE.md skill references, and the skill-index list inside
  `qaas-overview/SKILL.md` (add the 4 new skills + note analysis-first planner flow).
- Do NOT introduce "weak"/"weak model" into any `plugins/` file.
**Acceptance criteria:**
1. `grep -rl "16 skills\|15 task skills" plugins/ README.md INSTALL.md CLAUDE.md` returns NOTHING (all updated).
2. `grep -q "20 skills" README.md` and `grep -q "4 subagents" README.md` and `grep -q "s00–s16\|s00-s16" README.md`.
3. `qaas-overview/SKILL.md` skill index lists all 4 new skill names (`grep -c "analyze-sut-repo\|analyze-helm-k8s\|analyze-existing-tests\|document-test-project"` = 4).
4. `ls plugins/qaas/skills | wc -l` = 20; `ls plugins/qaas/agents | wc -l` = 4; `ls plugins/qaas/factbase/s*.md | wc -l` = 17.
5. plugin.json / marketplace.json parse as valid JSON (`python -c "import json,sys;json.load(open(...))"` exit 0) and any count field updated.
**Out of scope:** publishing to `qaas-copilot` (see Risks).

## Risks
- **Sync drift**: editing `plugins/qaas/*` directly for synced skills will be overwritten by the
  next `sync-plugin.ps1`. Mitigation: all synced skills/slices edited under `platform/` first;
  only plugin-only assets (`qaas-overview`, `validate-compatibility`, all `agents/`, all
  `commands/`) edited directly in `plugins/`.
- **Line-cap pressure**: analysis skills are content-heavy; the ≤150-line cap may force trimming the
  grep checklists. Mitigation: keep checklists terse, one line per framework; push examples out.
- **Docs-path accuracy**: `s16` paths are asserted from the request context, not verified against a
  live mirror in this airgapped planning step. The implementer MUST `/qaas:docs` one sample path of
  each family during VALIDATE-BEFORE-DELIVER and correct `s16` if a 404 returns.
- **Public-repo export (NON-GOAL, next sprint)**: mirror to `C:\Users\eldar\.copilot\repos\qaas-copilot`
  must copy: `plugins/qaas/factbase/s16-docs-navigation.md`, updated `s09`–`s12`, updated
  `pick-generator`/`pick-assertion` SKILLs, the 4 new analysis SKILLs, `agents/qaas-analyst.md`,
  updated `qaas-overview/SKILL.md`, `qaas-planner.md`, `new-test.md`, and the count-updated
  `README/INSTALL/CLAUDE` + `plugin.json`/`marketplace.json`.

## Verification Strategy  (commands the evaluator will run)
Repo-root, bash (Git Bash / WSL on the maintainer Windows box):
1. **Counts consistency**: `ls plugins/qaas/skills | wc -l` = 20; `ls plugins/qaas/agents | wc -l` = 4;
   `ls plugins/qaas/factbase/s*.md | wc -l` = 17; `grep -q "20 skills" README.md`.
2. **No stale counts**: `! grep -rq "16 skills\|15 task skills\|3 subagents" README.md INSTALL.md CLAUDE.md plugins/`.
3. **No "weak model" phrasing in plugin**: `! grep -riq "weak" plugins/`.
4. **Every new skill has full contract front-matter**: for each of the 4 new skills,
   `grep -c "name:\|version:\|description:\|when_to_use:\|inputs:\|outputs:\|fact_base_slices:\|references:\|done_rubric\|failure_modes\|escalation" SKILL.md` ≥ 11.
5. **Platform↔plugin sync**: for every synced skill/slice, `diff platform/.../X plugins/qaas/.../X`
   exits 0 (run `sync-plugin.ps1` then `git diff --quiet plugins/qaas/skills plugins/qaas/factbase` — clean).
6. **Constitution propagation**: the 4 new article names appear in all three of
   `plugins/qaas/skills/qaas-overview/SKILL.md`, `platform/CONSTITUTION.md`, `CLAUDE.md`.
7. **Docs-first markers present**: `grep -q "discovery-before-denial" plugins/qaas/factbase/s16-docs-navigation.md`;
   all of `s09`–`s12` carry the `SNAPSHOT at Runner 4.5.1 / Mocker 2.4.1` banner; `pick-generator`
   and `pick-assertion` reference `/qaas:docs` and `s16`.
8. **Citation discipline declared**: each analysis skill contains `file:line` and `NEEDS_CLARIFICATION`.
9. **Planner depth**: `qaas-planner.md` interview section has ≥14 numbered inputs and references
   analysis-first routing / `qaas-analyst`.
10. **JSON validity**: `plugins/qaas/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`
    parse as valid JSON.
11. **Line caps**: every new/edited SKILL ≤150 lines; `qaas-analyst.md` and `qaas-planner.md` ≤80 lines.
