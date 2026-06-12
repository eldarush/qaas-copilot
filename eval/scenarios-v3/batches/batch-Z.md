# Batch Z — IMPOSSIBLE-INTEGRATION (Final Boss)
# IDs: Z-101..Z-150 | Tier: T5 (all) | Theme: ≥3 capability areas per scenario
# Sources: FB §0-§16, s13 drift table (19 entries), CONSTITUTION v1.0
# Format: each scenario ≤30 lines, terse

### Z-101: Multi-Protocol Choreography — HTTP Ingress → Rabbit Fan-out → Redis State → HTTP Egress
Tier: T5
Goal: Prove end-to-end correctness of an order pipeline where an HTTP POST triggers a Rabbit fan-out, two consumers write to Redis, and a final HTTP GET returns the aggregated state.
SUT: REST API accepts `POST /order`; publishes to RabbitMQ exchange `order.fanout`; two consumer services update Redis keys; a read service exposes `GET /order/{id}/status` reading Redis.
Capabilities stacked: analysis, planning, runner, mocker, hooks, diagnose, docs
MOCK_REQUIRED: yes — all four SUT services are unavailable in CI; mocker stubs HTTP endpoints and simulates Redis via a separate controller-managed swap.
FB slices: §0, §2, §3, §9, §11, §13
Trap mines: s13#3 (DataSourceNames required), s13#4 (HttpStatus keys), s13#5 (no leading slash), s13#13 (vacuous pass), s13#17 (topology pre-creation), s13#19 (internal deps no host port)
Hard because:
- Four protocol boundaries must be wired in one runner suite across multiple sessions
- Rabbit topology (exchange + two queues) must be created via Stage 0 probes before publish
- Final HTTP assertion must guard against vacuous pass if Redis consumer lag causes 0 outputs
- Redis controller swap mid-run must not lose state already written by consumers
Verify (mechanical): `dotnet build` exits 0; `dotnet run -- template` exits 0; runner exits 0; allure shows sessions for HTTP-POST, Rabbit-pub, 2×Rabbit-consumer, HTTP-GET all green; count guard fires if consumer outputs < 2.
Rubric (graded): (1) Topology probe at Stage 0, correct exchange/queue config [0-10]; (2) All five session types present with hermetic guards [0-10]; (3) s13 drift traps absent [0-10]; (4) Redis controller swap demonstrated without state loss [0-10].
Solution sketch: Scaffold runner with 5 sessions (HttpTransaction POST, RabbitPublisher, 2×RabbitConsumer, HttpTransaction GET); add CreateRabbitMqExchanges probe at Stage 0; use HermeticByExpectedOutputCount on every session; Redis controller stub-swap via mocker YAML between consumer stage and read stage.

### Z-102: Chaos Engineering — RabbitMQ Broker Restart Mid-Suite with Hermetic Recovery
Tier: T5
Goal: Demonstrate that a QaaS suite detects and hermetically fails when the broker restarts mid-consumer-session, then self-recovers via a Stage 2 probe-restart and re-counts outputs.
SUT: Durable queue `jobs.work`; producer sends 200 messages; broker is killed and restarted at message 100; consumer must drain all 200 from durable queue.
Capabilities stacked: planning, runner, hooks, diagnose, docs
MOCK_REQUIRED: no — real RabbitMQ container managed by compose; no mock needed for broker chaos.
FB slices: §2, §6, §9, §11, §13
Trap mines: s13#17 (topology probe required), s13#13 (vacuous pass on reconnect), s13#3 (DataSourceNames required), s13#15 (live-run mocker/runner in one cmd)
Hard because:
- Durable queue semantics must be asserted via exactly-once count after restart
- A probe must execute the broker restart (docker stop/start) mid-suite at a defined stage
- HermeticByExpectedOutputCount must be set to 200; any reconnect drop triggers failure
- DataSourceNames file must pre-populate 200 job payloads deterministically
Verify (mechanical): `dotnet build` exits 0; runner exits 0 on no-chaos path; runner exits non-0 when count guard = 200 but broker drops 10; allure shows hermetic failure annotation.
Rubric (graded): (1) Stage-gated broker-restart probe present and syntactically correct [0-10]; (2) HermeticByExpectedOutputCount = 200 on consumer session [0-10]; (3) DataSourceNames populated with 200 records [0-10]; (4) Failure mode documented in diagnose artifact with s13#17 citation [0-10].
Solution sketch: Use a custom probe (`ShellProbe`) at Stage 1 to `docker restart rabbitmq`; consumer session at Stage 2 with `HermeticByExpectedOutputCount: 200`; if broker drops messages, count guard fires and allure logs "expected 200 got N".

### Z-103: Data-Integrity Marathon — 10k Records with Exactly-Once, Ordering, and Decimal Precision
Tier: T5
Goal: Validate a financial message bus that must deliver exactly 10,000 records in sequence-order with decimal amounts preserved to 4 decimal places, no duplicates, no drops.
SUT: Kafka topic `ledger.entries`; producer publishes 10k records with `seq` and `amount` (decimal); consumer writes to DB; read API returns ordered ledger.
Capabilities stacked: planning, runner, hooks, diagnose, docs
MOCK_REQUIRED: no — real Kafka + DB in compose; no mock needed; HTTP read endpoint via real service.
FB slices: §2, §4, §9, §10, §13
Trap mines: s13#3 (DataSourceNames required for 10k), s13#13 (vacuous pass if consumer lags), s13#4 (HttpStatus keys), s13#12 (silent typo in AssertionConfiguration)
Hard because:
- 10k DataSourceNames entries must be generated deterministically (SequentialGenerator or file)
- Ordering assertion requires custom hook comparing `seq` monotonically — no built-in
- Decimal precision assertion requires custom JsonFieldAssertion with exact string match
- HermeticByExpectedOutputCount: 10000 on consumer; any duplicate counted as failure
Verify (mechanical): `dotnet build` exits 0; runner exits 0; allure count-guard shows 10000/10000; no duplicate seq IDs in output; decimal values match source to 4dp.
Rubric (graded): (1) 10k DataSourceNames or SequentialGenerator correctly wired [0-10]; (2) Custom ordering hook compiles and is registered [0-10]; (3) Hermetic guard set to 10000 [0-10]; (4) Decimal precision assertion passes on sample spot-check [0-10].
Solution sketch: Use `SequentialIdGenerator` for seq field; custom `IAssertionHook` validates monotonic order; `JsonField` assertion with exact decimal string; `HermeticByExpectedOutputCount: 10000` on Kafka consumer session.

### Z-104: Regression Archaeology — Previously-Green Allure Report vs Now-Failing Run
Tier: T5
Goal: Given a previously-green allure report and a now-failing QaaS runner run, identify the exact delta (config change, version bump, or data mutation) that caused the regression.
SUT: Provided: (a) allure-report/ from last-green run; (b) current failing runner log; (c) git diff of YAML and csproj between runs. The SUT is an HTTP inventory service.
Capabilities stacked: analysis, diagnose, docs, planning
MOCK_REQUIRED: n/a — regression archaeology is read-only analysis; no new mocker authoring required.
FB slices: §7, §13, §9, §6
Trap mines: s13#4 (HttpStatus key rename between versions), s13#9 (independent package versions), s13#12 (silent typo), s13#13 (vacuous pass newly introduced)
Hard because:
- Must diff allure timeline vs current log to find the first divergence point
- A package version bump (s13#9) may have changed a config key silently (s13#12)
- A newly added vacuous pass (s13#13) may mask a real failure as green
- Root-cause must cite specific FB slice and s13 row, not guesswork
Verify (mechanical): Root-cause statement cites ≥1 s13 row; proposed fix applied; `dotnet run` exits 0; allure shows same session count as last-green report; no vacuous-pass sessions.
Rubric (graded): (1) Correct root-cause identified with s13 citation [0-10]; (2) Fix is minimal and surgical (≤2 file changes) [0-10]; (3) Vacuous-pass guard added if missing [0-10]; (4) Re-run produces allure matching last-green session count [0-10].
Solution sketch: Compare `allure-results/` test-case JSON from both runs; locate first session with status change; cross-reference config diff against s13 table; fix the single drift-left key or version mismatch; re-run and confirm green.

### Z-105: Zero-Downtime Config Swap via Redis Controller Under Load
Tier: T5
Goal: Prove that a mocker stub can be atomically swapped (response body changed) via Redis controller while a runner load session is in-flight, with no outputs lost.
SUT: HTTP service returning `{"version":"v1"}`; mid-run, controller command swaps stub to return `{"version":"v2"}`; runner must observe both versions and assert count of each.
Capabilities stacked: planning, runner, mocker, hooks, diagnose, docs
MOCK_REQUIRED: yes — SUT is a stub; the controller-swap behavior requires mocker with Redis controller enabled.
FB slices: §0, §2, §3, §9, §11, §13
Trap mines: s13#11 (controller boot log differs from docs), s13#4 (HttpStatus OutputNames list), s13#5 (route lowercase), s13#13 (vacuous pass before swap fires), s13#16 (port contract)
Hard because:
- Redis controller must be configured with correct channel and instance ID (s13#11)
- Runner must send 100 requests; a Stage 1 probe issues the swap command; Stage 2 continues
- Two separate JsonBody assertions must count v1 vs v2 outputs to sum to 100
- Port contract must be consistent across probe, mocker, and runner (s13#16)
Verify (mechanical): `dotnet build` exits 0; controller swap log line matches s13#11 pattern; v1-count + v2-count = 100 in allure; no vacuous passes; runner exits 0.
Rubric (graded): (1) Redis controller wired with correct channel config [0-10]; (2) Stage-split probe issues swap at correct timing [0-10]; (3) Two-version count assertions sum to 100 [0-10]; (4) s13#13 count guard present on both assertion sessions [0-10].
Solution sketch: Mocker YAML with Redis controller block; Stage 0 = 50 HTTP requests (v1); Stage 1 probe sends Redis PUBLISH command with swap payload; Stage 2 = 50 more requests (v2); two `JsonBodyContains` sessions with `HermeticByExpectedOutputCount: 50` each.

### Z-106: Contract-First from OpenAPI Spec — Derive Full Runner Suite with Drift Checks
Tier: T5
Goal: Given an OpenAPI 3.0 spec for a payments API, author a complete QaaS runner suite covering all endpoints, assert response schemas, and flag any drift between spec and mocker behavior.
SUT: OpenAPI spec with 5 paths (POST /payments, GET /payments/{id}, DELETE /payments/{id}, POST /payments/{id}/refund, GET /health); no live service.
Capabilities stacked: analysis, planning, runner, mocker, docs
MOCK_REQUIRED: yes — no live service; mocker stubs all 5 paths per spec schemas.
FB slices: §1, §2, §3, §9, §13, §14
Trap mines: s13#5 (no leading slash in Route), s13#5b (lowercase routes), s13#4 (HttpStatus keys), s13#13 (vacuous pass), s13#12 (silent typo)
Hard because:
- Five paths require five mocker stubs with spec-accurate response bodies
- All routes must be lowercase end-to-end (s13#5b); spec may use mixed case
- Each session needs HermeticByExpectedOutputCount; DELETE/refund may return 0 outputs vacuously
- Schema drift assertion requires JsonField checks on every required response field
Verify (mechanical): `dotnet build` exits 0; 5 sessions all green; HttpStatus sessions have `OutputNames:` list; allure shows no vacuous passes; count guards = 1 per single-call endpoint.
Rubric (graded): (1) All 5 OpenAPI paths covered with correct mocker stubs [0-10]; (2) Routes lowercase on both mocker and runner [0-10]; (3) HermeticByExpectedOutputCount on every session [0-10]; (4) JsonField assertions match spec required fields [0-10].
Solution sketch: Extract all paths from OpenAPI spec; lowercase routes; scaffold mocker with 5 stubs (spec-accurate JSON bodies); author runner YAML with 5 HttpTransaction sessions; apply count guards and JsonField assertions per spec schema; build and run.

### Z-107: Migration Parity — v1 vs v2 Side-by-Side with Divergence Mapping
Tier: T5
Goal: Run the same logical test suite against v1 and v2 of a message-processing service simultaneously, assert identical outputs on shared fields, and enumerate fields that legitimately diverge.
SUT: Two RabbitMQ consumer services (v1 on port 5672, v2 on port 5673) processing identical `orders.new` messages; v2 adds a `processingTime` field and changes `status` enum values.
Capabilities stacked: analysis, planning, runner, mocker, diagnose, docs
MOCK_REQUIRED: yes — both consumer services are mocked; same input messages routed to both via separate mocker instances.
FB slices: §0, §2, §3, §9, §10, §13
Trap mines: s13#17 (topology pre-creation for both instances), s13#3 (DataSourceNames required), s13#13 (vacuous pass on divergent fields), s13#9 (independent version per package)
Hard because:
- Two mocker instances must run on different ports; compose must not expose internal RabbitMQ ports (s13#19)
- Shared-field equality requires a custom assertion comparing outputs from two sessions
- Divergent-field detection requires a negative assertion (field absent in v1, present in v2)
- DataSourceNames must be identical for both sessions to ensure parity
Verify (mechanical): `dotnet build` exits 0; runner exits 0; allure shows 2 consumer sessions both green; shared fields identical; `processingTime` absent in v1 outputs, present in v2; count guards both = N.
Rubric (graded): (1) Two mocker instances on distinct ports, no internal port exposure [0-10]; (2) Shared-field equality assertion present [0-10]; (3) Divergent-field documented via negative assertion [0-10]; (4) Identical DataSourceNames used for both sessions [0-10].
Solution sketch: Scaffold two runner consumer sessions pointing to separate mocker instances; use same DataSourceNames file; `JsonField` assertion on shared fields in both sessions; custom hook `FieldAbsenceAssertion` on v1 session for `processingTime`; count guards equal.

### Z-108: HMAC Signing Chain + Token Refresh Mid-Session
Tier: T5
Goal: Test an API gateway that validates HMAC-signed requests, issues short-lived JWTs, and requires token refresh mid-session when TTL expires — all within a single QaaS runner session.
SUT: Auth service: `POST /auth/token` (HMAC-signed body → JWT); resource service: `GET /resource` (Bearer JWT); refresh: `POST /auth/refresh` (old JWT → new JWT, called when 401 received).
Capabilities stacked: planning, runner, hooks, mocker, docs
MOCK_REQUIRED: yes — auth and resource services unavailable; mocker stubs all three endpoints with stateful JWT tracking via processor.
FB slices: §2, §3, §4, §12, §13, §14
Trap mines: s13#1 (ProcessorConfiguration not TransactionData), s13#4 (HttpStatus keys), s13#5 (route lowercase), s13#5b (case-sensitive), s13#8 (package refs for built-in hooks)
Hard because:
- HMAC signing requires a custom `IGeneratorHook` that computes HMAC-SHA256 per request
- JWT refresh mid-session requires a `IProcessorHook` in mocker that tracks TTL and returns 401 on expiry
- Session must handle 401 response and branch to refresh before continuing — requires custom logic
- All three routes must be lowercase; processor must be stateless (s13 hook rules)
Verify (mechanical): `dotnet build` exits 0; auth session returns 200 with JWT; resource session 200 for valid JWT; 401 triggers refresh; post-refresh resource session 200; allure all green.
Rubric (graded): (1) HMAC generator hook compiles with correct `IGeneratorHook` signature [0-10]; (2) Mocker processor correctly tracks TTL and emits 401 [0-10]; (3) Token refresh flow modeled correctly in runner YAML [0-10]; (4) All routes lowercase, ProcessorConfiguration (not TransactionData) [0-10].
Solution sketch: Custom `HmacSigningGenerator` yield-returns requests with `X-Signature` header; mocker stateful processor returns 401 after TTL; runner YAML: Stage 0 = /auth/token, Stage 1 = /resource (200), Stage 2 probe = /auth/refresh, Stage 3 = /resource (200 again); all routes lowercase.

### Z-109: Airgapped CI End-to-End — Offline Feed + Image Save/Load + Compose + Run + Allure
Tier: T5
Goal: Reproduce a complete QaaS test run in a fully airgapped environment: offline NuGet feed, pre-pulled Docker images (save/load), docker-compose up, runner execution, and allure report generation.
SUT: Any HTTP SUT already covered by a working QaaS suite; the challenge is the airgap packaging and CI script, not the SUT logic.
Capabilities stacked: planning, runner, mocker, docker, diagnose, docs
MOCK_REQUIRED: yes — mocker image must be pre-built and saved as `.tar`; loaded into offline CI without internet.
FB slices: §1, §6, §8, §13, §14
Trap mines: s13#7 (aspnet not runtime base image), s13#18 (Dockerfile inline comments break FROM), s13#19 (only mocker port exposed), s13#15 (mocker+runner in one verify cmd), s13#9 (exact package versions)
Hard because:
- Offline NuGet feed must contain all QaaS packages at exact versions (s13#9)
- Mocker Dockerfile must use `aspnet:10.0` base (s13#7); inline comments on FROM line break build (s13#18)
- Compose must expose only mocker port; internal Redis/RabbitMQ get no host mapping (s13#19)
- Live-gate verify step must start mocker + wait-for-port + run + capture exit in ONE cmd (s13#15)
Verify (mechanical): `docker compose up` exits 0 with no port-conflict; `dotnet run` exits 0; allure-report/ generated; no internet calls during run (verified via network intercept); all NuGet restores from local feed.
Rubric (graded): (1) NuGet.config points to offline feed with exact versions [0-10]; (2) Dockerfile uses `aspnet:10.0`, no inline comments [0-10]; (3) Compose exposes only mocker port [0-10]; (4) Single verify cmd orchestrates full lifecycle [0-10].
Solution sketch: Pre-pull all images with `docker save`; create offline NuGet feed at `./packages/`; NuGet.Config with `<add key="offline" value="./packages/" />`; compose with mocker only exposed; verify script: `docker compose up -d && <wait-for-port> && dotnet run -- run && docker compose down`.

### Z-110: Test-the-Tests — Find All Vacuous Passes in a Flawed Existing Suite and Repair
Tier: T5
Goal: Given a provided QaaS test suite with 8 sessions, identify every vacuous pass (HttpStatus with zero outputs, missing count guards, silently-ignored config keys) and produce a repaired suite.
SUT: Provided flawed suite: 3 HttpTransaction sessions with HttpStatus assertions but no count guards; 2 sessions with misspelled AssertionConfiguration keys; 1 consumer session with DataSourceNames omitted.
Capabilities stacked: analysis, diagnose, docs, planning, runner
MOCK_REQUIRED: n/a — analysis and repair task; existing mocker YAML is already provided.
FB slices: §7, §9, §13, §2
Trap mines: s13#13 (vacuous HttpStatus), s13#12 (silent key typo), s13#3 (DataSourceNames required), s13#4 (OutputNames list vs scalar)
Hard because:
- Must enumerate all 6 failure modes systematically without missing any
- Silent key typos (s13#12) produce no error, requiring character-exact comparison against catalog
- Vacuous-pass repair requires adding HermeticByExpectedOutputCount to every HTTP session
- DataSourceNames omission causes FTL with exit -532462766, not a soft failure
Verify (mechanical): `dotnet build` exits 0 on repaired suite; runner exits 0; allure shows all 8 sessions green; no session has 0 outputs; every AssertionConfiguration key matches catalog exactly.
Rubric (graded): (1) All 3 vacuous-pass sessions identified and repaired with count guards [0-10]; (2) All 2 key-typo sessions corrected to catalog-exact keys [0-10]; (3) DataSourceNames added to consumer session [0-10]; (4) Repair rationale cites s13 row for each fix [0-10].
Solution sketch: Audit each session: for HttpStatus, verify `HermeticByExpectedOutputCount` present and `OutputNames:` is a list; for AssertionConfiguration, diff keys against §9 catalog; for consumer session, verify `DataSourceNames:` or `DataSourcePatterns:`; apply all fixes; re-run.

### Z-111: Self-Verifying Deliverable — Template Oracle + Live Gate + Completion Gate Evidence
Tier: T5
Goal: Produce a QaaS test deliverable that is fully self-verifying: `dotnet run -- template` exits 0, live gate runs mocker+runner in one cmd and exits 0, and completion-gate checklist is satisfied with real command output as evidence.
SUT: Simple HTTP echo service (`POST /echo` returns request body); the challenge is the verification harness, not the SUT complexity.
Capabilities stacked: planning, runner, mocker, docker, docs
MOCK_REQUIRED: yes — echo service is mocked; mocker ProcessorConfiguration echoes request body.
FB slices: §1, §2, §3, §6, §13, §14
Trap mines: s13#14 (verify cmd must not start with #), s13#15 (mocker+runner in one cmd), s13#16 (port contract), s13#13 (vacuous pass), s13#7 (aspnet base image)
Hard because:
- Template oracle requires `dotnet run -- template <ConfigType>` to exit 0 for EVERY config type used
- Live gate must start mocker (background), wait-for-port, run runner, capture $LASTEXITCODE, stop mocker — all in one cmd (s13#15)
- Verify cmd must not start with `#` (s13#14); intent goes in `description:`
- Port contract must match across probe, mocker, runner (s13#16)
Verify (mechanical): `dotnet run -- template HttpTransactionConfiguration` exits 0; live-gate cmd exits 0; allure shows echo session green with count = 1; completion-gate checklist has real exit-code evidence for each step.
Rubric (graded): (1) Template oracle invoked for every config type used [0-10]; (2) Live gate is a single cmd with mocker lifecycle [0-10]; (3) Port contract consistent in all three places [0-10]; (4) Completion-gate checklist populated with real output (not placeholders) [0-10].
Solution sketch: Author mocker with echo processor (ProcessorConfiguration, not TransactionData); runner YAML with HttpTransaction POST /echo; verify step: single PowerShell cmd starts mocker in background, waits for port 8080, runs dotnet run, captures exit; all port references = 8080.

### Z-112: Kafka Exactly-Once Ordering Guarantee with Dead-Letter Lane
Tier: T5
Goal: Validate that a Kafka consumer processes 500 messages in partition-key order, routes malformed messages to a dead-letter topic, and the runner asserts exact counts on both lanes.
SUT: Kafka topic `events.main` (3 partitions, keyed by `tenantId`); consumer writes valid messages to DB and malformed to `events.dlq`; 50 of 500 messages are intentionally malformed.
Capabilities stacked: planning, runner, hooks, diagnose, docs
MOCK_REQUIRED: no — real Kafka in compose; runner uses KafkaConsumer and KafkaPublisher natively.
FB slices: §2, §9, §10, §11, §13
Trap mines: s13#3 (DataSourceNames required for 500 records), s13#13 (vacuous pass on DLQ consumer if 0 outputs), s13#17 (topology pre-creation — topics must exist), s13#12 (silent config key typo)
Hard because:
- Two consumer sessions (main + DLQ) each need count guards: 450 and 50 respectively
- Partition-key ordering requires a custom assertion hook comparing consecutive `seq` values within same `tenantId`
- 500 DataSourceNames entries with 50 deliberately malformed require a generator hook
- Topic creation via Stage 0 probe (Kafka variant of CreateRabbitMqExchanges)
Verify (mechanical): `dotnet build` exits 0; runner exits 0; main-consumer count = 450; DLQ count = 50; ordering assertion passes on main lane; allure shows both sessions green.
Rubric (graded): (1) Stage 0 probe creates both Kafka topics [0-10]; (2) DataSourceNames has 500 entries, 50 malformed [0-10]; (3) Custom ordering hook compares seq within tenantId partition [0-10]; (4) Both sessions have correct HermeticByExpectedOutputCount [0-10].
Solution sketch: CreateKafkaTopic probe at Stage 0 for both topics; DataSourceNames file with 450 valid + 50 malformed; `SequenceOrderAssertion` custom hook groups by `tenantId` and checks monotonic `seq`; two KafkaConsumer sessions with count 450 and 50; build + run.

### Z-113: Redis Controller Zero-Downtime Swap Under Continuous Load — Race-Condition Proof
Tier: T5
Goal: Prove that a mocker stub swap via Redis controller during a 1000-request runner load session produces no lost outputs and no undefined-state responses, only v1 or v2 responses.
SUT: HTTP service returning `{"schema":"v1"}` initially; mid-load swap to `{"schema":"v2"}`; runner sends 1000 requests continuously; every response must be either v1 or v2 (no error, no empty).
Capabilities stacked: planning, runner, mocker, hooks, diagnose, docs
MOCK_REQUIRED: yes — SUT is a mocker stub; Redis controller manages swap.
FB slices: §0, §2, §3, §9, §11, §13
Trap mines: s13#11 (controller boot log pattern), s13#4 (HttpStatus OutputNames list), s13#13 (vacuous pass), s13#5b (routes lowercase), s13#16 (port contract)
Hard because:
- Redis controller channel name must match exactly between mocker YAML and runner probe cmd
- 1000-request session must be split into pre-swap and post-swap halves hermetically
- Any race-condition response (empty body or error) must be caught by a custom assertion
- Controller boot log pattern (s13#11) must appear in compose logs before runner starts
Verify (mechanical): Controller boot log matches s13#11 pattern; v1-count + v2-count = 1000; no error responses; runner exits 0; allure shows two body-check sessions summing to 1000.
Rubric (graded): (1) Redis controller config channel matches between YAML and probe cmd [0-10]; (2) 1000 total requests with no gaps (v1+v2=1000) [0-10]; (3) Race-condition guard (no-empty-body assertion) present [0-10]; (4) Controller boot verified before runner stage executes [0-10].
Solution sketch: Mocker with Redis controller; Stage 0 = 500 POST /api requests; Stage 1 probe = Redis PUBLISH swap command; Stage 2 = 500 more requests; `HermeticByExpectedOutputCount` on each stage session = 500; `BodyNotEmpty` custom assertion on all outputs.

### Z-114: Consumer Exactly-Once with Dead-Letter Retry and Idempotency Proof
Tier: T5
Goal: Validate that a RabbitMQ consumer processes each message exactly once even when the broker delivers duplicates (simulated via requeue), and that retried-but-already-processed messages go to DLQ without double-processing.
SUT: Queue `orders.processing`; consumer acknowledges after DB write; broker configured to redeliver 20% of messages as duplicates; idempotency key is `orderId`; DLQ is `orders.dlq`.
Capabilities stacked: planning, runner, hooks, mocker, docs
MOCK_REQUIRED: yes — mocker simulates the consumer service and idempotency store; real RabbitMQ in compose.
FB slices: §2, §3, §9, §11, §12, §13
Trap mines: s13#17 (topology for both queues), s13#3 (DataSourceNames), s13#13 (vacuous pass on DLQ), s13#1 (ProcessorConfiguration not TransactionData)
Hard because:
- Duplicate simulation requires a custom mocker processor that requeues 20% probabilistically
- Idempotency assertion requires custom hook tracking seen `orderId` values and failing on duplicates
- Two queues need Stage 0 topology probes; DLQ binding must be configured
- Count guard on main queue = N_unique; DLQ count = N_duplicate (not zero)
Verify (mechanical): `dotnet build` exits 0; runner exits 0; main queue processed count = unique orderId count; DLQ count = duplicate count; no `orderId` appears twice in main-queue outputs; allure green.
Rubric (graded): (1) Both queues created via Stage 0 probes [0-10]; (2) Requeue processor in mocker uses ProcessorConfiguration correctly [0-10]; (3) Idempotency assertion custom hook compiles and tracks seen IDs [0-10]; (4) Count guards on both queues with correct expected values [0-10].
Solution sketch: Stage 0 probes create main + DLQ; DataSourceNames with 100 messages (80 unique, 20 duplicates); mocker `RequeueProcessor` with ProcessorConfiguration `{ RequeueRate: 0.2 }`; custom `IdempotencyAssertion` checks no duplicate `orderId`; count guard main=80, DLQ=20.

### Z-115: Docker Mocker with Custom Processor + Chaos Probe + Allure Collection
Tier: T5
Goal: Build a Docker mocker image with a custom stateless `IProcessorHook`, run it in compose with chaos injection (container pause/resume mid-suite), collect allure report, and assert no outputs lost during pause window.
SUT: HTTP service with a `POST /transform` endpoint; mocker processor applies a transformation; chaos probe pauses the container at Stage 1; Stage 2 verifies no messages dropped after resume.
Capabilities stacked: planning, mocker, docker, hooks, diagnose, docs
MOCK_REQUIRED: yes — custom processor requires building a Docker mocker image; no live SUT.
FB slices: §1, §3, §4, §6, §8, §12, §13
Trap mines: s13#7 (aspnet base image), s13#18 (no inline Dockerfile comments), s13#1 (ProcessorConfiguration), s13#8 (package ref for QaaS.Common.Processors), s13#5b (lowercase routes)
Hard because:
- Custom processor must be stateless (shared instance) and implement `IProcessorHook` correctly
- Dockerfile must use `aspnet:10.0` base; no inline comments on FROM/COPY/RUN (s13#18)
- Chaos probe (`docker pause`/`docker unpause`) must be a separate Stage 1 step
- After resume, runner must still collect all expected outputs (count guard must account for pause buffering)
Verify (mechanical): `docker build` exits 0; `docker compose up` exits 0; runner exits 0; allure shows no outputs lost; processor transformation applied to all outputs; custom processor compiles without FTL.
Rubric (graded): (1) Dockerfile uses `aspnet:10.0`, no inline comments [0-10]; (2) Processor implements `IProcessorHook`, stateless, correct package ref [0-10]; (3) Chaos probe stages pause/resume correctly [0-10]; (4) Count guard accounts for all outputs including buffered-during-pause [0-10].
Solution sketch: Multi-stage Dockerfile with `sdk:10.0` build + `aspnet:10.0` runtime; custom `TransformProcessor : IProcessorHook` with `QaaS.Common.Processors` ref; mocker YAML with ProcessorConfiguration; Stage 0 = 50 requests, Stage 1 probe = `docker pause`, Stage 2 = 50 more, Stage 3 probe = `docker unpause`; count guard = 100.

### Z-116: Cross-Broker Parity — RabbitMQ vs Kafka Same SUT with Output Equivalence Proof
Tier: T5
Goal: Validate that a dual-protocol SUT (publishes identical events to both RabbitMQ and Kafka simultaneously) produces byte-for-byte equivalent outputs on both brokers for every input message.
SUT: Event publisher sends same `UserCreated` event to RabbitMQ exchange `user.events` and Kafka topic `user-events`; two consumer endpoints must produce identical JSON payloads.
Capabilities stacked: analysis, planning, runner, hooks, docs
MOCK_REQUIRED: no — real RabbitMQ + Kafka in compose; runner uses native consumer action types for both.
FB slices: §2, §9, §10, §11, §13
Trap mines: s13#17 (topology pre-creation for RabbitMQ), s13#3 (DataSourceNames required), s13#13 (vacuous pass on either broker if events lag), s13#12 (silent typo in consumer config)
Hard because:
- Two consumer sessions must be correlated by message ID to prove byte-level equivalence
- RabbitMQ topology probe must run at Stage 0; Kafka topic creation also at Stage 0
- A custom `CrossBrokerEqualityAssertion` hook must pair outputs by `eventId` and compare
- Count guards must be identical on both sessions (N = total messages sent)
Verify (mechanical): `dotnet build` exits 0; runner exits 0; Rabbit count = N; Kafka count = N; custom equality assertion passes; allure shows both sessions green.
Rubric (graded): (1) Both topology probes present at Stage 0 [0-10]; (2) Custom equality assertion pairs by eventId [0-10]; (3) Identical DataSourceNames used for both broker inputs [0-10]; (4) Count guards = N on both consumer sessions [0-10].
Solution sketch: Stage 0: CreateRabbitMqExchanges probe + CreateKafkaTopic probe; Stage 1: publisher sends N messages; Stage 2: two consumer sessions (RabbitConsumer + KafkaConsumer) each with count guard N; `CrossBrokerEqualityAssertion` loads both output sets, pairs by `eventId`, fails on diff.

### Z-117: OpenAPI Contract Compliance + Semantic Drift Detection Between Spec Versions
Tier: T5
Goal: Given two OpenAPI specs (v1.0 and v2.0 of a catalog API), author assertions that pass for v2 while detecting behavioral regressions against v1's previously-green suite.
SUT: Catalog API: v1 has `GET /items` returning `{items: []}`, `POST /items`; v2 renames `items` to `products`, adds `POST /items/bulk`, deprecates `DELETE /items/{id}`.
Capabilities stacked: analysis, planning, runner, mocker, docs
MOCK_REQUIRED: yes — both API versions are mocked; separate mocker stubs for v1 and v2.
FB slices: §2, §3, §9, §13, §14
Trap mines: s13#5b (routes lowercase), s13#4 (HttpStatus keys), s13#13 (vacuous pass on deprecated endpoint), s13#12 (silent key typo if assertion config copied from v1)
Hard because:
- v1 suite's `JsonField` assertion on `items` must FAIL against v2 mocker (proves regression detection)
- v2 suite must have updated `JsonField` on `products` and new session for `/items/bulk`
- Deprecated `DELETE /items/{id}` in v2 returns 410; HttpStatus must assert `StatusCode: 410`
- All routes lowercase; `bulk` route must not have leading slash
Verify (mechanical): v1 suite against v1 mocker: all green; v1 suite against v2 mocker: `items` assertion fails; v2 suite against v2 mocker: all green; `bulk` session with count guard = 1; `StatusCode: 410` on deprecated endpoint.
Rubric (graded): (1) v1 suite fails against v2 mocker (regression proof) [0-10]; (2) v2 suite passes against v2 mocker [0-10]; (3) Deprecated endpoint asserts 410 with correct HttpStatus keys [0-10]; (4) All routes lowercase, no leading slash [0-10].
Solution sketch: Author two mocker YAML files (v1/v2); two runner YAML files; v1 runner `JsonField` on `items`; v2 runner `JsonField` on `products`; v2 runner adds bulk session; deprecation session with `StatusCode: 410`, `OutputNames: [deprecated-check]`; count guards on all sessions.

### Z-118: HMAC + JWT Rotation Within Single Session — Full Auth-Resource-Refresh Flow
Tier: T5
Goal: Execute a complete authentication choreography: HMAC-signed token request, resource access with JWT, forced expiry (TTL=5s), token refresh, and continued resource access — all in one session with hermetic output counts.
SUT: Gateway: `POST /auth` (HMAC body → JWT TTL=5s); `GET /resource` (Bearer JWT); `POST /auth/refresh` (expired JWT → new JWT); all routes lowercase.
Capabilities stacked: planning, runner, hooks, mocker, docs
MOCK_REQUIRED: yes — auth gateway is mocked; processor tracks JWT state and returns 401 on expiry.
FB slices: §2, §3, §4, §9, §12, §13
Trap mines: s13#1 (ProcessorConfiguration), s13#5b (lowercase routes), s13#4 (HttpStatus keys), s13#8 (package refs), s13#13 (vacuous pass if any stage produces 0 outputs)
Hard because:
- HMAC signing generator must compute per-request signature from secret key (not hardcoded)
- Processor must track JWT issue time and return 401 after TTL; TTL must be configurable via ProcessorConfiguration
- Session must model: Stage 0 = /auth, Stage 1 = /resource (200), delay probe = 6s, Stage 2 = /resource (401), Stage 3 = /auth/refresh, Stage 4 = /resource (200)
- Every stage needs count guard = 1; total 5 sessions
Verify (mechanical): `dotnet build` exits 0; Stage 1 returns 200; Stage 2 returns 401 after delay; Stage 3 returns new JWT; Stage 4 returns 200; allure shows 5 sessions all green; no vacuous passes.
Rubric (graded): (1) HMAC generator implements `IGeneratorHook`, computes correct signature [0-10]; (2) TTL processor uses ProcessorConfiguration with configurable TTL field [0-10]; (3) 6-stage session flow correctly modeled [0-10]; (4) Count guard = 1 on every stage session [0-10].
Solution sketch: `HmacRequestGenerator` yields requests with `X-HMAC-Signature` header; mocker `JwtTtlProcessor` with `ProcessorConfiguration: { TtlSeconds: 5 }` returns 401 after TTL; runner YAML: 5 HttpTransaction sessions at Stages 0-4 with a SleepProbe at Stage 2 for 6s; all count guards = 1.

### Z-119: Decimal-Precision Financial Marathon — 1000 Ledger Entries, 4dp, No Rounding
Tier: T5
Goal: Validate a financial ledger API that must process 1000 entries with amounts to 4 decimal places, asserting that no rounding or truncation occurs and that total sum equals the expected value.
SUT: `POST /ledger/entry` (JSON body with `amount: decimal`); `GET /ledger/balance` returns running total; both endpoints mocked.
Capabilities stacked: planning, runner, hooks, mocker, docs
MOCK_REQUIRED: yes — ledger service is mocked; mocker tracks running sum via stateful processor (ProcessorConfiguration holds precision config).
FB slices: §2, §3, §4, §9, §12, §13
Trap mines: s13#1 (ProcessorConfiguration), s13#13 (vacuous pass on balance GET if sum=0), s13#3 (DataSourceNames for 1000 entries), s13#12 (silent typo in assertion config)
Hard because:
- 1000 DataSourceNames entries with 4dp amounts must be generated (custom `IGeneratorHook`)
- Custom `DecimalPrecisionAssertion` must check each output amount string for exactly 4dp
- Balance assertion must compute expected sum and compare with tolerance = 0
- Mocker processor accumulates sum; must be stateless (use static/thread-safe accumulator)
Verify (mechanical): `dotnet build` exits 0; runner exits 0; 1000 entry count guards pass; `DecimalPrecisionAssertion` passes all entries; balance assertion matches precomputed sum.
Rubric (graded): (1) 1000 DataSourceNames with 4dp amounts [0-10]; (2) `DecimalPrecisionAssertion` compiles and checks string format [0-10]; (3) Balance assertion uses precomputed sum with zero tolerance [0-10]; (4) Mocker stateless processor accumulates correctly [0-10].
Solution sketch: `LedgerEntryGenerator` yields 1000 JSON bodies with `amount` formatted to 4dp; mocker `LedgerSumProcessor` (stateless via `Interlocked.Add`) accumulates sum; custom `DecimalFormatAssertion` checks regex `^\d+\.\d{4}$`; balance GET session asserts `JsonField` total = precomputed sum; count guards = 1000 and 1.

### Z-120: Airgap Compose + Allure + Offline Report Generation — CI Evidence Package
Tier: T5
Goal: Produce a CI-ready package (offline NuGet feed, pre-pulled images, compose file, runner YAML, verify script) that executes end-to-end in an airgapped environment and generates an allure report as evidence.
SUT: HTTP health-check service (`GET /health → 200 {"status":"ok"}`); complexity is the packaging and CI pipeline, not the SUT.
Capabilities stacked: planning, runner, mocker, docker, docs
MOCK_REQUIRED: yes — health service is mocked; image must be built and saved for airgap.
FB slices: §1, §6, §8, §13, §14
Trap mines: s13#7 (aspnet base), s13#18 (no Dockerfile inline comments), s13#19 (only mocker port exposed), s13#15 (single verify cmd), s13#14 (verify cmd not starting with #)
Hard because:
- `docker save` + `docker load` pipeline must be scripted; image tags must match compose file
- NuGet.Config must override all package sources with local path; no fallback to nuget.org
- Allure report generation requires `--allure-results-directory` flag in runner CLI (FB §6)
- Verify cmd must not start with `#` comment character (s13#14)
Verify (mechanical): No internet calls during `dotnet restore`; `docker load` succeeds from `.tar`; `docker compose up` exits 0; runner exits 0; `allure-results/` directory non-empty; verify cmd exits 0.
Rubric (graded): (1) NuGet.Config with local feed, no nuget.org fallback [0-10]; (2) Docker save/load pipeline scripted correctly [0-10]; (3) Allure results directory generated via CLI flag [0-10]; (4) Single verify cmd with correct lifecycle and no leading `#` [0-10].
Solution sketch: `nuget add` all QaaS packages to `./packages/`; NuGet.Config with `<clear />` then local source; `docker build + save` mocker image to `mocker.tar`; compose with `image: qaas-mocker-health`; verify script: `docker load < mocker.tar && docker compose up -d && dotnet run -- run --allure-results-directory ./allure-results && docker compose down`.

### Z-121: Version-Bump Regression — Package Upgrade Broke Behavior, Find and Fix
Tier: T5
Goal: Given a runner project whose package was bumped from Common.Assertions 3.4.0 to 3.5.1, identify which assertion behavior changed, locate the affected sessions, and repair without downgrading.
SUT: Provided runner project with 6 sessions; 2 are now failing after the version bump; the failure is a changed config key name or default behavior difference (as documented in FB §13).
Capabilities stacked: analysis, diagnose, docs, planning
MOCK_REQUIRED: n/a — version-bump regression analysis; no new mocker authoring.
FB slices: §7, §9, §13, §16
Trap mines: s13#9 (independent versions — only Common.Assertions changed, not Runner), s13#12 (silent key typo after key rename), s13#4 (HttpStatus key changes between versions)
Hard because:
- Must isolate which of the 6 sessions use the changed assertion type (not all are affected)
- Version-specific behavior change is not always documented; must use `dotnet run -- template` as oracle
- Fix must not introduce new drift (can't just copy s13 left-column keys)
- Must verify fix without downgrading (s13#9 enforces non-uniform versions)
Verify (mechanical): `dotnet build` exits 0 with Common.Assertions 3.5.1; runner exits 0; all 6 sessions green; `dotnet run -- template` confirms new key names match YAML.
Rubric (graded): (1) Affected sessions correctly identified (2 of 6) [0-10]; (2) Fix uses 3.5.1-correct key names per template oracle [0-10]; (3) Unaffected sessions untouched [0-10]; (4) Root cause cites FB §9 or §13 row [0-10].
Solution sketch: Run `dotnet run -- template <AssertionConfigType>` for each assertion type used; diff template output against existing YAML keys; identify the 2 sessions with renamed keys; update YAML to template-oracle names; re-run with 3.5.1 to confirm.

### Z-122: Mocker Processor Chain — Three Sequential Processors on Same Stub
Tier: T5
Goal: Configure a mocker stub with three chained ProcessorConfiguration hooks (validate → enrich → transform) and prove each runs in order with a custom assertion checking the final output shape.
SUT: `POST /process` endpoint; processor 1 validates required fields; processor 2 enriches with `timestamp`; processor 3 transforms `name` to uppercase; final response is validated by runner.
Capabilities stacked: planning, mocker, hooks, runner, docs
MOCK_REQUIRED: yes — entire processing chain is in the mocker; no real SUT.
FB slices: §3, §4, §9, §12, §13
Trap mines: s13#1 (ProcessorConfiguration not TransactionData), s13#8 (QaaS.Common.Processors ref required), s13#5b (route lowercase), s13#13 (vacuous pass if processor chain fails silently)
Hard because:
- Three processors on one stub requires understanding mocker YAML processor-list syntax (not documented prominently)
- Each processor must be stateless; shared state between processors requires thread-safe design
- Custom `ChainOrderAssertion` must verify all three modifications are present in final output
- Silent failure in processor 1 (validation) would pass vacuously if count guard absent
Verify (mechanical): `dotnet build` exits 0; runner exits 0; output contains `timestamp`, uppercase `name`, and validation field; count guard = N; allure green; no vacuous passes.
Rubric (graded): (1) Three processors in mocker YAML with correct ProcessorConfiguration syntax [0-10]; (2) All three processors stateless with QaaS.Common.Processors ref [0-10]; (3) Custom assertion verifies chain output shape [0-10]; (4) Count guard prevents vacuous pass [0-10].
Solution sketch: Mocker stub with `Processors: [ValidateProcessor, EnrichProcessor, TransformProcessor]`; each implements `IProcessorHook` with distinct ProcessorConfiguration record; runner HttpTransaction POST /process with `JsonField` assertions on `timestamp`, uppercase `name`; count guard = 10.

### Z-123: Multi-Tenant Session Isolation — N Parallel Sessions, No Cross-Contamination
Tier: T5
Goal: Prove that N=5 concurrent QaaS sessions targeting tenant-isolated endpoints produce no cross-contamination: each session's outputs contain only its own `tenantId` value.
SUT: HTTP API with tenant header `X-Tenant-ID`; routes the request to a tenant-specific queue; each tenant has an isolated data store; mocked with 5 separate stub configurations.
Capabilities stacked: planning, runner, mocker, hooks, docs
MOCK_REQUIRED: yes — 5-tenant isolation requires mocker stubs with header-based routing; no real multi-tenant SUT.
FB slices: §2, §3, §9, §13, §14
Trap mines: s13#5b (all tenant routes must be lowercase), s13#13 (vacuous pass if tenant header mismatch → 0 matching outputs), s13#16 (port contract — single mocker port for all tenants), s13#4 (HttpStatus OutputNames list)
Hard because:
- Mocker must route by `X-Tenant-ID` header to different stubs (header-matching in mocker YAML)
- Custom `TenantIsolationAssertion` must verify each output's `tenantId` matches session's expected value
- 5 sessions × count guard = 20 requests each; cross-contamination = any output with wrong tenantId
- Single mocker port for all 5 tenants; no duplicate ports (s13#16)
Verify (mechanical): `dotnet build` exits 0; runner exits 0; 5 sessions each show 20 outputs; `TenantIsolationAssertion` passes all; no output from session A appears in session B; allure green.
Rubric (graded): (1) Mocker header-routing config for 5 tenants on single port [0-10]; (2) Custom isolation assertion verifies tenantId per output [0-10]; (3) Count guards = 20 on all 5 sessions [0-10]; (4) All routes lowercase end-to-end [0-10].
Solution sketch: Mocker YAML with 5 stubs differentiated by `RequestCondition: Headers: X-Tenant-ID = tenantN`; runner YAML with 5 HttpTransaction sessions, each setting `X-Tenant-ID` header; `TenantIsolationAssertion` hook checks `tenantId` field in response body; count guard = 20 per session.

### Z-124: Flawed Suite Repair — Vacuous HttpStatus + Missing Guards + Silently-Ignored Keys
Tier: T5
Goal: Given a QaaS suite with 4 specific planted defects (vacuous HttpStatus, missing count guard, silently-ignored config key, wrong OutputName scalar vs list), identify all 4 and produce a defect-free suite.
SUT: Provided: runner YAML with 4 sessions (each with one planted defect); mocker YAML is correct; task is YAML repair only.
Capabilities stacked: analysis, diagnose, docs
MOCK_REQUIRED: n/a — mocker YAML is correct; only runner YAML repair needed.
FB slices: §7, §9, §13
Trap mines: s13#13 (vacuous HttpStatus), s13#12 (silent key typo), s13#4 (OutputName scalar not list), s13#3 (missing DataSourceNames)
Hard because:
- All 4 defects are silent (no build error, no runner crash) — each produces a vacuous green
- Silent key typo is only detectable by character-exact comparison against catalog
- Vacuous HttpStatus is only visible by checking if count guard present AND OutputNames is a list
- Must prove detection by running defective suite first (confirms green), then repaired suite
Verify (mechanical): Defective suite run exits 0 (all vacuous green); repaired suite exits 0 with real assertions; `dotnet run -- template HttpStatusConfiguration` confirms key names; count guards present on all sessions.
Rubric (graded): (1) All 4 defects identified with s13 row citations [0-10]; (2) Defective suite demonstrated as vacuously green [0-10]; (3) Repaired suite passes with real assertions [0-10]; (4) OutputNames changed from scalar to list on affected session [0-10].
Solution sketch: Run suite as-is and record vacuous greens; audit each session against §9 catalog and s13 table; fix: add `HermeticByExpectedOutputCount`; change `OutputName: x` to `OutputNames: [x]`; correct key typo to catalog spelling; add `DataSourceNames`; re-run and compare.

### Z-125: Proto/gRPC Contract → Derive Full Kafka Consumer Suite
Tier: T5
Goal: Given a `.proto` file defining a `UserEvent` message, derive a QaaS Kafka consumer runner suite that validates deserialized message fields, ordering, and count — no gRPC transport (Kafka serialization only).
SUT: Kafka topic `user-events-proto`; producer serializes `UserEvent` proto messages; consumer deserializes and exposes JSON; runner validates JSON outputs.
Capabilities stacked: analysis, planning, runner, hooks, docs
MOCK_REQUIRED: no — real Kafka in compose; producer is a provided seed script; consumer is the real SUT.
FB slices: §2, §9, §10, §11, §13
Trap mines: s13#3 (DataSourceNames required for Kafka publisher), s13#13 (vacuous pass if consumer lag), s13#17 (Kafka topic creation probe), s13#12 (silent key typo in consumer config)
Hard because:
- Proto field mapping to JSON requires documenting the expected JSON shape per proto field
- Custom `ProtoFieldAssertion` must validate required fields from proto schema (no generated types available)
- Kafka topic creation at Stage 0; proto-encoded DataSourceNames require binary encoding step
- Ordering must be asserted by `seq` field within same partition key
Verify (mechanical): `dotnet build` exits 0; runner exits 0; Kafka consumer count = N; `ProtoFieldAssertion` passes all required fields; ordering assertion passes; topic creation probe at Stage 0.
Rubric (graded): (1) Kafka topic creation probe at Stage 0 [0-10]; (2) DataSourceNames encodes proto messages correctly [0-10]; (3) Custom `ProtoFieldAssertion` validates all required proto fields [0-10]; (4) Ordering assertion checks `seq` monotonicity [0-10].
Solution sketch: Stage 0 CreateKafkaTopic probe; DataSourceNames file with N proto-serialized messages (pre-generated by seed script); KafkaConsumer session with count guard N; `JsonField` assertions on deserialized `userId`, `eventType`, `timestamp`; custom `SequentialFieldAssertion` checks monotonic `seq`.

### Z-126: Broker Restart Chaos with Hermetic Count Guard — RabbitMQ Mid-Consumer Drain
Tier: T5
Goal: Publish 300 durable messages to a RabbitMQ queue, kill the broker after 150 are consumed, restart it, and assert that the remaining 150 are delivered exactly once after restart with no duplicates.
SUT: RabbitMQ queue `work.durable` (durable=true, ack=manual); consumer acks after processing; runner sends 300 messages via publisher; chaos probe kills/restarts broker at midpoint.
Capabilities stacked: planning, runner, hooks, diagnose, docs
MOCK_REQUIRED: no — real RabbitMQ in compose; chaos is a probe, not a mocker behavior.
FB slices: §2, §9, §11, §13
Trap mines: s13#17 (topology pre-creation), s13#3 (DataSourceNames = 300 entries), s13#13 (vacuous pass if consumer reconnect produces 0), s13#15 (live-run all in one cmd)
Hard because:
- Stage-split consumer sessions require Stage 0 = first 150 consumed, then chaos probe, then Stage 1 = next 150
- Hermetic count guard on total consumer session must be 300 (not 150+150)
- Manual ack must be verified — if consumer uses auto-ack, redelivered messages are duplicated
- A custom `DuplicateMessageAssertion` must track `messageId` across both stage halves
Verify (mechanical): `dotnet build` exits 0; runner exits 0; total consumer count = 300; no duplicate messageIds; broker restart log visible in allure artifacts; allure green.
Rubric (graded): (1) Durable queue topology probe at Stage 0 [0-10]; (2) Broker restart probe correctly staged between consume stages [0-10]; (3) DuplicateMessageAssertion tracks messageId across stages [0-10]; (4) Total count guard = 300, not split across two guards [0-10].
Solution sketch: Stage 0: CreateRabbitMqQueues (durable=true); Stage 1: Publisher 300 messages; Stage 2: Consumer (HermeticByExpectedOutputCount=150); Stage 3 probe: `docker restart rabbitmq`; Stage 4: Consumer (count=150); `DuplicateMessageAssertion` runs post-stage on combined output set.

### Z-127: Performance SLA Window — Latency Assertion + Count Assertion Simultaneously
Tier: T5
Goal: Prove that an HTTP API processes 200 requests within a 10-second window (20 req/s) while maintaining p99 latency < 500ms — both constraints asserted hermetially in the same session.
SUT: HTTP `GET /query` endpoint; mocked with a configurable delay processor (ProcessorConfiguration.DelayMs); default delay = 100ms; P99 target < 500ms.
Capabilities stacked: planning, runner, mocker, hooks, docs
MOCK_REQUIRED: yes — delay simulation requires mocker processor; no real SUT with controllable latency.
FB slices: §2, §3, §9, §11, §12, §13
Trap mines: s13#1 (ProcessorConfiguration not TransactionData), s13#13 (vacuous pass if 0 outputs inside window), s13#16 (port contract), s13#4 (HttpStatus keys for 200 assertion)
Hard because:
- `LatencyWindowAssertion` custom hook must compute p99 from response timing metadata
- Count guard must be exactly 200; any timeout/drop fails both SLA and count
- Mocker processor delay must be configurable to test boundary conditions (100ms vs 490ms vs 510ms)
- Session duration window must be enforced; cannot simply run 200 sequential requests with no time constraint
Verify (mechanical): `dotnet build` exits 0; runner exits 0 with 100ms delay; count = 200; p99 < 500ms; runner exits non-0 with 510ms delay (p99 exceeded); allure shows latency histogram.
Rubric (graded): (1) Custom `LatencyWindowAssertion` computes p99 from output timestamps [0-10]; (2) Count guard = 200 on session [0-10]; (3) Mocker ProcessorConfiguration.DelayMs configurable [0-10]; (4) Both SLA (count + latency) fail correctly on boundary breach [0-10].
Solution sketch: Mocker `DelayProcessor` with `ProcessorConfiguration: { DelayMs: 100 }`; runner HttpTransaction 200 requests; `LatencyWindowAssertion` hook reads response `X-Processing-Time` headers, sorts, picks p99; `HermeticByExpectedOutputCount: 200`; test boundary: change DelayMs to 510, confirm failure.

### Z-128: Redis State Verification Across Session Boundaries — Multi-Stage State Machine
Tier: T5
Goal: Validate a state-machine service where HTTP calls transition state stored in Redis, and a QaaS suite asserts the correct Redis state after each transition using Redis probes.
SUT: State machine: `POST /order/create` → Redis key `order:{id}` = "created"; `POST /order/{id}/pay` → Redis key = "paid"; `POST /order/{id}/ship` → Redis key = "shipped"; all via mocker.
Capabilities stacked: planning, runner, mocker, hooks, docs
MOCK_REQUIRED: yes — state machine transitions are simulated via mocker + Redis controller; no real SUT.
FB slices: §0, §2, §3, §9, §11, §13
Trap mines: s13#5b (routes lowercase), s13#5 (no leading slash), s13#13 (vacuous pass on state-read if Redis returns empty), s13#16 (port contract across all 3 routes), s13#11 (controller boot log)
Hard because:
- Redis state must be read by a probe after each HTTP transition and compared to expected value
- Three separate HTTP sessions (one per transition) each with count guard = 1
- Mocker must update Redis state via controller after each stub is hit
- Port contract: single HTTP port for all three mocker routes (s13#16)
Verify (mechanical): `dotnet build` exits 0; runner exits 0; Redis probe after /create reads "created"; after /pay reads "paid"; after /ship reads "shipped"; all HttpStatus sessions have count guard = 1; allure green.
Rubric (graded): (1) Three HTTP sessions with correct routes (no slash, lowercase) [0-10]; (2) Redis read probe after each session with state comparison [0-10]; (3) Mocker updates Redis state correctly (controller or processor) [0-10]; (4) Count guard = 1 on all HTTP sessions [0-10].
Solution sketch: Mocker with Redis controller; 3 stubs (/order/create, /order/{id}/pay, /order/{id}/ship) each triggering Redis HSET via processor; runner YAML: Stage 0 = POST /order/create + Redis probe; Stage 1 = POST /order/1/pay + Redis probe; Stage 2 = POST /order/1/ship + Redis probe; all count guards = 1.

### Z-129: Fan-Out with Convergence — N Publishers, M Consumers, All-Arrived Proof
Tier: T5
Goal: Publish messages from 5 parallel publisher sessions to a RabbitMQ fanout exchange, consumed by 3 separate consumer sessions, and assert that every published message arrived on every consumer.
SUT: RabbitMQ fanout exchange `events.fan`; 3 bound queues `events.q1`, `events.q2`, `events.q3`; 5 publishers each send 20 messages = 100 total; each consumer receives all 100.
Capabilities stacked: planning, runner, hooks, docs
MOCK_REQUIRED: no — real RabbitMQ in compose; fan-out topology is real.
FB slices: §2, §9, §11, §13
Trap mines: s13#17 (topology: exchange + 3 queues + 3 bindings at Stage 0), s13#3 (DataSourceNames = 100 messages), s13#13 (vacuous pass if consumer lag causes 0 on any queue), s13#12 (silent typo in consumer config)
Hard because:
- Stage 0 must create fanout exchange + 3 queues + bind all 3 queues to exchange
- 5 publisher sessions × 20 messages each = 100 published; each consumer must receive exactly 100
- Count guard per consumer = 100; if any queue misses even 1 message, fan-out is broken
- Custom `FanOutCompletenessAssertion` must verify all 100 message IDs arrived on each queue
Verify (mechanical): `dotnet build` exits 0; runner exits 0; each consumer count = 100; `FanOutCompletenessAssertion` passes all 3 queues; topology probe logs show exchange + 3 queue bindings; allure green.
Rubric (graded): (1) Stage 0 topology probe creates exchange + 3 queues + 3 bindings [0-10]; (2) 5 publisher sessions with DataSourceNames correctly partitioned [0-10]; (3) Count guard = 100 on all 3 consumer sessions [0-10]; (4) FanOutCompletenessAssertion checks all 100 message IDs per queue [0-10].
Solution sketch: Stage 0: `CreateRabbitMqExchanges` (type=fanout) + `CreateRabbitMqQueues` × 3 + bind probes; 5 `RabbitMqPublisher` sessions at Stage 1 each with 20 DataSourceNames; Stage 2: 3 `RabbitMqConsumer` sessions (count=100 each); `FanOutCompletenessAssertion` stores all message IDs from publishers, verifies against each consumer output set.

### Z-130: Side-by-Side v1/v2 Migration with Divergence Mapping and Parity Report
Tier: T5
Goal: Run a migration test that simultaneously exercises v1 and v2 of a messaging SUT, asserts parity on backward-compatible fields, documents deliberate divergences, and outputs an allure report highlighting both.
SUT: Kafka topic `orders.v1` and `orders.v2`; same logical order events; v2 adds `fulfillmentCenter` field, changes `status` from string to enum int, drops `legacyCode` field.
Capabilities stacked: analysis, planning, runner, hooks, diagnose, docs
MOCK_REQUIRED: no — real Kafka in compose with two topics; no mocker needed.
FB slices: §2, §9, §10, §11, §13
Trap mines: s13#17 (Kafka topic creation for both topics), s13#3 (identical DataSourceNames published to both), s13#13 (vacuous pass if either topic has 0 outputs), s13#12 (silent key typo in Kafka consumer config)
Hard because:
- Two consumer sessions must be run simultaneously; output correlation is by `orderId`
- Custom `MigrationParityAssertion` must assert equal values for backward-compat fields
- Divergence assertions must explicitly assert: `fulfillmentCenter` present in v2 only; `status` is int in v2; `legacyCode` absent in v2
- Count guards on both topics must be equal (same messages published to both)
Verify (mechanical): `dotnet build` exits 0; runner exits 0; both consumer counts = N; parity assertion passes on shared fields; divergence assertions pass; allure shows migration report with parity + divergence annotations.
Rubric (graded): (1) Both Kafka topic creation probes at Stage 0 [0-10]; (2) `MigrationParityAssertion` validates shared fields [0-10]; (3) Three divergence assertions explicitly tested [0-10]; (4) Count guards equal on both sessions [0-10].
Solution sketch: Stage 0: two CreateKafkaTopic probes; same DataSourceNames file published to both topics; two KafkaConsumer sessions (count=N each); `MigrationParityAssertion` correlates by `orderId`, checks `customerId` + `totalAmount` equality; explicit `FieldPresent/Absent` assertions for divergences.

### Z-131: Full-Stack Payment Flow — Auth → Charge → Webhook Notify, End-to-End
Tier: T5
Goal: Test a three-step payment flow: authenticate via HTTP, charge via HTTP (which publishes to RabbitMQ), consume the webhook notification from RabbitMQ, and assert all three steps completed with correct data linkage.
SUT: `POST /auth` → JWT; `POST /charge` (Bearer JWT, publishes `charge.completed` to RabbitMQ); RabbitMQ consumer delivers webhook notification; runner asserts charge ID links all three.
Capabilities stacked: planning, runner, mocker, hooks, docs
MOCK_REQUIRED: yes — all three services are mocked; mocker HTTP stubs + RabbitMQ publisher simulation.
FB slices: §0, §2, §3, §9, §11, §13
Trap mines: s13#17 (RabbitMQ topology probe), s13#5b (routes lowercase), s13#4 (HttpStatus keys), s13#13 (vacuous pass on consumer if charge event never published), s13#3 (DataSourceNames for charge session)
Hard because:
- Data linkage: `chargeId` from POST /charge response must appear in RabbitMQ consumer output
- Mocker must publish to RabbitMQ on /charge stub (requires processor integration with AMQP client)
- Three-session flow requires stage gating: auth (Stage 0), charge (Stage 1), consume (Stage 2)
- Custom `ChargeIdLinkageAssertion` must correlate HTTP charge response with queue message
Verify (mechanical): `dotnet build` exits 0; runner exits 0; auth session count=1; charge session count=1; consumer count=1; `chargeId` matches in charge response and queue message; allure green.
Rubric (graded): (1) Three-stage flow with correct stage assignments [0-10]; (2) Mocker charge stub publishes to RabbitMQ via processor [0-10]; (3) `ChargeIdLinkageAssertion` correlates across sessions [0-10]; (4) Topology probe + count guards on all three sessions [0-10].
Solution sketch: Stage 0: POST /auth (count=1); Stage 1: POST /charge with `Authorization: Bearer {{jwt}}` (count=1), mocker processor publishes `charge.completed` to AMQP; Stage 2: RabbitMqConsumer (count=1); `ChargeIdLinkageAssertion` reads Stage 1 output, confirms `chargeId` matches Stage 2 output field.

### Z-132: Self-Healing Test — Probe-Driven Retry + Assertion on Eventual Consistency
Tier: T5
Goal: Test a system that becomes eventually consistent: an HTTP POST triggers async processing; a probe polls `GET /status/{id}` until `status=completed` (max 30s); then final assertion validates the completed state.
SUT: `POST /jobs` → `{"jobId":"x"}`; async worker processes job; `GET /status/x` returns `{status: pending|completed}`; polling until `completed` within 30s.
Capabilities stacked: planning, runner, hooks, mocker, docs
MOCK_REQUIRED: yes — async worker behavior (pending → completed transition) requires mocker with stateful processor tracking call count.
FB slices: §2, §3, §9, §11, §12, §13
Trap mines: s13#1 (ProcessorConfiguration), s13#5b (route lowercase), s13#13 (vacuous pass if poll returns 0 outputs before status=completed), s13#16 (port contract for both routes)
Hard because:
- Mocker processor must transition state from "pending" to "completed" after N polls (simulating async delay)
- Runner probe must implement polling loop (not just a one-shot check) — requires custom `PollingProbe`
- Count guard on final assertion = 1 (only completed status); intermediate pending responses not counted
- Port contract must be consistent for both /jobs and /status/{jobId} routes (s13#16)
Verify (mechanical): `dotnet build` exits 0; runner exits 0; POST /jobs count=1; polling probe transitions through pending → completed; final status assertion count=1 with `status=completed`; allure green.
Rubric (graded): (1) Mocker processor transitions state after N polls via ProcessorConfiguration [0-10]; (2) Custom `PollingProbe` implements retry loop with timeout [0-10]; (3) Count guard on final status session = 1 [0-10]; (4) Port contract consistent across /jobs and /status routes [0-10].
Solution sketch: Mocker stateful processor: first 3 calls return `status: pending`, 4th returns `status: completed` (ProcessorConfiguration: { TransitionAfterCalls: 3 }); Stage 0: POST /jobs; Stage 1: `PollingProbe` calls GET /status/{jobId} every 2s up to 30s; Stage 2: GET /status/{jobId} final with `JsonField: status=completed`, count=1.

### Z-133: Airgap + Offline NuGet + Docker Save/Load + Compose + Run — Scripted CI Evidence
Tier: T5
Goal: Produce a fully scripted CI pipeline (single `.ps1` file) that reproduces a QaaS test run airgap end-to-end: NuGet restore from local feed, docker load, compose up, run, allure, tear down — with exit-code-based pass/fail.
SUT: RabbitMQ consumer test (already authored); challenge is the airgap CI script with complete lifecycle, correct error propagation, and no internet dependencies.
Capabilities stacked: planning, runner, mocker, docker, docs
MOCK_REQUIRED: yes — mocker image pre-built and saved; CI script must `docker load` it.
FB slices: §1, §6, §8, §13, §14
Trap mines: s13#7 (aspnet base), s13#14 (no leading # in verify cmd), s13#15 (single lifecycle cmd), s13#18 (no inline Dockerfile comments), s13#19 (only mocker port exposed in compose)
Hard because:
- PowerShell script must handle each step's exit code independently and fail-fast
- NuGet.Config must use `<clear />` to prevent fallback to nuget.org
- Compose internal services (RabbitMQ) must have no host port mapping (s13#19)
- Allure results directory path must be an absolute path in the CI script
Verify (mechanical): Script exits 0 on full run; no internet calls during execution; allure-results/ non-empty; docker load succeeds from .tar; compose up shows only mocker port exposed; script exits non-0 if runner fails.
Rubric (graded): (1) PowerShell script fail-fast on each step exit code [0-10]; (2) NuGet.Config with `<clear />` + local feed only [0-10]; (3) Compose exposes only mocker port, not RabbitMQ [0-10]; (4) Allure results generated at absolute path [0-10].
Solution sketch: `ci.ps1`: (1) `nuget restore` from `./packages/`; (2) `docker load < mocker.tar`; (3) `docker compose up -d`; (4) port-wait loop for mocker; (5) `dotnet run -- run --allure-results-directory $PWD/allure-results`; (6) `$exit = $LASTEXITCODE`; (7) `docker compose down`; (8) `exit $exit`; each step: `if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }`.

### Z-134: Proto/gRPC Contract → Kafka Consumer Suite with Field-Level Assertions
Tier: T5
Goal: Derive a Kafka consumer test suite from a `.proto` schema; validate that all required fields are deserialized correctly, optional fields are handled gracefully, and field count matches schema version.
SUT: Kafka topic `user-proto-events`; `UserEvent` proto with required: `userId (string)`, `eventType (enum)`, `timestamp (int64)`; optional: `metadata (map<string,string>)`.
Capabilities stacked: analysis, planning, runner, hooks, docs
MOCK_REQUIRED: no — real Kafka in compose; proto seed data pre-generated; consumer is real SUT.
FB slices: §2, §9, §10, §11, §13
Trap mines: s13#17 (Kafka topic creation), s13#3 (DataSourceNames = N pre-generated proto records), s13#13 (vacuous pass if consumer lag), s13#12 (silent config typo in Kafka consumer)
Hard because:
- Required vs optional field assertions need two separate assertion hooks
- `eventType` enum must be validated as one of a defined set of string values (not arbitrary)
- `metadata` map must be validated as key-value pairs (not flat JSON) — requires custom hook
- 100 messages: 80 with metadata, 20 without; optional-field assertion must not fail on absent metadata
Verify (mechanical): `dotnet build` exits 0; runner exits 0; count = 100; required-field assertions pass all 100; optional-field assertion passes 80 with metadata and 20 without; enum assertion passes all 100.
Rubric (graded): (1) Kafka topic creation at Stage 0 [0-10]; (2) Required-field assertions on userId, eventType, timestamp [0-10]; (3) Optional-field metadata assertion handles absent case gracefully [0-10]; (4) Enum value assertion validates eventType against defined set [0-10].
Solution sketch: Stage 0: CreateKafkaTopic; DataSourceNames = 100 pre-generated JSON records (80 with metadata, 20 without); KafkaConsumer with count=100; `JsonField` assertions on required fields; custom `OptionalMapAssertion` handles metadata presence/absence; custom `EnumValueAssertion` checks eventType ∈ {CREATED, UPDATED, DELETED}.

### Z-135: Regression Archaeology with Allure Timeline Diff — Find the Regression Commit
Tier: T5
Goal: Given two allure reports (last-green and now-failing) and a git log with 5 commits between them, identify which commit introduced the regression by comparing session status changes and config diffs.
SUT: HTTP CRUD API with 8 sessions; regression manifests as 2 sessions changing from PASSED to FAILED between allure reports; git diff shows 5 candidate commits.
Capabilities stacked: analysis, diagnose, docs
MOCK_REQUIRED: n/a — read-only archaeology; no new mocker or runner authoring.
FB slices: §7, §9, §13, §6
Trap mines: s13#9 (version bump may be the regression), s13#12 (silent key typo introduced in a commit), s13#4 (OutputNames changed from list to scalar in a commit), s13#13 (new vacuous pass introduced)
Hard because:
- Must bisect 5 commits to find the exact regression commit without re-running all 5
- Session status change in allure JSON requires parsing `testCase.status` field in allure-results/
- Regression may be a one-character key change (s13#12) invisible in code review
- Evidence must be mechanical: cite the allure-results/ file and line number where status changed
Verify (mechanical): Correct commit identified (e.g., `abc1234`); specific YAML line cited; fix applied; re-run exits 0; allure shows same 8 sessions green as last-green report.
Rubric (graded): (1) Correct regression commit identified with file+line citation [0-10]; (2) Root cause is one of the s13 drift traps (cited by row) [0-10]; (3) Fix is minimal (1 key change) [0-10]; (4) Re-run produces allure matching last-green report [0-10].
Solution sketch: Parse allure-results/*.json from both reports; diff `testCase.status` for each session name; identify 2 changed sessions; grep git log commits for changes to those session files; find commit touching the exact config key; cross-reference against s13 table; apply fix; re-run.

### Z-136: HMAC Signing Chain Across Three Cascaded HTTP Calls — Stateful Signature Tracking
Tier: T5
Goal: Test an API gateway where each call must include an HMAC signature derived from the previous call's response nonce, creating a chain of 3 signed requests that a custom generator produces in sequence.
SUT: `POST /init` → `{"nonce":"n1"}`; `POST /step1` (signed with n1) → `{"nonce":"n2"}`; `POST /step2` (signed with n2) → `{"result":"ok"}`; all routes lowercase; all via mocker.
Capabilities stacked: planning, runner, hooks, mocker, docs
MOCK_REQUIRED: yes — nonce generation chain is mocker-driven via stateful processor; no real auth service.
FB slices: §2, §3, §4, §9, §12, §13
Trap mines: s13#1 (ProcessorConfiguration), s13#5b (lowercase routes), s13#4 (HttpStatus keys), s13#13 (vacuous pass on /step2 if chain broken), s13#8 (generator hook package ref)
Hard because:
- Generator hook must read the previous session's output nonce to compute the next signature
- Session must be strictly sequential (Stage 0 = /init, Stage 1 = /step1, Stage 2 = /step2)
- Mocker processor must validate the HMAC signature and return 401 if invalid — tests the chain
- Custom `HmacChainGenerator` must maintain stateful nonce between stages (session-scoped variable)
Verify (mechanical): `dotnet build` exits 0; runner exits 0; /init count=1; /step1 count=1 with valid HMAC; /step2 count=1 with valid HMAC; mocker returns 401 on tampered signature (negative test); allure green.
Rubric (graded): (1) HmacChainGenerator reads nonce from prior output and computes correct signature [0-10]; (2) Mocker processor validates signature and returns 401 on failure [0-10]; (3) Three-stage sequential session structure [0-10]; (4) Negative test (tampered signature) verified [0-10].
Solution sketch: `HmacChainGenerator : IGeneratorHook` reads `{{output.nonce}}` from previous stage output, computes `HMAC-SHA256(secret, nonce + body)`, injects `X-Signature` header; mocker `HmacValidatorProcessor` (ProcessorConfiguration: { Secret: "test-secret" }) returns 401 on mismatch; 3-stage runner sessions; negative test uses wrong secret.

### Z-137: Chaos: RabbitMQ Restart Mid-Consumer With Exactly-Once Proof
Tier: T5
Goal: Publish 500 durable messages; consumer processes 250; broker is restarted; consumer drains remaining 250 after reconnect; assert exactly-once delivery (no duplicates, no drops) across restart.
SUT: RabbitMQ durable queue `tasks.main`; consumer uses manual ack; broker runs in Docker; chaos probe at Stage 2 restarts the broker container.
Capabilities stacked: planning, runner, hooks, diagnose, docs
MOCK_REQUIRED: no — real RabbitMQ; chaos is a probe; no mock needed.
FB slices: §2, §9, §11, §13
Trap mines: s13#17 (topology: durable queue), s13#3 (DataSourceNames = 500), s13#13 (vacuous pass if consumer reconnect yields 0), s13#15 (full lifecycle in one verify cmd)
Hard because:
- Manual ack must be verified; auto-ack would duplicate messages on restart
- `DuplicateDetectionAssertion` must scan all 500 consumed messages for duplicate `messageId`
- Stage 3 consumer session must explicitly wait for broker readiness before polling (probe with port-wait)
- Count guard = 500 total across both consumer stages; not 250+250 separately
Verify (mechanical): Runner exits 0; total consumer outputs = 500; no duplicate messageIds; broker restart logged in probe output; allure shows exactly-once annotation; count guard fires if < 500.
Rubric (graded): (1) Durable queue topology probe at Stage 0 [0-10]; (2) Broker restart probe correctly staged at Stage 2 [0-10]; (3) DuplicateDetectionAssertion scans all 500 outputs [0-10]; (4) Port-wait probe before Stage 3 consumer ensures broker ready [0-10].
Solution sketch: Stage 0: CreateRabbitMqQueues (durable=true); Stage 1: Publisher 500; Stage 2: Consumer (count=250); Stage 3 probe: docker restart + wait-for-port 5672; Stage 4: Consumer (count=250); `DuplicateDetectionAssertion` post-run on combined set.

### Z-138: Decimal-Precision Financial Processing — No Float Drift in 2000 Calculations
Tier: T5
Goal: Validate that a financial calculation service processes 2000 decimal amounts with no floating-point drift: each output must match the expected value to 6 decimal places, and running total must be exact.
SUT: `POST /calculate` accepts `{amount: string, operation: "compound"}` and returns `{result: string}` where result is a decimal string to 6dp; no floats in transport.
Capabilities stacked: planning, runner, mocker, hooks, docs
MOCK_REQUIRED: yes — calculation service is mocked with a processor that applies exact decimal arithmetic; validates that the runner's assertion chain can detect float drift if it occurs.
FB slices: §2, §3, §4, §9, §12, §13
Trap mines: s13#1 (ProcessorConfiguration for calculation config), s13#3 (DataSourceNames = 2000 records), s13#13 (vacuous pass if processor returns empty result), s13#12 (silent typo in processor config key)
Hard because:
- DataSourceNames must contain 2000 pre-computed decimal pairs (input → expected output to 6dp)
- Custom `DecimalExactAssertion` must parse decimal strings and compare without converting to double
- Running-total assertion requires stateful accumulation in custom hook (thread-safe)
- Mocker processor must not introduce float drift (must use `decimal` type internally)
Verify (mechanical): `dotnet build` exits 0; runner exits 0; count = 2000; all result strings match expected to 6dp; running total = precomputed exact value; no float-drift assertion failures; allure green.
Rubric (graded): (1) 2000 DataSourceNames with 6dp decimal amounts [0-10]; (2) `DecimalExactAssertion` compares decimal strings without float conversion [0-10]; (3) Running-total assertion stateful and thread-safe [0-10]; (4) Mocker processor uses `decimal` type (not `double`) [0-10].
Solution sketch: DataSourceNames CSV: `amount,expected` (2000 rows, 6dp strings); `DecimalExactAssertion` parses with `decimal.Parse()`, compares equality; `RunningTotalAssertion` uses `Interlocked`-guarded `decimal` accumulator; mocker processor: `decimal.Round(amount * rate, 6, MidpointRounding.AwayFromZero)`; count guard = 2000.

### Z-139: Zero-Downtime Redis Controller Config Swap — Dual-Behavior Proof Under Traffic
Tier: T5
Goal: Prove a mocker can serve two behaviors (fast path vs slow path) by swapping stub configuration via Redis controller during an active runner session, with no requests failing and behavior change captured in assertions.
SUT: HTTP `GET /api/data`; initially returns `{"latency":"fast"}`; after controller swap returns `{"latency":"slow"}`; 200 total requests split 100/100 across the swap event.
Capabilities stacked: planning, runner, mocker, docs
MOCK_REQUIRED: yes — behavior swap is a mocker-only capability; no real SUT supports runtime config swap.
FB slices: §0, §2, §3, §9, §11, §13
Trap mines: s13#11 (controller boot log), s13#4 (HttpStatus keys), s13#5b (route lowercase), s13#13 (vacuous pass before swap probe executes), s13#16 (port contract)
Hard because:
- Controller channel name must exactly match between mocker YAML `Controller:` block and probe Redis command
- Race condition: if swap probe fires before Stage 0 completes, count split becomes unpredictable
- Two `JsonBodyContains` sessions must be strictly stage-gated to avoid overlap
- Redis controller boot log (s13#11) must appear in compose logs before Stage 0 begins
Verify (mechanical): Controller boot log matches s13#11 pattern; Stage 0 count=100 (fast); Stage 2 count=100 (slow); total=200; no error responses; runner exits 0; allure shows both behavior sessions green.
Rubric (graded): (1) Controller boot verified via probe before Stage 0 [0-10]; (2) Swap probe fires precisely between Stage 0 and Stage 2 [0-10]; (3) Two `JsonBodyContains` sessions sum to 200 with count guards [0-10]; (4) Redis controller channel name matches YAML and probe cmd exactly [0-10].
Solution sketch: Stage -1 probe: wait for controller boot log; Stage 0: 100 GET /api/data (fast, count=100); Stage 1 probe: Redis PUBLISH swap command; Stage 2: 100 GET /api/data (slow, count=100); two JsonBodyContains sessions (`latency=fast` and `latency=slow`) with count guards; port contract = single value in mocker/runner/probe.

### Z-140: Multi-Protocol Choreography — HTTP → Kafka → Redis → HTTP Egress Asserted
Tier: T5
Goal: Test a pipeline where an HTTP POST triggers Kafka publish, a consumer writes to Redis, and a final HTTP GET reads the Redis-backed state — four protocol hops asserted end-to-end.
SUT: `POST /ingest` publishes to Kafka topic `ingest.events`; Kafka consumer writes `key={eventId}` to Redis; `GET /state/{eventId}` reads Redis and returns `{processed: true}`.
Capabilities stacked: analysis, planning, runner, mocker, hooks, docs
MOCK_REQUIRED: yes — /ingest and /state endpoints are mocked; Kafka and Redis are real in compose.
FB slices: §0, §2, §3, §9, §11, §13
Trap mines: s13#17 (Kafka topic creation), s13#5b (routes lowercase), s13#4 (HttpStatus keys), s13#13 (vacuous pass on /state if Redis write not complete), s13#19 (only mocker port exposed)
Hard because:
- Four protocol boundaries in one test require careful stage gating (6 stages minimum)
- Redis readiness between Kafka consumer and HTTP egress must be probed (not just a sleep)
- Mocker must simulate /ingest triggering Kafka publish via processor with AMQP/Kafka client
- Custom `EndToEndLinkageAssertion` must verify `eventId` from POST response matches Redis key and GET response
Verify (mechanical): `dotnet build` exits 0; runner exits 0; POST /ingest count=1; Kafka consumer count=1; Redis key present; GET /state count=1 with `processed=true`; `eventId` consistent across all stages; allure green.
Rubric (graded): (1) Kafka topic creation at Stage 0 [0-10]; (2) Mocker /ingest processor publishes to Kafka [0-10]; (3) Redis-readiness probe before GET /state stage [0-10]; (4) End-to-end `eventId` linkage assertion [0-10].
Solution sketch: Stage 0: CreateKafkaTopic; Stage 1: POST /ingest (mocker processor publishes to Kafka, count=1); Stage 2: KafkaConsumer (count=1, writes to Redis); Stage 3 probe: Redis GET probe checks key exists; Stage 4: GET /state/{{eventId}} (count=1); `EndToEndLinkageAssertion` verifies eventId consistency.

### Z-141: Test-the-Tests — Find All Vacuous Passes in Provided 10-Session Suite
Tier: T5
Goal: Given a 10-session QaaS suite planted with 5 distinct silent-failure modes, enumerate all 5, classify each by s13 row, repair all, and prove the repaired suite has no vacuous passes.
SUT: Provided runner + mocker YAML (10 sessions: 4 HTTP, 3 RabbitMQ, 2 Kafka, 1 Redis); each defect is a different s13 row; mocker YAML is correct.
Capabilities stacked: analysis, diagnose, docs
MOCK_REQUIRED: n/a — audit and repair only; no new mocker.
FB slices: §7, §9, §13
Trap mines: s13#13 (vacuous HttpStatus), s13#12 (silent config key), s13#3 (missing DataSourceNames), s13#4 (OutputName scalar), s13#17 (missing topology probe)
Hard because:
- All 5 defects are structurally silent (no build error, no crash, no runner failure)
- Must prove each defect produces vacuous green BEFORE repair by running the defective suite
- Repair must be minimal: one fix per defect, no unrelated changes
- Repaired suite must run and exit 0 with count guards active
Verify (mechanical): Defective suite exits 0 vacuously; repaired suite exits 0 with real assertions; count guards active on all 4 HTTP sessions; DataSourceNames present on consumer sessions; topology probes at Stage 0.
Rubric (graded): (1) All 5 defects identified with s13 row citations [0-10]; (2) Vacuous nature proven by pre-repair run [0-10]; (3) Minimal repair applied (1 change per defect) [0-10]; (4) Post-repair run produces real (non-vacuous) assertions [0-10].
Solution sketch: Run suite as-is; record green exit; audit each session: check for count guards (s13#13), DataSourceNames (s13#3), config key exact spelling (s13#12), OutputNames list (s13#4), topology probes (s13#17); apply 5 targeted fixes; re-run to confirm real assertion execution.

### Z-142: Message Format Migration Parity — Avro v1 vs JSON v2 Consumer Equivalence
Tier: T5
Goal: Validate that a Kafka topic migration from Avro-encoded (v1) to JSON-encoded (v2) messages produces semantically equivalent consumer outputs for all shared fields.
SUT: Two Kafka topics: `events.avro` (Avro-encoded, pre-decoded to JSON by seed script) and `events.json` (native JSON); same 200 events published to both; consumer outputs compared field-by-field.
Capabilities stacked: analysis, planning, runner, hooks, docs
MOCK_REQUIRED: no — real Kafka in compose; seed script pre-decodes Avro; consumer is real SUT.
FB slices: §2, §9, §10, §11, §13
Trap mines: s13#17 (two Kafka topic creation probes), s13#3 (identical DataSourceNames for both topics), s13#13 (vacuous pass if either topic consumer lags), s13#12 (config typo in Kafka consumer)
Hard because:
- Avro schema has field aliases; JSON schema uses different field names for same data
- Custom `AvroJsonParityAssertion` must map Avro field aliases to JSON field names
- Both topics must receive identical logical payloads (same DataSourceNames)
- Count guards = 200 on both consumer sessions; any schema mapping error fails 1 of 200
Verify (mechanical): `dotnet build` exits 0; runner exits 0; both consumer counts = 200; parity assertion passes all mapped fields; count guards active; allure shows both sessions green.
Rubric (graded): (1) Both Kafka topic creation probes at Stage 0 [0-10]; (2) `AvroJsonParityAssertion` maps field aliases correctly [0-10]; (3) Identical DataSourceNames published to both topics [0-10]; (4) Count guards = 200 on both sessions [0-10].
Solution sketch: Stage 0: CreateKafkaTopic × 2; same 200-entry DataSourceNames file published to both; two KafkaConsumer sessions (count=200 each); `AvroJsonParityAssertion` hook loads field-alias map (config file), correlates by `eventId`, compares mapped field values; fails on first mismatch.

### Z-143: 10k Exactly-Once + Ordering + Decimal Precision — The Data-Integrity Trifecta
Tier: T5
Goal: Deliver the hardest data-integrity scenario: 10,000 Kafka messages, each exactly once, in strict partition-key order, with decimal amounts preserved to 4 decimal places — all three constraints asserted simultaneously in a single suite.
SUT: Kafka topic `ledger.transactions` (10 partitions, keyed by `accountId`); consumer writes to DB; read API returns ordered ledger per account; all three SUT components are mocked.
Capabilities stacked: planning, runner, mocker, hooks, docs
MOCK_REQUIRED: yes — DB writer and read API are mocked; Kafka is real in compose.
FB slices: §2, §3, §4, §9, §12, §13
Trap mines: s13#17 (Kafka topic creation with 10 partitions), s13#3 (DataSourceNames = 10000 entries), s13#13 (vacuous pass if any partition consumer lags), s13#1 (ProcessorConfiguration on mocker DB writer)
Hard because:
- 10,000 DataSourceNames requires a generator hook (SequentialGenerator) to avoid a 10k file
- Partition-ordering assertion must group by `accountId` and check monotonic `seq` within each
- Decimal assertion must check regex `^\d+\.\d{4}$` on all 10,000 outputs
- Exactly-once requires a `DuplicateMessageAssertion` scanning all 10,000 outputs
Verify (mechanical): `dotnet build` exits 0; runner exits 0; consumer count = 10,000; no duplicate `transactionId`; monotonic seq per accountId; all amounts match 4dp regex; allure green.
Rubric (graded): (1) SequentialGenerator produces 10k entries correctly [0-10]; (2) Partition-ordering assertion groups by accountId [0-10]; (3) Exactly-once proof via DuplicateMessageAssertion [0-10]; (4) Decimal-precision assertion checks all 10k amounts [0-10].
Solution sketch: `SequentialTransactionGenerator` yields 10k records with accountId, seq, amount (4dp); Stage 0: CreateKafkaTopic (10 partitions); KafkaPublisher + KafkaConsumer (count=10000); three parallel assertion hooks: `PartitionOrderAssertion`, `DuplicateDetectionAssertion`, `DecimalPrecisionAssertion`; all run on same output set.

### Z-144: Custom Hook Chain — Generator → Processor → Assertion in Full Pipeline
Tier: T5
Goal: Implement a three-hook pipeline: a custom `IGeneratorHook` enriches requests, a custom mocker `IProcessorHook` transforms responses, and a custom `IAssertionHook` validates the transformation — all three hooks in the same suite.
SUT: `POST /enrich` accepts raw events; generator adds `correlationId`; mocker processor adds `processedAt` timestamp; assertion verifies both fields present and correctly linked.
Capabilities stacked: planning, runner, mocker, hooks, docs
MOCK_REQUIRED: yes — processor behavior is mocker-driven; no real enrichment service.
FB slices: §2, §3, §4, §9, §12, §13
Trap mines: s13#8 (package refs: Generators→QaaS.Common.Generators, Processors→QaaS.Common.Processors), s13#1 (ProcessorConfiguration not TransactionData), s13#5b (route lowercase), s13#13 (vacuous pass if processor returns empty body)
Hard because:
- Three hooks in different projects (runner + mocker) require two separate .csproj files
- Generator must `yield return` requests (not return a list) — FB §4 constraint
- Processor must be stateless; `correlationId` from request must be echoed in response (read from request body)
- Assertion must verify `correlationId` in request matches `correlationId` in response (cross-field)
Verify (mechanical): Both runner and mocker `dotnet build` exit 0; runner exits 0; all outputs have `correlationId` and `processedAt`; custom assertion passes all; count guard = N; allure green.
Rubric (graded): (1) Generator `yield return` pattern, correct `IGeneratorHook` signature [0-10]; (2) Processor stateless, reads request body for correlationId, QaaS.Common.Processors ref [0-10]; (3) Assertion verifies cross-field correlationId linkage [0-10]; (4) All package refs correct per FB §4 / s13#8 [0-10].
Solution sketch: Runner csproj: `QaaS.Runner` + `QaaS.Common.Generators`; `CorrelationIdGenerator : IGeneratorHook` yields with `X-Correlation-ID` header; mocker csproj: `QaaS.Mocker` + `QaaS.Common.Processors`; `EnrichProcessor : IProcessorHook` reads header, adds `processedAt`; assertion hook `CorrelationAssert` checks request `X-Correlation-ID` == response `correlationId`.

### Z-145: Full Airgap CI Pipeline — Feed + Compose + Run + Allure + Completion Gate
Tier: T5
Goal: Demonstrate a complete airgap-to-completion pipeline: offline NuGet feed, docker image save/load, compose up, runner execution, allure generation, and a completion-gate checklist validated with real mechanical evidence.
SUT: Any multi-protocol suite (HTTP + RabbitMQ); complexity is entirely in the pipeline and evidence production.
Capabilities stacked: planning, runner, mocker, docker, diagnose, docs
MOCK_REQUIRED: yes — mocker image built from scratch and saved as .tar for offline load.
FB slices: §1, §6, §7, §8, §13, §14
Trap mines: s13#7 (aspnet base), s13#17 (RabbitMQ topology probe), s13#14 (no # in verify cmd), s13#15 (single verify cmd lifecycle), s13#18 (no Dockerfile inline comments), s13#19 (only mocker port exposed)
Hard because:
- All 6 s13 traps listed above must be clean simultaneously
- Completion gate requires real mechanical evidence: exit codes, log lines, allure file count
- Offline feed must have all packages at exact versions (s13#9 — each package independently versioned)
- PowerShell verify script must propagate exit codes correctly and fail-fast
Verify (mechanical): No internet calls; `docker load` succeeds; compose up exits 0; runner exits 0; allure-results/ has ≥1 file; completion-gate checklist cites real exit codes and log lines; all 6 s13 traps clean.
Rubric (graded): (1) All 6 listed s13 traps clean (binary gate) [0-10]; (2) Offline feed with exact package versions [0-10]; (3) Completion-gate checklist has real mechanical evidence [0-10]; (4) Single verify cmd with fail-fast exit-code propagation [0-10].
Solution sketch: `prepare-offline.ps1`: nuget add all QaaS packages; docker build + save; `ci-verify.ps1`: docker load, compose up, wait-for-port, dotnet run with allure flag, capture exit, compose down, exit with captured code; completion gate: list allure-results/ file count, echo runner exit code, grep compose logs for controller boot pattern.

### Z-146: HTTP Order → Rabbit Fulfillment → Redis Inventory → HTTP Status — Full Commerce Flow
Tier: T5
Goal: Test a full e-commerce pipeline: HTTP order creation triggers RabbitMQ fulfillment message, fulfillment consumer decrements Redis inventory, HTTP status endpoint reads Redis to return order state.
SUT: `POST /orders` → RabbitMQ `fulfillment.queue`; fulfillment service consumes and does `DECRBY` on Redis `inventory:{sku}`; `GET /orders/{id}/status` reads Redis and returns `{status:"fulfilled",remaining:N}`.
Capabilities stacked: analysis, planning, runner, mocker, hooks, docs
MOCK_REQUIRED: yes — all three service layers are mocked; Redis is real in compose.
FB slices: §0, §2, §3, §9, §11, §13
Trap mines: s13#17 (RabbitMQ queue topology), s13#5b (routes lowercase), s13#5 (no leading slash), s13#13 (vacuous pass on /status if Redis not yet updated), s13#19 (only mocker port exposed, not Redis)
Hard because:
- Four-layer pipeline requires 6+ stages with correct gating
- Mocker fulfillment processor must execute Redis DECRBY (real Redis client call) — stateless constraint applies
- HTTP /status session depends on Redis state written in Stage 3; probe must verify Redis key before Stage 4
- `OrderFulfillmentLinkageAssertion` must verify `orderId` and `sku` consistent end-to-end
Verify (mechanical): `dotnet build` exits 0; runner exits 0; POST /orders count=1; Rabbit consumer count=1; Redis `inventory:{sku}` decremented; GET /status count=1 with `status=fulfilled`; allure green.
Rubric (graded): (1) Topology probe + Redis readiness probe at correct stages [0-10]; (2) Mocker fulfillment processor does Redis DECRBY stateless [0-10]; (3) End-to-end linkage assertion verifies orderId + sku [0-10]; (4) Count guards on all HTTP and queue sessions [0-10].
Solution sketch: Stage 0: queue topology; Stage 1: POST /orders (count=1); Stage 2: RabbitConsumer fulfillment (count=1, processor does DECRBY); Stage 3 probe: Redis GET to verify decremented; Stage 4: GET /orders/1/status (count=1); `FulfillmentLinkageAssertion` checks orderId and sku chain.

### Z-147: Broker Chaos — Stub-Swap Under Load with Count Guard Enforcement
Tier: T5
Goal: During a 500-request HTTP load session, a Redis controller stub-swap fires at request 250, changing the response schema; simultaneously verify the total count = 500 and that no response falls outside the two known schemas.
SUT: HTTP `GET /products` returns either `{"format":"compact"}` or `{"format":"extended"}`; swap fires at midpoint; any other schema value is an error.
Capabilities stacked: planning, runner, mocker, docs
MOCK_REQUIRED: yes — stub-swap is a mocker-only feature; no real SUT supports runtime schema change.
FB slices: §0, §2, §3, §9, §11, §13
Trap mines: s13#11 (controller boot log), s13#4 (HttpStatus keys), s13#5b (route lowercase), s13#13 (vacuous count if swap fires before Stage 0 ends), s13#16 (port contract)
Hard because:
- Count guards on two body-match sessions must sum to exactly 500 with no gap
- A third "unknown format" session must assert 0 outputs (proving no unknown schemas arrived)
- Redis controller swap must be stage-gated precisely between the two halves
- Controller boot log must be verified before Stage 0 begins (probe)
Verify (mechanical): compact-count + extended-count = 500; unknown-format count = 0; runner exits 0; controller boot log verified; allure shows three sessions green; no vacuous passes.
Rubric (graded): (1) Controller boot verified before Stage 0 [0-10]; (2) Three body-match sessions: compact(250) + extended(250) + unknown(0) [0-10]; (3) Swap probe fires precisely between Stage 0 and Stage 2 [0-10]; (4) Count guards enforce 250/250/0 split [0-10].
Solution sketch: Stage -1 probe: wait for controller boot log; Stage 0: 250 GET /products (compact, count=250); Stage 1 probe: Redis PUBLISH swap; Stage 2: 250 GET /products (extended, count=250); Stage 3: `JsonBodyContains(format≠compact AND format≠extended)` with count=0 guard; port contract = one literal.

### Z-148: Self-Verifying Template Oracle + Live Gate — Evidence-First Deliverable
Tier: T5
Goal: Produce a QaaS deliverable where every config type used is validated by `dotnet run -- template`, and the live gate runs the complete mocker+runner lifecycle in a single verify cmd — all with real command output as evidence, no placeholders.
SUT: HTTP `POST /validate` returns `{valid: true}`; challenge is the evidence harness, not the SUT.
Capabilities stacked: planning, runner, mocker, docs
MOCK_REQUIRED: yes — /validate endpoint is mocked; template oracle must cover all config types used in mocker and runner.
FB slices: §1, §2, §3, §6, §13, §14
Trap mines: s13#14 (verify cmd must not start with #), s13#15 (single lifecycle cmd), s13#16 (port contract), s13#13 (vacuous pass), s13#7 (aspnet base for mocker image)
Hard because:
- Every distinct `*Configuration` type used must have a corresponding `dotnet run -- template` invocation as evidence
- Live gate must be one cmd: start mocker (background), wait-for-port, run runner, capture $LASTEXITCODE, stop mocker
- Evidence document must contain real command outputs (not "Expected output: ...") — completion gate rule
- Template oracle exit codes must all be 0 — any non-0 indicates a config type typo
Verify (mechanical): `dotnet run -- template HttpTransactionConfiguration` exits 0; `dotnet run -- template HttpStatusConfiguration` exits 0; live gate cmd exits 0; allure-results/ non-empty; no verify cmd starts with `#`; count guard present.
Rubric (graded): (1) Template oracle invoked for every `*Configuration` type used (≥3 types) [0-10]; (2) Live gate is one cmd with mocker lifecycle [0-10]; (3) Evidence document contains real exit codes and output snippets [0-10]; (4) Count guard prevents vacuous pass on /validate session [0-10].
Solution sketch: Inventory all `*Configuration` types in YAML; run `dotnet run -- template <Type>` for each, capture output to evidence.md; live gate: one PowerShell cmd starts mocker, waits port 8081, runs dotnet run, captures exit, stops mocker; evidence.md shows real exit=0 lines for each template oracle invocation.

### Z-149: Cross-Protocol Regression — HTTP SLA + Rabbit Throughput Simultaneously Asserted
Tier: T5
Goal: Run an HTTP latency SLA test and a RabbitMQ throughput test simultaneously in the same suite, asserting that neither degrades the other: HTTP p99 < 300ms AND Rabbit throughput ≥ 100 msg/s.
SUT: HTTP `GET /api/fast` (p99 target < 300ms); RabbitMQ queue `throughput.queue` (100 msg/s target); both in compose; HTTP is mocked (with delay), Rabbit is real.
Capabilities stacked: planning, runner, mocker, hooks, docs
MOCK_REQUIRED: yes — HTTP delay simulation requires mocker processor; Rabbit throughput uses real broker.
FB slices: §2, §3, §9, §11, §12, §13
Trap mines: s13#1 (ProcessorConfiguration for delay), s13#17 (Rabbit topology), s13#3 (DataSourceNames for throughput), s13#13 (vacuous pass on either session if 0 outputs), s13#16 (port contract)
Hard because:
- Two concurrent sessions must not serialise; runner must execute them in parallel stages
- HTTP p99 assertion and Rabbit throughput assertion are custom hooks with different timing concerns
- `ThroughputAssertion` must compute msg/s from output timestamps (total/elapsed)
- If both sessions run sequentially instead of concurrently, throughput degrades artificially
Verify (mechanical): `dotnet build` exits 0; runner exits 0; HTTP count=200, p99 < 300ms; Rabbit count=500 in ≤5s; both assertions pass; no interference between sessions; allure shows both green.
Rubric (graded): (1) Sessions configured to run concurrently (same stage, no stage gate between) [0-10]; (2) `LatencyP99Assertion` computes p99 from response metadata [0-10]; (3) `ThroughputAssertion` computes msg/s from timestamps [0-10]; (4) Count guards active on both sessions [0-10].
Solution sketch: Same-stage HTTP + Rabbit sessions (Stage 0 for both); mocker `DelayProcessor` with 50ms delay; Rabbit topology probe at Stage -1; DataSourceNames = 500 messages; `LatencyP99Assertion` reads `X-Response-Time` header; `ThroughputAssertion` records first/last output timestamps; count guards: HTTP=200, Rabbit=500.

### Z-150: Final Boss — All Capabilities Stacked: Analysis + Planning + Runner + Mocker + Hooks + Docker + Diagnose + Docs
Tier: T5
Goal: Author, execute, diagnose, and repair a complete QaaS suite for a microservices SUT spanning HTTP, RabbitMQ, Kafka, and Redis — all capability areas exercised, all s13 traps navigated, completion gate satisfied with full mechanical evidence.
SUT: Payment platform: `POST /payment/initiate` (HTTP) → Kafka `payment.initiated`; Kafka consumer publishes to RabbitMQ `payment.processing`; RabbitMQ consumer updates Redis `payment:{id}`; `GET /payment/{id}/status` reads Redis. All services mocked.
Capabilities stacked: analysis, planning, runner, mocker, hooks, docker, diagnose, docs
MOCK_REQUIRED: yes — all 4 service layers are mocked; Docker mocker image required for custom processor; Redis + Kafka + RabbitMQ are real in compose.
FB slices: §0, §1, §2, §3, §4, §6, §7, §8, §9, §11, §12, §13, §14
Trap mines: s13#1, s13#3, s13#4, s13#5, s13#5b, s13#7, s13#8, s13#11, s13#13, s13#15, s13#16, s13#17, s13#18, s13#19 — ALL 14 applicable drift rows must be clean
Hard because:
- Five protocol boundaries across 8+ stages require precise stage gating and dependency ordering
- Custom Docker mocker image with `IProcessorHook` for Kafka-to-Rabbit bridge (stateless, aspnet base)
- 12 distinct `*Configuration` types used; all must pass template oracle
- Complete completion-gate evidence: exit codes, allure file count, controller boot log, duplicate-detection proof, decimal-precision proof
- Any single s13 trap violation causes silent failure that looks like a pass
Verify (mechanical): `dotnet build` (runner + mocker) exits 0; `docker build` exits 0; compose up exits 0; runner exits 0; allure-results/ ≥ 8 test cases; controller boot log matches s13#11 pattern; all count guards > 0; template oracle exits 0 for all 12 config types.
Rubric (graded): (1) All 14 s13 drift rows clean — binary gate, all or nothing [0-10]; (2) Custom Docker mocker compiles and runs with `aspnet:10.0` base [0-10]; (3) End-to-end payment ID linkage asserted across all 5 protocol hops [0-10]; (4) Completion-gate checklist populated with real mechanical evidence (no placeholders) [0-10].
Solution sketch: Scaffold runner csproj + mocker csproj (aspnet Dockerfile, QaaS.Common.Processors); Stage 0: CreateKafkaTopic + CreateRabbitMqExchanges/Queues; Stages 1-5: POST /initiate → KafkaConsumer → RabbitPublisher → RabbitConsumer → Redis probe → GET /status; `PaymentLinkageAssertion` verifies paymentId across all outputs; template oracle invoked for all 12 config types; completion gate cites exit codes and allure file count.

