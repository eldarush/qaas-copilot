# End-to-End Sandbox Trial Results

This is the **honest, current** record of how the QaaS plugin performs when driven by a *weak*
generator model under the harness. It is updated as trials are run. No scenario is listed as
"pass" unless it passed **both** the mechanical verify gates **and** the strong-model evaluator.

## How a trial works

```
seed clean workspace
   ↓
loop.ps1 (per task, max 3 iterations):
   assemble-context.ps1  →  generator (gpt-5-mini, "MiniMax proxy")  →  apply files
   verify.ps1            →  mechanical gates (build / template / live e2e / grep)
   evaluator (claude-sonnet-4.6 or gemini) →  graded rubric, assumes bugs exist
   PASS only if verify PASSES *and* evaluator PASSES; else feedback → next iteration
```

- **Generator:** `gpt-5-mini` (stand-in for the airgapped MiniMax M2.7 target). Sees **only** the
  skills, the offline Fact Base, the sprint contract, and (for edit tasks) the current workspace
  files. **Never** sees QaaS source or the internet.
- **Evaluator:** `claude-sonnet-4.6` (some runs cross-checked with Gemini). Separate context,
  separate model family, predefined rubric.
- **For real:** runner/mocker projects are built with real NuGets, live HTTP runs connect a real
  runner to a real mocker on a dedicated port, Docker images are actually built and run.

## Current pass matrix

The corpus has **50 scenarios** across 7 capability categories. Scenarios are run for real and
promoted to "pass" individually. Status as of the latest run:

| Category | Passed / Total | Proven? | Passing scenarios |
|---|---|---|---|
| **diagnose** | **6 / 6** | ✅ fully proven | D01, D02, D03, D04, D05, D06 |
| **runner-yaml** | **10 / 10** | ✅ fully proven | A01–A10 |
| **mocker-yaml** | **8 / 8** | ✅ fully proven | B01–B08 |
| **hooks** | **8 / 8** | ✅ fully proven | C01, C02, C03, C04, C05, C06, C07, C08 |
| **docker-image** | **6 / 6** | ✅ fully proven | E01, E02, E03, E04, E05, E06 |
| **offline** | **6 / 6** | ✅ fully proven | F01, F02, F03, F04, F05, F06 |
| **planning** | **6 / 6** | ✅ fully proven | G01, G02, G03, G04, G05, G06 |
| **analysis** (v2) | **7 / 7** | ✅ fully proven | H01, H02, H03, H04, H05, H06, H07 |

> **Summary: 57 / 57 — all 8 capability categories fully proven.** Every scenario passed end-to-end
> with a *weak* generator (gpt-5-mini, the MiniMax M2.7 stand-in) under the harness, gated by both the
> mechanical verify steps **and** a separate strong-model evaluator. Highlights: **diagnose (6/6)** —
> the hardest category, where the model must root-cause a broken suite and surgically fix it;
> **runner-yaml (10/10)** — full HTTP/REST/env-var/multi-session authoring with live runner→mocker
> e2e runs; **mocker-yaml (8/8)** — multi-route mockers booted live; **hooks (8/8)** — every custom-hook
> kind (Generator, Assertion, Probe, *and* the mocker-side `BaseTransactionProcessor`) authored,
> compiled, and run e2e; **docker-image (6/6)** — six distinct facets where Docker images are actually
> **built and run** (single-image, controller, Compose+redis, custom-processor-in-image, env-driven
> config, CI build script); **offline (6/6)** — airgap/Artifactory packaging; **planning (6/6)** —
> goal→`sprint.json` decomposition including ambiguous-goal clarification (G06) and a self-corrected
> port contract (G05). Each green was earned for real: runner/mocker projects built with real NuGets,
> live HTTP runs on dedicated ports, Docker images built and curled. The v2 **analysis (7/7)** category
> proves the docs-first + SUT-analysis capabilities: source-repo profiling with verifiable `file:line`
> citations (H01), RabbitMQ ETL contract extraction (H02), Helm overlay/secret-aware effective-config
> analysis (H03), test-inventory gap analysis (H04), structured README documentation (H05),
> unknown-hook discovery without hallucination (H06), and thin-goal interrogation depth (H07).

## What each passing scenario exercised

| ID | Category | What the weak model had to do | Iters to green |
|---|---|---|---|
| A01 | runner-yaml | Scaffold runner+mocker, author HTTP `HttpStatus`+hermetic+body assertions, run live e2e on :8090 | T1×2, T2×1, T3×1 |
| A02 | runner-yaml | 3-route catalog service, per-route assertions, one shared mocker | — |
| A03 | runner-yaml | RabbitMQ publish→consume session pair (Publisher + Consumer), broker-backed e2e | — |
| A04 | runner-yaml | Scaffold + author POST JSON-body runner+mocker YAML; live e2e on :8096 | iter 1 |
| A05 | runner-yaml | Scaffold + author runner/mocker YAML driven by **`%VAR%` env variables** (multi-env), test data; live e2e on :8097 | all iter 1 |
| A06 | runner-yaml | Multi-session HTTP suite (sequential dependent sessions) | — |
| A07 | runner-yaml | Hermetic percentage assertions (`HermeticByInputOutputPercentage`) | — |
| A08 | runner-yaml | RabbitMQ topology probe + publish/consume with broker assertions | — |
| A09 | runner-yaml | Delayed / retry-tolerant async message assertions | — |
| A10 | runner-yaml | Storage + metadata + maintainability-link rich runner suite | — |
| A04 | runner-yaml | Scaffold + author POST JSON-body runner+mocker YAML; live e2e on :8096 | iter 1 |
| A05 | runner-yaml | Scaffold + author runner/mocker YAML driven by **`%VAR%` env variables** (multi-env), test data; live e2e on :8097 | all iter 1 |
| B01 | mocker-yaml | Hello/health mocker, 2 routes, static processors | — |
| B02 | mocker-yaml | Multi-route REST CRUD mocker (GET/POST/PUT/DELETE), per-route processors; live boot on :8104 | all iter 1 |
| B03 | mocker-yaml | Mocker with a Redis-backed controller stub (stateful responses) | — |
| B04 | mocker-yaml | gRPC / multi-protocol server stub mocker | — |
| B05 | mocker-yaml | Mocker driven by request-data matching (route by body/header) | — |
| B06 | mocker-yaml | Request-echo template mocker; **recovered from `-532462766` (missing processor pkg) via evaluator feedback** — no seed fix | iter 2 |
| B07 | mocker-yaml | Not-found / fallback mocker (default 404 stub + matched routes); live boot on :8109 | all iter 1 |
| B08 | mocker-yaml | Template-driven response mocker (dynamic body from request) | — |
| C01 | hooks | Custom `IGenerator` (synthetic JSON-array payloads) + e2e. Hook **compiled iter1** | iter 2 (yaml) |
| C02 | hooks | Custom `IAssertion` (response body length bounds) with attachment | — |
| C03 | hooks | Custom `IProbe` (stage-scoped diagnostic) + e2e. Hook **passed iter1** | iter 2 (yaml) |
| C04 | hooks | Custom `IAssertion` reading a JSON field from the HTTP body; build + e2e. **Needed all 3 iters** — 2 compile failures fed the hook-skill fix below | iter 3 |
| C05 | hooks | Custom `IGenerator` (deterministic sequential ids) wired into a **live runner→mocker e2e** (3 POSTs, all 200, hermetic count). Hook **compiled iter1** | all iter 1 |
| C06 | hooks | Custom `IProbe` (diagnostic) + e2e | all iter 1 |
| C07 | hooks | Custom `IAssertion` (per-output latency budget). Hook **compiled iter1** (vs C04's 3) | iter 1 (hook) |
| C08 | hooks | Custom **mocker `BaseTransactionProcessor`** returning a bespoke 200 + `CUSTOM-OK` body; live mocker serves it on :8111. Earlier **correctly refused to hallucinate** the processor namespace → drove the s04/s14 namespace fix; **compiles iter2** after the fix | T2×2, rest iter 1 |
| D01 | diagnose | Find + fix Transaction missing `DataSourceNames` (FTL invalid); cite drift | iter 1 |
| D02 | diagnose | Find + fix mocker `TransactionData` → `ProcessorConfiguration`; cite drift | iter 2 |
| D03 | diagnose | Find + fix leading-slash route (`/route` → 404); cite drift | iter 1 |
| D04 | diagnose | Detect a **vacuous green** (zero outputs) and add a hermetic count guard | iter 1 |
| D05 | diagnose | Find + fix missing `QaaS.Common.Generators` package (exit -532462766) | iter 1 |
| D06 | diagnose | Find + fix silently-ignored `ExpectedOutputCount` → `ExpectedCount` key | iter 1 |
| E01 | docker-image | Author Dockerfile (`aspnet:10.0` base) + `.dockerignore` + BUILD.md; real `docker build` + `docker run` on :8094 + curl | iter 1 |
| E02 | docker-image | Build a mocker image whose stub uses a **controller** (Redis-backed); real `docker build` + run on :8124 | iter 1 |
| E03 | docker-image | **docker-compose** (mocker + redis); redis is **internal-only** (no host port — reached by service name), only the mocker publishes 8125:8080; `compose up --build` + curl + `down -v` | iter 1 |
| E04 | docker-image | Bake a **custom `BaseTransactionProcessor<object>`** into the image (compiled by `dotnet publish`); curl :8126 → `CUSTOM-OK` | iter 1 |
| E05 | docker-image | **Env-driven config**: `sh -c` ENTRYPOINT selects the mocker config from `$QAAS_MOCKER_CONFIG`; run with `-e` + curl :8127 | iter 1 |
| E06 | docker-image | **CI build script** (`build.ps1`) that runs `docker build`; verify *executes the script*, then runs the image + curl :8128 | iter 1 |
| F01 | offline | Author `NuGet.config` with a single Artifactory feed + `<clear/>` | — |
| F02 | offline | Author an offline-pinned `NuGet.config` + restore-verification notes | iter 1 |
| F03 | offline | Author an offline template-install / packaging config (Artifactory routing) | iter 1 |
| F04 | offline | Author a docs-mirror directory layout for the airgapped docs root | iter 1 |
| F05 | offline | Author an airgap bootstrap runbook (feed setup + docs root config) | iter 1 |
| F06 | offline | Author a complete offline package-restore + docs-mirror operator guide | — |
| G01 | planning | Turn a goal into a canonical 3-task `sprint.json` (correct order) | — |
| G02 | planning | Plan a RabbitMQ publish→consume sprint; **corrected plan quality after a strong-evaluator reject** | iter 2 |
| G03 | planning | Plan a multi-session HTTP+broker sprint; validated `sprint.json` | iter 2 |
| G04 | planning | Plan a sprint for a **custom-hook feature**; validated `sprint.json`; **corrected after a strong-evaluator reject** | iter 2 |
| G05 | planning | Plan a mocker-image + container live-gate sprint; **PORT CONTRACT consistency** (one port literal across probe/mocker/runner) | iter 1 |
| G06 | planning | Refuse a **vague goal** — emit a well-formed `QUESTIONS.md` clarification instead of hallucinating a plan (`expectsClarification`) | iter 1 |
| H01 | analysis | Profile an unknown ASP.NET SUT repo → `sut-profile.md` with **real `file:line` citations** + reachability `QUESTIONS.md` | T1×1, T2×1 |
| H02 | analysis | Extract a RabbitMQ **ETL contract** (exchanges, routing keys, in/out schemas, transform rules) from worker source | iter 1 |
| H03 | analysis | Compute **effective config** from a Helm chart (values + prod overlay + ConfigMap + secret refs flagged, not guessed) | iter 1 |
| H04 | analysis | Inventory an existing QaaS test project → coverage map + **gap list** ranked by risk | iter 1 |
| H05 | analysis | Document a test project as a structured `README.md` (purpose/layout/run/extend) | iter 1 |
| H06 | analysis | Asked for nonexistent `FromAzureBlob` generator — **discover-before-deny** via FB s10, offer real alternatives, no hallucination | iter 1 |
| H07 | analysis | Thin goal ("test the parser") → **≥8 pointed questions** across intent/protocols/data/env instead of a guessed plan | iter 1 |

## Harness improvements discovered *by* running weak models

The trials are not just a scoreboard — each failure fed a concrete fix to the platform:

1. **Generator never saw the files it had to edit.** `assemble-context.ps1` embedded current
   workspace files only for the *evaluator*. Edit/diagnose tasks therefore either correctly
   refused (`NEEDS_CLARIFICATION`) or reconstructed files from memory and broke sibling contracts.
   **Fix:** added a "CURRENT WORKSPACE FILES" section to the *generator* context (edit target
   tagged, siblings read-only, build dirs excluded, size-capped). After this, D01/D04/D05/D06 all
   passed on iteration 1, and A01 still passed (no regression).
2. **Route case-sensitivity (Fact Base drift #5b).** The mocker lowercases the configured `Path`
   then builds a *case-sensitive* regex; the runner sends `Route:` verbatim. Any uppercase → 404.
   Captured as a new drift row and enforced in the authoring skills.
3. **Vacuous-pass guard wording.** `HttpStatus` passes on zero outputs; the hermetic guard's field
   is `ExpectedCount` (not `ExpectedOutputCount`, which is silently ignored). Both are now drift
   rows (#13, #12) with a golden example.
4. **Verify-cmd hazards (drift #14, #15).** A leading `#` comments out a single-line verify command
   (instant vacuous exit 0); and a live run split across two verify entries loses the background
   mocker. Both are documented so sprint authors write atomic live-run verify commands.
5. **Weak-model response resilience.** Local/weak models occasionally emit an empty or truncated
   response (no file markers, tiny stdout). Previously the harness treated this as a deliberate
   `INVALID_STATUS` halt and escalated the whole trial to "needs human", killing an otherwise
   recoverable run (seen on a hooks trial). **Fix (two layers):** `invoke-copilot-cli.ps1` now
   retries the model call up to 3× when the response is empty/too small (logs `attempt N/3`), and
   `loop.ps1` treats a surviving `INVALID_STATUS` as a *retryable* iteration with a corrective nudge
   instead of a halt (still bounded by the max-iteration guard). Confirmed live across the A04, B06
   and C04 re-runs.
6. **Custom-hook compile traps (the hooks category is the weak model's hardest).** Re-running the
   C04 hooks scenario, the weak model needed all 3 iterations to produce a *compiling* custom
   `IAssertion`. Two distinct, repeatable compile failures showed up: (a) it imported only
   `QaaS.Framework.SDK.Session.DataObjects` (`Data<T>`) and omitted
   `QaaS.Framework.SDK.Session.SessionDataObjects` (`SessionData`) → `CS0246` + a cascading
   `CS0534 'does not implement Assert(...)'`; and (b) it treated a JSON response body
   (`CastCommunicationData<JsonElement>()` → a `JsonElement` **struct**) with `?.` (`CS0023`) and
   `is byte[]`/`is string` patterns (`CS8121`). The strong evaluator diagnosed both precisely, but a
   weaker target may not recover in 3 tries. **Fix:** the `author-custom-hook` skill now ships a
   copy-verbatim `using` header (calling out the two separate `SessionData`/`Data<T>` namespaces) and
   a complete, compiling **JSON-field assertion** example with the correct `TryGetProperty` /
   `ValueKind` / `GetString()` pattern — both inline in `SKILL.md` (not a side reference), plus two
   new trap rows.

   **Measured payoff (re-running fresh hooks scenarios after the fix):**

   | Scenario | Hook kind | Hook compiled on… | Compile failures |
   |---|---|---|---|
   | C04 (**before** fix) | `IAssertion` (JSON field) | iter 3 | 2 (`CS0246`/`CS0534`, then `CS8121`/`CS0023`) |
   | C07 (after fix) | `IAssertion` (latency budget) | **iter 1** | 0 |
   | C01 (after fix) | `IGenerator` (JSON array) | **iter 1** | 0 |
   | C03 (after fix) | `IProbe` (diagnostic) | **iter 1** | 0 |

   After the fix, the custom hook compiled on the **first** attempt in all three fresh trials across
   all three runner hook kinds. The hooks category went from the weakest (1/8) to 5/8.

7. **Parallel live-run isolation (operational).** Running 5 trials at once where 3 performed live
   port-bound runs (a runner e2e plus two live mockers) led to **both** live-mocker trials (B02, B07)
   being killed at the *exact same instant* — after their mechanical verify had already gone green,
   but during the strong-evaluator call — leaving no `trial-result.json`. Re-running the same two
   scenarios **serially** produced a clean `PASS 2/2 iter 1` for each, confirming the cause was host
   resource contention / an external kill of the attached shells, **not** a model or skill defect.
   **Operating rule:** cap concurrent *live-run* (port-binding) trials at ~3; non-live trials (hooks
   build-only, offline config, planning `sprint.json`) parallelize freely. Live-run scenarios always
   use a **unique port** (A05 :8097, B02 :8104, B07 :8109, …) so they never collide when they do run
   together.

8. **Mis-specified scenarios are real failures — fix the scenario, not the model.** Two hooks
   scenarios initially FAILED for the *right* reason: **C08** scaffolded a *runner* project but asked
   for a custom *mocker* `BaseTransactionProcessor` (which only resolves against `QaaS.Mocker`) — the
   weak model **correctly refused to hallucinate** the unknown base-class namespace (`NEEDS_CLARIFICATION`)
   rather than inventing one; **C05** asked for a custom `IGenerator` with no consumer, so a generator-only
   Transaction tripped `Missing supported type in transaction`. Both were genuine **scenario-authoring
   bugs**, and the anti-hallucination design surfaced them. **Fix:** (a) corrected the processor namespace
   across Fact Base s04/s14 and the `author-custom-hook` skill (`QaaS.Framework.SDK.Hooks.Processor` +
   `…Session.MetaDataObjects`, mocker-project rule); (b) re-authored C08 as a coherent **mocker-only**
   processor scenario (live `/status` → 200 + `CUSTOM-OK` on :8111) and C05 as a coherent **runner→mocker
   generator e2e** (3 POSTs, all 200, hermetic count, :8112). After the fix the processor **compiled iter2**
   (namespace gap closed) and the generator e2e **passed all iter 1** — taking the hooks category to **8/8**.

9. **Model-invocation resilience (two more layers).** A single transient model call (notably the *last*
   task's evaluator) could `throw` and unwind the whole trial under `ErrorActionPreference=Stop`, losing
   all per-task progress **and** the `trial-result.json`. **Fix:** (a) `loop.ps1`'s `Invoke-Model` now
   retries each generator/evaluator invocation up to **3× with backoff** before giving up; (b)
   `run-trial.ps1` wraps the loop so a result file is **always** written (no more silent holes in the
   matrix); (c) `invoke-copilot-cli.ps1`'s timeout is now env-overridable (`QAAS_TRIAL_TIMEOUT_SEC`,
   default 600s) so a hung nested invocation is killed and re-spawned **fresh** quickly instead of blocking
   for 20 min. Validated: C05 ran fully through its final-task evaluator and wrote a clean `PASS 3/3`.

10. **A poisoned golden example in a skill is a platform bug, not a model failure — and the loop
    catches it.** **G05** (plan a mocker-image + container live-gate sprint) FAILED all 3 iterations:
    the strong evaluator kept flagging a `[blocker]` — the planned live-gate probed TCP port **8095**
    while the mocker/runner bound **8080**, so the gate could never go green. Root cause: the
    `plan-test-sprint` skill's **own worked-example** `verify` command hard-coded `TcpClient(...,8095)`
    against an `8080` mocker. The weak model faithfully copied its authoritative reference — including
    the bug — and couldn't "fix" what the skill told it to write. **This is exactly the failure mode the
    separate strong evaluator exists to catch.** **Fix:** (a) corrected the skill example to a single
    `8080` literal; (b) added an explicit **PORT CONTRACT rule** — probe port == mocker `Servers.Http.Port`
    == runner `Http.Port`, one literal, never invent a second — to `plan-test-sprint` §4b + checklist and
    to `run-and-collect` (new §4b *Live e2e gate* with the canonical one-command snippet); (c) added Fact
    Base **s13#16** (inconsistent port → `MOCKER NEVER READY` exit 9) and a golden **s14.9** live-gate
    example. After the fix the weak model produced a consistent plan and **G05 passed iter 1** — taking
    planning to **6/6**. Lesson: skills must ship *internally consistent* golden examples; a single wrong
    literal in a reference propagates into every artifact a weak model builds from it.

11. **"The right answer is a question" needs first-class harness support.** **G06** (deliberately vague
    goal: *"Test our new service and make sure it works."*) must NOT yield a hallucinated plan — the
    correct deliverable is a **clarification request**. Added an `expectsClarification: true` task flag:
    when the generator returns `NEEDS_CLARIFICATION`, `loop.ps1` treats it as the deliverable (falls
    through to verify + evaluate: does `QUESTIONS.md` exist with ≥3 specific questions?) instead of
    halting to a human. The `plan-test-sprint` skill already teaches this refusal; G06 now **proves** the
    weak model questions ambiguity instead of inventing requirements — passed iter 1.

12. **`NoConfiguration` was a skill-template bug that cost a wasted iteration (now fixed).** The
    `author-custom-hook` skill, plus Fact Base s04/s14, told the model that a *no-config* custom hook
    should subclass `BaseTransactionProcessor<NoConfiguration>`. **`NoConfiguration` is not an SDK type**
    → `CS0246` on every build, forcing the weak model to burn an iteration discovering it. Every real
    docs/source example uses either a concrete `public record XxxConfig` (configurable) **or**
    `BaseTransactionProcessor<object>` / `BaseProbe<object>` (no config). **Fix:** replaced all
    `NoConfiguration` references with `object` (plus an inline `// NoConfiguration is NOT an SDK type`
    warning) in the skill template, s04, and the s14 golden example, and corrected the **E04** seed
    processor. E04's custom processor then compiled and baked into the image cleanly. Lesson: a single
    non-existent type name in an authoritative template propagates a guaranteed compile failure into
    every artifact a weak model derives from it — skills must only show types that actually exist.

13. **Docker body live-gates must use `curl.exe`, not `Invoke-WebRequest.Content` (IWR byte[] trap).**
    **E04** failed its live gate for two iterations *even though the image was correct* — running the
    container by hand showed the processor loaded and `curl.exe` returned `CUSTOM-OK`. Root cause:
    PowerShell `Invoke-WebRequest -UseBasicParsing` returns `.Content` as a **`System.Byte[]`** (which
    has no `.Trim()`) when the HTTP response carries **no `Content-Type` header** — exactly what a custom
    processor that sets only `StatusCode` produces. `.Content.Trim()` threw, got caught, blanked the body
    → exit 1. (E03/E05/E06 used `StaticResponseProcessor` with `text/plain`, so IWR returned a string and
    they passed.) **Fix:** all Docker body live-gates now use `curl.exe -s` (Content-Type-agnostic string
    output, matching the BUILD.md smoke pattern). Lesson: the verify harness itself must be robust to
    valid-but-headerless responses; don't let a host-shell quirk masquerade as a generation failure.

14. **Compose must publish only the service you curl — never an internal dependency's port (s13#19).**
    **E03** (mocker + redis via docker-compose) failed because my own `build-mocker-image` skill §9
    example published redis as `ports: ["6379:6379"]`, which collided with the persistent lab
    `qaas-lab-redis` already bound to host 6379 → `docker compose up` aborted with
    `Bind for 0.0.0.0:6379 failed: port is already allocated`, so the mocker never started. Internal
    dependencies reach each other by **compose service name** (`redis:6379`) and need **no host
    mapping**. **Fix:** corrected skill §9 to publish only the mocker, added Fact Base **s13#19**, and
    rewrote the E03 sprint so redis is internal-only and only `8125:8080` is published. E03 then passed
    iter 1. Lesson: distinguish a *real skill defect* (the §9 example) from a *mis-specified rig*; here
    the skill was wrong and fixing it fixed the scenario.

15. **Six genuinely distinct Docker facets, all built and run for real.** The docker-image category
    isn't one Dockerfile six times — each scenario exercises a different real capability: **E01**
    single-image build+run; **E02** controller-backed (Redis) stub in an image; **E03** docker-compose
    with an internal redis; **E04** a custom `BaseTransactionProcessor` compiled *into* the image;
    **E05** an env-driven (`sh -c $QAAS_MOCKER_CONFIG`) ENTRYPOINT; **E06** a CI `build.ps1` that the
    verify step *executes*. All six end in a real `docker build` + `docker run`/`compose up` + an HTTP
    curl against the live container on a unique host port (8094/8124/8125/8126/8127/8128). This is the
    category most likely to drift from docs, so every facet is anchored to a Fact Base trap
    (aspnet-vs-runtime base #7, inline-comment #18, compose internal-dep #19).

16. **Weak models cite line numbers from their *prompt*, not the *file* (H01).** Asked to profile a
    52-line `Program.cs`, the model cited `Program.cs:641` — the line where `MapGet` appeared in its
    assembled **context document**, not in the source file. All mechanical verifies passed (the strings
    existed); only the strong evaluator's plausibility check (citation vs file length) caught it.
    **Fix (ecosystem, not scenario):** `analyze-sut-repo` gained a **line-number discipline** rule
    (count from line 1 of THAT file; sanity-check against file length; omit rather than guess) + a
    "context-relative line numbers" trap row; the harness context header gained a CITATION RULE; and
    Constitution Article X now pins citation semantics. Re-run: H01 passed 2/2 iter 1.

17. **`Start-Job` + `Start-Process -NoNewWindow` deadlocks console apps (operational).** The first
    H-wave returned 0/7 — every trial timed out at 600s. The copilot CLI hangs at startup when spawned
    `-NoNewWindow` inside a PowerShell background job (jobs have no parent console to attach to).
    **Fix:** `-WindowStyle Hidden` (child gets its own hidden console). Proven by a 3-concurrent repro,
    then the full wave: 6/7 first pass.

18. **Fetch-before-ask: clarifications that name a document are routing errors (C02 regression).**
    A regression re-run had the generator emit `NEEDS_CLARIFICATION: ... probe schema (FB s11 §11.1)
    not in context` — refusing to guess (correct!) but asking a *human* for a fact that lives in a
    *document* (wrong channel; production would just run `/qaas:fact s11`). **Fix:** the generator
    persona now carries an explicit ROUTING RULE (named doc/slice ⇒ `NEEDS_CONTEXT`; clarification
    only for user-intent/environment facts no document answers), `loop.ps1` rescues slice-shaped
    clarifications by injecting the named slice and retrying once, and Constitution Article XI gained
    FETCH-BEFORE-ASK on both surfaces. Re-run: the misroute disappeared (YAML authored iter 1).

19. **The runner resolves config paths against the process CWD — and a verify step that forgets this
    is a scenario bug the model can out-diagnose (C02).** FB s07 already documents
    `CouldNotFindConfigurationException … resolves against CWD, not project dir`; C02's own verify
    ran `dotnet run --project Telemetry … template telemetry.qaas.yaml` from the artifacts root while
    the task spec mandated `Telemetry/telemetry.qaas.yaml` — unwinnable as written. The earlier green
    had slipped through on a duplicate root copy of the YAML. The weak model actually **root-caused
    the harness defect itself** on iter 3 ("YAML relocated … to fix harness file-not-found") and went
    green. **Fix:** C02's verify now `cwd: Telemetry` (the proven A03 pattern), so the task spec and
    the gate agree. Lesson: verify commands must obey the same FB facts the model is graded on.

> **Run trials serially.** When trials run *inside* an interactive Copilot session, the nested evaluator
> child can occasionally spin under parallel-shell contention; the same evaluator runs fine in isolation
> (~2 min). This is a test-execution artifact of nesting Copilot-in-Copilot, **not** a defect in the
> shipped plugin (which runs in Claude Code directly). Mitigation: run one trial at a time with
> `QAAS_TRIAL_TIMEOUT_SEC=600`; the Invoke-Model retry self-heals a hang by killing + respawning fresh.

## Reproduce

```powershell
cd eval
.\run-trial.ps1 -ScenarioId D02 -MaxIterations 3      # one scenario
# result JSON + full transcript land in work\trials\<scenario>-<timestamp>\
```

Requirements: .NET 10 SDK, Docker Desktop (for mocker-image + broker scenarios), the QaaS NuGets
reachable (nuget.org or your Artifactory mirror), and model API access for the generator/evaluator.
See [AIRGAP.md](../AIRGAP.md) for the offline wiring.
