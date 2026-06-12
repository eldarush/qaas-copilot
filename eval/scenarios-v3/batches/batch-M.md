# Batch M — ADVANCED MOCKER Scenarios (M-101..M-150)
# Category: advanced-mocker | Total: 50 | Tiers: T3×10, T4×20, T5×20
# FB anchors: s03-mocker-yaml, s13-doc-drift
# Generated for QaaS evaluation harness — models have ONLY docs + Fact Base + ready NuGets

---

### M-101: Dual-Port HTTP Mocker with Health and Business Routes
Tier: T3
Goal: Author a single mocker YAML with two `Http` servers on distinct ports — port 8101 serving `/health` and port 8102 serving `/api/orders`.
SUT: A platform team's service scaffold; no live service exists yet — endpoint is under development.
MOCK_REQUIRED: yes — service under development; no real endpoint is deployed to any environment.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration not TransactionData), s13#5 (Path keeps leading slash on server side), s13#5b (routes must be lowercase end-to-end), s13#8 (QaaS.Common.Processors ref required)
Hard because:
- Two `Http:` blocks under `Servers:` with distinct ports; must avoid `Server:` singular trap.
- `ProcessorConfiguration` key must be exact (s13#1); wrong key silently ignored.
- Route on runner side must be lowercase with no leading slash (s13#5/#5b).
Verify (mechanical):
- `dotnet build` exit 0 for mocker project.
- `dotnet run -- template` exit 0, both server ports present in resolved config.
- Mocker boots; `curl http://localhost:8101/health` → 200; `curl http://localhost:8102/api/orders` → 200.
Rubric (graded):
- 9-10: Both ports bound, correct keys, lowercase routes, hermetic count guard in runner.
- 6-8: Both ports correct but missing count guard or minor key typo caught by template.
- 1-5: Single server only, or TransactionData trap hit, or route 404.
Solution sketch: Define `Servers:` list with two `Http:` entries each having unique `Port:` and `Endpoints:` with lowercase `Path:`; bind each to a `StaticResponseProcessor` stub with `ProcessorConfiguration:`; reference `QaaS.Common.Processors` in csproj.

---

### M-102: ProcessorConfiguration vs TransactionData Trap (Static Stub)
Tier: T3
Goal: Author a mocker stub that uses `ProcessorConfiguration:` correctly — proving the model avoids the `TransactionData:` doc-drift trap.
SUT: Any greenfield HTTP mock; the real service returns a fixed JSON blob — no real endpoint accessible in CI.
MOCK_REQUIRED: yes — CI environment has no external network; mock is the only available response source.
FB slices: s03, s13
Trap mines: s13#1 (TransactionData → ProcessorConfiguration), s13#11 (typo keys silently ignored), s13#8 (Processors package ref)
Hard because:
- The official quickstart docs still show `TransactionData:` — model trained on those will silently fail.
- Silent ignore of wrong key means the stub runs but returns default empty body (not failure), masking the bug.
- Evaluator must check the actual response body, not just HTTP 200.
Verify (mechanical):
- `dotnet run -- template` shows `ProcessorConfiguration` (not `TransactionData`) in resolved config.
- `curl` to stub endpoint returns expected body string verbatim.
- No `TransactionData` key present anywhere in the YAML.
Rubric (graded):
- 9-10: `ProcessorConfiguration:` used, body verified, template confirms schema.
- 6-8: Correct key but body not verified or template step skipped.
- 1-5: `TransactionData:` used; stub silently ignores config; body is empty/default.
Solution sketch: Author stub with `Processor: StaticResponseProcessor` and `ProcessorConfiguration: { Body: ..., StatusCode: 200, ContentType: application/json }` per s03 reference example; verify via `dotnet run -- template`.

---

### M-103: Lowercase Route End-to-End Trap
Tier: T3
Goal: Demonstrate and correctly handle the mocker's case-sensitive route matching — a mixed-case `Path:` and `Route:` both lowercased to avoid 404.
SUT: Legacy API with a camelCase endpoint name (`/getOrderStatus`); mock is needed because the real service is only in production.
MOCK_REQUIRED: yes — production-only service; no staging or dev instance available.
FB slices: s03, s13
Trap mines: s13#5b (mocker lowercases Path to build regex, runner sends Route verbatim — must both be lowercase), s13#5 (runner Route has no leading slash)
Hard because:
- Mocker lowercases `Path` → `FixedPath = Path.ToLowerInvariant()` then builds case-sensitive regex.
- Runner sends `Route:` verbatim — any uppercase → no match → 404 → vacuous HttpStatus pass.
- Developer instinct is to mirror the real endpoint's casing.
Verify (mechanical):
- `curl http://localhost:PORT/getorderstatus` → 200 (lowercase path works).
- `curl http://localhost:PORT/getOrderStatus` → 404 (mixed case, proves the trap).
- Runner session with lowercase `Route: getorderstatus` → HttpStatus assertion passes non-vacuously.
Rubric (graded):
- 9-10: Both mocker Path and runner Route lowercase; count guard present; 404 variant documented.
- 6-8: Correct lowercase but missing count guard.
- 1-5: Mixed-case Route → 404; HttpStatus vacuous pass not caught.
Solution sketch: Set mocker `Path: /getorderstatus` (lowercase, with leading slash on server side) and runner `Route: getorderstatus` (no leading slash, lowercase); add `HermeticByExpectedOutputCount` guard per s13#13.

---

### M-104: Latency Injection via DelayProcessor
Tier: T3
Goal: Configure a stub using `DelayProcessor` with `ProcessorConfiguration` to inject a fixed 500 ms delay before responding, then assert the runner observes elevated latency.
SUT: A payment gateway's slow confirmation endpoint; no test environment exposes controllable latency.
MOCK_REQUIRED: yes — no test double exists for the payment gateway; latency must be synthetic.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#8 (QaaS.Common.Processors ref), s13#9 (package version 1.5.1 for Common.Processors)
Hard because:
- `DelayProcessor` configuration key and shape must be exact; typos silently ignored (s13#11).
- Runner-side latency assertion must use correct assertion type from `QaaS.Common.Assertions`.
- Version mismatch (e.g., using 4.5.1 on Common.Processors) → NU1102 build failure.
Verify (mechanical):
- `dotnet build` exit 0 with `QaaS.Common.Processors 1.5.1` reference.
- Mocker boots; endpoint responds with ≥ 500 ms observable delay.
- Runner latency assertion passes; output count guard is non-zero.
Rubric (graded):
- 9-10: Correct processor, correct version, latency assertion passes, count guard present.
- 6-8: Delay works but latency assertion missing or wrong version referenced.
- 1-5: Wrong processor key, missing package ref, or build fails.
Solution sketch: Set `Processor: DelayProcessor` with `ProcessorConfiguration: { DelayMs: 500 }` (verify exact key via `template`); reference `QaaS.Common.Processors 1.5.1`; add runner latency assertion from `QaaS.Common.Assertions 3.5.1`.

---

### M-105: Not-Found Fallback Default Stub Behavior
Tier: T3
Goal: Verify that the mocker's auto-generated not-found stub returns 404 for unregistered routes, and that the runner correctly handles — rather than vacuously passes — this response.
SUT: A microservice router; production returns 404 for unmapped paths — no staging environment available.
MOCK_REQUIRED: yes — staging environment decommissioned; only production exists.
FB slices: s03, s13
Trap mines: s13#13 (HttpStatus vacuous pass on zero outputs), s13#6 (missing output → null reference), s13#4 (HttpStatus key shape: StatusCode + OutputNames list)
Hard because:
- Default not-found stub is auto-generated at runtime — must not be redeclared.
- Runner must explicitly target the unregistered path and assert 404 StatusCode.
- Vacuous pass trap: if output is empty, HttpStatus 404 assertion passes without real validation.
Verify (mechanical):
- Mocker boot log shows `Built 4 transaction stub(s) including default not-found and internal-error stubs`.
- `curl` to registered path → 200; unregistered path → 404.
- Runner session: HttpStatus assertion with `StatusCode: 404` + count guard passes non-vacuously.
Rubric (graded):
- 9-10: Auto-stub leveraged, count guard present, 404 assertion non-vacuous.
- 6-8: 404 assertion works but count guard absent.
- 1-5: Model attempts to declare custom 404 stub conflicting with auto-generated one, or vacuous pass uncaught.
Solution sketch: Register only the success path stub; runner sends request to unregistered route; assert `StatusCode: 404` with `OutputNames:` list and `HermeticByExpectedOutputCount: 1`.

---

### M-106: JSON Content-Type Response Simulation
Tier: T3
Goal: Author a mocker stub that returns a structured JSON body with `Content-Type: application/json` and assert the runner parses a specific field value.
SUT: A catalog service returning product JSON; service is third-party SaaS — not accessible in test environments.
MOCK_REQUIRED: yes — third-party SaaS; no sandbox or test environment is provided by the vendor.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#4 (HttpStatus StatusCode + OutputNames), s13#11 (typo in ContentType key silently ignored)
Hard because:
- `ContentType` key in `ProcessorConfiguration` must be exact; wrong spelling returns default content-type.
- JSON body must be valid JSON string in YAML — escaping required.
- Runner-side field assertion must reference correct output name.
Verify (mechanical):
- `curl -i` shows `Content-Type: application/json` response header.
- Runner `JsonField` assertion extracts expected field value successfully.
- Output count guard is non-zero (non-vacuous).
Rubric (graded):
- 9-10: Correct ContentType, valid JSON body, field assertion passes, count guard present.
- 6-8: Correct content-type but field assertion skipped or wrong output name.
- 1-5: ContentType key typo → wrong content-type returned; assertion fails or vacuous.
Solution sketch: Set `ProcessorConfiguration: { Body: '{"id":1,"name":"widget"}', StatusCode: 200, ContentType: application/json }` under `StaticResponseProcessor` stub; use `JsonFieldAssertion` from `QaaS.Common.Assertions 3.5.1`.

---

### M-107: 5xx Fault Injection Stub
Tier: T3
Goal: Configure a stub to return HTTP 500 with an error body to simulate a downstream service failure, then assert the runner correctly handles and records the error response.
SUT: A payment processor that occasionally returns 500; no test environment exposes fault injection.
MOCK_REQUIRED: yes — payment processor has no sandbox fault-injection capability; only production exists.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#4 (StatusCode in assertion, not ExpectedStatus), s13#13 (vacuous pass if zero outputs)
Hard because:
- Model must explicitly configure `StatusCode: 500` in `ProcessorConfiguration` (not default 200).
- Runner assertion must use `StatusCode:` key (not outdated `ExpectedStatus:` — s13#4).
- Count guard essential: an unreachable mocker still "passes" HttpStatus vacuously.
Verify (mechanical):
- `curl` to stub endpoint returns HTTP 500.
- Runner HttpStatus assertion with `StatusCode: 500` passes.
- `HermeticByExpectedOutputCount: 1` guard ensures non-vacuous evaluation.
Rubric (graded):
- 9-10: Correct StatusCode 500 in both stub and assertion, non-vacuous count guard.
- 6-8: 500 configured but outdated `ExpectedStatus:` used in assertion.
- 1-5: StatusCode missing from ProcessorConfiguration; stub returns 200; assertion vacuously passes.
Solution sketch: `ProcessorConfiguration: { StatusCode: 500, Body: '{"error":"internal"}', ContentType: application/json }` on a `StaticResponseProcessor`; runner asserts `StatusCode: 500` with `OutputNames:` list and `HermeticByExpectedOutputCount: 1`.

---

### M-108: Pagination Simulation via SequenceProcessor
Tier: T3
Goal: Use `SequenceProcessor` to return page-1 on first call and page-2 on second call from the same endpoint, simulating a paginated API.
SUT: A report-export service with cursor-based pagination; staging environment is behind a VPN unreachable from CI.
MOCK_REQUIRED: yes — staging VPN unreachable from CI; mock must simulate paginated responses.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#8 (QaaS.Common.Processors ref), s13#11 (sequence config key typos silently ignored)
Hard because:
- `SequenceProcessor` config shape must be confirmed via `template` — docs don't show it fully.
- Runner must issue two transactions to the same route and assert different body content per call.
- DataSourceNames may be required to feed the sequence responses (s13#3).
Verify (mechanical):
- First runner transaction → body contains page-1 data.
- Second runner transaction → body contains page-2 data.
- Both output count guards pass non-vacuously.
Rubric (graded):
- 9-10: Sequence advances correctly, both pages asserted, count guards present.
- 6-8: Sequence configured but only first page asserted.
- 1-5: `StaticResponseProcessor` used instead (always returns same page); no sequence behavior.
Solution sketch: Define `Processor: SequenceProcessor` with `ProcessorConfiguration` listing ordered responses; run two sequential runner transactions targeting same route; assert distinct body content per transaction.

---

### M-109: Rate-Limit Simulation (429 + Retry-After Header)
Tier: T3
Goal: Simulate a rate-limited API — first N requests return 200, then subsequent requests return 429 with `Retry-After: 60` header, using `SequenceProcessor`.
SUT: A third-party SMS gateway with per-minute rate limiting; no sandbox supports rate-limit testing.
MOCK_REQUIRED: yes — vendor sandbox does not expose rate-limit behavior; must be synthetic.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#4 (StatusCode assertion shape), s13#8 (Processors package), s13#13 (vacuous pass on zero outputs)
Hard because:
- Must configure response headers (Retry-After) in `ProcessorConfiguration` — key shape must be exact.
- SequenceProcessor must transition from 200 to 429 states deterministically.
- Asserting custom response headers requires correct assertion type from `QaaS.Common.Assertions`.
Verify (mechanical):
- First two requests → 200.
- Third request → 429 with `Retry-After: 60` header present.
- Runner HttpStatus assertion for 429 passes non-vacuously.
Rubric (graded):
- 9-10: Sequence 200→429, header asserted, count guards present.
- 6-8: Status code correct but Retry-After header not asserted.
- 1-5: Static 429 only (no sequence), or vacuous pass not caught.
Solution sketch: `SequenceProcessor` with two `StaticResponseProcessor`-shaped entries in sequence — first returning 200, then returning 429 with `Headers: { Retry-After: "60" }` in `ProcessorConfiguration`; assert via `HttpStatus` and header assertion.

---

### M-110: Request Echo Processor
Tier: T3
Goal: Configure a stub using `EchoProcessor` (or equivalent) to mirror the request body back as the response body, asserting the runner receives its own payload.
SUT: A message transformation service in early development; no deployed instance exists yet.
MOCK_REQUIRED: yes — service in early development; no environment is deployed.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#8 (QaaS.Common.Processors ref), s13#11 (processor name typo silently fails at runtime)
Hard because:
- Processor name must be exact character-for-character (no validation at config parse time).
- Echo behavior must be confirmed via `template` — exact ProcessorConfiguration shape not well-documented.
- Runner-side body assertion must match the exact sent payload.
Verify (mechanical):
- Runner sends POST with body `{"echo":"test"}`.
- Response body matches sent payload verbatim.
- Output count guard non-zero.
Rubric (graded):
- 9-10: Correct processor name, echo verified, count guard present.
- 6-8: Echo works but body assertion skipped or approximate.
- 1-5: Wrong processor name → runtime error; or StaticResponseProcessor used instead (no real echo).
Solution sketch: Author stub with correct echo processor name (confirmed via `dotnet run -- template`); runner POSTs body and asserts `BodyEquals` or `BodyContains` on response matching sent content.

---

### M-111: Three-Server Mocker (HTTP + HTTP + HTTP, Distinct Ports)
Tier: T4
Goal: Author a mocker YAML with exactly three `Http:` servers on ports 8111, 8112, 8113 — each serving a different microservice domain — and assert all three via a single runner session.
SUT: A distributed order-management system with separate auth, catalog, and checkout services; no shared test environment exists.
MOCK_REQUIRED: yes — test environment decommissioned; three services must be mocked locally.
FB slices: s03, s13
Trap mines: s13#8 (Processors package ref), s13#5b (all routes lowercase on both sides), s13#9 (version independence — Common.Processors 1.5.1 not 4.5.1), s13#16 (PORT CONTRACT: probe/mocker/runner ports must match exactly)
Hard because:
- Three `Http:` blocks under `Servers:` with unique ports; duplicate port → fail-fast error.
- PORT CONTRACT (s13#16): TCP probe, mocker `Port:`, and runner `Http.Port` must be one literal each.
- All three paths and routes must be lowercase end-to-end (s13#5b).
Verify (mechanical):
- `dotnet run -- template` resolves three server entries with distinct ports.
- All three `curl` calls return 200 on respective ports.
- Runner session asserts all three services; all count guards non-zero.
Rubric (graded):
- 9-10: Three servers, all routes lowercase, PORT CONTRACT honored, count guards on all three.
- 6-8: Three servers correct but one route mixed-case or one count guard missing.
- 1-5: Only two servers defined, or duplicate port, or PORT CONTRACT violated.
Solution sketch: Define `Servers:` list with three `Http:` entries on 8111/8112/8113; each has one lowercase-path endpoint linked to a `StaticResponseProcessor` stub; runner session has three transactions with matching lowercase routes and three count guards.

---

### M-112: Redis Controller Mid-Run Stub Swap
Tier: T4
Goal: Use the Redis controller to send a swap command that replaces the active stub mid-run, then verify the runner observes the new response on subsequent transactions.
SUT: A feature-flag service that changes behavior based on remote config; no test harness supports dynamic behavior injection.
MOCK_REQUIRED: yes — real feature-flag service has no test-mode behavior switching capability.
FB slices: s03, s13
Trap mines: s13#11 (Controller.ServerName must match Runner MockerCommands[].ServerName byte-for-byte), s13#10 (real controller boot log: "Initialized Redis controller..."), s13#19 (Redis port publishing — only expose mocker, not Redis internally)
Hard because:
- `Controller.ServerName` in mocker YAML must exactly match `MockerCommands[].ServerName` in runner YAML.
- Redis must be reachable by both runner and mocker; Docker compose must not expose Redis host port (s13#19).
- Runner must issue transactions BEFORE and AFTER the swap command to prove behavioral change.
Verify (mechanical):
- Mocker boot log contains `Initialized Redis controller for server`.
- Pre-swap transactions return stub-A response; post-swap transactions return stub-B response.
- Both output count guards non-zero.
Rubric (graded):
- 9-10: Swap executed mid-run, before/after responses differ, count guards present.
- 6-8: Controller configured correctly but only post-swap response asserted.
- 1-5: `Controller.ServerName` mismatch → controller skipped silently; no swap occurs.
Solution sketch: Configure `Controller: { ServerName: order-mock }` in mocker YAML and `MockerCommands: [{ ServerName: order-mock, ... }]` in runner YAML with byte-for-byte match; issue swap command between two transaction stages.

---

### M-113: Stateful Conversation Mock via SequenceProcessor
Tier: T4
Goal: Model a multi-step API conversation (init → process → confirm) using `SequenceProcessor` where each call to the same endpoint returns the next response in a predefined sequence.
SUT: A loan-application workflow service; staging environment has unstable stateful sessions unsuitable for CI.
MOCK_REQUIRED: yes — staging has unstable sessions; CI requires deterministic stateful mock.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#8 (Processors ref), s13#3 (DataSourceNames may be required to supply sequence data), s13#11 (sequence config keys silently ignored if wrong)
Hard because:
- SequenceProcessor must advance state per request — config shape must be confirmed via `template`.
- Runner must issue three sequential transactions and assert unique response per step.
- DataSourceNames may be needed if sequence reads from a data file (s13#3).
Verify (mechanical):
- Transaction 1 → `{"step":"init","status":"accepted"}`.
- Transaction 2 → `{"step":"process","status":"processing"}`.
- Transaction 3 → `{"step":"confirm","status":"approved"}`.
- All three count guards pass.
Rubric (graded):
- 9-10: All three steps return correct responses, count guards on all, DataSourceNames correct if used.
- 6-8: Sequence advances but only two steps asserted.
- 1-5: Static processor used; all three steps return identical response.
Solution sketch: `SequenceProcessor` stub with three entries in `ProcessorConfiguration`; runner session with three transactions to the same route with per-transaction body assertions; `HermeticByExpectedOutputCount: 1` per transaction.

---

### M-114: Conditional Routing on Request Header
Tier: T4
Goal: Configure two stubs on the same route where routing is determined by the `X-Tenant-Id` request header — one stub for `tenant-a`, another for `tenant-b`.
SUT: A multi-tenant SaaS API; production tenant isolation cannot be tested in shared dev environments.
MOCK_REQUIRED: yes — shared dev environment cannot safely isolate tenant data; mock is required.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#5b (lowercase route), s13#11 (header matching config key must be exact), s13#8 (Processors ref)
Hard because:
- Header-conditional routing may require a custom processor or specific built-in with header-matching config.
- Config shape for header matching must be confirmed via `template` — docs don't fully specify it.
- Both stubs must be reachable on the same endpoint path; wrong routing → wrong tenant response.
Verify (mechanical):
- `curl -H "X-Tenant-Id: tenant-a"` → response A body.
- `curl -H "X-Tenant-Id: tenant-b"` → response B body.
- Both runner transactions with distinct headers assert correct bodies; count guards present.
Rubric (graded):
- 9-10: Header routing works for both tenants, bodies asserted, count guards non-zero.
- 6-8: Header routing works but only one tenant asserted.
- 1-5: Same stub returned regardless of header (no routing logic); or build fails.
Solution sketch: Use a header-conditional processor (verify exact type via `template`/s03) with `ProcessorConfiguration` specifying header name and value for each stub; two runner transactions with distinct `X-Tenant-Id` headers.

---

### M-115: Auth Handshake Mock (401 → Token → 200 Flow)
Tier: T4
Goal: Simulate a two-step auth flow: first request returns 401 Unauthorized; after client sends credentials to `/token`, a bearer token is returned; subsequent requests with `Authorization: Bearer <token>` return 200.
SUT: A secure internal API with OAuth2-style auth; no test environment accepts synthetic tokens.
MOCK_REQUIRED: yes — test environment rejects non-production tokens; auth flow must be fully mocked.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#4 (StatusCode assertion shape), s13#5b (lowercase routes for both /token and /resource), s13#13 (vacuous pass if auth request never reaches mocker)
Hard because:
- Two distinct endpoints required: `/token` and `/resource` with different stubs.
- SequenceProcessor on `/resource`: first call returns 401, second (with auth header) returns 200.
- Runner must assert 401 on first transaction and 200 on second; count guards on both.
Verify (mechanical):
- `curl /token` → 200 with `{"access_token":"mock-token"}`.
- `curl /resource` (no auth) → 401.
- `curl /resource -H "Authorization: Bearer mock-token"` → 200.
- Runner: two transactions, HttpStatus 401 and 200 both asserted non-vacuously.
Rubric (graded):
- 9-10: Both endpoints correct, 401→200 sequence, auth header routing, count guards.
- 6-8: Endpoints correct but 401 not asserted or count guard missing.
- 1-5: Single static 200 stub; no auth flow simulation.
Solution sketch: `/token` stub returns static `{"access_token":"mock-token"}`; `/resource` stub uses `SequenceProcessor` returning 401 then 200; runner transactions in two stages with header injection between them.

---

### M-116: Webhook Callback Mock
Tier: T4
Goal: Mock a webhook receiver endpoint that the SUT POSTs events to, then assert the runner captured the incoming webhook payload.
SUT: A payment processor that fires webhooks on payment events; no staging webhook receiver is available.
MOCK_REQUIRED: yes — no staging webhook receiver; payment processor webhooks cannot be replayed in dev.
FB slices: s03, s13
Trap mines: s13#5b (lowercase path for webhook endpoint), s13#1 (ProcessorConfiguration), s13#6 (missing output → null reference if webhook body not captured), s13#13 (vacuous pass if SUT never fires)
Hard because:
- Mocker must be the POST target for incoming webhooks (inverted from normal mock usage).
- Runner must be configured to capture and assert the incoming POST body, not send one.
- Vacuous pass trap: if SUT never fires the webhook, HttpStatus and body assertions pass vacuously.
Verify (mechanical):
- SUT fires POST to mocker webhook endpoint; mocker returns 200.
- Runner captures the POST body and asserts expected event fields.
- Count guard ensures at least one webhook was received.
Rubric (graded):
- 9-10: Webhook received, body asserted, count guard non-zero.
- 6-8: Webhook received and 200 returned but body not asserted.
- 1-5: Mocker sends request instead of receiving; or vacuous pass uncaught.
Solution sketch: Define mocker endpoint at lowercase `/webhook` accepting POST via `StaticResponseProcessor` returning 200 acknowledgement; runner session captures incoming transaction and asserts body fields; `HermeticByExpectedOutputCount: 1`.

---

### M-117: Idempotency-Key Behavior Simulation
Tier: T4
Goal: Simulate idempotency behavior — identical requests with the same `Idempotency-Key` header return the cached first response; different keys get fresh responses.
SUT: A payment API implementing idempotency keys; no test environment enforces idempotency contracts.
MOCK_REQUIRED: yes — test environment does not enforce idempotency; behavior must be synthetically simulated.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#11 (header matching key exact), s13#8 (Processors ref), s13#13 (vacuous pass on empty outputs)
Hard because:
- Must distinguish repeated requests by `Idempotency-Key` header value — requires conditional processor.
- SequenceProcessor alone can't simulate caching by header; may require custom processor.
- Runner must send same key twice and different key once; assert different bodies per scenario.
Verify (mechanical):
- Request with `Idempotency-Key: k1` → response R1.
- Repeated request with `Idempotency-Key: k1` → same response R1 (idempotent).
- Request with `Idempotency-Key: k2` → response R2 (different key, fresh response).
Rubric (graded):
- 9-10: Idempotency enforced correctly for same and different keys; all count guards non-zero.
- 6-8: Same-key idempotency works but different-key not tested.
- 1-5: SequenceProcessor used naively; ignores header; no idempotency semantics.
Solution sketch: Use a header-conditional processor configured with `Idempotency-Key` header matching; define two response stubs for `k1` and `k2`; or design SequenceProcessor chain that holds state per key via DataSources.

---

### M-118: 5xx Storm Simulation (Repeated Failures then Recovery)
Tier: T4
Goal: Simulate a service outage pattern — five consecutive 503 responses followed by successful 200 recovery — to test the runner's retry and circuit-breaker behavior.
SUT: A flaky microservice dependency; no chaos engineering tooling is available in test environments.
MOCK_REQUIRED: yes — no chaos tooling in test environment; failure pattern must be synthetic.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#4 (StatusCode 503 in assertion), s13#8 (Processors ref), s13#13 (vacuous pass if runner never retries)
Hard because:
- SequenceProcessor must return exactly five 503s then one 200 — count must be precise.
- Runner must be configured to retry on 503 and assert final 200.
- Both 503 and 200 count guards needed; if runner stops after first 503 the 200 count guard fails.
Verify (mechanical):
- Requests 1-5 → 503 Service Unavailable.
- Request 6 → 200 OK.
- Runner retry logic reaches the 200; HttpStatus 200 assertion count guard passes.
Rubric (graded):
- 9-10: 5× 503 then 200, retry logic in runner, all count guards correct.
- 6-8: Sequence correct but runner retry not configured or count guard absent.
- 1-5: Static 503 or static 200; no sequence; or sequence count wrong.
Solution sketch: `SequenceProcessor` with five `{ StatusCode: 503 }` entries followed by one `{ StatusCode: 200, Body: "OK" }` entry; runner configured with retry count ≥ 5; count guards for both 503 and 200 outcomes.

---

### M-119: Malformed JSON Fault Injection
Tier: T4
Goal: Configure a stub to return an intentionally malformed JSON body (truncated or syntactically invalid) with `Content-Type: application/json`, to test the runner's error-handling for corrupt responses.
SUT: A data-ingestion pipeline that must handle corrupt upstream responses; no upstream can be configured to return bad JSON in dev.
MOCK_REQUIRED: yes — upstream cannot be configured to return corrupt data in any test environment.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#11 (ContentType key exact), s13#6 (runner may throw null reference on body parse failure), s13#13 (vacuous pass if output missing)
Hard because:
- Malformed JSON in YAML body string requires careful escaping.
- Runner JSON assertion will fail on parse error — must assert raw body contains substring instead.
- Must distinguish between "output received but invalid JSON" vs "no output received" (vacuous pass trap).
Verify (mechanical):
- `curl` returns HTTP 200 with body `{"truncated":` (invalid JSON).
- Runner receives output (count guard non-zero).
- Body substring assertion finds `"truncated"` without attempting JSON parse.
Rubric (graded):
- 9-10: Malformed JSON delivered, count guard non-zero, raw body assertion passes.
- 6-8: Malformed JSON delivered but JSON field assertion attempted (throws error).
- 1-5: Body defaults to valid JSON due to key typo; or vacuous pass; or count guard absent.
Solution sketch: `ProcessorConfiguration: { Body: '{"truncated":', StatusCode: 200, ContentType: application/json }`; runner asserts body contains `"truncated"` using `BodyContains` assertion, NOT `JsonFieldAssertion`.

---

### M-120: Binary Payload Response (Octet-Stream)
Tier: T4
Goal: Configure a mocker stub to return a binary payload (base64-encoded bytes) with `Content-Type: application/octet-stream`, simulating a file-download endpoint.
SUT: A document-storage service that returns file bytes; no test environment stores accessible binary assets.
MOCK_REQUIRED: yes — document service has no test assets; binary file responses must be synthetic.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#11 (ContentType exact), s13#8 (Processors ref), s13#13 (vacuous pass if Content-Type mismatch causes runner to reject response)
Hard because:
- Binary body in YAML must be represented correctly (base64 or literal bytes as string).
- `ContentType: application/octet-stream` must be exact in ProcessorConfiguration.
- Runner must assert response length or content bytes rather than text body.
Verify (mechanical):
- `curl -o output.bin` saves response; `wc -c output.bin` shows expected byte count.
- Content-Type header is `application/octet-stream`.
- Runner count guard non-zero; body length assertion passes.
Rubric (graded):
- 9-10: Correct binary payload, octet-stream content-type, body length asserted, count guard.
- 6-8: Binary returned but content-type wrong or body not asserted.
- 1-5: Text body used; ContentType key typo; or vacuous pass.
Solution sketch: `ProcessorConfiguration: { Body: "AAAA", StatusCode: 200, ContentType: application/octet-stream }`; verify body length assertion via `QaaS.Common.Assertions`; confirm content-type via `curl -i`.

---

### M-121: Cursor-Based Pagination Simulation
Tier: T4
Goal: Simulate a cursor-based pagination API where each response includes a `nextCursor` token, and the runner issues subsequent requests using that cursor until an empty page is returned.
SUT: A large-dataset analytics API with cursor pagination; no test dataset is small enough for predictable pagination in shared dev.
MOCK_REQUIRED: yes — analytics dataset is unpredictably large in shared dev; mock provides deterministic page sizes.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#3 (DataSourceNames required if sequence reads from file), s13#8 (Processors ref), s13#11 (sequence config keys exact)
Hard because:
- Three-step sequence: page-1 (with cursor), page-2 (with cursor), page-3 (empty, no cursor).
- Runner must extract `nextCursor` from response and inject into next request — requires variable extraction.
- DataSourceNames may be required to supply page data to SequenceProcessor.
Verify (mechanical):
- Transaction 1 → `{"items":[1,2],"nextCursor":"c2"}`.
- Transaction 2 with cursor `c2` → `{"items":[3,4],"nextCursor":"c3"}`.
- Transaction 3 with cursor `c3` → `{"items":[],"nextCursor":null}`.
- All three count guards non-zero.
Rubric (graded):
- 9-10: Three pages returned in sequence, cursor extraction and injection, all count guards.
- 6-8: Pages return correctly but cursor injection not implemented (manual hardcoded).
- 1-5: Static response; all three calls return same page.
Solution sketch: `SequenceProcessor` with three entries in order; runner uses variable extraction on `nextCursor` field and passes to next transaction; `DataSourceNames` provided if needed.

---

### M-122: Multi-Stub ProcessorConfiguration Chain on One Route
Tier: T4
Goal: Configure one endpoint to serve three different stubs in rotation (A/B/C) — stub A on first hit, stub B on second, stub C on subsequent hits — using `SequenceProcessor` with three `ProcessorConfiguration` entries.
SUT: A circuit-breaker-protected service with changing behavior across retry attempts; no test harness supports per-attempt response variation.
MOCK_REQUIRED: yes — no test harness supports per-retry response injection; must be mocked.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#8 (Processors ref), s13#9 (Common.Processors 1.5.1), s13#11 (sequence entry config keys exact)
Hard because:
- Three distinct `ProcessorConfiguration` entries in the sequence must each produce different status codes and bodies.
- Runner must issue exactly three transactions and assert each response independently.
- Version trap: using wrong `QaaS.Common.Processors` version (e.g., 4.5.1) → NU1102 build failure.
Verify (mechanical):
- Call 1 → `{ "attempt": 1, "status": "timeout" }` with HTTP 408.
- Call 2 → `{ "attempt": 2, "status": "error" }` with HTTP 500.
- Call 3 → `{ "attempt": 3, "status": "ok" }` with HTTP 200.
- All count guards non-zero.
Rubric (graded):
- 9-10: All three stubs distinct, correct status codes, count guards, correct package version.
- 6-8: Stubs cycle correctly but one status code wrong or count guard absent.
- 1-5: All three calls return same response; or package version causes build failure.
Solution sketch: `SequenceProcessor` with three `ProcessorConfiguration` entries each specifying distinct `StatusCode` and `Body`; runner session with three transactions; assert `StatusCode` and body per call; use `QaaS.Common.Processors 1.5.1`.

---

### M-123: Conditional Routing on Request Body Regex
Tier: T4
Goal: Route requests to different stubs based on a regex match against the request body — requests containing `"type":"express"` return one stub, `"type":"standard"` return another.
SUT: A shipping calculator that branches on order type; no test environment supports branching logic inspection.
MOCK_REQUIRED: yes — no test environment exposes branching behavior; mock controls routing logic.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#11 (body-matching config key exact), s13#5b (lowercase route), s13#8 (Processors ref)
Hard because:
- Body-regex routing may require a specific processor or conditional stub type — must confirm via `template`.
- YAML regex patterns may require escaping.
- If body routing is unsupported natively, custom processor is needed (s03 custom hook rules apply).
Verify (mechanical):
- POST with `{"type":"express"}` → response with `{"rate":15.99}`.
- POST with `{"type":"standard"}` → response with `{"rate":4.99}`.
- Both count guards non-zero.
Rubric (graded):
- 9-10: Body-regex routing works for both types, bodies asserted, count guards.
- 6-8: One type routes correctly but not both.
- 1-5: No routing logic; same stub returned for all body variants.
Solution sketch: Use a body-conditional processor (confirm name via `template`/s03); configure `ProcessorConfiguration` with body regex patterns for express vs standard; two runner transactions with distinct POST bodies.

---

### M-124: XML vs JSON Content-Type Negotiation
Tier: T4
Goal: Configure two stubs on the same route — one returns JSON when `Accept: application/json` is sent, another returns XML when `Accept: application/xml` — simulating a content-negotiation API.
SUT: A legacy enterprise API supporting both XML and JSON clients; no test environment accepts both protocols simultaneously.
MOCK_REQUIRED: yes — legacy API does not have a test environment that supports both content types.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#11 (ContentType key exact), s13#5b (lowercase route), s13#8 (Processors ref)
Hard because:
- `Accept` header routing requires a conditional processor — config shape must be confirmed via `template`.
- Both JSON and XML stubs must be on same route; only the Accept header differentiates.
- XML body in YAML requires careful escaping of `<` and `>` characters.
Verify (mechanical):
- `curl -H "Accept: application/json"` → `Content-Type: application/json` + JSON body.
- `curl -H "Accept: application/xml"` → `Content-Type: application/xml` + XML body.
- Runner asserts both; count guards present.
Rubric (graded):
- 9-10: Both content types routed correctly, headers and bodies asserted, count guards.
- 6-8: One content type correct; the other returns wrong type or same stub.
- 1-5: Single static stub ignores Accept header; one content type for all requests.
Solution sketch: Header-conditional processor on `Accept` header; `ProcessorConfiguration` for JSON stub: `{ ContentType: application/json, Body: '{"id":1}' }`; XML stub: `{ ContentType: application/xml, Body: "<id>1</id>" }`; two runner transactions.

---

### M-125: CORS Header Injection Mock
Tier: T4
Goal: Configure a mocker stub to return CORS headers (`Access-Control-Allow-Origin`, `Access-Control-Allow-Methods`) on both OPTIONS preflight and GET requests, simulating a CORS-enabled API.
SUT: A browser-facing API under development; CORS configuration cannot be tested against real endpoints without deploying to a CDN.
MOCK_REQUIRED: yes — CORS behavior requires CDN deployment to test against real endpoints; mock provides controlled header simulation.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#11 (response headers config key exact), s13#5b (lowercase routes), s13#9 (package versions)
Hard because:
- Two endpoints needed: OPTIONS (preflight) and GET (actual request) — both with CORS headers.
- `ProcessorConfiguration` headers map must use exact key name (verify via `template`).
- OPTIONS method must be explicitly listed in `Actions[].Method` (valid value per s03).
Verify (mechanical):
- OPTIONS request → 204 with `Access-Control-Allow-Origin: *` header.
- GET request → 200 with CORS headers and body.
- Runner asserts both response headers present; count guards non-zero.
Rubric (graded):
- 9-10: OPTIONS and GET both return CORS headers, method-level routing correct, count guards.
- 6-8: CORS headers present on GET but OPTIONS preflight not handled.
- 1-5: No CORS headers; headers config key typo silently ignored; or OPTIONS method not supported.
Solution sketch: Two `Actions` on same endpoint: `Method: Options` returning 204 with CORS headers and `Method: Get` returning 200 with body; `ProcessorConfiguration` includes `Headers:` map for both stubs.

---

### M-126: Stub Priority and Matching Order
Tier: T4
Goal: Define multiple stubs that could match the same request and verify the mocker applies the correct priority order — more specific (header-matched) stub wins over the generic fallback stub.
SUT: A versioned API that serves different contracts based on `API-Version` header; priority is business-critical and cannot be tested against production.
MOCK_REQUIRED: yes — production-only versioned API; no test environment supports multi-version isolation.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#11 (matching config keys exact), s13#13 (vacuous pass if lower-priority stub selected), s13#8 (Processors ref)
Hard because:
- Mocker stub priority/ordering semantics must be confirmed from docs — not obvious from YAML structure.
- Without proper priority, generic stub matches first; versioned stub never selected.
- Must prove both stubs ARE reachable — generic when no version header, specific when header present.
Verify (mechanical):
- `curl` without `API-Version` header → generic stub response.
- `curl -H "API-Version: v2"` → v2-specific stub response.
- Both count guards non-zero.
Rubric (graded):
- 9-10: Priority semantics correct, both stubs reachable, count guards.
- 6-8: V2 stub reachable but generic fallback not verified.
- 1-5: Generic stub always wins; v2 stub never selected; or priority semantics guessed incorrectly.
Solution sketch: Define header-specific stub before generic stub in YAML (order matters in mocker); `API-Version: v2` stub before generic fallback; two runner transactions to verify both paths.

---

### M-127: Connection Timeout Simulation
Tier: T4
Goal: Configure a stub to simulate a connection-level timeout by injecting a delay longer than the runner's configured HTTP timeout, verifying the runner records a timeout error output.
SUT: A slow third-party API that occasionally hangs indefinitely; no test environment allows connection timeout simulation.
MOCK_REQUIRED: yes — no test environment allows controllable connection timeout simulation.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#8 (Processors ref), s13#13 (vacuous pass if runner swallows timeout silently), s13#16 (PORT CONTRACT)
Hard because:
- Delay must exceed runner's HTTP timeout threshold — both values must be coordinated.
- Runner timeout behavior: does it produce an output with error status, or zero outputs?
- If zero outputs → vacuous pass trap; count guard must catch this.
Verify (mechanical):
- `DelayProcessor` with `DelayMs: 30000` (> runner timeout).
- Runner transaction records a timeout error in outputs.
- Count guard with expected error output non-zero; HttpStatus assertion catches the error.
Rubric (graded):
- 9-10: Timeout injected, runner records error output, count guard catches it.
- 6-8: Timeout injected but runner error behavior not asserted.
- 1-5: Delay less than timeout; runner succeeds; no timeout simulation.
Solution sketch: `DelayProcessor` with delay greater than runner `TimeoutMs` config; runner asserts on timeout/error output; `HermeticByExpectedOutputCount: 1` guards against vacuous pass.

---

### M-128: Multi-Path Routing on One Server Port
Tier: T4
Goal: Configure a single HTTP server with four distinct lowercase path endpoints (`/users`, `/orders`, `/products`, `/health`) each backed by separate stubs, and assert all four via one runner session.
SUT: A monolithic API gateway exposing multiple resource types; no shared dev environment is stable enough for integration tests.
MOCK_REQUIRED: yes — shared dev environment is unstable; mock provides a deterministic multi-resource gateway.
FB slices: s03, s13
Trap mines: s13#5b (all paths lowercase), s13#5 (runner Route no leading slash), s13#1 (ProcessorConfiguration), s13#16 (single PORT CONTRACT for all four routes)
Hard because:
- Four `Endpoints` entries under one `Http:` server — all paths must be lowercase.
- Runner must target all four with correct lowercase routes (no leading slash).
- Single PORT CONTRACT: probe/mocker/runner all use the same port literal.
Verify (mechanical):
- All four `curl` calls return 200 on respective paths.
- Runner session issues four transactions; all HttpStatus assertions pass.
- All four count guards non-zero.
Rubric (graded):
- 9-10: All four paths lowercase, all routes correct, single port consistent, count guards.
- 6-8: Three paths correct; one has a case or slash issue.
- 1-5: Multiple ports used instead of multiple paths; or fewer than four paths.
Solution sketch: One `Http:` block with `Port: 8128`; four `Endpoints` with lowercase `Path:` values and distinct `Actions`; four stubs; runner session with four transactions and four count guards.

---

### M-129: Dockerfile Base Image Trap (aspnet vs runtime)
Tier: T4
Goal: Build a mocker Docker image and verify it uses `mcr.microsoft.com/dotnet/aspnet:10.0` (not `runtime:10.0`) as the runtime base, catching the s13#7 drift trap before it causes a container startup failure.
SUT: A containerized mocker to be deployed in a Kubernetes test cluster; wrong base image causes silent startup failure.
MOCK_REQUIRED: yes — Kubernetes cluster only accepts containerized services; local process mock is not an option.
FB slices: s03, s13
Trap mines: s13#7 (aspnet vs runtime base image), s13#18 (no trailing comments on Dockerfile instruction lines), s13#9 (correct package versions in csproj)
Hard because:
- Scaffold may generate `runtime:10.0` by default — model must override per s13#7.
- Dockerfile inline comments on instruction lines cause parse errors (s13#18).
- Container startup failure from wrong base image gives no clear error until container is running.
Verify (mechanical):
- Dockerfile `FROM` runtime stage uses `mcr.microsoft.com/dotnet/aspnet:10.0`.
- `docker build` exits 0.
- `docker run` starts mocker; `curl /health` returns 200.
Rubric (graded):
- 9-10: aspnet base image, no inline Dockerfile comments, build and run succeed.
- 6-8: aspnet base image correct but inline comment on FROM line causes parse error.
- 1-5: `runtime:10.0` used; container starts but HTTP server fails; or build fails.
Solution sketch: Two-stage Dockerfile: `FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build` then `FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime`; no inline comments on instruction lines; `ENTRYPOINT ["dotnet", "mocker.dll"]`.

---

### M-130: Redis Port Publish Trap in Compose
Tier: T4
Goal: Author a `docker-compose.yml` for a mocker + Redis setup where ONLY the mocker port is published to the host, and Redis uses only the internal network — preventing the s13#19 port collision trap.
SUT: A containerized mocker that uses Redis for the controller channel; CI host may already have Redis on port 6379.
MOCK_REQUIRED: yes — CI host Redis conflicts prevent exposing Redis externally; mocker must use internal Redis only.
FB slices: s03, s13
Trap mines: s13#19 (only publish mocker port — not Redis; internal services use service-name routing), s13#7 (aspnet base), s13#16 (PORT CONTRACT for mocker port)
Hard because:
- Model instinct is to publish Redis port for debugging — but this collides with host Redis in CI.
- Mocker must connect to Redis via service name (`redis:6379`) not `localhost:6379`.
- PORT CONTRACT: only mocker port appears in published `ports:` map.
Verify (mechanical):
- `docker compose up` exits without `Bind for 0.0.0.0:6379 failed` error.
- `docker compose ps` shows mocker container running; Redis container running (no host port).
- `curl http://localhost:MOCKER_PORT/health` → 200.
Rubric (graded):
- 9-10: Only mocker port published, Redis internal-only, mocker connects via service name.
- 6-8: Compose works but Redis port published (passes locally but fails in CI with collision).
- 1-5: Redis port published; `docker compose up` fails with port-already-allocated error.
Solution sketch: Compose `redis:` service with NO `ports:` section; `mocker:` service with `ports: ["8130:8130"]`; mocker config references `redis:6379` as Redis connection string via env var.

---

### M-131: Four-Server Mocker Estate with Controller
Tier: T5
Goal: Author a mocker YAML with four HTTP servers on ports 8131–8134 — representing auth, catalog, cart, and checkout microservices — connected via a Redis controller, with all four asserted hermetially in a single runner session.
SUT: A full e-commerce microservices stack; no complete integration test environment exists; services are owned by separate teams.
MOCK_REQUIRED: yes — four services owned by separate teams; no shared integration environment is available.
FB slices: s03, s13
Trap mines: s13#16 (PORT CONTRACT × 4), s13#5b (all routes lowercase × 4 servers), s13#1 (ProcessorConfiguration × all stubs), s13#19 (Redis internal-only in compose), s13#11 (Controller.ServerName byte-for-byte match)
Hard because:
- Four distinct `Http:` servers under `Servers:` — each must have unique port, lowercase paths, correct stubs.
- Redis controller requires `Controller.ServerName` to match runner `MockerCommands[].ServerName` exactly.
- Compose: only mocker ports published; Redis internal; all four PORT CONTRACTs respected.
Verify (mechanical):
- `dotnet run -- template` resolves four server entries; no duplicate ports.
- All four `curl` calls return 200 on respective ports.
- Runner session: four transactions + controller command; all count guards non-zero.
- Controller boot log shows `Initialized Redis controller`.
Rubric (graded):
- 9-10: Four servers, controller connected, all routes lowercase, PORT CONTRACTs × 4, count guards × 4.
- 6-8: Four servers correct but controller not connected or one route has case issue.
- 1-5: Fewer than four servers, duplicate port, or controller ServerName mismatch.
Solution sketch: `Servers:` list with four `Http:` entries on 8131-8134; `Controller: { ServerName: ecommerce-mesh }`; runner `MockerCommands: [{ ServerName: ecommerce-mesh, ... }]`; four lowercase-route transactions; `HermeticByExpectedOutputCount: 1` per transaction.

---

### M-132: Controller Swaps Stubs Between Runner Sessions
Tier: T5
Goal: Run two separate runner sessions against the same mocker: session-1 sends a controller command to swap stub-A to stub-B; session-2 verifies the mocker now serves stub-B responses (proving cross-session stub persistence).
SUT: A configuration-driven service that changes behavior between deployments; no mechanism exists to inject mid-test behavior changes in any test environment.
MOCK_REQUIRED: yes — no test environment supports mid-run behavior injection between test sessions.
FB slices: s03, s13
Trap mines: s13#11 (Controller.ServerName byte-for-byte), s13#10 (real controller boot log vs docs), s13#15 (two verify steps don't share background process — mocker must stay running across both sessions), s13#13 (vacuous pass in session-2 if swap didn't execute)
Hard because:
- Mocker must remain running between session-1 and session-2 (s13#15: separate verify steps kill background process).
- Controller command must execute in session-1 and persist in mocker state for session-2.
- Session-2 count guard must prove stub-B was served, not stub-A or nothing.
Verify (mechanical):
- Session-1 completes; controller swap command logged in mocker output.
- Session-2 transactions return stub-B body (different from stub-A).
- Session-2 count guard non-zero.
- `grep` on mocker logs shows `Initialized Redis controller`.
Rubric (graded):
- 9-10: Mocker persists across sessions, swap executed, session-2 serves stub-B, count guard.
- 6-8: Swap executed but mocker restarted between sessions (swap lost); session-2 gets stub-A.
- 1-5: Sessions share no state; controller command has no effect.
Solution sketch: Single `cmd` in verify that starts mocker in background, runs session-1 (swap), runs session-2 (assert stub-B), then stops mocker — all in one shell command per s13#15; `HermeticByExpectedOutputCount: 1` in session-2.

---

### M-133: Auth Mock Gates a Webhook Flow
Tier: T5
Goal: Simulate a complete auth-gated webhook flow: runner first obtains a mock bearer token from `/token`, then registers a webhook callback at `/webhooks/register` (requires Bearer token), then receives a webhook POST to `/webhooks/callback` — all hermetically asserted.
SUT: A SaaS platform with OAuth2-gated webhook registration; no sandbox supports end-to-end auth+webhook flow testing.
MOCK_REQUIRED: yes — SaaS sandbox requires production credentials for OAuth2; webhook delivery cannot be triggered in dev.
FB slices: s03, s13
Trap mines: s13#5b (all three routes lowercase), s13#4 (StatusCode assertions), s13#13 (vacuous pass if any step skipped), s13#16 (PORT CONTRACT for single server hosting all three routes)
Hard because:
- Three-step flow: token → register → callback; each step depends on the previous.
- Bearer token from step-1 must be injected into step-2 request header via runner variable extraction.
- Webhook callback in step-3 is an INBOUND POST to the mocker — runner captures it as an output.
Verify (mechanical):
- Step-1 → `{"access_token":"mock-token","expires_in":3600}`.
- Step-2 with `Authorization: Bearer mock-token` → 201 Created.
- Step-3 mocker receives POST to `/webhooks/callback` → 200; body asserted.
- All three count guards non-zero.
Rubric (graded):
- 9-10: All three steps correct, token injection, callback captured, all count guards.
- 6-8: Steps 1-2 correct but callback step 3 not implemented or vacuous.
- 1-5: No auth injection; all requests return same stub; webhook callback not modeled.
Solution sketch: Three endpoints on one mocker server (port 8133); runner session in three stages: (1) GET `/token` → extract token variable; (2) POST `/webhooks/register` with Bearer header → assert 201; (3) assert incoming POST to `/webhooks/callback` with count guard.

---

### M-134: Full OAuth2 Authorization Code Flow Simulation
Tier: T5
Goal: Simulate a complete OAuth2 authorization code flow: `/authorize` → redirect with code → `/token` (exchange code for token) → `/userinfo` (Bearer-authenticated resource) — all four hops mocked and asserted.
SUT: An OAuth2 identity provider (IdP) in production; no sandbox IdP exists for the application under test.
MOCK_REQUIRED: yes — production IdP only; no sandbox or test tenant is available.
FB slices: s03, s13
Trap mines: s13#5b (all routes lowercase), s13#4 (StatusCode per step), s13#13 (vacuous pass on any step), s13#1 (ProcessorConfiguration), s13#16 (PORT CONTRACT)
Hard because:
- Four distinct endpoints with sequential dependency: code issued in step-1 used in step-2, token from step-2 used in step-3.
- Redirect response (302 with Location header) requires header injection in ProcessorConfiguration.
- Variable extraction chain: code → token → Bearer header across three runner transactions.
Verify (mechanical):
- `/authorize` → 302 with `Location` header containing `code=mock-code`.
- `/token` with `code=mock-code` → `{"access_token":"mock-token"}`.
- `/userinfo` with Bearer → `{"sub":"user-123","email":"test@example.com"}`.
- All four count guards non-zero.
Rubric (graded):
- 9-10: All four hops correct, variable chain, count guards, lowercase routes.
- 6-8: Three hops correct; one variable extraction missing.
- 1-5: Flat stubs with no variable extraction; code/token not threaded through the flow.
Solution sketch: Four endpoints under one mocker server; `ProcessorConfiguration` includes `Headers: { Location: "http://app/callback?code=mock-code" }` on `/authorize`; variable extraction in runner for `code` and `access_token`; four count guards.

---

### M-135: Stateful Conversation Mock with Controller Reset
Tier: T5
Goal: Run a five-step stateful conversation against a mocker (`SequenceProcessor`), then send a Redis controller reset command to rewind the sequence to step-1, then run the five steps again — asserting both full passes are identical.
SUT: A session-based customer service chatbot; stateful session resets are required for regression testing but not available in any environment.
MOCK_REQUIRED: yes — no test environment supports session state reset between test runs.
FB slices: s03, s13
Trap mines: s13#11 (Controller.ServerName exact), s13#15 (mocker must stay alive across both conversation passes), s13#13 (vacuous pass if reset fails silently), s13#10 (real controller boot log)
Hard because:
- Sequence must advance through five steps (step-by-step conversation).
- Controller reset command must rewind to step-1 — requires knowing exact command format from docs.
- Second pass must produce identical responses to first pass; if reset fails, second pass starts from step-6 (error).
Verify (mechanical):
- First pass: transactions 1-5 return steps 1-5 bodies.
- Controller reset command logged in mocker.
- Second pass: transactions 1-5 again return identical step 1-5 bodies.
- All 10 count guards non-zero.
Rubric (graded):
- 9-10: Both passes identical, reset confirmed in logs, all 10 count guards.
- 6-8: Reset works but second pass not fully asserted.
- 1-5: No reset; second pass returns steps 6-10 (out of sequence data) or errors.
Solution sketch: `SequenceProcessor` with five entries; single verify `cmd` starts mocker, runs pass-1, issues controller reset, runs pass-2, asserts both; `HermeticByExpectedOutputCount: 5` per pass.

---

### M-136: Multi-Stage Fault Injection with Recovery Assertion
Tier: T5
Goal: Simulate a cascading failure and recovery: stage-1 server returns 200; controller injects fault (stub swap to 503); stage-2 requests hit 503; controller restores (swap back to 200 stub); stage-3 asserts 200 recovery — all three stages hermetically counted.
SUT: A resilience-tested API gateway; no test environment supports controlled fault injection and removal.
MOCK_REQUIRED: yes — no chaos engineering tooling in test environment; fault must be injected via controller.
FB slices: s03, s13
Trap mines: s13#11 (Controller.ServerName byte-for-byte), s13#4 (StatusCode 503 assertion), s13#13 (vacuous pass on stage-2 if fault injection failed), s13#15 (mocker persists across all three stages in one cmd)
Hard because:
- Three-stage runner session with two controller stub swaps between stages.
- Fault swap in stage-2 must produce real 503s (not pass vacuously if swap failed).
- Recovery swap in stage-3 must restore 200s; count guard proves it.
Verify (mechanical):
- Stage-1: 3× 200; count guard = 3.
- Fault inject → controller swap logged.
- Stage-2: 3× 503; count guard = 3.
- Recovery → controller swap logged.
- Stage-3: 3× 200; count guard = 3.
Rubric (graded):
- 9-10: All three stages correct with controller swaps, count guards × 3.
- 6-8: Stages 1 and 3 correct; fault stage not asserted or count guard absent.
- 1-5: No fault injection; all stages return 200 (no state change via controller).
Solution sketch: Two stubs registered: `HealthyStub` (200) and `FaultStub` (503); controller swap from Healthy→Fault between stages 1-2, Fault→Healthy between stages 2-3; three runner transaction sets with individual count guards.

---

### M-137: Rate-Limit with Exponential Backoff Simulation
Tier: T5
Goal: Simulate an API that rate-limits after 3 calls (returns 429 with `Retry-After: 2`), then recovers when retried after the indicated wait — runner implements backoff and eventually succeeds, all hermetically asserted.
SUT: An AI inference API with strict rate limits per minute; no sandbox allows rate-limit simulation.
MOCK_REQUIRED: yes — inference API sandbox has no rate-limit simulation capability.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#4 (StatusCode 429), s13#13 (vacuous pass if runner skips 429 stage), s13#8 (Processors ref), s13#9 (version 1.5.1)
Hard because:
- SequenceProcessor: exactly 3× 200, then 2× 429 with `Retry-After: 2`, then 200 on recovery.
- Runner must implement wait/backoff between retry attempts.
- Count guard must account for ALL attempts including the 429 responses.
Verify (mechanical):
- Calls 1-3 → 200.
- Calls 4-5 → 429 with `Retry-After: 2` header present.
- Call 6 (after backoff) → 200 recovery.
- Count guards: 3 successes + 2 rate-limits + 1 recovery all non-zero.
Rubric (graded):
- 9-10: Sequence correct, Retry-After header present and asserted, backoff in runner, all count guards.
- 6-8: Sequence correct but Retry-After not asserted or backoff not implemented.
- 1-5: No sequence; static 429; or runner never implements backoff.
Solution sketch: `SequenceProcessor` with 3× `{StatusCode:200}`, 2× `{StatusCode:429, Headers:{Retry-After:"2"}}`, 1× `{StatusCode:200}`; runner configured with backoff delay; six count guards total.

---

### M-138: Idempotency Across Multiple Attempts with Key Tracking
Tier: T5
Goal: Simulate an idempotency-enforcing payment API — the same `Idempotency-Key` submitted three times returns the same charge response; a different key triggers a new charge; and a replayed key after expiry (simulated by controller swap) returns 422 Unprocessable.
SUT: A payment platform with idempotency-key expiry; no test environment enforces expiry transitions.
MOCK_REQUIRED: yes — payment platform has no test environment that simulates idempotency key expiry.
FB slices: s03, s13
Trap mines: s13#11 (header matching key exact), s13#4 (StatusCode 422), s13#13 (vacuous pass if key routing fails), s13#11 (Controller.ServerName for expiry swap)
Hard because:
- Three behavioral phases: (1) key valid → 200; (2) key expired (post-swap) → 422; (3) new key → 200.
- Requires controller stub swap between phases 1 and 2 to simulate key expiry.
- Count guards for all three phases; phase-2 422 must be non-vacuous.
Verify (mechanical):
- Phase-1: 3× requests with `Idempotency-Key: k1` → 200 same body.
- Phase-2: 1× request with expired `k1` (post-swap) → 422.
- Phase-3: 1× request with new key `k2` → 200 new body.
- All count guards non-zero.
Rubric (graded):
- 9-10: All three phases, controller-driven expiry, count guards × 3.
- 6-8: Phases 1 and 3 correct; expiry phase not implemented.
- 1-5: No idempotency logic; all requests return same response regardless of key.
Solution sketch: Header-conditional processor for `Idempotency-Key`; controller swaps `k1` stub from 200 to 422 between phases 1-2; three runner transaction sets with individual count guards.

---

### M-139: Binary + JSON Content Negotiation Under Controller Swap
Tier: T5
Goal: Run a mocker that serves JSON by default; controller swaps to a binary (`application/octet-stream`) stub mid-run; runner asserts both content types are received in the correct order — proving controller-driven content negotiation.
SUT: A document API that can serve preview JSON or full binary depending on server-side configuration; no test environment supports live content-type switching.
MOCK_REQUIRED: yes — live content-type switching requires server-side configuration access not available in test environments.
FB slices: s03, s13
Trap mines: s13#7 (aspnet base if containerized), s13#1 (ProcessorConfiguration ContentType exact), s13#11 (Controller.ServerName), s13#13 (vacuous pass if swap fails silently)
Hard because:
- Two stubs on same route: JSON stub and binary stub; controller swap transitions between them.
- Runner must assert `Content-Type: application/json` on pre-swap outputs and `application/octet-stream` post-swap.
- Count guard must account for both phases independently.
Verify (mechanical):
- Pre-swap: GET → 200 `application/json` + JSON body.
- Controller swap logged.
- Post-swap: GET → 200 `application/octet-stream` + binary body.
- Both count guards non-zero.
Rubric (graded):
- 9-10: Both content types asserted at correct phase, controller swap confirmed, count guards.
- 6-8: Swap occurs but content-type assertion absent or vacuous.
- 1-5: Same stub served both phases; controller swap has no effect.
Solution sketch: Two stubs: `JsonStub` and `BinaryStub`; controller swap command between runner stage-1 and stage-2; runner asserts content-type header and body length per phase; `HermeticByExpectedOutputCount: 1` per phase.

---

### M-140: Pagination with Dynamic Page-Size via Controller
Tier: T5
Goal: Simulate an API where default page size is 10 items; controller sends a command mid-run to reduce page size to 3 items (to simulate resource constraints); runner detects the reduced page and asserts both page sizes are observed.
SUT: A data-streaming API with server-side configurable page sizes; no test environment supports runtime page-size changes.
MOCK_REQUIRED: yes — no test environment exposes runtime page-size configuration; must be mocked.
FB slices: s03, s13
Trap mines: s13#11 (Controller.ServerName exact), s13#13 (vacuous pass on either page phase), s13#3 (DataSourceNames if sequence reads from files), s13#15 (mocker persists across both phases)
Hard because:
- SequenceProcessor with two page-size variants: large page then small page.
- Controller swap changes from large-page stub to small-page stub mid-run.
- Runner must count items in JSON array response (length assertion) per page.
Verify (mechanical):
- Phase-1: response array has 10 items.
- Controller swap logged.
- Phase-2: response array has 3 items.
- Both count guards non-zero.
Rubric (graded):
- 9-10: Both page sizes asserted, controller swap confirmed, count guards.
- 6-8: Page sizes differ but no controller involvement (hardcoded sequence).
- 1-5: Static same-size pages; no controller-driven size change.
Solution sketch: Two stubs: `LargePageStub` (10-item array body) and `SmallPageStub` (3-item array body); controller swap between phases; runner asserts `JsonArrayLength` per phase; two count guards.

---

### M-141: Conditional Routing on Multiple Header Combinations
Tier: T5
Goal: Route requests based on two simultaneous header conditions — `X-Region: eu` AND `X-Tier: premium` → premium-EU stub; `X-Region: us` AND `X-Tier: standard` → standard-US stub; any other combination → 400 Bad Request stub; all three paths asserted.
SUT: A geo-tiered pricing API with complex routing rules; no test environment can simulate all routing combinations simultaneously.
MOCK_REQUIRED: yes — routing logic is production-only; test environment only supports single-header routing.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#4 (StatusCode 400), s13#11 (multi-header condition config exact), s13#5b (lowercase route), s13#13 (vacuous pass on fallback path)
Hard because:
- Multi-header conditional routing may require a custom processor or specific built-in with AND-semantics.
- Three distinct routing outcomes on the same path — must confirm processor supports AND-conditions.
- Fallback 400 stub must be explicitly defined and not confused with auto-generated not-found stub.
Verify (mechanical):
- `X-Region: eu` + `X-Tier: premium` → premium-EU response body.
- `X-Region: us` + `X-Tier: standard` → standard-US response body.
- `X-Region: eu` + `X-Tier: standard` → 400 Bad Request.
- All three count guards non-zero.
Rubric (graded):
- 9-10: All three routing paths correct, count guards × 3, AND-condition semantics confirmed.
- 6-8: Two of three paths correct; fallback not implemented or vacuous.
- 1-5: Single-header routing only; second header ignored; or fallback always triggered.
Solution sketch: Multi-condition header processor (verify via `template`); three stubs: `PremiumEuStub`, `StandardUsStub`, `FallbackStub`; three runner transactions with distinct header combinations; count guards per path.

---

### M-142: Four-Server Microservices Mesh (All HTTP, Full Flow)
Tier: T5
Goal: Mock an entire microservice mesh: API Gateway (8142), Auth Service (8143), Product Service (8144), Order Service (8145) — with the runner exercising a complete checkout flow across all four services in one session.
SUT: A distributed e-commerce checkout flow spanning four services; no full-stack integration test environment exists.
MOCK_REQUIRED: yes — no full-stack integration test environment; each service is owned by a separate team.
FB slices: s03, s13
Trap mines: s13#16 (PORT CONTRACT × 4 — each server has its own probe/mocker/runner port triple), s13#5b (lowercase routes × all four services), s13#1 (ProcessorConfiguration × all stubs), s13#9 (versions: Runner 4.5.1, Common packages independent)
Hard because:
- Four `Http:` servers; four PORT CONTRACTs; all routes lowercase — any one wrong causes 404.
- Runner session issues four sequential transactions: auth → catalog → cart → checkout.
- Variable chain: auth token from service-1 threaded to services 2-4.
Verify (mechanical):
- All four servers bind on correct ports; `template` confirms all four entries.
- Auth → `{"token":"mock-jwt"}`.
- Catalog → `{"items":[{"id":1}]}` with Bearer header.
- Cart → `{"cart_id":"c1"}` with Bearer header.
- Checkout → `{"order_id":"o1","status":"confirmed"}` with Bearer header and cart_id.
Rubric (graded):
- 9-10: All four services, variable chain, count guards × 4, PORT CONTRACTs × 4, lowercase routes × 4.
- 6-8: Four services correct but variable chain incomplete or one route has case issue.
- 1-5: Fewer than four services, or flat stubs with no variable injection.
Solution sketch: `Servers:` with four `Http:` entries on 8142-8145; runner session with four transactions in order; extract `token` from auth, inject as Bearer in subsequent calls; `HermeticByExpectedOutputCount: 1` × 4.

---

### M-143: Controller-Driven A/B Testing Mock
Tier: T5
Goal: Model an A/B test scenario — mocker serves variant-A for the first runner session; controller sends a command to switch to variant-B; second runner session asserts variant-B — simulating a feature-flag-driven A/B rollout.
SUT: A feature-flagging system for A/B test rollout; no test environment supports live flag changes during a test run.
MOCK_REQUIRED: yes — live flag changes require production access; A/B behavior cannot be tested without mocking.
FB slices: s03, s13
Trap mines: s13#11 (Controller.ServerName byte-for-byte), s13#15 (mocker must persist across both sessions in one cmd), s13#13 (vacuous pass in session-2 if variant-B swap failed), s13#10 (real controller boot log)
Hard because:
- Two runner sessions with controller stub swap between them (same mocker process must stay running).
- Variant-A and variant-B produce observably different JSON responses — diff must be asserted.
- Session-2 count guard must prove variant-B was served, not variant-A (subtle if bodies only differ in one field).
Verify (mechanical):
- Session-1: all outputs contain `{"variant":"A"}`.
- Controller swap logged (`Initialized Redis controller`).
- Session-2: all outputs contain `{"variant":"B"}`.
- Count guards non-zero in both sessions.
Rubric (graded):
- 9-10: Both variants asserted, controller swap confirmed in logs, count guards × 2.
- 6-8: Swap executed but variant distinction not asserted (body check missing).
- 1-5: No controller; both sessions return same variant; or mocker restarts between sessions.
Solution sketch: Two stubs: `VariantAStub` and `VariantBStub`; single verify cmd starts mocker, runs session-1 (assert A), issues swap, runs session-2 (assert B), stops mocker; `BodyContains` assertion per session.

---

### M-144: Webhook Delivery with Signature Verification Mock
Tier: T5
Goal: Mock a webhook receiver that validates the `X-Signature-256` HMAC header — requests with a valid signature header return 200 acknowledged; requests with missing or invalid signature return 401 Unauthorized; runner exercises both paths.
SUT: A payments webhook platform that signs deliveries with HMAC-SHA256; no test environment generates real signatures.
MOCK_REQUIRED: yes — real HMAC signatures require production secrets; no test environment generates valid signatures.
FB slices: s03, s13
Trap mines: s13#5b (lowercase `/webhooks/events` route), s13#4 (StatusCode 401 assertion), s13#13 (vacuous pass if signature header not routed), s13#11 (header matching config exact)
Hard because:
- Must route on `X-Signature-256` header presence/value — requires conditional processor.
- Two outcomes on same route: 200 (valid sig) and 401 (invalid/missing sig).
- Runner must send two POST requests: one with a mock-valid signature and one without.
Verify (mechanical):
- POST with `X-Signature-256: valid-sig` → 200 `{"received":true}`.
- POST without header → 401 `{"error":"unauthorized"}`.
- Both count guards non-zero.
Rubric (graded):
- 9-10: Both paths asserted, header routing correct, count guards × 2.
- 6-8: 200 path correct; 401 path not implemented or vacuous.
- 1-5: No header routing; all requests return 200; or route case mismatch → 404.
Solution sketch: Header-conditional processor on `X-Signature-256`; `ValidSigStub` (200) and `InvalidSigStub` (401); two runner POST transactions; `HermeticByExpectedOutputCount: 1` per transaction.

---

### M-145: Multi-Tenant Auth Mock with Per-Tenant Stub Profiles
Tier: T5
Goal: Simulate three tenant profiles on a single auth endpoint — each tenant's Bearer token maps to a different set of permissions returned in `/me` — with all three profiles asserted hermetically.
SUT: A multi-tenant SaaS identity system where tenant tokens are issued only in production.
MOCK_REQUIRED: yes — production-only identity system; tenant tokens cannot be minted in test environments.
FB slices: s03, s13
Trap mines: s13#5b (lowercase `/me` route), s13#1 (ProcessorConfiguration), s13#11 (Bearer header matching key exact), s13#13 (vacuous pass on any tenant path)
Hard because:
- Three tenant profiles on same `/me` route, differentiated by Bearer token value.
- Header matching on `Authorization` value (not just presence) — requires sub-string or exact-value matching.
- All three count guards must be non-zero; a vacuous pass on any tenant proves routing is broken.
Verify (mechanical):
- Bearer `token-tenant-a` → `{"tenant":"a","role":"admin"}`.
- Bearer `token-tenant-b` → `{"tenant":"b","role":"user"}`.
- Bearer `token-tenant-c` → `{"tenant":"c","role":"readonly"}`.
- All three count guards non-zero.
Rubric (graded):
- 9-10: All three tenant profiles routed correctly, count guards × 3, exact Bearer matching.
- 6-8: Two tenants correct; third falls through to wrong stub.
- 1-5: Same stub for all tokens; no authorization header routing.
Solution sketch: Header-value-conditional processor on `Authorization`; three stubs for tenant-a/b/c profiles; runner session with three transactions using distinct Bearer tokens; `HermeticByExpectedOutputCount: 1` per transaction.

---

### M-146: Circuit Breaker State Simulation (Open / Half-Open / Closed)
Tier: T5
Goal: Simulate all three circuit breaker states in sequence: Closed (5× 200), Open (3× 503 immediate), Half-Open (1× 200 probe), then Closed again (3× 200) — using `SequenceProcessor` and controller to drive state transitions.
SUT: A resilience pattern library under test; no real flaky dependency can be controlled precisely enough.
MOCK_REQUIRED: yes — real dependencies cannot be made to fail exactly N times then recover on demand.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#4 (StatusCode 503 assertion), s13#13 (vacuous pass on open-circuit phase), s13#8 (Processors ref), s13#16 (PORT CONTRACT)
Hard because:
- 12-step sequence (5+3+1+3) must be exact; wrong count makes circuit state assertions fail.
- Runner must have per-phase count guards: 5 + 3 + 1 + 3 = 12 total.
- Controller may be used to trigger state transitions or SequenceProcessor alone — must confirm correct approach.
Verify (mechanical):
- Phase-1 (Closed): 5× 200; count guard = 5.
- Phase-2 (Open): 3× 503; count guard = 3.
- Phase-3 (Half-Open): 1× 200; count guard = 1.
- Phase-4 (Closed): 3× 200; count guard = 3.
Rubric (graded):
- 9-10: All four phases, correct status codes per phase, count guards × 4 sum = 12.
- 6-8: Three phases correct; one count guard wrong or absent.
- 1-5: Flat sequence without phase semantics; or count guards not per-phase.
Solution sketch: `SequenceProcessor` with 12 entries (5× 200, 3× 503, 1× 200, 3× 200); four runner stages with individual `HermeticByExpectedOutputCount` guards per phase; `QaaS.Common.Processors 1.5.1`.

---

### M-147: GraphQL Mock with Introspection Response
Tier: T5
Goal: Mock a GraphQL endpoint that responds to both `__schema` introspection queries and business `{ user { id name } }` queries — routing determined by the `query` field in the POST body.
SUT: A GraphQL API in early schema design; no real GraphQL server is deployed in test environments.
MOCK_REQUIRED: yes — schema under design; no GraphQL server is deployed in any environment.
FB slices: s03, s13
Trap mines: s13#5b (lowercase `/graphql` route), s13#1 (ProcessorConfiguration), s13#11 (body-regex config exact), s13#13 (vacuous pass if introspection query never hits correct stub)
Hard because:
- Body-regex routing on `query` field value — must distinguish `__schema` from `user` queries.
- Both introspection and business queries POST to same path (`/graphql`) with same `Content-Type: application/json`.
- Response bodies are complex nested JSON — must be valid JSON strings in YAML.
Verify (mechanical):
- POST `{"query":"{ __schema { types { name } } }"}` → introspection schema response.
- POST `{"query":"{ user { id name } }"}` → `{"data":{"user":{"id":"1","name":"Alice"}}}`.
- Both count guards non-zero.
Rubric (graded):
- 9-10: Both query types routed correctly, valid JSON bodies, count guards × 2.
- 6-8: One query type correct; introspection not handled or vice versa.
- 1-5: Same static stub for all POST requests; no body-based routing.
Solution sketch: Body-regex conditional processor distinguishing `__schema` from `user` queries; two stubs with GraphQL-shaped JSON responses; runner POSTs both query types; two count guards.

---

### M-148: Service Mesh Retry with Controller-Injected Transient Fault
Tier: T5
Goal: Run a multi-service mesh mock (3 servers) where the controller injects a transient 503 into the catalog service mid-run; the runner retries and succeeds; all retry attempts and the final success are hermetically asserted.
SUT: A service mesh retry policy under test; no infrastructure allows on-demand 503 injection into a specific service.
MOCK_REQUIRED: yes — no infrastructure supports per-service fault injection on demand in test environments.
FB slices: s03, s13
Trap mines: s13#16 (PORT CONTRACT × 3 services), s13#5b (lowercase routes × 3), s13#11 (Controller.ServerName), s13#13 (vacuous pass if fault injection fails), s13#15 (mocker persists across fault injection)
Hard because:
- Three-server mocker; controller targets only the catalog service stub for the fault injection.
- Runner must observe 503 on catalog, retry successfully (stub back to 200 post-recovery swap).
- Count guards: auth (1× 200) + catalog pre-fault (1× 200) + catalog fault (1× 503) + catalog recovery (1× 200) + checkout (1× 200).
Verify (mechanical):
- Auth → 200; pre-fault catalog → 200; controller injects fault.
- Catalog retry → 503; controller recovers; catalog final → 200; checkout → 200.
- Five count guards all non-zero.
Rubric (graded):
- 9-10: Three services, controller fault targeting catalog only, retry observed, count guards × 5.
- 6-8: Fault injection works but retry not observed or checkout count guard absent.
- 1-5: Fault applied to all servers (not targeted), or no recovery, or mocker restarts.
Solution sketch: Three `Http:` servers; controller `ServerName` targets catalog only; runner session in five stages; individual count guards per stage; all in single verify cmd.

---

### M-149: Full Event-Driven Saga Mock (Four Services + Controller)
Tier: T5
Goal: Mock a complete distributed saga across four services (Order, Payment, Inventory, Notification) where the controller simulates a payment failure mid-saga, triggering compensation: order cancelled, inventory restored, notification sent — all four compensation responses asserted.
SUT: A saga orchestration service; no test environment supports controlled distributed transaction failure injection.
MOCK_REQUIRED: yes — distributed saga failure injection requires coordinated cross-service state changes not possible in test environments.
FB slices: s03, s13
Trap mines: s13#11 (Controller.ServerName byte-for-byte), s13#16 (PORT CONTRACT × 4), s13#5b (lowercase routes × all services), s13#13 (vacuous pass if compensation not triggered), s13#15 (mocker persists across all saga steps)
Hard because:
- Eight-step saga: 4 happy-path steps + controller fault injection + 4 compensation steps.
- Each service must serve both happy-path and compensation stubs — controller drives the switch.
- Runner must assert both happy-path outputs AND compensation outputs with individual count guards.
Verify (mechanical):
- Steps 1-4 (happy path): Order→201, Payment→200, Inventory→200, Notification→200.
- Controller injects payment failure.
- Steps 5-8 (compensation): Order→cancelled, Payment→refunded, Inventory→restored, Notification→failure-alert.
- All 8 count guards non-zero.
Rubric (graded):
- 9-10: All 8 steps, controller-driven compensation, count guards × 8, PORT CONTRACT × 4.
- 6-8: Happy path correct; compensation partially asserted (< 4 services).
- 1-5: No compensation flow; or fewer than four services; or controller not connected.
Solution sketch: Four `Http:` servers; two stubs per service (happy + compensation); controller swaps all four after saga step 4; runner session with eight transaction stages; `HermeticByExpectedOutputCount: 1` × 8.

---

### M-150: Canary Deployment Simulation with Weighted Traffic Split
Tier: T5
Goal: Simulate a canary deployment: mocker serves stable-v1 for first 8 requests and canary-v2 for the next 2 (10% canary via SequenceProcessor); controller then promotes canary (swap to all-v2); runner asserts the 80/20 phase and then the full-v2 phase hermetically.
SUT: A canary release system where traffic is progressively shifted; no staging environment supports weighted routing simulation.
MOCK_REQUIRED: yes — traffic weighting cannot be simulated in any non-production environment.
FB slices: s03, s13
Trap mines: s13#1 (ProcessorConfiguration), s13#8 (Processors ref), s13#11 (Controller.ServerName), s13#13 (vacuous pass in canary phase if sequence miscounted), s13#15 (single cmd for all phases)
Hard because:
- SequenceProcessor must deliver exactly 8× v1 then 2× v2 (then controller promotes to all-v2).
- Runner issues 10 requests in phase-1; then controller promotes; then 5 more in phase-2 (all v2).
- Count guards: 8× v1 + 2× v2 in phase-1; 5× v2 in phase-2 — must be separate and precise.
Verify (mechanical):
- Phase-1 requests 1-8 → v1 body `{"version":"v1"}`.
- Phase-1 requests 9-10 → v2 body `{"version":"v2"}`.
- Controller promotion logged.
- Phase-2 requests 1-5 → all `{"version":"v2"}`.
- Count guards: phase-1 v1=8, phase-1 v2=2, phase-2 v2=5.
Rubric (graded):
- 9-10: Sequence 8+2 correct, controller promotion, phase-2 all-v2, count guards × 3.
- 6-8: Sequence correct but controller promotion not implemented (manual sequence extends).
- 1-5: Static v1 always; no canary; or sequence count wrong; or count guards absent.
Solution sketch: `SequenceProcessor` with 8× `{Body:'{"version":"v1"}'}` + 2× `{Body:'{"version":"v2"}'}`; controller swap to `V2Stub` after 10 requests; runner in two phases (10 + 5 transactions) with three count guards.
