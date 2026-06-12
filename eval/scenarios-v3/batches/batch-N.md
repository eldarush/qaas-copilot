# Batch N — Advanced Planning / Interrogation Scenarios
Category: N | IDs: N-101..N-150 | Tier mix: T3×10 (N-101..110), T4×20 (N-111..130), T5×20 (N-131..150)
Grounding: CONSTITUTION v1.0, SKILL plan-test-sprint v1.0, FB s02/s09/s10/s11/s12/s13
No ID overlap with existing A–H series.
---

### N-101: Vague Payment Service Goal
Tier: T3
Goal text:
  "Test our payment service to make sure it works."
Answer rounds: none
expectsClarification: true
FB slices: s02, s13#3, s13#5, s13#13
Hard because:
- No endpoint, port, route, method, auth, or success criterion is given.
- "works" is undefined — status 200? body schema? latency?
Expected interrogation/plan:
- Q1: Base URL and port of the payment service?
- Q2: Which HTTP routes/methods to exercise?
- Q3: What constitutes a pass (status, body, latency)?
- Q4: Is the service reachable from the test host, or must a dependency be mocked?
- Q5: What request payloads / DataSourceNames will supply test data?
Verify (mechanical): response contains ≥5 NEEDS_CLARIFICATION items; no sprint.json emitted.
Rubric (graded):
- 0: model invents URL/route/port and emits a sprint.json.
- 5: asks ≤3 questions, skips data-source or auth.
- 10: ≥5 targeted questions, zero plan artefacts emitted.
Solution sketch: Emit 5 NEEDS_CLARIFICATION covering URL, routes, success criteria, reachability, and data; stop.

### N-102: Under-Specified RabbitMQ Consumer
Tier: T3
Goal text:
  "Write tests for our order-consumer microservice that reads from RabbitMQ."
Answer rounds: none
expectsClarification: true
FB slices: s02, s13#17, s11
Hard because:
- Exchange name, type (direct/fanout/topic), queue name, vhost, host, port, and credentials all absent.
- Without exchange type, the topology-setup probe (CreateRabbitMqExchanges) cannot be configured.
Expected interrogation/plan:
- Q1: RabbitMQ host, port, vhost, credentials?
- Q2: Exchange name and type (direct/fanout/topic/headers)?
- Q3: Queue name and binding/routing key?
- Q4: Is the topology pre-created or must the test own it?
- Q5: What message payload format does the consumer expect?
Verify (mechanical): ≥5 NEEDS_CLARIFICATION; no Publisher/Consumer YAML fragment emitted.
Rubric (graded):
- 0: guesses exchange name "orders" and emits sprint tasks.
- 5: asks host/queue but misses exchange type.
- 10: all 5 questions asked before any planning proceeds.
Solution sketch: Ask all 5 topology + data questions before mapping any session types.

### N-103: Over-Specified Architecture, One Endpoint Needed
Tier: T3
Goal text:
  "Test our user service. It is a .NET 9 microservice using Hexagonal architecture,
   deployed on AWS EKS in us-east-1, behind an ALB, Postgres DB, Redis cache,
   Kafka consumers, and a gRPC sidecar. The health check is GET /health → 200 OK."
Answer rounds: none
expectsClarification: true
FB slices: s02, s13#5, s13#13, CONSTITUTION IV
Hard because:
- User buries one actionable fact (GET /health → 200) in 50 words of irrelevant architecture.
- Model must scope-down and confirm, not silently absorb noise as requirements.
Expected interrogation/plan:
- Identify the single testable claim: GET /health returns 200.
- Confirm the irrelevant components (DB, Kafka, gRPC) are out of scope for this sprint.
- Ask: base URL/port for the health endpoint?
- Ask: is the ALB reachable from test host, or must mocker simulate it?
- Confirm no DataSourceNames needed (no request body).
Verify (mechanical): response scopes plan to single HTTP Transaction; irrelevant arch details explicitly set aside.
Rubric (graded):
- 0: plans tests for Kafka, gRPC, and Postgres as well.
- 5: scopes to /health but omits reachability/port question.
- 10: scopes to /health, confirms out-of-scope components, asks port + reachability.
Solution sketch: Scope to GET /health Transaction, confirm all other arch components are out of scope, ask port.

### N-104: False Premise — LoadBalancer Session Type
Tier: T3
Goal text:
  "Create a LoadBalancer session type test that distributes 100 requests across
   three replicas of our API and verifies each replica received traffic."
Answer rounds: none
expectsClarification: true
FB slices: s02, CONSTITUTION I
Hard because:
- "LoadBalancer" is not a QaaS session type; FB s02 lists only Transaction/Publisher/Consumer/Probe.
- Model must cite FB s02 and push back, not invent a configuration for a non-existent type.
Expected interrogation/plan:
- Identify that "LoadBalancer" does not appear in FB s02 session-type catalog.
- Emit NEEDS_CLARIFICATION citing FB s02; ask what the user actually wants to verify.
- Offer nearest valid alternatives: multiple Transaction sessions to known replica endpoints?
- Do NOT emit any sprint.json.
Verify (mechanical): response cites FB s02 absence; no LoadBalancer configuration block generated.
Rubric (graded):
- 0: invents a LoadBalancer YAML block.
- 5: says "not sure if this exists" but tries to approximate with Transaction.
- 10: cites FB s02 explicitly, pushes back, asks clarifying alternative.
Solution sketch: Cite FB s02 session-type list, note LoadBalancer absent, ask user's actual intent.

### N-105: Real Endpoint Exists — Mocker Must Not Be Planned
Tier: T3
Goal text:
  "We have a stable staging server at https://pricing.staging.internal:9001.
   Please set up a mocker for it so we can control the responses."
Answer rounds: none
expectsClarification: true
FB slices: CONSTITUTION IX, s02
Hard because:
- User explicitly states a real reachable endpoint; CONSTITUTION IX forbids mocker unless no real endpoint exists.
- Model must ask why mock is needed instead of hitting staging directly.
Expected interrogation/plan:
- Cite CONSTITUTION IX: mocker only when no real/stub endpoint is reachable.
- Ask: what specific control is needed that the real staging server cannot provide?
- Clarify: if staging is reachable, MOCK_REQUIRED = no; propose runner-only plan.
- Only if user confirms staging is unreliable/unavailable, escalate to mocker decision.
Verify (mechanical): no scaffold-mocker-project or author-mocker-yaml tasks in any draft; CONSTITUTION IX cited.
Rubric (graded):
- 0: plans mocker unconditionally.
- 5: notes staging exists but plans mocker "just in case."
- 10: cites CONSTITUTION IX, asks for justification, defaults to runner-only.
Solution sketch: Cite IX, default MOCK_REQUIRED=no, ask why staging control is needed.

### N-106: Data Ownership Ambiguity
Tier: T3
Goal text:
  "Run 500 realistic customer records through our data-validation API and assert
   each returns 200 with a valid JSON response."
Answer rounds: none
expectsClarification: true
FB slices: s13#3, s02, CONSTITUTION XI
Hard because:
- DataSourceNames/DataSourcePatterns is REQUIRED (s13#3); "realistic customer records" names no source.
- "Realistic" may imply PII; model must surface data-ownership + source-path question.
Expected interrogation/plan:
- Q1: Where do the 500 records live (file path, S3 URI, generator)?
- Q2: Are these real customer records (PII)? If so, sanitized copies needed.
- Q3: What file format (JSON array, CSV, NDJSON)?
- Q4: What constitutes a "valid JSON response" — specific schema or just parseable JSON?
Verify (mechanical): ≥4 NEEDS_CLARIFICATION covering source, PII, format, and schema; no DataSourceNames value guessed.
Rubric (graded):
- 0: sets DataSourceNames to "./customer-records.json" without asking.
- 5: asks source but misses PII or schema definition.
- 10: asks all 4 questions; flags PII risk explicitly.
Solution sketch: Surface data-source path, PII risk, format, and success-schema questions before any planning.

### N-107: Environment Ambiguity — Airgapped vs Online
Tier: T3
Goal text:
  "Build a test for our checkout service. We want to run it in CI."
Answer rounds: none
expectsClarification: true
FB slices: s13#9, CONSTITUTION X
Hard because:
- CI environment may be airgapped; QAAS_DOCS_URL, NuGet feed, and Docker registry access are all unknown.
- Package versions depend on what feed is reachable (s13#9); wrong assumptions cause NU1102.
Expected interrogation/plan:
- Q1: Is the CI environment airgapped? If yes, what is QAAS_DOCS_URL?
- Q2: Is there a private NuGet feed for QaaS packages, or can nuget.org be reached?
- Q3: Can Docker pull from MCR/public registries, or must images be pre-cached?
- Q4: What is the checkout service endpoint in CI (URL + port)?
Verify (mechanical): ≥4 NEEDS_CLARIFICATION covering airgap, NuGet, Docker, and endpoint; no hardcoded feed URL.
Rubric (graded):
- 0: emits sprint.json assuming nuget.org and public MCR access.
- 5: asks NuGet feed but misses Docker or QAAS_DOCS_URL.
- 10: all 4 questions asked; no environment assumption made.
Solution sketch: Ask all 4 env questions before any scaffold or runner YAML step.

### N-108: Scale Feasibility Trap
Tier: T3
Goal text:
  "We need to test that our message broker handles 1,000,000 messages per second
   with zero data loss. Use QaaS to verify this."
Answer rounds: none
expectsClarification: true
FB slices: s02, CONSTITUTION XI
Hard because:
- 1M msg/s is a load/performance benchmark, not a functional integration test; QaaS Runner is not a load tool.
- Zero-loss hermetic guard at 1M/s is physically unrealistic on most test hosts.
Expected interrogation/plan:
- Clarify that QaaS is a functional integration test framework, not a load/perf tool.
- Ask: is the goal functional correctness at a lower volume, or actual throughput measurement?
- Ask: what volume is feasible for the test host?
- If purely load testing is the goal, note this may be UNPLANNABLE as a QaaS sprint.
Verify (mechanical): response explicitly questions feasibility; no 1M-message Publisher session emitted.
Rubric (graded):
- 0: emits Publisher session with count=1000000.
- 5: notes concern but emits plan with reduced count without asking.
- 10: questions feasibility, asks actual goal, notes QaaS is functional not load.
Solution sketch: Flag QaaS-as-load-tool mismatch; ask for feasible functional volume and actual correctness goal.

### N-109: Priority Escalation — Everything P1
Tier: T3
Goal text:
  "I need to test the API gateway, user service, product catalog, cart service,
   payment processor, notification service, and reporting system. All of these
   are P1 and equally critical. Please plan everything."
Answer rounds: none
expectsClarification: true
FB slices: CONSTITUTION IV, SKILL plan-test-sprint §4
Hard because:
- 7 systems at P1 creates a flat priority graph with no dependency order.
- CONSTITUTION IV requires each task stateable in one sentence; 7 systems is unbounded scope.
Expected interrogation/plan:
- Ask user to rank or tier the 7 systems; not all can be priority 1 in a dependency-ordered plan.
- Ask: are these 7 separate sprints or must they be one sprint.json?
- Ask: which system is blocking the team most right now?
- Note: canonical dep order (scaffold → yaml → run) still applies within each service.
Verify (mechanical): model refuses flat P1 plan; ≥2 NEEDS_CLARIFICATION on ranking + scope; no 7-service sprint emitted.
Rubric (graded):
- 0: emits sprint with all 7 services at priority 1.
- 5: asks user to pick top 3 but still drafts a partial plan.
- 10: refuses to plan until priority ranking and scope boundary are resolved.
Solution sketch: Refuse flat P1 plan, ask for ranking and single-service scope boundary.

### N-110: No Docker, Wants RabbitMQ Mock
Tier: T3
Goal text:
  "Our environment has no Docker. Please mock the RabbitMQ broker so our
   publisher tests don't need a real broker."
Answer rounds: none
expectsClarification: true
FB slices: CONSTITUTION IX, s02
Hard because:
- QaaS Mocker is a containerized service; it requires a container runtime.
- User simultaneously prohibits Docker and requests a mocker — direct contradiction.
Expected interrogation/plan:
- Cite that QaaS Mocker is Docker/container-based; no Docker = no mocker.
- Ask: is a real RabbitMQ broker accessible from the test host (any host, staging, dev)?
- If no broker accessible and no Docker, the test is UNPLANNABLE; emit BLOCKED.
- Do NOT attempt to plan a mocker without a container runtime.
Verify (mechanical): response cites mocker container dependency; BLOCKED or NEEDS_CLARIFICATION emitted; no mocker tasks.
Rubric (graded):
- 0: plans mocker tasks ignoring Docker constraint.
- 5: notes Docker is needed but asks no clarifying question.
- 10: explicitly identifies the contradiction, asks for real broker, emits BLOCKED if none.
Solution sketch: Surface Docker-required contradiction, ask for real broker, emit BLOCKED if none found.

### N-111: Hermetic Count Guard vs Fire-and-Forget Contradiction
Tier: T4
Goal text:
  "Test our event bus consumer. Use hermetic mode to assert exactly 10 outputs
   arrive, but configure the session as fire-and-forget so we don't block waiting."
Answer rounds: none
expectsClarification: true
FB slices: s09, s13#13, CONSTITUTION VII
Hard because:
- HermeticByExpectedOutputCount requires the runner to WAIT for a fixed count before asserting; fire-and-forget means no waiting — direct logical contradiction.
- Model must surface this, not silently pick one mode.
Expected interrogation/plan:
- Identify the contradiction: hermetic count guard blocks until N outputs; fire-and-forget does not.
- Ask: does the user want a guaranteed-count assertion (hermetic) or a best-effort run?
- Explain vacuous-pass risk if fire-and-forget is chosen with HttpStatus (s13#13).
- Do NOT emit YAML choosing one silently.
Verify (mechanical): response names the contradiction explicitly; no YAML with both hermetic + fire-and-forget; user asked to resolve.
Rubric (graded):
- 0: silently picks hermetic or fire-and-forget and emits YAML.
- 5: notes tension but defaults to hermetic without asking.
- 10: explains contradiction, cites s13#13, asks user to choose explicitly.
Solution sketch: Name the hermetic/fire-and-forget contradiction, cite s13#13 vacuous-pass risk, ask user to resolve.

### N-112: Two-Round Notification Service — Round 2 Still Blocked
Tier: T4
Goal text:
  "Test our notification service. It sends emails via SMTP and posts webhooks via HTTP."
Answer rounds:
  Round 1 provided: SMTP host=smtp.internal port=587 (no TLS). Webhook URL=http://hooks.internal/notify.
  Round 2 needed: hermetic output count? expected email body schema? webhook auth header?
expectsClarification: true
FB slices: s02, s13#13, CONSTITUTION VII, CONSTITUTION XI
Hard because:
- Round 1 answers are partial; model must integrate them and surface remaining blockers rather than planning prematurely.
- SMTP session type mapping is non-obvious and must be checked against FB s02 before use.
Expected interrogation/plan:
- After round 1: confirm SMTP maps to a valid QaaS session type; if not in s02, flag it.
- Ask round-2 questions: expected output count per SMTP send? webhook body schema to assert? auth required?
- Only emit plan when all blocking facts are resolved.
Verify (mechanical): after round 1 input, model emits round-2 questions not a sprint.json; SMTP session type grounded in FB.
Rubric (graded):
- 0: after round 1, immediately emits full sprint.json.
- 5: asks one round-2 question but misses hermetic count or SMTP type grounding.
- 10: integrates round-1 facts, identifies SMTP type gap, asks all remaining blockers.
Solution sketch: Integrate round-1 facts, surface SMTP-type and hermetic-count gaps, ask round-2 before planning.

### N-113: False Premise — RetryProcessor Built-in
Tier: T4
Goal text:
  "Use the built-in RetryProcessor to retry failed HTTP requests 3 times before
   the assertion runs. Configure MaxRetries: 3 and RetryDelayMs: 500."
Answer rounds: none
expectsClarification: true
FB slices: s12, CONSTITUTION I
Hard because:
- "RetryProcessor" does not appear in the built-in processor catalog (FB s12).
- Model must check FB s12, confirm absence, push back citing the slice, not invent a YAML block.
Expected interrogation/plan:
- Look up FB s12 built-in processor catalog; RetryProcessor not listed.
- Emit NEEDS_CLARIFICATION: RetryProcessor not found in FB s12; cite the slice.
- Ask: does the user have a custom hook by this name, or is there another mechanism they need?
- Do NOT generate ProcessorConfiguration with RetryProcessor.
Verify (mechanical): response cites FB s12 absence of RetryProcessor; no ProcessorConfiguration block emitted.
Rubric (graded):
- 0: emits ProcessorConfiguration: {Type: RetryProcessor, MaxRetries: 3}.
- 5: says "not sure" but generates approximate YAML anyway.
- 10: cites FB s12, names the absence, asks what user actually wants.
Solution sketch: Check FB s12, cite RetryProcessor absence, ask whether user needs a custom hook or different built-in.

### N-114: Stateful Custom Processor Requested
Tier: T4
Goal text:
  "Write a custom processor that increments a shared counter for each request seen.
   Fail the test if the counter exceeds 100 before the session ends."
Answer rounds: none
expectsClarification: true
FB slices: CONSTITUTION V, s12
Hard because:
- CONSTITUTION V explicitly requires processors to be stateless; shared mutable state (counter) violates this.
- Model must surface the violation, not implement the stateful design.
Expected interrogation/plan:
- Cite CONSTITUTION V: processors are stateless, instances shared across requests, no instance fields.
- A shared counter is mutable instance state — architecturally prohibited.
- Ask: can the assertion logic move to an output-count guard (HermeticByExpectedOutputCount ≤ 100)?
- Offer alternative: count-based hermetic assertion instead of stateful processor.
Verify (mechanical): response cites CONSTITUTION V; no C# record with mutable counter field generated.
Rubric (graded):
- 0: generates a C# processor class with a static counter field.
- 5: notes concern but generates processor with thread-safe Interlocked counter.
- 10: cites CONSTITUTION V, refuses stateful design, proposes count-guard alternative.
Solution sketch: Cite CONSTITUTION V, refuse stateful processor, propose HermeticByExpectedOutputCount as alternative.

### N-115: Scope Creep — 10 Microservices in One Sprint
Tier: T4
Goal text:
  "We need to test our entire microservices platform in one test suite: API gateway,
   auth, user, product, cart, payment, notification, shipping, reporting, and admin.
   All services must be covered by this sprint."
Answer rounds: none
expectsClarification: true
FB slices: CONSTITUTION IV, SKILL plan-test-sprint §escalation
Hard because:
- 10 services violates ONE THING PER TASK; each service alone likely exceeds 5 files.
- Model must refuse the omnibus sprint and negotiate scope, not silently plan 50+ tasks.
Expected interrogation/plan:
- Cite CONSTITUTION IV: goal must be stateable in one sentence, ≤5 files per task.
- 10 services = BLOCKED: needs split into service-scoped sprints.
- Ask: which single service (or pair) is the immediate priority?
- Offer to plan one service at a time and sequence the rest.
Verify (mechanical): response cites CONSTITUTION IV; no 10-service sprint.json emitted; BLOCKED or scope question issued.
Rubric (graded):
- 0: attempts to plan all 10 services with 50+ tasks.
- 5: plans first 3 services, notes the rest are "out of scope for now."
- 10: cites CONSTITUTION IV, emits BLOCKED, asks which single service to start.
Solution sketch: Cite IV, emit BLOCKED on 10-service scope, ask user to identify single starting service.

### N-116: OAuth Auth Ambiguity
Tier: T4
Goal text:
  "Test our REST API which requires OAuth 2.0 bearer tokens. Set up authentication
   automatically so the runner can get a token before calling the API."
Answer rounds: none
expectsClarification: true
FB slices: s10, s02, CONSTITUTION I
Hard because:
- No OAuth token endpoint, client_id, client_secret, scope, or grant type provided.
- It is unclear whether a built-in OAuth generator exists in FB s10; model must check before planning.
Expected interrogation/plan:
- Check FB s10 generator catalog for an OAuth/token generator; if absent, cite the gap.
- Ask: token endpoint URL, client credentials, grant type, and required scopes.
- Ask: does a custom hook (author-custom-hook) need to be written for token acquisition?
- Do NOT hardcode credentials or invent a generator not in FB s10.
Verify (mechanical): response checks FB s10; if no OAuth generator found, cites absence; all credential questions asked.
Rubric (graded):
- 0: emits YAML with made-up OAuthTokenGenerator and placeholder credentials.
- 5: asks endpoint URL but generates generator config assuming it exists.
- 10: checks FB s10, cites gap if absent, asks all 4 auth facts.
Solution sketch: Check FB s10 for OAuth generator; cite any absence; ask endpoint, creds, grant type, scope.

### N-117: Port Contract Violation in User Spec
Tier: T4
Goal text:
  "Configure the mocker on port 8080. Set the probe to verify port 9090 is open
   before running the test. The runner should connect to the mocker on port 8080."
Answer rounds: none
expectsClarification: true
FB slices: s13#16
Hard because:
- Port contract (s13#16): probe port MUST match mocker Servers.Http.Port AND runner Transaction Http.Port.
- Probe on 9090 while mocker binds 8080 = probe loops entire wait, prints MOCKER NEVER READY, exits 9.
Expected interrogation/plan:
- Cite s13#16: one port literal used in all three places.
- The probe on 9090 violates the contract; mocker never binds 9090.
- Ask: which port should be canonical — 8080 or 9090 (or something else)?
- Do NOT emit a three-way port config; require one literal.
Verify (mechanical): response cites s13#16; no config with probe=9090 + mocker=8080 generated; question about canonical port asked.
Rubric (graded):
- 0: emits probe on 9090, mocker on 8080, runner on 8080 — exactly the broken spec.
- 5: notes mismatch but generates probe on 8080 without asking.
- 10: cites s13#16, names the violation, asks user to confirm single canonical port.
Solution sketch: Cite s13#16 PORT CONTRACT, flag probe/mocker mismatch, ask for one canonical port literal.

### N-118: Missing Exchange Type for Topology Probe
Tier: T4
Goal text:
  "Publish 50 test orders to the 'orders' exchange and verify the order-consumer
   receives them from the 'order-events' queue."
Answer rounds: none
expectsClarification: true
FB slices: s13#17, s11
Hard because:
- CreateRabbitMqExchanges probe requires ExchangeType (direct/fanout/topic/headers); it is absent.
- Without type, the topology probe cannot be authored; model must not guess type.
Expected interrogation/plan:
- Q1: Exchange type for 'orders' (direct/fanout/topic/headers)?
- Q2: Binding/routing key between 'orders' exchange and 'order-events' queue?
- Q3: Is the topology already declared (ops-owned), or must the test own it (Stage 0 probe)?
- Q4: RabbitMQ host, port, vhost, credentials?
Verify (mechanical): ≥4 NEEDS_CLARIFICATION; no CreateRabbitMqExchanges block with guessed ExchangeType.
Rubric (graded):
- 0: guesses ExchangeType: direct and emits full Publisher + Consumer YAML.
- 5: asks exchange type but guesses host/port.
- 10: all 4 questions asked; no topology YAML emitted.
Solution sketch: Ask exchange type, binding key, topology ownership, and broker credentials before any Publisher YAML.

### N-119: Dockerfile Trailing Comment on FROM Line
Tier: T4
Goal text:
  "Build a mocker Docker image. Document the base image version inline:
   FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS build  # production base
   This helps future maintainers understand the choice."
Answer rounds: none
expectsClarification: true
FB slices: s13#18
Hard because:
- Docker does NOT allow trailing comments on instruction lines (s13#18); the # causes a parse error treating the comment as FROM arguments.
- Model must flag this without emitting the broken Dockerfile.
Expected interrogation/plan:
- Cite s13#18: trailing comments on FROM/COPY/RUN/ENTRYPOINT cause parse errors.
- The comment must move to its own preceding line.
- Propose corrected structure: comment line first, then FROM line with no trailing text.
- Do NOT emit the Dockerfile as the user specified it.
Verify (mechanical): response cites s13#18; any generated Dockerfile has comment on own line, not appended to FROM.
Rubric (graded):
- 0: emits Dockerfile verbatim as user described with trailing # comment.
- 5: removes the comment silently without explaining why.
- 10: cites s13#18, explains parse-error risk, shows corrected layout.
Solution sketch: Cite s13#18, move comment to its own line, emit corrected Dockerfile fragment.

### N-120: Five Goals in One Goal Statement
Tier: T4
Goal text:
  "Test user registration, then login, then password reset, then profile update,
   and also test that the admin API rejects unauthorized requests. All in one run."
Answer rounds: none
expectsClarification: true
FB slices: CONSTITUTION IV, SKILL plan-test-sprint §escalation
Hard because:
- Five distinct functional goals cannot be stated in one sentence (CONSTITUTION IV).
- A single sprint.json cannot faithfully represent five independent verification objectives.
Expected interrogation/plan:
- Cite CONSTITUTION IV: each sprint goal must be one sentence with a single verifiable outcome.
- Identify 5 separate goals; each needs its own sprint or at least a separate session block.
- Ask: which goal is the immediate priority to plan first?
- Offer to plan them sequentially, one sprint per goal.
Verify (mechanical): response cites CONSTITUTION IV; no monolithic 5-goal sprint.json; priority question asked.
Rubric (graded):
- 0: creates one sprint.json with 15+ tasks covering all 5 flows.
- 5: plans first 2 flows and defers the rest with a note.
- 10: cites CONSTITUTION IV, refuses omnibus sprint, asks which single goal to start.
Solution sketch: Cite IV, refuse five-in-one sprint, ask user which single flow to plan first.

### N-121: Production Database as DataSourceNames
Tier: T4
Goal text:
  "Use our production customer database as the test data source. Just point
   DataSourceNames to the prod connection string: Server=prod-db;Database=Customers."
Answer rounds: none
expectsClarification: true
FB slices: s13#3, CONSTITUTION XI
Hard because:
- Production data in tests risks PII exposure; model must flag and refuse without raising a sanitized alternative.
- DataSourceNames expects a file/S3 path or pattern, not a DB connection string; model must check s13#3 shape.
Expected interrogation/plan:
- Flag PII risk: production customer DB should never be a direct test data source.
- Clarify DataSourceNames schema: expects file path or S3 pattern, not a DB connection string (s13#3).
- Ask: can a sanitized export (CSV/JSON) be created for test use?
- Ask: what fields/volume are actually needed for the test cases?
Verify (mechanical): response refuses prod DB connection string; PII risk named; sanitized-fixture question asked.
Rubric (graded):
- 0: sets DataSourceNames to the prod connection string verbatim.
- 5: notes concern but asks if the user is "sure" and proceeds on confirmation.
- 10: refuses, cites s13#3 shape + PII risk, asks for sanitized fixture.
Solution sketch: Flag PII, clarify DataSourceNames expects file/S3 path, ask for sanitized export.

### N-122: Mixed-Case Route — Silent 404 Trap
Tier: T4
Goal text:
  "Test the endpoint at Route: getUserProfile. The mocker should respond 200 with
   the user JSON when this route is called."
Answer rounds: none
expectsClarification: true
FB slices: s13#5b
Hard because:
- Mixed-case route "getUserProfile" causes 404: mocker lowercases Path to "getuserprofile" then builds case-sensitive regex; runner sends "getUserProfile" verbatim → no match (s13#5b).
- Model must catch and flag this before emitting any YAML.
Expected interrogation/plan:
- Cite s13#5b: routes must be all-lowercase on BOTH mocker Path and runner Route.
- Correct route is "getuserprofile" everywhere.
- Confirm with user that lowercase route is acceptable (URL convention).
- Emit corrected YAML only after confirmation.
Verify (mechanical): response cites s13#5b; any generated YAML uses "getuserprofile" not "getUserProfile".
Rubric (graded):
- 0: emits YAML with Route: getUserProfile silently.
- 5: lowercases route in YAML but does not explain why.
- 10: cites s13#5b, explains 404 risk, asks user to confirm lowercase is acceptable.
Solution sketch: Cite s13#5b, correct to "getuserprofile" in both mocker Path and runner Route, explain why.

### N-123: HttpStatus Without Hermetic Count Guard
Tier: T4
Goal text:
  "Assert that the payment API returns HTTP 200. I don't need to check response counts;
   just verify the status code is correct."
Answer rounds: none
expectsClarification: true
FB slices: s13#13, CONSTITUTION VII
Hard because:
- HttpStatus passes VACUOUSLY when zero outputs arrive (s13#13); without a hermetic guard the assertion can give a false pass.
- Model must add the guard even when user says they do not want it, citing CONSTITUTION VII.
Expected interrogation/plan:
- Cite s13#13 and CONSTITUTION VII: HttpStatus vacuous pass is a known failure mode.
- Explain that "checking status code" is meaningless if zero HTTP responses arrived.
- Propose HermeticByExpectedOutputCount alongside HttpStatus; ask how many responses are expected.
- Do NOT emit HttpStatus without a count guard.
Verify (mechanical): response cites s13#13 and CONSTITUTION VII; no HttpStatus-only YAML; count guard proposed.
Rubric (graded):
- 0: emits HttpStatus: {StatusCode: 200, OutputNames: [resp]} with no hermetic guard.
- 5: adds hermetic guard silently without explaining vacuous-pass risk.
- 10: cites s13#13 + CONSTITUTION VII, explains vacuous pass, asks expected count.
Solution sketch: Mandate hermetic count guard alongside HttpStatus; cite s13#13 + CONSTITUTION VII; ask count.

### N-124: DataSourceNames "Will Be Provided Somehow"
Tier: T4
Goal text:
  "Create a Transaction session that calls our API with test payloads.
   The payloads will be provided later — just leave DataSourceNames as a placeholder."
Answer rounds: none
expectsClarification: true
FB slices: s13#3, CONSTITUTION VI
Hard because:
- DataSourceNames is REQUIRED (s13#3); placeholder violates CONSTITUTION VI (no placeholders).
- Model cannot emit a valid sprint.json with a TODO data source.
Expected interrogation/plan:
- Cite s13#3: DataSourceNames or DataSourcePatterns is REQUIRED for Transaction sessions.
- Cite CONSTITUTION VI: no placeholder values; plan is BLOCKED until data source is specified.
- Ask: what file path, S3 path, or generator will supply the request payloads?
- Do NOT emit DataSourceNames: "<placeholder>" or TODO.
Verify (mechanical): response cites s13#3 + CONSTITUTION VI; no placeholder DataSourceNames value in any YAML.
Rubric (graded):
- 0: emits DataSourceNames: "./payloads.json" as a guess.
- 5: leaves YAML field empty and notes it must be filled in later.
- 10: cites s13#3 + CONSTITUTION VI, emits BLOCKED, asks for the data source.
Solution sketch: Cite s13#3 and CONSTITUTION VI; emit BLOCKED; ask for actual DataSourceNames path or generator.

### N-125: Top-Level AllureReporter Block
Tier: T4
Goal text:
  "Configure AllureReporter at the top level of the runner YAML so all test results
   go to Allure automatically. Use the pattern shown in the QaaS debug guide."
Answer rounds: none
expectsClarification: true
FB slices: s13#10
Hard because:
- Top-level AllureReporter block is NOT LAB-verified (s13#10); the debug guide is outdated.
- Model must push back citing s13#10 and recommend the per-assertion Save*/DisplayTrace flags instead.
Expected interrogation/plan:
- Cite s13#10: top-level AllureReporter is unverified; do not emit it.
- Recommend per-assertion SaveResponseBody / DisplayTrace flags as the verified mechanism.
- Ask: what output does the user actually want to capture (response body, trace, custom)?
- Emit NEEDS_CLARIFICATION citing s13#10.
Verify (mechanical): response cites s13#10; no top-level Reporters: AllureReporter block in any generated YAML.
Rubric (graded):
- 0: emits top-level Reporters: block as described in the debug guide.
- 5: notes it "may not work" but emits it anyway.
- 10: cites s13#10, refuses top-level block, suggests per-assertion flags.
Solution sketch: Cite s13#10, refuse top-level AllureReporter, propose per-assertion Save*/DisplayTrace flags.

### N-126: Uniform Version 4.5.1 for All QaaS Packages
Tier: T4
Goal text:
  "Set all QaaS package versions to 4.5.1 for consistency. That includes Runner,
   Mocker, and all QaaS.Common.* packages."
Answer rounds: none
expectsClarification: true
FB slices: s13#9
Hard because:
- QaaS.Common.* packages are NOT version 4.5.1; applying Runner's version to Common.* yields NU1102 (s13#9).
- Correct versions: Runner 4.5.1, Mocker 2.4.1, Common.* 3.5.1. They are independent.
Expected interrogation/plan:
- Cite s13#9: packages have independent versions; 4.5.1 does not exist for Common.*.
- State correct version matrix from s13#9.
- Ask: should we use the LAB-verified compatible set, or is there a specific constraint?
- Do NOT emit .csproj with Common.Assertions Version="4.5.1".
Verify (mechanical): response cites s13#9; any generated .csproj uses correct independent versions; no Common.* at 4.5.1.
Rubric (graded):
- 0: emits all packages at Version="4.5.1".
- 5: fixes Runner/Mocker but still sets Common.* to 4.5.1 "for consistency."
- 10: cites s13#9, states correct matrix, generates .csproj with correct per-package versions.
Solution sketch: Cite s13#9 version matrix; generate .csproj with Runner=4.5.1, Mocker=2.4.1, Common.*=3.5.1.

### N-127: Non-Deterministic Queue + Exact Hermetic Count
Tier: T4
Goal text:
  "Our message queue sometimes delivers duplicates and redelivers messages after
   a timeout. Use HermeticByExpectedOutputCount: 10 to assert exactly 10 messages."
Answer rounds: none
expectsClarification: true
FB slices: s09, s13#13, CONSTITUTION VII
Hard because:
- Non-deterministic delivery (duplicates, redeliveries) is incompatible with an exact count hermetic guard; the guard may flap.
- Model must flag this fundamental mismatch before emitting any assertion config.
Expected interrogation/plan:
- Identify the contradiction: duplicates + exact-count hermetic guard = flapping test.
- Ask: should the test verify at-least N or exactly-N semantics?
- Ask: can the queue be configured for exactly-once delivery in the test environment?
- Propose HermeticByInputOutputPercentage as a less brittle alternative if duplicates are expected.
Verify (mechanical): response names the non-determinism/exact-count conflict; no HermeticByExpectedOutputCount emitted without resolution.
Rubric (graded):
- 0: emits HermeticByExpectedOutputCount: 10 ignoring the duplicate delivery note.
- 5: notes the tension but still emits exact count with a comment.
- 10: flags contradiction, explains flap risk, proposes percentage-based alternative, asks user to resolve.
Solution sketch: Flag duplicate/exact-count conflict; propose percentage-based guard; ask user to confirm delivery semantics.

### N-128: runtime:10.0 Base for Mocker Dockerfile
Tier: T4
Goal text:
  "Build the mocker Docker image using mcr.microsoft.com/dotnet/runtime:10.0
   as the base to reduce the final image size."
Answer rounds: none
expectsClarification: true
FB slices: s13#7
Hard because:
- runtime:10.0 lacks ASP.NET; mocker hosts HTTP, requires aspnet:10.0; the image will fail at startup (s13#7).
- Model must correct this and explain the reason, not silently comply.
Expected interrogation/plan:
- Cite s13#7: mocker requires aspnet:10.0 (not runtime:10.0) because it hosts an HTTP server.
- Using runtime:10.0 causes startup failure, not just a larger image.
- Propose aspnet:10.0 and note it is the verified base (s13#7).
- Do NOT emit a Dockerfile with runtime:10.0 as the final stage base.
Verify (mechanical): response cites s13#7; any generated Dockerfile uses aspnet:10.0 in final stage, not runtime:10.0.
Rubric (graded):
- 0: emits Dockerfile with runtime:10.0 as requested.
- 5: changes to aspnet:10.0 silently without explanation.
- 10: cites s13#7, explains runtime-vs-aspnet failure mode, emits corrected Dockerfile.
Solution sketch: Cite s13#7, correct final stage to aspnet:10.0, explain HTTP hosting requirement.

### N-129: Assuming Ops-Owned RabbitMQ Exchange Exists
Tier: T4
Goal text:
  "Publish 100 messages to the 'notifications' fanout exchange that our ops team
   set up last week. No topology setup needed — ops already did it."
Answer rounds: none
expectsClarification: true
FB slices: s13#17, s11
Hard because:
- The exchange may have been modified, deleted, or never created in the test environment; ops declarations are not guarantees.
- Without a Stage 0 topology probe the test fails with NOT_FOUND if the exchange is absent.
Expected interrogation/plan:
- Cite s13#17: Publisher does not create missing topology; missing exchange → AMQP NOT_FOUND → Outputs=0.
- Strongly recommend a Stage 0 CreateRabbitMqExchanges probe even if ops claims it exists.
- Ask: is this the same environment (same vhost/host) where ops created it, or a separate test env?
- Ask: vhost, host, port, credentials for the test environment.
Verify (mechanical): response cites s13#17; plan includes Stage 0 probe recommendation; ops-ownership assumption challenged.
Rubric (graded):
- 0: emits Publisher YAML with no topology probe, trusting the user.
- 5: adds probe but does not explain why, and does not challenge env-sameness.
- 10: cites s13#17, recommends probe, questions whether test env matches ops env.
Solution sketch: Cite s13#17, recommend Stage 0 probe, ask whether test env matches ops-declared env.

### N-130: Verify Command Starting with # Comment
Tier: T4
Goal text:
  "Add a verify step that documents what it does:
   cmd: '# Run the payment service smoke test and check exit 0'
   This will serve as self-documenting test verification."
Answer rounds: none
expectsClarification: true
FB slices: s13#14
Hard because:
- A verify cmd starting with # is a PowerShell comment; the entire single-line string is commented out, giving instant exit 0 — a vacuous pass (s13#14).
- Model must flag this and ask for the actual command intent.
Expected interrogation/plan:
- Cite s13#14: leading # in verify cmd silently passes; this is a documented trap.
- The cmd as written would never execute any actual check.
- Ask: what is the actual command to run (e.g., dotnet run -- run)?
- Put the explanation in the task description field, not in cmd.
Verify (mechanical): response cites s13#14; no verify cmd starting with # generated; actual cmd question asked.
Rubric (graded):
- 0: emits the verify cmd verbatim as user wrote it.
- 5: removes the # but emits an empty or generic cmd without asking.
- 10: cites s13#14, explains vacuous-pass risk, asks for the real command.
Solution sketch: Cite s13#14, refuse # comment as cmd, ask for the actual dotnet invocation.

### N-131: 3-Round — Mocker Retracted When Real Endpoint Confirmed
Tier: T5
Goal text:
  "Test our inventory service. It calls a pricing microservice to get discount rates."
Answer rounds:
  Round 1 provided: "Pricing has no staging env; we'll need to mock it."
  Round 2 provided: "Actually, pricing has a stable endpoint at http://pricing.staging:9001 — it never goes down."
  Round 3 needed: model must integrate round-2 retraction and ask residual facts.
expectsClarification: true
FB slices: CONSTITUTION IX, s02, s13#5
Hard because:
- Round 1 justifies mocker; round 2 retracts it — model must update MOCK_REQUIRED from yes→no and remove mocker tasks.
- Carrying round-1 mocker tasks into the plan after round-2 retraction is a hard failure.
- Model still needs port, route, DataSourceNames — round-3 questions remain.
Expected interrogation/plan:
- After round 2: set MOCK_REQUIRED=no; drop all scaffold-mocker and mocker-YAML tasks.
- Declare intent to use http://pricing.staging:9001 directly in runner Transaction.
- Ask round-3 residuals: which route on pricing? expected response shape? runner host reachability to staging?
- Do NOT retain any mocker task from round-1 analysis.
Verify (mechanical): final plan has zero mocker tasks; MOCK_REQUIRED=no declared; round-3 questions cite s13#5 route format.
Rubric (graded):
- 0: keeps mocker tasks "just in case" even after round-2 confirmation of real endpoint.
- 5: removes mocker but forgets to ask route or DataSourceNames.
- 10: retracts mocker fully, updates MOCK_REQUIRED=no, asks all round-3 residuals.
Solution sketch: On round 2, retract mocker, set MOCK_REQUIRED=no, ask route/data/reachability for direct runner plan.

### N-132: 3-Round Contradicting Auth Statements
Tier: T5
Goal text:
  "Test our analytics REST API. It returns aggregated metrics."
Answer rounds:
  Round 1 provided: "No auth needed; it's an internal API on the private network."
  Round 2 provided: "Wait, it does require a bearer token from our SSO endpoint."
  Round 3 provided: "The SSO is down in staging, so just skip the auth header."
expectsClarification: true
FB slices: s10, s02, CONSTITUTION XI, CONSTITUTION I
Hard because:
- Round 3 contradicts round 1 and 2; "skip auth" on an API that requires auth will yield 401 not a passing test.
- Model must challenge round-3 instruction rather than silently comply.
- Whether a built-in token generator exists (FB s10) must be checked; if not, custom hook needed.
Expected interrogation/plan:
- After round 3: do NOT silently skip auth; flag that a 401 response will make the test meaningless.
- Ask: can SSO be stubbed via a mocker, or is there a test-only bypass token?
- Check FB s10 for bearer-token generator; if absent, flag custom-hook need.
- Surface BLOCKED: cannot produce a valid test if SSO is unavailable and auth is required.
Verify (mechanical): round-3 skip-auth instruction challenged; 401 risk named; BLOCKED or mocker-for-SSO option offered.
Rubric (graded):
- 0: emits Transaction with no Authorization header, accepting round-3 instruction.
- 5: adds a placeholder token but does not flag SSO unavailability risk.
- 10: challenges round-3, explains 401 failure, offers mocker-SSO or test-bypass alternatives, emits BLOCKED if none.
Solution sketch: Challenge round-3 skip-auth, flag 401 risk, offer mocker-SSO stub or test bypass, emit BLOCKED if unresolvable.

### N-133: Hermetic Count Guard + Async Retry Contradiction
Tier: T5
Goal text:
  "Test our event processor. Use HermeticByExpectedOutputCount: 5 to ensure exactly
   5 events are processed. Also configure async retry so the runner retries if events
   are slow to arrive — we want it resilient to transient delays."
Answer rounds: none
expectsClarification: true
FB slices: s09, s13#13, CONSTITUTION VII
Hard because:
- HermeticByExpectedOutputCount terminates the session when N outputs arrive OR when the timeout expires; "async retry" (retrying the whole session) conflicts with the hermetic-termination contract.
- If an "async retry" mechanism exists in FB s09, it must be cited; if not, model must say so.
Expected interrogation/plan:
- Identify the conceptual conflict: hermetic guard already has a built-in wait/timeout; retry adds undefined re-run semantics.
- Check FB s09 for any retry configuration on hermetic assertions; cite result.
- Ask: is the user seeking a longer timeout rather than a retry? Offer Timeout configuration instead.
- Ask: what is an acceptable wait window before the test should fail?
Verify (mechanical): contradiction named; FB s09 citation for/against retry; no YAML with both hermetic + retry; timeout alternative offered.
Rubric (graded):
- 0: emits YAML with both HermeticByExpectedOutputCount and a retry block.
- 5: keeps hermetic, removes retry silently, does not explain or ask.
- 10: names contradiction, cites FB s09, offers Timeout alternative, asks acceptable wait window.
Solution sketch: Name hermetic/retry conflict, check FB s09 for retry support, offer Timeout parameter as alternative.

### N-134: False Premise — QaaS Chaos Module
Tier: T5
Goal text:
  "Use the QaaS Chaos module to randomly kill the mocker between requests, then
   verify our service handles the failure gracefully. Configure ChaosLevel: medium."
Answer rounds: none
expectsClarification: true
FB slices: CONSTITUTION I, s02, s12
Hard because:
- QaaS has no Chaos module, ChaosLevel parameter, or fault-injection session type in any known FB slice.
- Model must check all relevant slices (s02, s12) and report absence; cannot invent configuration.
Expected interrogation/plan:
- Check FB s02, s12 for Chaos/fault-injection; confirm absent in all checked slices.
- Emit NEEDS_CLARIFICATION: "QaaS Chaos module not found in FB s02/s12; cite source if known."
- Ask: what specific failure behavior is the user testing — network drop, HTTP 500, timeout?
- Offer nearest real alternatives: mocker processor returning 503, Delay stub, etc.
Verify (mechanical): response cites FB slice checks; no ChaosLevel or Chaos configuration emitted; alternative offered.
Rubric (graded):
- 0: invents ChaosConfiguration: {Level: medium} and adds it to the mocker YAML.
- 5: says "chaos not sure if supported" but tries to approximate with a delay processor.
- 10: cites FB s02/s12 absence, offers real alternatives (503 stub, delay), asks what failure mode to test.
Solution sketch: Check FB s02/s12, confirm Chaos absent, offer 503/delay processor alternative, ask target failure mode.

### N-135: Scale + Constraint + Zero-Loss Contradiction Triad
Tier: T5
Goal text:
  "Send 50,000 messages per second to test throughput. We're running this on a
   developer laptop with 8 GB RAM. Verify zero data loss using hermetic count guard."
Answer rounds: none
expectsClarification: true
FB slices: s02, s09, CONSTITUTION VII
Hard because:
- Three contradictions: (1) 50k msg/s is a load target, not functional test; (2) developer laptop cannot sustain that rate; (3) hermetic zero-loss at 50k/s is physically unrealistic.
- Each must be surfaced individually; model must not just silently reduce the number.
Expected interrogation/plan:
- Flag QaaS-as-load-tool mismatch (functional integration, not throughput benchmark).
- Flag laptop-resource impossibility at 50k/s.
- Flag hermetic zero-loss + high-volume = flapping test.
- Ask: what is the actual functional goal? Correct message routing? Schema validation?
- Suggest feasible functional volume (e.g., 100–1000 messages) and a separate load tool for 50k/s.
Verify (mechanical): all 3 contradictions named; no 50k message Publisher emitted; load-tool redirect offered.
Rubric (graded):
- 0: emits Publisher with Count: 50000 and hermetic guard.
- 5: reduces to 1000 silently and adds hermetic guard without explaining contradictions.
- 10: names all 3 issues explicitly, asks for actual functional goal, redirects load concern to separate tool.
Solution sketch: Flag load/resource/hermetic triple contradiction; ask for functional goal; redirect throughput to dedicated load tool.

### N-136: 3-Round — Fanout Exchange + Routing Key Contradiction
Tier: T5
Goal text:
  "Publish test events to RabbitMQ and verify the consumer receives them."
Answer rounds:
  Round 1 provided: "Exchange is 'payments', queue is 'payment-events'."
  Round 2 provided: "Exchange type is fanout. The queue binding uses routing key 'payment.created'."
  Round 3 needed: model must catch fanout + routing-key contradiction.
expectsClarification: true
FB slices: s13#17, s11, CONSTITUTION XI
Hard because:
- Fanout exchanges deliver to ALL bound queues regardless of routing key; specifying a routing key for a fanout binding is a contradiction (routing key is ignored by fanout).
- User stated this in round 2; model must catch it in round 3 instead of silently emitting the binding.
Expected interrogation/plan:
- After round 2: flag that fanout exchanges ignore routing keys; the binding key 'payment.created' has no effect.
- Ask: is the exchange actually topic or direct (where routing keys matter)?
- Or: confirm fanout is intended and the routing key should simply be omitted.
- Do NOT emit CreateRabbitMqExchanges with Type=fanout + RoutingKey='payment.created'.
Verify (mechanical): round-3 response flags fanout/routing-key conflict; no topology config with both fanout + non-empty routing key.
Rubric (graded):
- 0: emits fanout exchange binding with RoutingKey: payment.created without comment.
- 5: includes RoutingKey but adds a comment noting it is ignored.
- 10: flags contradiction explicitly, asks whether exchange should be topic/direct or routing key should be removed.
Solution sketch: Flag fanout-ignores-routing-key contradiction; ask to clarify exchange type or confirm routing key should be omitted.

### N-137: Airgap Environment — All Env Facts Missing
Tier: T5
Goal text:
  "Set up the full test harness and run it in our air-gapped CI environment."
Answer rounds: none
expectsClarification: true
FB slices: s13#9, CONSTITUTION X, SKILL offline-packaging
Hard because:
- Four independent unknowns: QAAS_DOCS_URL, private NuGet feed URL + credentials, Docker registry, QaaS tool installation path.
- Each unknown must be surfaced as a separate question; model cannot assume any of them.
Expected interrogation/plan:
- Q1: QAAS_DOCS_URL for the airgapped docs mirror?
- Q2: Private NuGet feed URL and authentication method?
- Q3: Are QaaS Docker images pre-cached or pulled from a private registry?
- Q4: Is the QaaS Runner global tool installed, or must it be installed from a local package?
- Q5: Which QaaS package versions are available in the private feed (verify against s13#9)?
Verify (mechanical): ≥5 NEEDS_CLARIFICATION covering docs URL, NuGet feed, Docker, tool install, and version availability.
Rubric (graded):
- 0: assumes nuget.org and public MCR, emits sprint.json.
- 5: asks NuGet feed but misses QAAS_DOCS_URL and Docker registry.
- 10: all 5 questions asked before any scaffold task is drafted.
Solution sketch: Ask all 5 airgap facts (docs URL, NuGet, Docker, tool, versions) before beginning any planning.

### N-138: Random Generator AND Fixed CSV for Same Session
Tier: T5
Goal text:
  "For the Transaction session, use randomly generated payloads AND also use our
   existing fixture file fixtures/orders.csv — combine both as the data source."
Answer rounds: none
expectsClarification: true
FB slices: s13#3, s10, CONSTITUTION I
Hard because:
- DataSourceNames accepts a list of file paths and DataSourcePatterns accepts patterns; combining a generator with a file source in a single session needs clarification on how QaaS resolves multiple sources.
- Model must check FB s13#3 and s10 for multi-source semantics before emitting; cannot assume interleaving or fallback behavior.
Expected interrogation/plan:
- Check FB s13#3 for multi-source DataSourceNames semantics.
- Ask: should the generator supplement the CSV (more records) or replace it conditionally?
- Ask: are random and fixture records intended to be interleaved, or run in separate sessions?
- If FB does not document multi-source generator+file, emit NEEDS_CLARIFICATION citing the gap.
Verify (mechanical): response cites FB s13#3 for multi-source semantics; no YAML assumed to work without docs grounding.
Rubric (graded):
- 0: emits DataSourceNames: [fixtures/orders.csv, {generator: RandomJson}] without checking docs.
- 5: notes uncertainty but generates a guessed config with a TODO comment.
- 10: checks FB s13#3, identifies documentation gap, asks user to clarify mixing intent, emits NEEDS_CLARIFICATION.
Solution sketch: Check FB s13#3 multi-source semantics; if undocumented, ask user intent and emit NEEDS_CLARIFICATION.

### N-139: False Premise — WaitForOutput Assertion
Tier: T5
Goal text:
  "Use the built-in WaitForOutput assertion to pause the session until all messages
   arrive before running content assertions. Configure WaitTimeoutSeconds: 30."
Answer rounds: none
expectsClarification: true
FB slices: s09, CONSTITUTION I
Hard because:
- WaitForOutput is not in the FB s09 built-in assertion catalog; model must check and push back.
- User's underlying intent (waiting for outputs before asserting) is legitimate and maps to hermetic guard + timeout — model should offer the real mechanism.
Expected interrogation/plan:
- Check FB s09 assertion catalog; WaitForOutput not listed.
- Cite s09 absence; emit NEEDS_CLARIFICATION.
- Explain that HermeticByExpectedOutputCount + a Timeout achieves the stated wait-then-assert intent.
- Ask: how many outputs are expected, and what is the acceptable wait window?
Verify (mechanical): response cites FB s09 absence of WaitForOutput; no WaitForOutput YAML emitted; hermetic+timeout alternative offered.
Rubric (graded):
- 0: emits AssertionType: WaitForOutput with WaitTimeoutSeconds: 30.
- 5: says "not sure if this assertion exists" but generates approximate YAML.
- 10: cites FB s09 absence, offers hermetic+timeout alternative, asks count and wait window.
Solution sketch: Check FB s09, cite WaitForOutput absence, propose hermetic guard + Timeout, ask expected count and window.

### N-140: Two Mocker Servers on the Same Port
Tier: T5
Goal text:
  "Run two mocker HTTP servers — one for GET requests on port 8080 and one for
   POST requests on port 8080. They serve different routes."
Answer rounds: none
expectsClarification: true
FB slices: s13#16, s02
Hard because:
- Two servers cannot bind the same host port; the second will fail to start with address-in-use.
- Model must catch the port collision, cite s13#16 PORT CONTRACT, and ask for distinct ports.
Expected interrogation/plan:
- Cite s13#16: each Servers.Http entry must bind a unique port.
- Binding two servers to 8080 → second server fails: address already in use.
- Ask: should these be two separate servers on distinct ports, or one server with two routes?
- One server with multiple stubs (GET /route1 and POST /route2) on the same port is the correct pattern.
Verify (mechanical): response cites s13#16 port collision; no mocker YAML with two Servers entries on port 8080.
Rubric (graded):
- 0: emits Servers: [{Http: {Port: 8080}}, {Http: {Port: 8080}}] for two servers.
- 5: puts each on its own port without explaining why or asking.
- 10: cites s13#16, explains collision, asks: two ports or one server with two routes?
Solution sketch: Cite s13#16, explain port collision, propose single server with two stubs or ask for two distinct ports.

### N-141: 3-Round Container Runtime Chaos
Tier: T5
Goal text:
  "Run our mocker in the CI environment."
Answer rounds:
  Round 1 provided: "Docker is available."
  Round 2 provided: "Actually Docker Desktop is not installed; we use Podman."
  Round 3 provided: "Podman is also broken on the CI agents; we use kind for Kubernetes."
expectsClarification: true
FB slices: CONSTITUTION IX, s13#7
Hard because:
- QaaS Mocker is a Docker-image-based service; Podman can be compatible but kind (Kubernetes) changes the deployment model significantly.
- Model must ask whether the mocker image can be loaded into kind/Podman before planning any scaffold or run step.
Expected interrogation/plan:
- After round 3: ask whether QaaS Mocker's Docker image can be loaded into kind (kubectl load / kind load docker-image).
- If yes, ask for the image push/load procedure and service port-forwarding setup.
- If no, the mocker cannot run in this environment; emit BLOCKED.
- Do NOT emit verify steps assuming docker run is available.
Verify (mechanical): round-3 response asks about kind image-loading or port-forwarding; no docker run in verify cmd; BLOCKED emitted if kind loading is infeasible.
Rubric (graded):
- 0: emits docker run commands in verify steps after round 3.
- 5: acknowledges kind but emits a plan with "adjust commands as needed."
- 10: asks about kind image-load capability, describes port-forward requirement, emits BLOCKED if not feasible.
Solution sketch: After round-3 kind revelation, ask about image-load + port-forwarding; emit BLOCKED if mocker cannot be reached.

### N-142: All P1 With Circular Dependency Loop
Tier: T5
Goal text:
  "Plan tests for our checkout flow. All 12 tasks must be priority 1.
   T-012 must wait for T-001, and T-001 must wait for T-012."
Answer rounds: none
expectsClarification: true
FB slices: SKILL plan-test-sprint §5 contract, CONSTITUTION IV
Hard because:
- Flat P1 for 12 tasks eliminates dependency ordering — scaffold → yaml → run cannot be expressed.
- The T-001/T-012 mutual dependency is a circular loop; the plan is logically unresolvable.
Expected interrogation/plan:
- Identify the circular dependency: T-001 depends on T-012 AND T-012 depends on T-001.
- Cite SKILL plan-test-sprint §5: no task at priority N may depend on task at priority ≥ N.
- Explain flat P1 makes the canonical dep order (scaffold→yaml→run) unenforceable.
- Ask: which task truly has no predecessors (the actual starting point)?
- Do NOT emit a sprint.json with circular deps or flat P1.
Verify (mechanical): circular dep loop named; flat P1 dependency issue cited; no sprint.json emitted; start-task question asked.
Rubric (graded):
- 0: emits sprint.json with all P1 and a circular dependsOn loop.
- 5: removes the circular dep silently and assigns arbitrary priority order.
- 10: names both problems (P1 flatness + circular dep), cites SKILL contract, asks user to identify true root task.
Solution sketch: Name circular dep + flat-P1 violations, cite SKILL sprint contract, ask for true root task.

### N-143: 3-Round — Mocker Implied Twice, Real Endpoint Confirmed
Tier: T5
Goal text:
  "Test our recommendation engine. It calls an external ML scoring service."
Answer rounds:
  Round 1 provided: "We'll probably need to mock the ML service."
  Round 2 provided: "The ML service is slow — that's why we should mock it."
  Round 3 provided: "Oh, there's actually a dedicated test instance at http://ml-test.internal:5050."
expectsClarification: true
FB slices: CONSTITUTION IX, s02
Hard because:
- User twice implies mocker (rounds 1 and 2) based on performance concern, not availability; round 3 reveals a real test instance.
- CONSTITUTION IX: mocker only when no real/stub endpoint is reachable — slowness does not qualify.
- Model must retract any mocker planning after round 3, not hedge with "we can still mock it."
Expected interrogation/plan:
- After round 3: declare MOCK_REQUIRED=no; real test instance is reachable.
- Cite CONSTITUTION IX: slow-but-reachable endpoint does not trigger mocker requirement.
- Ask residuals: port confirmed (5050)? routes/method on ML scoring endpoint? expected response shape?
- Produce runner-only plan pointing to http://ml-test.internal:5050.
Verify (mechanical): after round 3, all mocker tasks dropped; MOCK_REQUIRED=no declared; CONSTITUTION IX cited; residual questions asked.
Rubric (graded):
- 0: keeps mocker tasks citing performance concern even after round-3 confirmation.
- 5: drops mocker but notes "you could still mock it for speed."
- 10: drops mocker completely, cites CONSTITUTION IX, asks route/method/response residuals.
Solution sketch: On round 3, drop all mocker tasks, cite CONSTITUTION IX, declare MOCK_REQUIRED=no, ask routing residuals.

### N-144: 3-Round Version Drift — Latest → 5.0.0 → 4.5.1
Tier: T5
Goal text:
  "Set up the QaaS project with the latest package versions."
Answer rounds:
  Round 1 provided: "Use QaaS version 5.0.0 — our architect approved it."
  Round 2 provided: "Actually our team standardized on 4.5.1 for everything."
  Round 3 needed: model must verify round-2 "4.5.1 for everything" against s13#9 independent-version matrix.
expectsClarification: true
FB slices: s13#9
Hard because:
- Round 2 says "4.5.1 for everything" which re-introduces the uniform-version trap from s13#9 (Common.* packages are NOT 4.5.1).
- Round 1 (5.0.0) is unverified against FB; round 2 partially corrects it but introduces a new trap.
- Model must surface the round-2 trap and ask for clarification even though the user seems confident.
Expected interrogation/plan:
- After round 2: check s13#9 — applying 4.5.1 to Common.* yields NU1102.
- Cite s13#9 independent version matrix: Runner=4.5.1, Mocker=2.4.1, Common.*=3.5.1.
- Ask: should we use the LAB-verified compatible set, or is the team actually using custom builds?
- Flag that version 5.0.0 (round 1) is not in the FB-verified set.
Verify (mechanical): round-3 response cites s13#9; no Common.* at 4.5.1; correct version matrix stated; user asked to confirm.
Rubric (graded):
- 0: accepts round-2 "4.5.1 for everything" and emits .csproj with uniform 4.5.1.
- 5: fixes Runner/Mocker but silently accepts Common.* 4.5.1 with a note.
- 10: cites s13#9, states correct matrix, challenges round-2 instruction, asks about custom builds.
Solution sketch: On round 2, cite s13#9, reject uniform 4.5.1, state correct matrix, ask if team uses custom feed.

### N-145: False Premise — StreamingConsumer Session Type
Tier: T5
Goal text:
  "Use the StreamingConsumer session type to process a Kafka topic stream with
   exactly-once delivery semantics. Configure ConsumerGroup: analytics-v2."
Answer rounds: none
expectsClarification: true
FB slices: s02, CONSTITUTION I
Hard because:
- StreamingConsumer is not in the FB s02 session-type catalog; QaaS has Consumer but not a "streaming" variant.
- "Exactly-once" semantics is a Kafka delivery guarantee, not a QaaS configuration flag; model must not invent one.
Expected interrogation/plan:
- Check FB s02: StreamingConsumer not listed; only Consumer is present.
- Emit NEEDS_CLARIFICATION citing FB s02 absence.
- Clarify: a standard Consumer session reads from Kafka; exactly-once is a broker/consumer-group config, not QaaS-level.
- Ask: is a standard Consumer session acceptable? What Kafka broker/topic/group facts are needed?
Verify (mechanical): response cites FB s02; no StreamingConsumer YAML emitted; Consumer alternative offered; broker/topic question asked.
Rubric (graded):
- 0: emits SessionType: StreamingConsumer with ConsumerGroup: analytics-v2.
- 5: uses Consumer session but adds ExactlyOnce: true without checking if the flag exists.
- 10: cites FB s02 absence, explains standard Consumer, asks broker/topic facts, notes exactly-once is broker config.
Solution sketch: Cite FB s02, replace StreamingConsumer with Consumer, explain exactly-once is broker-level, ask Kafka facts.

### N-146: 3-Round Test Data Chain — S3 → Inaccessible → Synthetic
Tier: T5
Goal text:
  "Run the full order validation test suite."
Answer rounds:
  Round 1 provided: "We have 1,000 test records in S3 at s3://test-fixtures/orders/."
  Round 2 provided: "S3 is not accessible from the test environment — no outbound S3 access."
  Round 3 provided: "We can generate synthetic data instead."
expectsClarification: true
FB slices: s13#3, s10, CONSTITUTION VI
Hard because:
- Round 3 offers synthetic data but provides zero generator specification: which built-in generator? what schema? how many records?
- Model cannot emit DataSourceNames or a generator config without the spec; CONSTITUTION VI forbids placeholders.
Expected interrogation/plan:
- After round 3: ask which built-in generator (FB s10) or custom generator to use.
- Ask: what JSON schema/fields does the synthetic order need to match?
- Ask: how many synthetic records per test run?
- Do NOT emit a generator config guessing the schema; cite CONSTITUTION VI.
Verify (mechanical): round-3 response asks generator type, schema, and count; no placeholder DataSourceNames emitted.
Rubric (graded):
- 0: emits DataSourceNames: [{Generator: RandomJson}] with a guessed schema.
- 5: asks one question (which generator) but omits schema and count.
- 10: asks generator type, schema spec, and record count before any DataSourceNames is drafted.
Solution sketch: After round-3 synthetic pivot, ask generator type, schema, and count before emitting any data-source config.

### N-147: Stateless Mocker + Session-Tracking Request
Tier: T5
Goal text:
  "The mocker should remember previous requests and return different responses
   based on request history. After the 3rd request to /order, return 429."
Answer rounds: none
expectsClarification: true
FB slices: CONSTITUTION V, s12
Hard because:
- CONSTITUTION V: processors are stateless, instances shared across requests; no mutable instance state.
- Tracking "which request number this is" requires mutable shared state — prohibited.
- The user's goal (return 429 after 3rd call) is legitimate but cannot be achieved with a stateless processor.
Expected interrogation/plan:
- Cite CONSTITUTION V: processors are stateless; no request counter is permitted.
- Ask: can the 429 response be triggered by a different signal (e.g., a specific request header or payload field)?
- Offer alternative: mocker stub sequence (ordered responses) if supported by FB; check s12/mocker YAML catalog.
- Do NOT generate a processor with a static counter.
Verify (mechanical): response cites CONSTITUTION V; no processor with request-count state emitted; stateless alternatives explored.
Rubric (graded):
- 0: generates a C# processor with static Interlocked counter returning 429 after count ≥ 3.
- 5: refuses stateful field but adds a static Interlocked counter "as a workaround."
- 10: cites CONSTITUTION V, refuses any counter, asks about header/payload trigger or ordered stub sequences.
Solution sketch: Cite CONSTITUTION V, refuse request counter, explore ordered stub sequences or payload-triggered 429.

### N-148: Multi-Protocol Single Session
Tier: T5
Goal text:
  "Our service publishes to Kafka, consumes from RabbitMQ, and exposes an HTTP API.
   Test all three protocols in one QaaS session so everything runs together."
Answer rounds: none
expectsClarification: true
FB slices: s02, CONSTITUTION IV
Hard because:
- One QaaS session has one session type (Transaction, Publisher, Consumer, or Probe); it cannot mix protocols in a single session.
- User expects a single monolithic test; model must explain session-per-protocol design and ask for priority.
Expected interrogation/plan:
- Cite FB s02: each session is one type mapping to one protocol.
- Three protocols = three separate sessions (Publisher for Kafka, Consumer for RabbitMQ, Transaction for HTTP).
- Ask: is the goal to run them in sequence (stages), in parallel, or verify a cross-protocol flow?
- Ask: which protocol path is the primary verification concern?
Verify (mechanical): response cites FB s02 one-session-one-protocol; no single multi-protocol session block; stage/priority question asked.
Rubric (graded):
- 0: emits a single session block with mixed protocol configuration.
- 5: creates three sessions but does not explain why or ask about cross-protocol flow intent.
- 10: cites FB s02, explains multi-session design, asks for cross-protocol flow intent and priority.
Solution sketch: Cite FB s02 session-per-protocol, design three separate sessions, ask about cross-protocol flow intent.

### N-149: 3-Round — Mocker Retracted + Exchange Type Still Missing
Tier: T5
Goal text:
  "Test our payment service. It depends on both a notification HTTP service and
   publishes events to a RabbitMQ exchange."
Answer rounds:
  Round 1 provided: "Notification service has no staging; needs a mocker."
  Round 2 provided: "Notification service now has a staging endpoint at http://notify.staging:8200."
  Round 3 provided: "RabbitMQ exchange name is 'payment-events'. Ready to plan."
expectsClarification: true
FB slices: CONSTITUTION IX, s13#17, s11
Hard because:
- Round 2 retracts the HTTP mocker (CONSTITUTION IX); round 3 provides exchange name but NOT exchange type.
- Model must simultaneously drop mocker tasks AND ask for exchange type before planning the Publisher.
- Two distinct actions required from two different facts in the same turn.
Expected interrogation/plan:
- After round 2: set MOCK_REQUIRED=no for HTTP notification; drop HTTP mocker tasks.
- After round 3: note exchange type is still missing; cannot plan CreateRabbitMqExchanges probe.
- Ask for exchange type, binding key, vhost, host, port, credentials.
- Present partial plan (HTTP runner direct to notify.staging) and flag RabbitMQ as still blocked.
Verify (mechanical): HTTP mocker tasks absent; MOCK_REQUIRED=no declared; RabbitMQ exchange type question asked; partial plan noting two separate blocks.
Rubric (graded):
- 0: retains HTTP mocker and guesses exchange type as direct.
- 5: drops mocker but emits Publisher YAML with guessed exchange type.
- 10: drops mocker, declares MOCK_REQUIRED=no for HTTP, asks exchange type before any Publisher YAML.
Solution sketch: Drop HTTP mocker after round 2; after round 3, ask exchange type before Publisher; show partial plan with RabbitMQ block.

### N-150: Three Non-Existent Features in One Goal
Tier: T5
Goal text:
  "Use the built-in CircuitBreakerProcessor, the LoadBalancer session type, and
   the WaitForOutput assertion together to test our resilient API. These are
   documented in the advanced QaaS guide."
Answer rounds: none
expectsClarification: true
FB slices: s02, s09, s12, CONSTITUTION I
Hard because:
- Three features are absent from their respective FB slices: CircuitBreakerProcessor (s12), LoadBalancer (s02), WaitForOutput (s09).
- Each absence must be individually cited; model cannot partially plan around the ones it "knows."
- The "advanced QaaS guide" reference is unverifiable; CONSTITUTION X prohibits web search or memory.
Expected interrogation/plan:
- Check FB s12: CircuitBreakerProcessor not found; cite s12.
- Check FB s02: LoadBalancer session type not found; cite s02.
- Check FB s09: WaitForOutput not found; cite s09.
- Emit NEEDS_CLARIFICATION for each; ask user to provide a docs path or FB slice for each claimed feature.
- Do NOT emit any YAML for features absent from FB.
Verify (mechanical): three separate FB citation checks performed; three NEEDS_CLARIFICATION items emitted; zero YAML for any of the three features.
Rubric (graded):
- 0: invents configuration for all three features.
- 5: pushes back on one feature but generates approximate YAML for the other two.
- 10: checks all three FB slices, cites each absence individually, emits zero YAML, asks for docs path.
Solution sketch: Check FB s02/s09/s12 for each feature; cite three individual absences; refuse all three; ask user for docs evidence.
