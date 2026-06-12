# Scenario Catalog v3 - 500 Advanced Scenarios

Generated from batches/ on 2026-06-12. Tiers: T3 hard / T4 expert / T5 almost-impossible.

| Category | Count | T3 | T4 | T5 | Focus |
|---|---|---|---|---|---|
| A | 50 | 10 | 20 | 20 | Analysis (SUT/Helm/tests) |
| D | 50 | 10 | 20 | 20 | Docker/offline/CI |
| H | 50 | 10 | 20 | 20 | Custom C# hooks |
| M | 50 | 10 | 20 | 20 | Advanced mocker estates |
| N | 50 | 10 | 20 | 20 | Planning/interrogation |
| P | 50 | 10 | 20 | 20 | Parsing/ETL transformation contracts |
| Q | 50 | 10 | 20 | 20 | Messaging/broker topology |
| R | 50 | 10 | 20 | 20 | Advanced runner YAML (no mocker) |
| X | 50 | 10 | 20 | 20 | Failure forensics (multi-bug) |
| Z | 50 | 0 | 0 | 50 | Impossible integration (all-T5) |

Total: 500 scenarios. Full text in batches/batch-<cat>.md; machine-readable index in catalog.json.

## Category A - Analysis (SUT/Helm/tests)

| ID | Tier | Title |
|---|---|---|
| A-101 | T3 | ASP.NET Minimal-API Route Extraction |
| A-102 | T3 | appsettings.json Env-Config Extraction |
| A-103 | T3 | Single Helm Chart Port Extraction |
| A-104 | T3 | Minimal QaaS YAML Test Inventory |
| A-105 | T3 | RabbitMQ Consumer Endpoint Extraction |
| A-106 | T3 | gRPC Proto Contract Extraction |
| A-107 | T3 | OpenAPI Spec vs Handler Code Drift Check |
| A-108 | T3 | NUnit Test Inventory with Gap Diff |
| A-109 | T3 | Docker Compose Port and Env Extraction |
| A-110 | T3 | Feature-Flag-Gated Route Detection |
| A-111 | T4 | Polyglot C# + Node Sidecar Surface Extraction |
| A-112 | T4 | Env-Var Resolution Chain (appsettings â†’ Env â†’ Helm) |
| A-113 | T4 | Umbrella Helm Chart â€” Subchart Values Layering |
| A-114 | T4 | Dead-Code Endpoint Trap |
| A-115 | T4 | Multi-Queue RabbitMQ Topology from Code |
| A-116 | T4 | DTO Schema Extraction â€” Nullable, Enum, Inheritance |
| A-117 | T4 | Mixed NUnit + QaaS YAML Test Inventory |
| A-118 | T4 | Secrets vs ConfigMaps â€” Never-Fill-Gaps Rule |
| A-119 | T4 | Broker Topology from MassTransit Configuration |
| A-120 | T4 | gRPC Proto with Multiple Services and Imports |
| A-121 | T4 | OpenAPI vs Code Drift â€” Multiple Endpoints |
| A-122 | T4 | Feature-Flag-Gated Endpoint with Toggle Source |
| A-123 | T4 | Readiness and Liveness Probe Semantics |
| A-124 | T4 | Resource Limits Affecting Test Timing |
| A-125 | T4 | Python Worker Message Schema Extraction |
| A-126 | T4 | Existing QaaS YAML Repair Gap Analysis |
| A-127 | T4 | Multi-Env Values Override Analysis |
| A-128 | T4 | Test Data Lineage Analysis |
| A-129 | T4 | C# Inheritance DTO + Polymorphic Discriminator |
| A-130 | T4 | Kubernetes ConfigMap Env Resolution |
| A-131 | T5 | 3-Repo Polyglot + Umbrella Chart + OpenAPI/Code Drift + Feature Flag |
| A-132 | T5 | Two-Service Integration Surface Derivation |
| A-133 | T5 | Complex Env-Var Resolution Chain with Secrets |
| A-134 | T5 | Deep Broker Topology â€” Dead Letter Queues and Retry Exchanges |
| A-135 | T5 | Full Coverage-Gap Analysis with Create/Repair/Update |
| A-136 | T5 | Polyglot SUT â€” gRPC + HTTP + RabbitMQ Surface Extraction |
| A-137 | T5 | Umbrella Helm Chart â€” Global vs Subchart Value Precedence + Secret Gap |
| A-138 | T5 | Feature Flag Tree Analysis with Dead-Code Detection |
| A-139 | T5 | Cross-Repo DTO Schema Drift Detection |
| A-140 | T5 | Comprehensive README Contract for Finished Test Project |
| A-141 | T5 | Polyglot Kafka Topology (C# + Node + Python) |
| A-142 | T5 | Multi-Layer Helm Chart with Global Secrets and Per-Subchart Config |
| A-143 | T5 | OpenAPI Contradicts Code + Feature Flag Hides Route |
| A-144 | T5 | Complete SUT Profile for Microservices System |
| A-145 | T5 | Dead Code and Unreachable Endpoint Multi-Pattern Detection |
| A-146 | T5 | README Contract for a Finished Multi-Session Test Project |
| A-147 | T5 | Integration Surface Between Two Services with Shared Contract Repo |
| A-148 | T5 | Test Data Lineage Across Multiple Sessions and Fixtures |
| A-149 | T5 | Mixed Assertion Repair + New Test Creation Plan |
| A-150 | T5 | Full Polyglot 3-Repo Analysis â€” Effective Config + Surface Catalog + Gap Diff |

## Category D - Docker/offline/CI

| ID | Tier | Title |
|---|---|---|
| D-101 | T3 | aspnet vs runtime base in mocker Dockerfile |
| D-102 | T3 | Dockerfile trailing inline comment breaks FROM |
| D-103 | T3 | Compose internal-service port collision with host |
| D-104 | T3 | NuGet.config missing `<clear/>` leaks nuget.org in airgap |
| D-105 | T3 | Template install from local .nupkg with version pin |
| D-106 | T3 | NU1102 from applying Runner version to Common.* packages |
| D-107 | T3 | `IsLocalhost:true` makes mocker unreachable in container |
| D-108 | T3 | Volume-mounted session-data storage path mismatch |
| D-109 | T3 | Single published port with internal-only service mesh |
| D-110 | T3 | Redis service name vs localhost in mocker container |
| D-111 | T4 | Multi-stage mocker image with custom processor baked in |
| D-112 | T4 | Env-var-driven YAML config file selection at container startup |
| D-113 | T4 | Registry substitution for airgapped Docker builds |
| D-114 | T4 | Layer caching invalidation via build-arg placement |
| D-115 | T4 | Healthcheck + depends_on condition in compose |
| D-116 | T4 | CI build script: build â†’ test â†’ tag â†’ save tar |
| D-117 | T4 | docker save/load offline flow for air-gapped USB transfer |
| D-118 | T4 | NuGet.config %VAR% expansion matrix across environments |
| D-119 | T4 | NU1301 feed authentication failure forensics |
| D-120 | T4 | Multi-arch mocker image build for arm64 CI runners |
| D-121 | T4 | Container log capture piped to assertion verification |
| D-122 | T4 | Network isolation â€” mocker internal, runner on host |
| D-123 | T4 | Port-conflict matrix diagnosis in parallel CI jobs |
| D-124 | T4 | Compose project-name isolation for parallel CI lanes |
| D-125 | T4 | OOM diagnosis during mocker container run |
| D-126 | T4 | Version pinning audit across all QaaS packages in airgap build |
| D-127 | T4 | Feed ordering and clear-first with multiple Artifactory repositories |
| D-128 | T4 | dotnet new template not found after .nupkg install on air-gapped machine |
| D-129 | T4 | Probe port contract consistency across YAML files in compose topology |
| D-130 | T4 | RabbitMQ internal service name vs `localhost` in async consumer test |
| D-131 | T5 | Full airgapped CI: custom processor â†’ mocker image â†’ compose + redis healthgate â†’ runner |
| D-132 | T5 | Multi-stage mocker with processor + assertions packages, airgap feed, aspnet base |
| D-133 | T5 | Compose topology: mocker-internal network + runner on host + healthcheck gate |
| D-134 | T5 | Registry substitution in multi-stage Dockerfile via ARG before each FROM |
| D-135 | T5 | Full airgap bootstrap: template .nupkg install + version alignment + private feed restore |
| D-136 | T5 | Parallel CI lanes with project-name isolation and unique ports |
| D-137 | T5 | docker save/load with volume-mounted session-data in offline environment |
| D-138 | T5 | %VAR% expansion matrix: four environments, one NuGet.config |
| D-139 | T5 | Container log capture as CI assertion with exit-code gating |
| D-140 | T5 | NU1102/NU1301 forensics with layered feed misconfiguration |
| D-141 | T5 | Complete offline CI: custom processor build â†’ mocker image â†’ compose + internal redis â†’ runner â†’ exit code validation |
| D-142 | T5 | Multi-arch arm64 mocker image with private aspnet:10.0 mirror |
| D-143 | T5 | Compose depends_on healthcheck chain: rabbitmq â†’ mocker â†’ runner |
| D-144 | T5 | OOM + port-conflict matrix in 4-lane parallel CI |
| D-145 | T5 | Env-var-driven mocker config with runtime %VAR% substitution in YAML |
| D-146 | T5 | Airgap template install + version alignment + runner restore from private feed in one script |
| D-147 | T5 | Multi-stage image with private registry mirror substitution and aspnet validation |
| D-148 | T5 | Full CI artifact pipeline: build â†’ test â†’ tag â†’ save tar â†’ load â†’ run â†’ capture logs |
| D-149 | T5 | Network isolation validation â€” prove internal services unreachable from host |
| D-150 | T5 | Complete airgapped regression suite: compose topology + private NuGet + healthgates + runner exit codes |

## Category H - Custom C# hooks

| ID | Tier | Title |
|---|---|---|
| H-101 | T3 | Sequential ID Generator with Configurable Start/Step |
| H-102 | T3 | Output Field-Count Matches Input Field-Count Assertion |
| H-103 | T3 | TCP Port Reachability Pre-Run Probe |
| H-104 | T3 | Generator Reading External JSON File via DataSource |
| H-105 | T3 | Uniqueness-Invariant Assertion Across All Outputs |
| H-106 | T3 | Timezone-Stable UTC Timestamp Generator |
| H-107 | T3 | File-Existence Pre/Post Probe |
| H-108 | T3 | Seeded Deterministic Pseudo-Random Generator |
| H-109 | T3 | Numeric Sum Invariant Assertion |
| H-110 | T3 | Config Record with Enum Field Validation |
| H-111 | T4 | Sliding-Window Generator (Last N Elements) |
| H-112 | T4 | JSON Schema Shape-Validating Assertion |
| H-113 | T4 | HMAC Signature Chain Generator |
| H-114 | T4 | Input-to-Output Field Cross-Correlation Assertion |
| H-115 | T4 | Mocker Decrypt-Mutate-Resign Processor Chain |
| H-116 | T4 | CSV File Data-Source Generator |
| H-117 | T4 | UTF-8 BOM Encoding Pitfall in File-Reading Generator |
| H-118 | T4 | Decimal Rounding Integrity Assertion |
| H-119 | T4 | Ordering Invariant Assertion Across Multiple Outputs |
| H-120 | T4 | Idempotency Probe Verifying Deterministic Re-execution |
| H-121 | T4 | Culture-Invariant String Comparison Pitfall (tr-TR Casing) |
| H-122 | T4 | Coexisting Generator + Assertion + Probe in One Project Without DI Conflicts |
| H-123 | T4 | Process-Existence Synchronous Probe |
| H-124 | T4 | Large-Payload Generator (Configurable Size) |
| H-125 | T4 | Config Record with Nested Required Object |
| H-126 | T4 | Stateful Generator with Per-Session Sequence Reset |
| H-127 | T4 | Request-to-Response Field Mirror Assertion |
| H-128 | T4 | Processor with Static HttpClient for External Enrichment |
| H-129 | T4 | Post-Session File Cleanup Probe |
| H-130 | T4 | Configurable Date-Range Timezone-Stable Timestamp Generator |
| H-131 | T5 | HMAC Signature Chain Integrity Assertion (T5) |
| H-132 | T5 | Full Processor Chain: Base64-Decode â†’ Mutate JSON â†’ HMAC Re-Sign (T5) |
| H-133 | T5 | Multi-Output Sum + Ordering + Uniqueness Combined Assertion (T5) |
| H-134 | T5 | Sliding-Window State Persisted via DataSource File (T5) |
| H-135 | T5 | CSV Generator with Culture-Invariant Decimal Parsing (T5) |
| H-136 | T5 | JSON Schema Assertion Without Third-Party Library (Deep Traversal) (T5) |
| H-137 | T5 | Processor with Nested Config Records and Enum Validation (T5) |
| H-138 | T5 | Three-Check Synchronous Probe (TCP + File + Process) (T5) |
| H-139 | T5 | Idempotency Assertion: Two Runs Must Hash Identically (T5) |
| H-140 | T5 | Large-Payload Assertion Verifying Fields Without OOM (T5) |
| H-141 | T5 | Four-Hook Coexistence (Generator + Assertion + Probe + Processor) Without DI Conflicts (T5) |
| H-142 | T5 | Seeded PRNG Generator Whose Seed Derives from Config + Session Metadata (T5) |
| H-143 | T5 | Cross-Output Total = Sum of Subtotals Assertion (T5) |
| H-144 | T5 | Input-to-Output Schema Drift Detection Assertion (T5) |
| H-145 | T5 | AES-256 Decrypt â†’ Validate â†’ Re-Encrypt Processor (T5) |
| H-146 | T5 | DST-Crossing Timestamp Generator with Sort Stability (T5) |
| H-147 | T5 | UTF-8 BOM + tr-TR Casing Double-Pitfall Assertion (T5) |
| H-148 | T5 | Three-Level Nested Config Record with Full Validation (T5) |
| H-149 | T5 | Synchronous Probe: TCP + File + Redis PING All-in-One (T5) |
| H-150 | T5 | Full-Stack Hook Suite: Generator + Assertion + Probe + Processor with HMAC Chain, Nested Config, and Cross-Output Invariants (T5) |

## Category M - Advanced mocker estates

| ID | Tier | Title |
|---|---|---|
| M-101 | T3 | Dual-Port HTTP Mocker with Health and Business Routes |
| M-102 | T3 | ProcessorConfiguration vs TransactionData Trap (Static Stub) |
| M-103 | T3 | Lowercase Route End-to-End Trap |
| M-104 | T3 | Latency Injection via DelayProcessor |
| M-105 | T3 | Not-Found Fallback Default Stub Behavior |
| M-106 | T3 | JSON Content-Type Response Simulation |
| M-107 | T3 | 5xx Fault Injection Stub |
| M-108 | T3 | Pagination Simulation via SequenceProcessor |
| M-109 | T3 | Rate-Limit Simulation (429 + Retry-After Header) |
| M-110 | T3 | Request Echo Processor |
| M-111 | T4 | Three-Server Mocker (HTTP + HTTP + HTTP, Distinct Ports) |
| M-112 | T4 | Redis Controller Mid-Run Stub Swap |
| M-113 | T4 | Stateful Conversation Mock via SequenceProcessor |
| M-114 | T4 | Conditional Routing on Request Header |
| M-115 | T4 | Auth Handshake Mock (401 â†’ Token â†’ 200 Flow) |
| M-116 | T4 | Webhook Callback Mock |
| M-117 | T4 | Idempotency-Key Behavior Simulation |
| M-118 | T4 | 5xx Storm Simulation (Repeated Failures then Recovery) |
| M-119 | T4 | Malformed JSON Fault Injection |
| M-120 | T4 | Binary Payload Response (Octet-Stream) |
| M-121 | T4 | Cursor-Based Pagination Simulation |
| M-122 | T4 | Multi-Stub ProcessorConfiguration Chain on One Route |
| M-123 | T4 | Conditional Routing on Request Body Regex |
| M-124 | T4 | XML vs JSON Content-Type Negotiation |
| M-125 | T4 | CORS Header Injection Mock |
| M-126 | T4 | Stub Priority and Matching Order |
| M-127 | T4 | Connection Timeout Simulation |
| M-128 | T4 | Multi-Path Routing on One Server Port |
| M-129 | T4 | Dockerfile Base Image Trap (aspnet vs runtime) |
| M-130 | T4 | Redis Port Publish Trap in Compose |
| M-131 | T5 | Four-Server Mocker Estate with Controller |
| M-132 | T5 | Controller Swaps Stubs Between Runner Sessions |
| M-133 | T5 | Auth Mock Gates a Webhook Flow |
| M-134 | T5 | Full OAuth2 Authorization Code Flow Simulation |
| M-135 | T5 | Stateful Conversation Mock with Controller Reset |
| M-136 | T5 | Multi-Stage Fault Injection with Recovery Assertion |
| M-137 | T5 | Rate-Limit with Exponential Backoff Simulation |
| M-138 | T5 | Idempotency Across Multiple Attempts with Key Tracking |
| M-139 | T5 | Binary + JSON Content Negotiation Under Controller Swap |
| M-140 | T5 | Pagination with Dynamic Page-Size via Controller |
| M-141 | T5 | Conditional Routing on Multiple Header Combinations |
| M-142 | T5 | Four-Server Microservices Mesh (All HTTP, Full Flow) |
| M-143 | T5 | Controller-Driven A/B Testing Mock |
| M-144 | T5 | Webhook Delivery with Signature Verification Mock |
| M-145 | T5 | Multi-Tenant Auth Mock with Per-Tenant Stub Profiles |
| M-146 | T5 | Circuit Breaker State Simulation (Open / Half-Open / Closed) |
| M-147 | T5 | GraphQL Mock with Introspection Response |
| M-148 | T5 | Service Mesh Retry with Controller-Injected Transient Fault |
| M-149 | T5 | Full Event-Driven Saga Mock (Four Services + Controller) |
| M-150 | T5 | Canary Deployment Simulation with Weighted Traffic Split |

## Category N - Planning/interrogation

| ID | Tier | Title |
|---|---|---|
| N-101 | T3 | Vague Payment Service Goal |
| N-102 | T3 | Under-Specified RabbitMQ Consumer |
| N-103 | T3 | Over-Specified Architecture, One Endpoint Needed |
| N-104 | T3 | False Premise â€” LoadBalancer Session Type |
| N-105 | T3 | Real Endpoint Exists â€” Mocker Must Not Be Planned |
| N-106 | T3 | Data Ownership Ambiguity |
| N-107 | T3 | Environment Ambiguity â€” Airgapped vs Online |
| N-108 | T3 | Scale Feasibility Trap |
| N-109 | T3 | Priority Escalation â€” Everything P1 |
| N-110 | T3 | No Docker, Wants RabbitMQ Mock |
| N-111 | T4 | Hermetic Count Guard vs Fire-and-Forget Contradiction |
| N-112 | T4 | Two-Round Notification Service â€” Round 2 Still Blocked |
| N-113 | T4 | False Premise â€” RetryProcessor Built-in |
| N-114 | T4 | Stateful Custom Processor Requested |
| N-115 | T4 | Scope Creep â€” 10 Microservices in One Sprint |
| N-116 | T4 | OAuth Auth Ambiguity |
| N-117 | T4 | Port Contract Violation in User Spec |
| N-118 | T4 | Missing Exchange Type for Topology Probe |
| N-119 | T4 | Dockerfile Trailing Comment on FROM Line |
| N-120 | T4 | Five Goals in One Goal Statement |
| N-121 | T4 | Production Database as DataSourceNames |
| N-122 | T4 | Mixed-Case Route â€” Silent 404 Trap |
| N-123 | T4 | HttpStatus Without Hermetic Count Guard |
| N-124 | T4 | DataSourceNames "Will Be Provided Somehow" |
| N-125 | T4 | Top-Level AllureReporter Block |
| N-126 | T4 | Uniform Version 4.5.1 for All QaaS Packages |
| N-127 | T4 | Non-Deterministic Queue + Exact Hermetic Count |
| N-128 | T4 | runtime:10.0 Base for Mocker Dockerfile |
| N-129 | T4 | Assuming Ops-Owned RabbitMQ Exchange Exists |
| N-130 | T4 | Verify Command Starting with # Comment |
| N-131 | T5 | 3-Round â€” Mocker Retracted When Real Endpoint Confirmed |
| N-132 | T5 | 3-Round Contradicting Auth Statements |
| N-133 | T5 | Hermetic Count Guard + Async Retry Contradiction |
| N-134 | T5 | False Premise â€” QaaS Chaos Module |
| N-135 | T5 | Scale + Constraint + Zero-Loss Contradiction Triad |
| N-136 | T5 | 3-Round â€” Fanout Exchange + Routing Key Contradiction |
| N-137 | T5 | Airgap Environment â€” All Env Facts Missing |
| N-138 | T5 | Random Generator AND Fixed CSV for Same Session |
| N-139 | T5 | False Premise â€” WaitForOutput Assertion |
| N-140 | T5 | Two Mocker Servers on the Same Port |
| N-141 | T5 | 3-Round Container Runtime Chaos |
| N-142 | T5 | All P1 With Circular Dependency Loop |
| N-143 | T5 | 3-Round â€” Mocker Implied Twice, Real Endpoint Confirmed |
| N-144 | T5 | 3-Round Version Drift â€” Latest â†’ 5.0.0 â†’ 4.5.1 |
| N-145 | T5 | False Premise â€” StreamingConsumer Session Type |
| N-146 | T5 | 3-Round Test Data Chain â€” S3 â†’ Inaccessible â†’ Synthetic |
| N-147 | T5 | Stateless Mocker + Session-Tracking Request |
| N-148 | T5 | Multi-Protocol Single Session |
| N-149 | T5 | 3-Round â€” Mocker Retracted + Exchange Type Still Missing |
| N-150 | T5 | Three Non-Existent Features in One Goal |

## Category P - Parsing/ETL transformation contracts

| ID | Tier | Title |
|---|---|---|
| P-101 | T3 | CSVâ†’JSON Field Normalizer |
| P-102 | T3 | Fixed-Width Column Parser |
| P-103 | T3 | Log-Line Severity Enricher |
| P-104 | T3 | Currency Amount Half-Up Rounding |
| P-105 | T3 | UTC Timestamp Normalizer |
| P-106 | T3 | Simple Deduplicator (Exact-Once) |
| P-107 | T3 | Field Rename / Drop / Default Mapper |
| P-108 | T3 | Email PII Masker |
| P-109 | T3 | UTF-8 Multibyte Passthrough Validator |
| P-110 | T3 | 1â†’2 Record Fan-Out |
| P-111 | T4 | CSV Embedded Commas and Quoted Fields |
| P-112 | T4 | Fixed-Width Multi-Record Batch Parser |
| P-113 | T4 | Log Enricher with Host and Environment Metadata |
| P-114 | T4 | DST Spring-Forward Timestamp Normalization |
| P-115 | T4 | 5-Second Windowed Count Aggregator |
| P-116 | T4 | Schema V1 Input Tolerance (Default Injection) |
| P-117 | T4 | Malformed Record Quarantine (Goodâ†’Out, Badâ†’Error) |
| P-118 | T4 | PII Phone and Email Combined Masker |
| P-119 | T4 | Idempotent Reprocessing (Same Message ID Twice) |
| P-120 | T4 | Ordering Preservation Through ETL |
| P-121 | T4 | High-Precision Decimal String Preservation |
| P-122 | T4 | Windows-1255 Hebrew Encoding Decoder |
| P-123 | T4 | CSV With Embedded Newlines in Quoted Fields |
| P-124 | T4 | Metrics Endpoint Record Count |
| P-125 | T4 | Log Stream Queue Assertion via RabbitMQ |
| P-126 | T4 | Latency Budget Assertion (Sub-500ms Processing) |
| P-127 | T4 | Windowed Amount Total Aggregator |
| P-128 | T4 | Conditional Default Field Injection |
| P-129 | T4 | PII Pass-Through â€” No Over-Masking |
| P-130 | T4 | 1â†’N Fan-Out Hermetic Count Verification |
| P-131 | T5 | Mixed V1+V2 Stream Schema Evolution |
| P-132 | T5 | Malformed Record Quarantine With Reason Codes |
| P-133 | T5 | 10-Second Tumbling Window Aggregation |
| P-134 | T5 | Banker's Rounding (Round-Half-to-Even) Verification |
| P-135 | T5 | Metrics Counter Must Equal Hermetic Output Count |
| P-136 | T5 | Windows-1255 â†” UTF-8 Hebrew Text Roundtrip |
| P-137 | T5 | 1â†’3 Fan-Out Hermetics Across Three Target Queues |
| P-138 | T5 | DST Fall-Back Ambiguous Timestamp Handling |
| P-139 | T5 | Multi-Stage ETL Pipeline (Parse â†’ Enrich â†’ Validate) |
| P-140 | T5 | Deduplication + Ordering Preservation Combined |
| P-141 | T5 | Quarantine Dual Assertion â€” Good Queue AND Error Queue Same Run |
| P-142 | T5 | Idempotent Reprocessing State Probe via HTTP |
| P-143 | T5 | Multiline Quoted CSV Field End-to-End Integrity |
| P-144 | T5 | Float Accumulation vs Decimal Precision in Batch Sum |
| P-145 | T5 | Schema Evolution Combined With PII Masking |
| P-146 | T5 | Metrics Counter Reconciliation (processed + errors = total) |
| P-147 | T5 | Windowed Aggregator Late-Arrival Routing |
| P-148 | T5 | Log Stream Enrichment Fields Assertion |
| P-149 | T5 | Mixed Encoding Auto-Detection (UTF-8 vs ISO-8859-1) |
| P-150 | T5 | Full E2E ETL Contract (Parse + Enrich + Mask + Count + Metrics) |

## Category Q - Messaging/broker topology

| ID | Tier | Title |
|---|---|---|
| Q-101 | T3 | Direct Exchange Routing â€” Declare + Publish + Consume |
| Q-102 | T3 | Fanout Exchange â€” Two Queues Receive Same Message |
| Q-103 | T3 | Topic Exchange â€” Wildcard Routing Key Match |
| Q-104 | T3 | Headers Exchange â€” Route by Message Header Value |
| Q-105 | T3 | Consumer TimeoutMs Tuning â€” Avoid Flaky Empty Output |
| Q-106 | T3 | Publisher Iterations â€” Hermetic Count Equals Iterations |
| Q-107 | T3 | Redis Pub/Sub â€” Publisher and Consumer via Redis Protocol |
| Q-108 | T3 | Kafka Topic â€” Basic Publish and Consume |
| Q-109 | T3 | Priority Queue â€” Declare With Arguments and Consume High-Priority First |
| Q-110 | T3 | Setup + Teardown Probes â€” Topology Lifecycle Across Sessions |
| Q-111 | T4 | Dead-Letter Queue â€” TTL Expiry Routes to DLQ |
| Q-112 | T4 | Competing Consumers â€” Hermetic Percentage Math |
| Q-113 | T4 | Publisher with LoadBalance Rate Policy â€” Hermetic Count in Window |
| Q-114 | T4 | Kafka Consumer Group â€” Two Groups Same Topic Independent Offsets |
| Q-115 | T4 | Redis Keyspace Events â€” Consumer on __keyevent@0__:set |
| Q-116 | T4 | Fanout to Three Queues â€” Per-Queue Hermetic Count + Aggregate |
| Q-117 | T4 | Topic Exchange Routing Matrix â€” Four Binding Patterns |
| Q-118 | T4 | Delayed Message via SleepTimeMs â€” Verify Delay Assertion |
| Q-119 | T4 | Large Message Body â€” Binary Serialization End-to-End |
| Q-120 | T4 | Header Routing Matrix â€” Two Binding Variants, Assert Each |
| Q-121 | T4 | Mixed-Broker Pipeline â€” HTTP Ingress â†’ RabbitMQ Work Queue â†’ Consumer Assert |
| Q-122 | T4 | Poison Message â€” DLQ After Max-Retry Count |
| Q-123 | T4 | Kafka Partition Ordering â€” Single Partition Guarantees Sequence |
| Q-124 | T4 | RabbitMQ PurgeQueue Probe â€” Isolation Between Test Runs |
| Q-125 | T4 | Advanced Load Balance â€” Staged Ramp-Up With Hermetic Range |
| Q-126 | T4 | Throughput Window â€” 100 Messages in 5 Seconds, Hermetic Range |
| Q-127 | T4 | RabbitMQ Binding Probe â€” Exchange-to-Queue Wiring Before Publish |
| Q-128 | T4 | Kafka â€” Unique GroupId via Variable for Deterministic Reruns |
| Q-129 | T4 | RabbitMQ Vhost Isolation â€” Two Vhosts, No Cross-Bleed |
| Q-130 | T4 | Kafka Topic â€” IncreasingLoadBalance with Hermetic Percentage Range |
| Q-131 | T5 | Topic Fan-Out to 4 Queues With Per-Queue TTL Cascading to Shared DLQ |
| Q-132 | T5 | Competing Consumers With Increasing Load Balance â€” Hermetic Percentage + Per-Consumer Range |
| Q-133 | T5 | Broker Restart Resilience â€” OsRestartPods Probe Mid-Run |
| Q-134 | T5 | Three-Level DLQ Cascade â€” Source â†’ DLQ1 â†’ DLQ2 â†’ Consumer |
| Q-135 | T5 | Headers Exchange `x-match: all` vs `x-match: any` â€” Side-by-Side Contrast |
| Q-136 | T5 | Multi-Session Fanout â€” Sessions 1+2+3 Publish, Session 4 Aggregates |
| Q-137 | T5 | Kafka + RabbitMQ Mixed-Broker â€” Publish to Kafka, Shovel to Rabbit, Assert Consumer |
| Q-138 | T5 | MockerCommand Consume â€” Assert Mocker Received Expected Messages |
| Q-139 | T5 | Throughput + DelayByChunks â€” Chunks of 10, Max Delay 500ms Per Chunk |
| Q-140 | T5 | End-to-End: HTTP Ingress â†’ Fanout â†’ 4 Consumers â†’ Per-Queue DelayByAverage + Aggregate Hermetic |
| Q-141 | T5 | Kafka â€” Compacted Topic, Only Latest Value per Key Survives |
| Q-142 | T5 | Redis Pub/Sub â€” Multiple Channels, Per-Channel Hermetic Count |
| Q-143 | T5 | Kafka Consumer Group Rebalance â€” Two Consumers Same GroupId, Hermetic Range |
| Q-144 | T5 | ValidateHermeticMetricsByInputOutputPercentage â€” Prometheus Collector Integration |
| Q-145 | T5 | ObjectOutputJsonSchema â€” All Consumer Messages Match Schema |
| Q-146 | T5 | Delayed Exchange Plugin (x-delayed-message) â€” Docs-Thin Scenario |
| Q-147 | T5 | Cases â€” Three Data Variants Through Same Pipeline, Per-Case Assertions |
| Q-148 | T5 | Large-Scale Kafka â€” 1000 Messages, 4 Partitions, Hermetic Percentage |
| Q-149 | T5 | Port Contract Violation â€” Probe Port Mismatches Mocker Port |
| Q-150 | T5 | Overwrite Files â€” Multi-Environment Fanout, Consumer Timeout Parameterized |

## Category R - Advanced runner YAML (no mocker)

| ID | Tier | Title |
|---|---|---|
| R-101 | T3 | Sequential Two-Session HTTP Chain |
| R-102 | T3 | Environment Overwrite File (-w flag) |
| R-103 | T3 | Cases Matrix for Status-Code Testing (-c flag) |
| R-104 | T3 | HermeticByExpectedOutputCount Boundary Math |
| R-105 | T3 | FileSystem Storage Act/Assert Session Pair |
| R-106 | T3 | Metadata and Observability Links |
| R-107 | T3 | Large DataSource Fan-Out with AsciiAsc Order |
| R-108 | T3 | Timing Windows with TimeoutBeforeSessionMs/TimeoutAfterSessionMs |
| R-109 | T3 | Route Case Trap â€” Uppercase Route Yields 404 |
| R-110 | T3 | Vacuous Pass Trap Demonstration with HttpStatus |
| R-111 | T4 | Five-Session Staged HTTP Load Test |
| R-112 | T4 | HermeticByInputOutputPercentage Edge Math |
| R-113 | T4 | Weighted Distribution Generator |
| R-114 | T4 | Unicode Boundary Payload Transactions |
| R-115 | T4 | Large Payload (1MB) Transaction Stress |
| R-116 | T4 | Empty Body Boundary Transaction |
| R-117 | T4 | Cases Matrix with DataSources Override |
| R-118 | T4 | Variables Default Value Syntax |
| R-119 | T4 | YAML Anchors for Shared Transaction Configuration |
| R-120 | T4 | Allure Artifact Verification and Save Flags |
| R-121 | T4 | Overwrite File for Port Configuration (-w flag) |
| R-122 | T4 | Parallel Sessions Within Same Stage |
| R-123 | T4 | LoadBalance Policy Rate Control |
| R-124 | T4 | IncreasingLoadBalance Ramp-Up Test |
| R-125 | T4 | Count Policy Capping Transaction Count |
| R-126 | T4 | Timeout Policy Stopping Long-Running Consumer |
| R-127 | T4 | MockerCommand ChangeActionStub at Runtime |
| R-128 | T4 | S3 Storage Configuration |
| R-129 | T4 | Prometheus Collector with CollectionRange |
| R-130 | T4 | Template Oracle Workflow Validation |
| R-131 | T5 | Six-Session Hermetic-Percentage Choreography with Mixed Delays (T5) |
| R-132 | T5 | Five-Session Kafka+HTTP Mixed Protocol Hermetic Test (T5) |
| R-133 | T5 | Dynamic Cases Ã— Overwrite Matrix (12 Combinations) (T5) |
| R-134 | T5 | AdvancedLoadBalance Multi-Stage Rate Profile (T5) |
| R-135 | T5 | Exit Code Interpretation Matrix Across 5 Session Outcomes (T5) |
| R-136 | T5 | RunUntilStage Partial Execution with Stage Skipping (T5) |
| R-137 | T5 | StorageMetaData FullPath vs RelativePath in FromFileSystem (T5) |
| R-138 | T5 | JwtAuth Transaction with Custom Claims (T5) |
| R-139 | T5 | Deserializer Chain â€” JSON Transaction Output + MessagePack Consumer (T5) |
| R-140 | T5 | Parallel Publisher + Consumer with Stage Ordering (T5) |
| R-141 | T5 | Seven-Session Orchestration with Category Filters (-I flag) (T5) |
| R-142 | T5 | Chunk Publisher with ChunkSize and Consumer Correlation (T5) |
| R-143 | T5 | DataFilter Body + MetaData Transformation (T5) |
| R-144 | T5 | Serialize/Deserialize Round-Trip with SpecificType (T5) |
| R-145 | T5 | Three-Overwrite-File Environment Promotion Test (T5) |
| R-146 | T5 | Hermetic Percentage + Fixed Count Double Guard on 10-Session YAML (T5) |
| R-147 | T5 | Allure Links + StatusesToReport Filtering (T5) |
| R-148 | T5 | CLI -r Overwrite-Argument Runtime Value (T5) |
| R-149 | T5 | Parallel Datasource Iteration with Parallel{Parallelism:N} (T5) |
| R-150 | T5 | Full Regression Harness â€” 8-Session, 3-Protocol, 4-Assertion, 2-Overwrite (T5) |

## Category X - Failure forensics (multi-bug)

| ID | Tier | Title |
|---|---|---|
| X-101 | T3 | TransactionData + Missing DataSourceNames Double Fault |
| X-102 | T3 | Runtime Image Mocker Crash on HTTP Start |
| X-103 | T3 | HttpStatus Vacuous Pass â€” Zero Outputs |
| X-104 | T3 | Leading-Slash Route 404 |
| X-105 | T3 | Missing QaaS.Common.Assertions Package â†’ FTL |
| X-106 | T3 | CWD Trap â€” Config File Not Found |
| X-107 | T3 | Redis Controller Not Configured â€” MockerCommands Timeout |
| X-108 | T3 | Verify Step Commented Out â€” Vacuous Exit 0 |
| X-109 | T3 | Port Contract Violation â€” Probe on Different Port Than Mocker |
| X-110 | T3 | RabbitMQ Topology Missing â€” No Exchange Found |
| X-111 | T4 | Mixed-Case Route 404 + Vacuous HttpStatus Green |
| X-112 | T4 | Silent Key Typo in AssertionConfiguration |
| X-113 | T4 | Version Mis-Alignment â€” NU1102 on Common.Generators |
| X-114 | T4 | Split Verify Steps â€” Mocker Dead Before Runner Runs |
| X-115 | T4 | Dockerfile Trailing Comment on FROM â†’ Parse Error |
| X-116 | T4 | Internal Dependency Port Collision â€” Compose Bind Failure |
| X-117 | T4 | BOM in YAML Config â€” Silent Parse Failure |
| X-118 | T4 | CRLF Line Endings in Container Shell Script â€” Crash on Start |
| X-119 | T4 | Multi-Bug: Wrong Storage Shape + Missing DataSourceNames |
| X-120 | T4 | Hook Compiled But Not Discovered â€” Wrong Assembly in csproj |
| X-121 | T4 | Hermetic Guard on Wrong OutputName â€” Passes Despite No Real Traffic |
| X-122 | T4 | NuGet Feed with Unresolved %VAR% Environment Variable |
| X-123 | T4 | Template Version Mismatch â€” Scaffold Produces Outdated csproj |
| X-124 | T4 | Mocker Stub TransactionData + Probe Wrong Port â€” Two-Bug Stack |
| X-125 | T4 | allure-results Missing â€” Verify Cmd Not Copying Output Directory |
| X-126 | T4 | RabbitMQ Auth Failure â€” Wrong vhost in Runner Config |
| X-127 | T4 | HttpStatus + Wrong OutputNames List â€” Assertion Broken on Null |
| X-128 | T4 | Exit -532462766 from Missing Common.Probes Package |
| X-129 | T4 | Redis Container Mapped to Host â€” Bind Collision + Mocker Unreachable |
| X-130 | T4 | Log Says "Controller Ready" But Real Log Format Differs â€” False Confidence |
| X-131 | T5 | Triple Silent Failure â€” Vacuous HttpStatus + Typo'd Hermetic Key + Wrong OutputName |
| X-132 | T5 | Vacuous HttpStatus + Count Guard on Orphaned Output + Route Double-Slash |
| X-133 | T5 | Mixed-Case Route + Vacuous Hermetic + Silently-Ignored Processor Key |
| X-134 | T5 | Multi-Bug: FTL from Two Missing Packages + Vacuous Pass on Third Assertion |
| X-135 | T5 | Hermetic Math Error â€” Percentage Guard Set to 0 |
| X-136 | T5 | RabbitMQ Exchange Missing + HttpStatus Vacuous + Port Contract Off-by-One |
| X-137 | T5 | Dockerfile Trailing Comment + Wrong Base Image â€” Build Fails Then Would Crash |
| X-138 | T5 | Silent Typo in ProcessorConfiguration Key + Missing DataSourceNames + Vacuous Hermetic |
| X-139 | T5 | Compose Port Collision + Redis Controller Mismatch + Missing Package FTL |
| X-140 | T5 | Stale Template + Wrong Storages Shape + Vacuous HttpStatus â€” Full Scaffold Forensics |
| X-141 | T5 | Four-Bug Stack â€” Leading Slash + Case Route + TransactionData + Vacuous Guard |
| X-142 | T5 | Allure-Results JSON Broken + Session Data Missing â€” Evidence of Null-Output Cascade |
| X-143 | T5 | hermetic Guard ExpectedCount Correct But OutputNames Targets HttpStatus Output â€” Guard is Structural No-Op |
| X-144 | T5 | Log-Says-Success-But-Assert-Failed Paradox â€” Mocker Returns 200 But Body Check Fails |
| X-145 | T5 | Port Contract: Runner Uses Different Port Than Mocker, HttpStatus Vacuous |
| X-146 | T5 | CWD Trap + Vacuous Hermetic + CRLF Verify Script â€” Three Environmental Failures |
| X-147 | T5 | Green Run Proven Wrong â€” HttpStatus Vacuous + Wrong StatusCode Key + Typo'd Output |
| X-148 | T5 | Compose Redis Internal Mapping + Controller ServerName Blank + Vacuous HttpStatus |
| X-149 | T5 | NU1102 + Stale Storages + Missing Topology â€” Full Green-Field Failure Stack |
| X-150 | T5 | Ultimate Green-Run Forensics â€” Five Stacked Silent Failures, Exit 0 |

## Category Z - Impossible integration (all-T5)

| ID | Tier | Title |
|---|---|---|
| Z-101 | T5 | Multi-Protocol Choreography â€” HTTP Ingress â†’ Rabbit Fan-out â†’ Redis State â†’ HTTP Egress |
| Z-102 | T5 | Chaos Engineering â€” RabbitMQ Broker Restart Mid-Suite with Hermetic Recovery |
| Z-103 | T5 | Data-Integrity Marathon â€” 10k Records with Exactly-Once, Ordering, and Decimal Precision |
| Z-104 | T5 | Regression Archaeology â€” Previously-Green Allure Report vs Now-Failing Run |
| Z-105 | T5 | Zero-Downtime Config Swap via Redis Controller Under Load |
| Z-106 | T5 | Contract-First from OpenAPI Spec â€” Derive Full Runner Suite with Drift Checks |
| Z-107 | T5 | Migration Parity â€” v1 vs v2 Side-by-Side with Divergence Mapping |
| Z-108 | T5 | HMAC Signing Chain + Token Refresh Mid-Session |
| Z-109 | T5 | Airgapped CI End-to-End â€” Offline Feed + Image Save/Load + Compose + Run + Allure |
| Z-110 | T5 | Test-the-Tests â€” Find All Vacuous Passes in a Flawed Existing Suite and Repair |
| Z-111 | T5 | Self-Verifying Deliverable â€” Template Oracle + Live Gate + Completion Gate Evidence |
| Z-112 | T5 | Kafka Exactly-Once Ordering Guarantee with Dead-Letter Lane |
| Z-113 | T5 | Redis Controller Zero-Downtime Swap Under Continuous Load â€” Race-Condition Proof |
| Z-114 | T5 | Consumer Exactly-Once with Dead-Letter Retry and Idempotency Proof |
| Z-115 | T5 | Docker Mocker with Custom Processor + Chaos Probe + Allure Collection |
| Z-116 | T5 | Cross-Broker Parity â€” RabbitMQ vs Kafka Same SUT with Output Equivalence Proof |
| Z-117 | T5 | OpenAPI Contract Compliance + Semantic Drift Detection Between Spec Versions |
| Z-118 | T5 | HMAC + JWT Rotation Within Single Session â€” Full Auth-Resource-Refresh Flow |
| Z-119 | T5 | Decimal-Precision Financial Marathon â€” 1000 Ledger Entries, 4dp, No Rounding |
| Z-120 | T5 | Airgap Compose + Allure + Offline Report Generation â€” CI Evidence Package |
| Z-121 | T5 | Version-Bump Regression â€” Package Upgrade Broke Behavior, Find and Fix |
| Z-122 | T5 | Mocker Processor Chain â€” Three Sequential Processors on Same Stub |
| Z-123 | T5 | Multi-Tenant Session Isolation â€” N Parallel Sessions, No Cross-Contamination |
| Z-124 | T5 | Flawed Suite Repair â€” Vacuous HttpStatus + Missing Guards + Silently-Ignored Keys |
| Z-125 | T5 | Proto/gRPC Contract â†’ Derive Full Kafka Consumer Suite |
| Z-126 | T5 | Broker Restart Chaos with Hermetic Count Guard â€” RabbitMQ Mid-Consumer Drain |
| Z-127 | T5 | Performance SLA Window â€” Latency Assertion + Count Assertion Simultaneously |
| Z-128 | T5 | Redis State Verification Across Session Boundaries â€” Multi-Stage State Machine |
| Z-129 | T5 | Fan-Out with Convergence â€” N Publishers, M Consumers, All-Arrived Proof |
| Z-130 | T5 | Side-by-Side v1/v2 Migration with Divergence Mapping and Parity Report |
| Z-131 | T5 | Full-Stack Payment Flow â€” Auth â†’ Charge â†’ Webhook Notify, End-to-End |
| Z-132 | T5 | Self-Healing Test â€” Probe-Driven Retry + Assertion on Eventual Consistency |
| Z-133 | T5 | Airgap + Offline NuGet + Docker Save/Load + Compose + Run â€” Scripted CI Evidence |
| Z-134 | T5 | Proto/gRPC Contract â†’ Kafka Consumer Suite with Field-Level Assertions |
| Z-135 | T5 | Regression Archaeology with Allure Timeline Diff â€” Find the Regression Commit |
| Z-136 | T5 | HMAC Signing Chain Across Three Cascaded HTTP Calls â€” Stateful Signature Tracking |
| Z-137 | T5 | Chaos: RabbitMQ Restart Mid-Consumer With Exactly-Once Proof |
| Z-138 | T5 | Decimal-Precision Financial Processing â€” No Float Drift in 2000 Calculations |
| Z-139 | T5 | Zero-Downtime Redis Controller Config Swap â€” Dual-Behavior Proof Under Traffic |
| Z-140 | T5 | Multi-Protocol Choreography â€” HTTP â†’ Kafka â†’ Redis â†’ HTTP Egress Asserted |
| Z-141 | T5 | Test-the-Tests â€” Find All Vacuous Passes in Provided 10-Session Suite |
| Z-142 | T5 | Message Format Migration Parity â€” Avro v1 vs JSON v2 Consumer Equivalence |
| Z-143 | T5 | 10k Exactly-Once + Ordering + Decimal Precision â€” The Data-Integrity Trifecta |
| Z-144 | T5 | Custom Hook Chain â€” Generator â†’ Processor â†’ Assertion in Full Pipeline |
| Z-145 | T5 | Full Airgap CI Pipeline â€” Feed + Compose + Run + Allure + Completion Gate |
| Z-146 | T5 | HTTP Order â†’ Rabbit Fulfillment â†’ Redis Inventory â†’ HTTP Status â€” Full Commerce Flow |
| Z-147 | T5 | Broker Chaos â€” Stub-Swap Under Load with Count Guard Enforcement |
| Z-148 | T5 | Self-Verifying Template Oracle + Live Gate â€” Evidence-First Deliverable |
| Z-149 | T5 | Cross-Protocol Regression â€” HTTP SLA + Rabbit Throughput Simultaneously Asserted |
| Z-150 | T5 | Final Boss â€” All Capabilities Stacked: Analysis + Planning + Runner + Mocker + Hooks + Docker + Diagnose + Docs |

