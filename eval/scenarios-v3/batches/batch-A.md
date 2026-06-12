# Batch A — Advanced Analysis Scenarios (A-101..A-150)
# Tier mix: T3×10 (A-101..110) | T4×20 (A-111..130) | T5×20 (A-131..150)
# Deliverables: sut-profile.md / runtime-config.md / coverage-gaps.md / README.md
# MOCK_REQUIRED: n/a (analysis only) for all scenarios
# Skills: analyze-sut-repo · analyze-helm-k8s · analyze-existing-tests

---

### A-101: ASP.NET Minimal-API Route Extraction
Tier: T3
Goal: Extract all HTTP routes, HTTP methods, and handler return-types from a single-project C# Minimal-API SUT and produce sut-profile.md with file:line citations.
Provided artifacts:
```
order-api/
  Program.cs          (32 lines)
  OrderHandler.cs     (28 lines)
  Models/OrderDto.cs  (18 lines)
```
Program.cs:14  `app.MapGet("/orders", OrderHandler.GetAll);`
Program.cs:15  `app.MapPost("/orders", OrderHandler.Create);`
Program.cs:16  `app.MapGet("/orders/{id}", OrderHandler.GetById);`
OrderDto.cs:5  `public record OrderDto(int Id, string CustomerId, decimal Total, OrderStatus Status);`
OrderDto.cs:9  `public enum OrderStatus { Pending, Shipped, Delivered }`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- Minimal-API registrations are in Program.cs, not on controller classes; model must not confuse with MapControllers.
- Enum type on DTO must be extracted, not guessed.
- Line-number discipline: file is 32 lines; fabricated citations must fit.
Expected findings:
- GET /orders → OrderHandler.GetAll (Program.cs:14)
- POST /orders → OrderHandler.Create (Program.cs:15)
- GET /orders/{id} → OrderHandler.GetById (Program.cs:16)
- DTO fields: Id:int, CustomerId:string, Total:decimal, Status:OrderStatus (OrderDto.cs:5)
- Enum values: Pending, Shipped, Delivered (OrderDto.cs:9)
Verify (mechanical):
- sut-profile.md exists with `## Protocols`, `## Message schemas/DTOs`, `## Env config` sections.
- Every fact line contains `(file:line)` with line ≤32 for Program.cs.
- No fabricated route or field present.
Rubric (graded):
- Citation discipline (0–10): every fact has `(file:line)`, line numbers within file bounds → 10; any missing or out-of-range → 0.
- Surface completeness (0–10): all 3 routes + DTO + enum present → 10; missing ≥1 → 5; missing ≥3 → 0.
- No invention (0–10): zero fields not present in artifact → 10; any invented → 0.
Solution sketch: Grep Program.cs for MapGet/MapPost, read OrderDto.cs for record fields and enum, populate sut-profile.md sections.

---

### A-102: appsettings.json Env-Config Extraction
Tier: T3
Goal: Read appsettings.json and appsettings.Production.json and produce an effective-config table showing which keys are overridden per environment.
Provided artifacts:
```
notification-svc/
  appsettings.json              (22 lines)
  appsettings.Production.json   (12 lines)
  appsettings.Development.json  (8 lines)
```
appsettings.json:5       `"SmtpHost": "localhost"`
appsettings.json:6       `"SmtpPort": 25`
appsettings.json:7       `"MaxRetries": 3`
appsettings.Production.json:4  `"SmtpHost": "smtp.internal.corp"`
appsettings.Production.json:5  `"SmtpPort": 587`
appsettings.Development.json:4 `"SmtpHost": "mailhog.local"`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s16
Hard because:
- Must distinguish base vs override layers without conflating them.
- MaxRetries not overridden in any env-specific file; must correctly report base value only.
- Open question: runtime ASPNETCORE_ENVIRONMENT value unknown from static files alone.
Expected findings:
- SmtpHost: Development=mailhog.local, Production=smtp.internal.corp, base=localhost (file:line each)
- SmtpPort: Production=587, base=25 (not overridden in Development)
- MaxRetries: base=3, no override in either env file
- Open question #1: ASPNETCORE_ENVIRONMENT runtime value unknown
Verify (mechanical):
- runtime-config.md has effective-config table with ≥3 rows.
- Each row cites source file:line.
- MaxRetries row shows base=3 with "no override" note.
Rubric (graded):
- Citation discipline (0–10): all values cite correct file:line → 10.
- Layer separation (0–10): base vs per-env distinguished in every row → 10; any merge without labelling → 3.
- Open-question discipline (0–10): ASPNETCORE_ENVIRONMENT listed as open question, value not invented → 10; value invented → 0.
Solution sketch: Read all three appsettings files, build three-column table (key | base | Dev | Prod), mark absent overrides explicitly, emit open question for runtime env selector.

---

### A-103: Single Helm Chart Port Extraction
Tier: T3
Goal: Extract container port, service port, and any broker-address env vars from a single Helm chart and produce runtime-config.md.
Provided artifacts:
```
helm/inventory-svc/
  Chart.yaml          (8 lines)
  values.yaml         (20 lines)
  templates/
    deployment.yaml   (38 lines)
    service.yaml      (18 lines)
```
values.yaml:7        `replicaCount: 2`
values.yaml:10       `service: { port: 8080, targetPort: 8080 }`
values.yaml:14       `env: { RABBIT_HOST: "rabbitmq.default.svc", RABBIT_PORT: "5672" }`
deployment.yaml:22   `containerPort: {{ .Values.service.targetPort }}`
deployment.yaml:28   `value: {{ .Values.env.RABBIT_HOST }}`
deployment.yaml:29   `value: {{ .Values.env.RABBIT_PORT }}`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- containerPort is a template expression; must resolve via values.yaml, not read literally.
- CAUTION must be emitted: rendered without `helm template`, overlay values may differ.
- No secrets present; must not flag secretKeyRef where none exists.
Expected findings:
- containerPort: 8080 (values.yaml:10 → deployment.yaml:22)
- service port: 8080 (values.yaml:10)
- RABBIT_HOST: rabbitmq.default.svc (values.yaml:14, deployment.yaml:28)
- RABBIT_PORT: 5672 (values.yaml:14, deployment.yaml:29)
- CAUTION: helm not run; overlay values may differ
Verify (mechanical):
- runtime-config.md exists with all 4 env/port entries.
- CAUTION note present.
- No invented env vars.
Rubric (graded):
- Citation discipline (0–10): every value traces to values.yaml:line → 10.
- Template resolution (0–10): containerPort resolved to 8080, not emitted as `{{ .Values... }}` → 10; literal template emitted → 0.
- CAUTION discipline (0–10): CAUTION note present → 10; absent → 0.
Solution sketch: Read values.yaml, resolve template expressions manually, emit effective config table with CAUTION.

---

### A-104: Minimal QaaS YAML Test Inventory
Tier: T3
Goal: Read two existing QaaS Runner YAML files and produce a test-inventory.md with all 6 required fields per row plus file:line citations.
Provided artifacts:
```
tests/
  smoke-orders.qaas.yaml   (45 lines)
  smoke-health.qaas.yaml   (18 lines)
```
smoke-orders.qaas.yaml:3   `Name: CreateOrder_ReturnsCreated`
smoke-orders.qaas.yaml:12  `Route: orders`
smoke-orders.qaas.yaml:14  `Method: POST`
smoke-orders.qaas.yaml:31  `HttpStatus: { StatusCode: 201, OutputNames: [resp] }`
smoke-health.qaas.yaml:3   `Name: Health_Returns200`
smoke-health.qaas.yaml:10  `Route: health`
smoke-health.qaas.yaml:15  `HttpStatus: { StatusCode: 200, OutputNames: [hresp] }`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s09, s10, s13
Hard because:
- Both rows must include all 6 inventory fields; mocked_deps must be "none" if absent.
- integration_surface must note HTTP + route name from YAML, not inferred.
- Citation line numbers must not exceed file line counts (45 and 18).
Expected findings:
- Row 1: CreateOrder_ReturnsCreated | orders-api | POST body | none | HttpStatus 201 | HTTP POST /orders (smoke-orders.qaas.yaml:3)
- Row 2: Health_Returns200 | health endpoint | none | none | HttpStatus 200 | HTTP GET /health (smoke-health.qaas.yaml:3)
- No gaps: both surfaces have tests (Covered section)
Verify (mechanical):
- test-inventory.md has exactly 2 rows, each with all 6 fields + citation.
- coverage-gaps.md ## Covered section lists both surfaces.
Rubric (graded):
- Citation discipline (0–10): both rows have `(file:line)` within bounds → 10; any missing → 0.
- Field completeness (0–10): all 6 fields present per row → 10; missing field → 5 per missing.
- Gap classification (0–10): no false gaps reported → 10; spurious gap → 5.
Solution sketch: Parse both YAML files field by field, populate inventory table rows, compare against SUT surface (none provided — note as open question), emit Covered section.

---

### A-105: RabbitMQ Consumer Endpoint Extraction
Tier: T3
Goal: Extract queue name, exchange, routing key, and message type from a single C# MassTransit consumer and produce sut-profile.md publish/consume section.
Provided artifacts:
```
billing-worker/
  Consumers/InvoiceConsumer.cs  (34 lines)
  Messages/InvoiceRequest.cs    (14 lines)
  Program.cs                    (24 lines)
```
Program.cs:14            `cfg.ReceiveEndpoint("invoice-queue", e => { e.ConfigureConsumer<InvoiceConsumer>(ctx); });`
InvoiceConsumer.cs:8     `public class InvoiceConsumer : IConsumer<InvoiceRequest>`
InvoiceConsumer.cs:12    `public async Task Consume(ConsumeContext<InvoiceRequest> ctx)`
InvoiceRequest.cs:4      `public record InvoiceRequest(Guid OrderId, decimal Amount, string Currency);`
InvoiceRequest.cs:9      `// Currency: ISO-4217 code, e.g. "USD"`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- Exchange and routing key are not declared in this snippet; must emit as open questions, not invent defaults.
- Message schema must list all 3 fields with types.
- Currency comment is documentation, not a constraint; must not become an assertion.
Expected findings:
- Queue: invoice-queue (Program.cs:14)
- Consumer type: InvoiceConsumer<InvoiceRequest> (InvoiceConsumer.cs:8)
- Message schema: OrderId:Guid, Amount:decimal, Currency:string (InvoiceRequest.cs:4)
- Open question #1: exchange name — not declared in provided files
- Open question #2: routing key — not declared in provided files
Verify (mechanical):
- sut-profile.md ## Publish/consume points lists invoice-queue with citation.
- ## Message schemas/DTOs lists all 3 fields.
- Open questions section has ≥2 entries.
Rubric (graded):
- Citation discipline (0–10): queue name and schema fields each cite file:line → 10.
- No invention (0–10): exchange/routing-key not fabricated → 10; invented → 0.
- Open-question discipline (0–10): ≥2 open questions for exchange and routing key → 10; missing → 5 each.
Solution sketch: Grep Program.cs for ReceiveEndpoint, read InvoiceConsumer.cs for generic type, read InvoiceRequest.cs for record fields, emit open questions for missing topology.

---

### A-106: gRPC Proto Contract Extraction
Tier: T3
Goal: Extract all RPC method signatures, request/response message fields, and service name from a single .proto file and produce the sut-profile.md gRPC section.
Provided artifacts:
```
pricing-svc/
  proto/pricing.proto     (38 lines)
  src/PricingService.cs   (42 lines)
```
pricing.proto:5   `service PricingService {`
pricing.proto:6   `  rpc GetPrice (PriceRequest) returns (PriceResponse);`
pricing.proto:7   `  rpc ListPrices (ListRequest) returns (stream PriceResponse);`
pricing.proto:11  `message PriceRequest { string sku = 1; string currency = 2; }`
pricing.proto:15  `message PriceResponse { string sku = 1; double price = 2; string currency = 3; }`
pricing.proto:19  `message ListRequest { repeated string skus = 1; }`
PricingService.cs:8  `MapGrpcService<PricingServiceImpl>();`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- Server-streaming RPC (returns stream) must be distinguished from unary.
- Field numbers are proto wire format; model must report field names + types, not wire numbers alone.
- MapGrpcService confirms registration but does not add new routes; must not double-count.
Expected findings:
- Service: PricingService (pricing.proto:5)
- RPC GetPrice: unary, PriceRequest→PriceResponse (pricing.proto:6)
- RPC ListPrices: server-streaming, ListRequest→stream PriceResponse (pricing.proto:7)
- PriceRequest fields: sku:string, currency:string (pricing.proto:11)
- PriceResponse fields: sku:string, price:double, currency:string (pricing.proto:15)
Verify (mechanical):
- sut-profile.md ## Protocols section lists gRPC with both RPCs cited.
- Streaming flag noted on ListPrices.
- No HTTP routes invented.
Rubric (graded):
- Citation discipline (0–10): each RPC and each message field cites proto:line → 10.
- Streaming accuracy (0–10): ListPrices flagged as server-streaming → 10; missed → 0.
- No invention (0–10): no HTTP routes or extra RPCs fabricated → 10; invented → 0.
Solution sketch: Parse pricing.proto top-to-bottom, classify each rpc as unary vs streaming, enumerate message fields with types, confirm registration via PricingService.cs:8.

---

### A-107: OpenAPI Spec vs Handler Code Drift Check
Tier: T3
Goal: Compare an OpenAPI spec against the actual controller to identify drifted routes, status codes, or schema fields and produce sut-profile.md with drift findings cited from both sources.
Provided artifacts:
```
catalog-api/
  openapi.yaml            (52 lines)
  Controllers/ItemsController.cs  (44 lines)
```
openapi.yaml:12   `get: /items/{id}  → 200 ItemDto, 404 ErrorDto`
openapi.yaml:20   `post: /items      → 201 ItemDto`
openapi.yaml:31   `delete: /items/{id} → 204`
ItemsController.cs:10  `[HttpGet("{id}")] public IActionResult Get(int id) => id > 0 ? Ok(...) : NotFound();`
ItemsController.cs:18  `[HttpPost] public IActionResult Create([FromBody] CreateItemDto dto) => Created(...);`
ItemsController.cs:26  `// DELETE endpoint removed in v2 — method deleted`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- DELETE is declared in OpenAPI but the handler method no longer exists — code wins.
- Must cite both spec line and code line for each drift item, not just one source.
- "Code wins" rule must be stated explicitly in output.
Expected findings:
- GET /items/{id}: aligned — spec 200/404, code returns Ok/NotFound (openapi.yaml:12, ItemsController.cs:10)
- POST /items: aligned — spec 201, code Created (openapi.yaml:20, ItemsController.cs:18)
- DELETE /items/{id}: DRIFT — spec declares 204 (openapi.yaml:31), no handler in code (ItemsController.cs:26 comment)
- "Code wins" ruling: DELETE surface absent from SUT; do not plan test for it
Verify (mechanical):
- sut-profile.md has drift section with DELETE flagged.
- "Code wins" ruling present.
- Both spec:line and code:line cited for drift item.
Rubric (graded):
- Citation discipline (0–10): each finding cites both openapi.yaml:line and code:line → 10; single-source only → 5.
- Drift detection (0–10): DELETE drift identified with code-wins ruling → 10; missed → 0.
- No false positives (0–10): GET and POST not flagged as drifted → 10; false positive → 5.
Solution sketch: Enumerate spec routes, cross-reference each against controller methods via grep, flag missing handlers as drift, emit code-wins ruling.

---

### A-108: NUnit Test Inventory with Gap Diff
Tier: T3
Goal: Read a NUnit test class and a sut-profile.md and produce test-inventory.md + coverage-gaps.md classifying each gap as create/repair/update.
Provided artifacts:
```
tests/
  ShippingServiceTests.cs  (60 lines)
qaas-analysis/
  sut-profile.md           (surface catalog — 3 HTTP endpoints + 1 queue)
```
ShippingServiceTests.cs:12  `[Test] public void Ship_ValidOrder_ReturnsShipped() { ... }`
ShippingServiceTests.cs:24  `[Test] public void Ship_MissingAddress_Returns400() { ... }`
ShippingServiceTests.cs:40  `[Test] public void Track_ValidId_ReturnsTracking() { ... }`
sut-profile.md surface list: POST /ship, POST /ship (error path), GET /track/{id}, queue shipment.updates
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s09, s10, s13
Hard because:
- NUnit tests lack explicit route info; must infer SUT surface from test method naming + sut-profile cross-reference.
- Queue shipment.updates has no matching test; must classify as "create", not "repair".
- Inventory rows must still cite NUnit file:line even though format differs from QaaS YAML.
Expected findings:
- Test row: Ship_ValidOrder_ReturnsShipped → POST /ship (ShippingServiceTests.cs:12)
- Test row: Ship_MissingAddress_Returns400 → POST /ship error path (ShippingServiceTests.cs:24)
- Test row: Track_ValidId_ReturnsTracking → GET /track/{id} (ShippingServiceTests.cs:40)
- Gap CREATE: queue shipment.updates — no test in NUnit class
Verify (mechanical):
- test-inventory.md has 3 rows each with 6 fields + citation.
- coverage-gaps.md ## Create section has shipment.updates entry.
- No repair or update entries (existing tests not broken per artifacts).
Rubric (graded):
- Citation discipline (0–10): all 3 rows cite ShippingServiceTests.cs:line → 10.
- Gap classification (0–10): shipment.updates classified as "create" (not just "missing") → 10; wrong classification → 3.
- No over-classification (0–10): no spurious repair/update gaps → 10; any false gap → 5.
Solution sketch: Parse NUnit methods, match to sut-profile.md surfaces by name inference, emit inventory, diff against 4-surface catalog, flag queue as create gap.

---

### A-109: Docker Compose Port and Env Extraction
Tier: T3
Goal: Extract all exposed ports, container names, and env vars from a docker-compose.yaml and produce runtime-config.md.
Provided artifacts:
```
infra/
  docker-compose.yaml  (55 lines)
```
docker-compose.yaml:8   `services:`
docker-compose.yaml:9   `  api: { image: myorg/api:latest, ports: ["8080:8080"], environment: [DB_HOST=postgres, DB_PORT=5432] }`
docker-compose.yaml:18  `  worker: { image: myorg/worker:latest, environment: [RABBIT_HOST=rabbitmq, RABBIT_PORT=5672] }`
docker-compose.yaml:28  `  postgres: { image: postgres:16, ports: ["5432:5432"] }`
docker-compose.yaml:36  `  rabbitmq: { image: rabbitmq:3-management, ports: ["5672:5672","15672:15672"] }`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- Compose resolves service names as hostnames (DB_HOST=postgres refers to the compose service, not an external host); this must be noted.
- Two rabbitmq ports (5672 and 15672) have different purposes; must distinguish AMQP vs management.
- worker service has no exposed host ports; must not fabricate one.
Expected findings:
- api: host:8080→container:8080, env DB_HOST=postgres, DB_PORT=5432 (docker-compose.yaml:9)
- worker: no exposed ports, env RABBIT_HOST=rabbitmq, RABBIT_PORT=5672 (docker-compose.yaml:18)
- rabbitmq: AMQP 5672, management UI 15672 (docker-compose.yaml:36)
- Note: DB_HOST=postgres resolves to compose service hostname, not external
Verify (mechanical):
- runtime-config.md lists all 4 services with ports and env vars.
- compose-hostname note present for DB_HOST.
- worker listed with "no exposed host ports".
Rubric (graded):
- Citation discipline (0–10): each service entry cites docker-compose.yaml:line → 10.
- Hostname semantics (0–10): compose-service hostname note present → 10; absent → 0.
- Port purpose (0–10): rabbitmq ports labelled AMQP vs management → 10; unlabelled → 5.
Solution sketch: Parse docker-compose.yaml services block, extract ports and environment arrays, annotate compose-DNS semantics, classify rabbitmq ports by well-known numbers.

---

### A-110: Feature-Flag-Gated Route Detection
Tier: T3
Goal: Identify which HTTP routes are behind a feature flag, report the flag name and default value, and mark gated routes as conditional in sut-profile.md.
Provided artifacts:
```
promotions-api/
  Program.cs              (28 lines)
  FeatureFlags.cs         (14 lines)
  Controllers/PromoController.cs  (36 lines)
```
Program.cs:10   `app.MapGet("/promotions", PromoController.List);`
Program.cs:11   `if (featureFlags.IsEnabled("flash-sale")) { app.MapPost("/promotions/flash", PromoController.Flash); }`
FeatureFlags.cs:6  `public static readonly Dictionary<string,bool> Defaults = new() { { "flash-sale", false }, { "loyalty", true } };`
PromoController.cs:8   `[HttpGet("/promotions/loyalty")] public IActionResult Loyalty() => ...`
PromoController.cs:22  `// guarded by "loyalty" flag — checked in middleware`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- flash-sale route is conditionally registered at startup; model must flag it as CONDITIONAL, not always-present.
- loyalty route is always registered (attribute routing) but guarded in middleware; semantics differ — must distinguish startup-gating from runtime-gating.
- Default values must be read from FeatureFlags.cs, not assumed.
Expected findings:
- GET /promotions: unconditional (Program.cs:10)
- POST /promotions/flash: CONDITIONAL — startup-gated by flag "flash-sale" default=false (Program.cs:11, FeatureFlags.cs:6)
- GET /promotions/loyalty: registered unconditionally, runtime-gated by "loyalty" default=true (PromoController.cs:8, PromoController.cs:22, FeatureFlags.cs:6)
- Test note: flash-sale route unreachable by default — flag must be enabled to test
Verify (mechanical):
- sut-profile.md marks POST /promotions/flash as CONDITIONAL with flag name + default.
- GET /promotions/loyalty marked as runtime-gated (distinct from startup-gated).
- "unreachable by default" note present for flash-sale.
Rubric (graded):
- Citation discipline (0–10): all 3 routes cite file:line → 10.
- Gating-type accuracy (0–10): startup vs runtime gating distinguished → 10; conflated → 3.
- Default-value discipline (0–10): default=false for flash-sale sourced from FeatureFlags.cs:6 → 10; invented → 0.
Solution sketch: Grep Program.cs for conditional MapPost, read FeatureFlags.cs for defaults, grep PromoController for attribute routes + middleware comment, classify gating type per route.

---

### A-111: Polyglot C# + Node Sidecar Surface Extraction
Tier: T4
Goal: Extract all HTTP surfaces from a C# main service and a Node.js sidecar in the same repo, deduplicate shared ports, and produce a unified sut-profile.md with file:line citations from both languages.
Provided artifacts:
```
gateway-svc/
  src/                          (C# ASP.NET)
    Program.cs         (30 lines)
    Handlers/MetricsHandler.cs  (22 lines)
  sidecar/                      (Node.js Express)
    index.js           (28 lines)
    routes/admin.js    (18 lines)
```
Program.cs:12     `app.MapGet("/health", () => Results.Ok());`
Program.cs:13     `app.MapPost("/ingest", MetricsHandler.Ingest);`
MetricsHandler.cs:8  `public static IResult Ingest([FromBody] MetricBatch batch) => ...`
index.js:6        `const app = express(); app.listen(3000);`
index.js:10       `app.use('/admin', adminRouter);`
admin.js:5        `router.get('/status', (req, res) => res.json({ status: 'ok' }));`
admin.js:10       `router.post('/reload', (req, res) => { config.reload(); res.sendStatus(204); });`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- Two distinct processes on different ports (C# on unspecified port, Node on 3000); must not merge into one service.
- admin.js routes mount under /admin prefix from index.js:10; must compose paths correctly.
- MetricBatch schema comes from C# side; Node side has no schema — must not invent one for admin routes.
Expected findings:
- C# service: GET /health (Program.cs:12), POST /ingest (Program.cs:13)
- Node sidecar port 3000 (index.js:6): GET /admin/status (admin.js:5, prefix index.js:10), POST /admin/reload (admin.js:10)
- MetricBatch schema: open question (MetricsHandler.cs:8 references type but body not provided)
- Open question #1: C# service port not found in provided files
Verify (mechanical):
- sut-profile.md has two ## Protocols subsections or clearly labels C#-service vs Node-sidecar.
- /admin/status and /admin/reload listed with composed paths.
- C# port listed as open question.
Rubric (graded):
- Citation discipline (0–10): all routes cite file:line from correct language file → 10.
- Path composition (0–10): /admin prefix correctly composed for both Node routes → 10; bare /status without prefix → 0.
- Process separation (0–10): two distinct processes at distinct ports noted → 10; merged → 0.
Solution sketch: Grep C# for Map*, grep index.js for app.use + listen, grep admin.js for router.get/post, compose paths from mount + route, note open question for C# port.

---

### A-112: Env-Var Resolution Chain (appsettings → Env → Helm)
Tier: T4
Goal: Compute effective values for all configuration keys by resolving the full chain: appsettings.json defaults → OS environment overrides → Helm values → ConfigMap env injections, and produce runtime-config.md with each layer cited.
Provided artifacts:
```
payment-svc/
  appsettings.json             (18 lines)
  helm/values.yaml             (24 lines)
  helm/templates/deployment.yaml  (42 lines)
  helm/templates/configmap.yaml   (16 lines)
```
appsettings.json:6       `"PaymentGateway": "https://sandbox.pay.io"`
appsettings.json:7       `"Timeout": 30`
values.yaml:9            `env: { PAYMENT_GATEWAY: "https://prod.pay.io", TIMEOUT: "60" }`
deployment.yaml:18       `envFrom: [ configMapRef: { name: payment-config } ]`
deployment.yaml:22       `- name: PAYMENT_GATEWAY  valueFrom: { configMapKeyRef: { name: payment-config, key: gateway_url } }`
configmap.yaml:7         `data: { gateway_url: "https://staging.pay.io" }`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- Three layers override the same key: appsettings (sandbox) → Helm values (prod) → ConfigMap (staging); precedence must be determined by K8s injection order, not guessed.
- deployment.yaml:18 uses envFrom + deployment.yaml:22 uses explicit env override — explicit env takes precedence over envFrom per K8s spec; must note this rule.
- Timeout only in appsettings and values.yaml; ConfigMap does not override it — correct effective value is values.yaml:9.
Expected findings:
- PAYMENT_GATEWAY effective: staging.pay.io (configmap.yaml:7 via deployment.yaml:22 explicit envFrom override rule)
- TIMEOUT effective: 60 (values.yaml:9; not overridden by configmap)
- CAUTION: rendered without helm template — overlay values may differ (values.yaml:9 may not be final)
- Note K8s rule: explicit env block overrides envFrom for same key
Verify (mechanical):
- runtime-config.md has all three values for PAYMENT_GATEWAY traced per layer.
- K8s precedence rule explicitly stated.
- CAUTION note present.
Rubric (graded):
- Citation discipline (0–10): each layer cites exact file:line → 10; any missing → 5.
- Precedence accuracy (0–10): PAYMENT_GATEWAY resolved to staging via K8s rule → 10; wrong final value → 0.
- CAUTION discipline (0–10): CAUTION note for helm-absent render → 10; missing → 0.
Solution sketch: Read all 4 files, build layered resolution table, apply K8s precedence rule (explicit env > envFrom), emit CAUTION for unrendered templates.

---

### A-113: Umbrella Helm Chart — Subchart Values Layering
Tier: T4
Goal: Identify which configuration values are set at global scope vs subchart scope in an umbrella Helm chart, determine precedence for conflicting keys, and produce runtime-config.md.
Provided artifacts:
```
umbrella/
  Chart.yaml            (14 lines)  [dependencies: auth-svc, order-svc]
  values.yaml           (28 lines)
  charts/
    auth-svc/values.yaml   (20 lines)
    order-svc/values.yaml  (18 lines)
```
umbrella/values.yaml:5     `global: { dbHost: "db.prod.internal", dbPort: 5432 }`
umbrella/values.yaml:10    `auth-svc: { replicaCount: 2, env: { DB_HOST: "auth-db.prod" } }`
umbrella/values.yaml:16    `order-svc: { replicaCount: 1 }`
auth-svc/values.yaml:6     `env: { DB_HOST: "localhost", DB_PORT: 5432 }`
order-svc/values.yaml:5    `env: { DB_HOST: "localhost", DB_PORT: 5432 }`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- Helm precedence: parent values.yaml overrides subchart values.yaml for subchart-namespaced keys; global.* is available in subcharts but does not override subchart-specific keys by default.
- auth-svc DB_HOST: umbrella overrides to "auth-db.prod" (umbrella/values.yaml:10 > auth-svc/values.yaml:6).
- order-svc DB_HOST: no override in umbrella; effective value is subchart default "localhost" (order-svc/values.yaml:5) unless global resolution applies.
Expected findings:
- auth-svc DB_HOST effective: auth-db.prod (umbrella/values.yaml:10 overrides auth-svc/values.yaml:6)
- auth-svc DB_PORT: 5432 (auth-svc/values.yaml:6, not overridden)
- order-svc DB_HOST effective: localhost (order-svc/values.yaml:5, no umbrella override; global.dbHost not auto-injected)
- global.dbPort: 5432 — available as .Values.global.dbPort in subcharts if they reference it
- Open question #1: do subcharts reference .Values.global.dbHost in their templates?
Verify (mechanical):
- runtime-config.md has per-subchart effective-config table.
- auth-svc and order-svc rows distinguished.
- Open question about global reference present.
Rubric (graded):
- Citation discipline (0–10): each effective value traces to exact values.yaml:line → 10.
- Precedence accuracy (0–10): auth-svc DB_HOST correctly resolved to auth-db.prod → 10; order-svc not incorrectly overridden → 10 (combined).
- Open-question discipline (0–10): global reference question emitted → 10; global value silently propagated → 0.
Solution sketch: Read umbrella values.yaml global and subchart sections, read each subchart values.yaml, apply Helm parent-override-subchart rule, flag global keys as available-if-referenced, emit open question.

---

### A-114: Dead-Code Endpoint Trap
Tier: T4
Goal: Detect an HTTP endpoint that is defined in a controller but never registered in the routing pipeline and flag it as unreachable in sut-profile.md.
Provided artifacts:
```
warehouse-api/
  Program.cs              (26 lines)
  Controllers/
    StockController.cs    (48 lines)
    LegacyController.cs   (34 lines)
```
Program.cs:10   `app.MapControllers();`
Program.cs:11   `// Note: LegacyController excluded from DI — not registered`
StockController.cs:6    `[ApiController, Route("api/[controller]")]`
StockController.cs:10   `[HttpGet] public IActionResult GetAll() => Ok(_stock.GetAll());`
StockController.cs:18   `[HttpPost("{id}/reserve")] public IActionResult Reserve(int id) => ...`
LegacyController.cs:6   `[ApiController, Route("api/legacy")]`
LegacyController.cs:10  `[HttpGet("items")] public IActionResult GetItems() => ...`
LegacyController.cs:18  `// This controller is not added to services — dead code`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- MapControllers() at Program.cs:10 would normally pick up all controllers, but the comment at Program.cs:11 signals exclusion — must read startup code carefully, not assume all controllers are active.
- LegacyController.cs:18 comment confirms dead code; model must cite both lines.
- StockController routes must still be listed as reachable.
Expected findings:
- REACHABLE: GET /api/stock (StockController.cs:10, Program.cs:10)
- REACHABLE: POST /api/stock/{id}/reserve (StockController.cs:18)
- DEAD CODE: GET /api/legacy/items — LegacyController not registered in DI (Program.cs:11, LegacyController.cs:18)
- Recommendation: do not author tests for /api/legacy/items
Verify (mechanical):
- sut-profile.md has DEAD CODE section with LegacyController entry.
- Both Program.cs:11 and LegacyController.cs:18 cited for dead-code finding.
- "Do not test" note present.
Rubric (graded):
- Citation discipline (0–10): dead-code finding cites both Program.cs and LegacyController.cs lines → 10; single source → 5.
- Dead-code detection (0–10): LegacyController flagged as unreachable → 10; omitted → 0.
- No false negatives (0–10): StockController routes listed as reachable → 10; incorrectly flagged → 0.
Solution sketch: Grep Program.cs for MapControllers and exclusion comments, read both controllers for attribute routes, cross-reference DI registration, flag unregistered controller with dual citation.

---

### A-115: Multi-Queue RabbitMQ Topology from Code
Tier: T4
Goal: Extract the full broker topology (exchanges, queues, bindings, routing keys) from C# code using direct AMQP client calls and produce sut-profile.md publish/consume section with file:line citations.
Provided artifacts:
```
events-svc/
  Infrastructure/
    BrokerSetup.cs   (54 lines)
    Publisher.cs     (30 lines)
    Subscriber.cs    (36 lines)
```
BrokerSetup.cs:12   `channel.ExchangeDeclare("orders.events", ExchangeType.Topic, durable: true);`
BrokerSetup.cs:18   `channel.QueueDeclare("orders.created", durable: true, ...);`
BrokerSetup.cs:22   `channel.QueueBind("orders.created", "orders.events", "order.created");`
BrokerSetup.cs:28   `channel.QueueDeclare("orders.failed", durable: true, ...);`
BrokerSetup.cs:32   `channel.QueueBind("orders.failed", "orders.events", "order.failed");`
Publisher.cs:14     `channel.BasicPublish("orders.events", "order.created", ...);`
Subscriber.cs:10    `channel.BasicConsume("orders.created", autoAck: false, ...);`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- Exchange type (Topic) affects routing semantics; must be noted, not omitted.
- Two queues bind to the same exchange with different routing keys; both bindings must be captured.
- autoAck: false on consumer affects test design — must flag in notes, not silently omit.
Expected findings:
- Exchange: orders.events, type=Topic, durable (BrokerSetup.cs:12)
- Queue orders.created bound to orders.events with routing key order.created (BrokerSetup.cs:18,22)
- Queue orders.failed bound to orders.events with routing key order.failed (BrokerSetup.cs:28,32)
- Publisher: publishes to orders.events / order.created (Publisher.cs:14)
- Consumer: consumes orders.created, autoAck=false (Subscriber.cs:10)
Verify (mechanical):
- sut-profile.md ## Publish/consume points lists both queues with exchange + routing key.
- Exchange type=Topic noted.
- autoAck=false noted.
Rubric (graded):
- Citation discipline (0–10): each queue + binding cites BrokerSetup.cs:line → 10.
- Exchange-type accuracy (0–10): Topic type noted → 10; omitted → 0.
- Consumer-flag discipline (0–10): autoAck=false noted → 10; silently omitted → 0.
Solution sketch: Read BrokerSetup.cs for ExchangeDeclare/QueueDeclare/QueueBind, read Publisher.cs for BasicPublish, read Subscriber.cs for BasicConsume, map full topology with flags.

---

### A-116: DTO Schema Extraction — Nullable, Enum, Inheritance
Tier: T4
Goal: Extract the complete DTO schema hierarchy (base class + derived + nullable fields + enum types) and produce the sut-profile.md Message schemas/DTOs section.
Provided artifacts:
```
claims-api/
  Models/
    ClaimBase.cs      (18 lines)
    MedicalClaim.cs   (24 lines)
    DentalClaim.cs    (20 lines)
    ClaimStatus.cs    (12 lines)
```
ClaimBase.cs:5    `public abstract class ClaimBase { public Guid Id { get; set; } public DateTime SubmittedAt { get; set; } public ClaimStatus Status { get; set; } }`
MedicalClaim.cs:5 `public class MedicalClaim : ClaimBase { public string DiagnosisCode { get; set; } public decimal? Deductible { get; set; } }`
DentalClaim.cs:5  `public class DentalClaim : ClaimBase { public string ProcedureCode { get; set; } public bool? OrthodonticFlag { get; set; } }`
ClaimStatus.cs:4  `public enum ClaimStatus { Submitted, UnderReview, Approved, Denied, Paid }`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- Inherited fields must be listed on derived DTOs from ClaimBase, not just declared fields.
- Nullable fields (Deductible, OrthodonticFlag) must be marked nullable; omitting `?` is a correctness error.
- Abstract base cannot be instantiated; must note it is not a concrete message type.
Expected findings:
- ClaimBase (abstract): Id:Guid, SubmittedAt:DateTime, Status:ClaimStatus (ClaimBase.cs:5)
- MedicalClaim: inherits ClaimBase + DiagnosisCode:string, Deductible:decimal? (MedicalClaim.cs:5)
- DentalClaim: inherits ClaimBase + ProcedureCode:string, OrthodonticFlag:bool? (DentalClaim.cs:5)
- ClaimStatus enum values: Submitted, UnderReview, Approved, Denied, Paid (ClaimStatus.cs:4)
- Note: ClaimBase is abstract — not a concrete wire type
Verify (mechanical):
- sut-profile.md lists both derived DTOs with full inherited + declared fields.
- Nullable annotations present (decimal?, bool?).
- Abstract note on ClaimBase.
Rubric (graded):
- Citation discipline (0–10): each type cites Models/filename:line → 10.
- Nullable accuracy (0–10): decimal? and bool? present → 10; either missing `?` → 5.
- Inheritance completeness (0–10): derived DTOs include all 3 inherited fields → 10; missing any → 3 each.
Solution sketch: Read each Models/ file, build inheritance tree, list all fields (inherited + declared) per concrete type, mark nullable fields, emit enum values.

---

### A-117: Mixed NUnit + QaaS YAML Test Inventory
Tier: T4
Goal: Produce a unified test-inventory.md by parsing both NUnit test classes and QaaS Runner YAML files for the same SUT, then diff against sut-profile.md to classify gaps.
Provided artifacts:
```
tests/
  unit/
    PricingEngineTests.cs  (55 lines)
  integration/
    pricing-smoke.qaas.yaml  (38 lines)
qaas-analysis/
  sut-profile.md  (surfaces: POST /price, GET /price/{id}, queue price.updates, gRPC GetRate)
```
PricingEngineTests.cs:10   `[Test] public void Calculate_ValidInputs_ReturnsExpectedPrice()`
PricingEngineTests.cs:24   `[Test] public void Calculate_ZeroQuantity_ThrowsException()`
pricing-smoke.qaas.yaml:4  `Name: Smoke_PostPrice`
pricing-smoke.qaas.yaml:11 `Route: price`
pricing-smoke.qaas.yaml:13 `Method: POST`
pricing-smoke.qaas.yaml:28 `HttpStatus: { StatusCode: 200, OutputNames: [resp] }`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s09, s10, s13
Hard because:
- NUnit tests cover internal engine logic, not HTTP surface; must not map them to HTTP routes.
- QaaS YAML covers POST /price; GET /price/{id}, queue, and gRPC remain uncovered.
- Three distinct framework types in one inventory requires consistent row format.
Expected findings:
- NUnit row: Calculate_ValidInputs → pricing engine logic, not HTTP (PricingEngineTests.cs:10)
- NUnit row: Calculate_ZeroQuantity → pricing engine error path (PricingEngineTests.cs:24)
- QaaS row: Smoke_PostPrice → POST /price, HttpStatus 200 (pricing-smoke.qaas.yaml:4)
- Gap CREATE: GET /price/{id} — no test
- Gap CREATE: queue price.updates — no test
- Gap CREATE: gRPC GetRate — no test
Verify (mechanical):
- test-inventory.md has 3 rows with mixed citations.
- coverage-gaps.md ## Create section has 3 entries (GET, queue, gRPC).
- NUnit rows do not incorrectly claim HTTP coverage.
Rubric (graded):
- Citation discipline (0–10): each row cites its own file:line → 10.
- NUnit scope accuracy (0–10): NUnit rows not mapped to HTTP surface → 10; incorrect mapping → 0.
- Gap completeness (0–10): all 3 uncovered surfaces in Create section → 10; missing any → 3.
Solution sketch: Parse NUnit class for [Test] methods, parse QaaS YAML for Name/Route/Method/assertions, build unified rows, diff 4-surface catalog, emit 3 create gaps.

---

### A-118: Secrets vs ConfigMaps — Never-Fill-Gaps Rule
Tier: T4
Goal: Analyze a Kubernetes deployment that mixes configMapKeyRef and secretKeyRef env vars and produce runtime-config.md, emitting secrets as numbered open questions and config values as resolved citations.
Provided artifacts:
```
k8s/
  deployment.yaml   (48 lines)
  configmap.yaml    (20 lines)
```
deployment.yaml:22  `- name: DB_HOST  valueFrom: { configMapKeyRef: { name: app-config, key: db_host } }`
deployment.yaml:24  `- name: DB_PASS  valueFrom: { secretKeyRef: { name: app-secret, key: db_password } }`
deployment.yaml:26  `- name: API_KEY  valueFrom: { secretKeyRef: { name: app-secret, key: api_key } }`
deployment.yaml:28  `- name: LOG_LEVEL valueFrom: { configMapKeyRef: { name: app-config, key: log_level } }`
configmap.yaml:7    `data: { db_host: "postgres.prod.internal", log_level: "warn" }`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- secretKeyRef values are not in provided files; model must emit open questions, never invent values.
- Two configMapKeyRef values are resolvable from configmap.yaml — must cite configmap.yaml:line, not deployment.yaml:line.
- Must clearly separate "resolved" from "secret/unknown" in output.
Expected findings:
- DB_HOST: postgres.prod.internal (configmap.yaml:7, referenced at deployment.yaml:22)
- LOG_LEVEL: warn (configmap.yaml:7, referenced at deployment.yaml:28)
- Open question #1: DB_PASS — secretKeyRef app-secret/db_password (deployment.yaml:24), value unknown
- Open question #2: API_KEY — secretKeyRef app-secret/api_key (deployment.yaml:26), value unknown
Verify (mechanical):
- runtime-config.md has resolved section (2 entries) and open-questions section (2 entries).
- Secret values not invented.
- configmap.yaml:7 cited for both resolved values.
Rubric (graded):
- Citation discipline (0–10): configMapKeyRef values cite configmap.yaml:7 → 10; citing deployment.yaml only → 5.
- Never-fill-gaps (0–10): both secrets emitted as open questions, no invented values → 10; any invented → 0.
- Separation discipline (0–10): resolved and secret sections clearly separated → 10; mixed → 3.
Solution sketch: Parse deployment.yaml env block, resolve configMapKeyRef against configmap.yaml data block, emit secretKeyRef as numbered questions.

---

### A-119: Broker Topology from MassTransit Configuration
Tier: T4
Goal: Extract RabbitMQ topology (exchanges, queues, bindings) configured via MassTransit fluent API and produce sut-profile.md publish/consume section with file:line citations.
Provided artifacts:
```
logistics-svc/
  Infrastructure/BusConfig.cs  (62 lines)
  Consumers/
    ShipmentConsumer.cs   (28 lines)
    ReturnConsumer.cs     (24 lines)
```
BusConfig.cs:14  `cfg.Message<ShipmentCreated>(x => x.SetEntityName("shipments.exchange"));`
BusConfig.cs:18  `cfg.ReceiveEndpoint("shipment-queue", e => { e.ConfigureConsumer<ShipmentConsumer>(ctx); e.Bind("shipments.exchange"); });`
BusConfig.cs:26  `cfg.Message<ReturnRequested>(x => x.SetEntityName("returns.exchange"));`
BusConfig.cs:30  `cfg.ReceiveEndpoint("returns-queue", e => { e.ConfigureConsumer<ReturnConsumer>(ctx); e.Bind("returns.exchange"); });`
BusConfig.cs:40  `cfg.Publish<ShipmentCreated>(x => x.ExchangeType = ExchangeType.Fanout);`
ShipmentConsumer.cs:6  `public class ShipmentConsumer : IConsumer<ShipmentCreated>`
ReturnConsumer.cs:6    `public class ReturnConsumer : IConsumer<ReturnRequested>`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- MassTransit uses message-type-named exchanges by default; SetEntityName overrides this — must note the explicit override.
- ExchangeType.Fanout on ShipmentCreated means all bindings receive all messages — semantics matter.
- Binding direction: e.Bind() on ReceiveEndpoint binds the queue to the named exchange.
Expected findings:
- Exchange shipments.exchange: type=Fanout (BusConfig.cs:14, BusConfig.cs:40)
- Queue shipment-queue bound to shipments.exchange (BusConfig.cs:18), consumer ShipmentConsumer
- Exchange returns.exchange: type not specified — open question #1 (BusConfig.cs:26)
- Queue returns-queue bound to returns.exchange (BusConfig.cs:30), consumer ReturnConsumer
- Note: SetEntityName overrides default MassTransit exchange name for both message types
Verify (mechanical):
- sut-profile.md lists both exchanges and queues with bindings.
- Fanout type noted on shipments.exchange.
- Open question for returns.exchange type.
Rubric (graded):
- Citation discipline (0–10): each exchange/queue/binding cites BusConfig.cs:line → 10.
- Fanout semantics (0–10): ExchangeType.Fanout noted with semantic implication → 10; type omitted → 0.
- Open-question discipline (0–10): returns.exchange type emitted as open question → 10; guessed → 0.
Solution sketch: Read BusConfig.cs line-by-line, map Message<T>→SetEntityName→exchange, map ReceiveEndpoint→Bind→queue, classify exchange types, emit open question for unspecified type.

---

### A-120: gRPC Proto with Multiple Services and Imports
Tier: T4
Goal: Extract all services, RPC methods, and cross-file imported message types from a multi-file proto set and produce sut-profile.md gRPC section with per-file citations.
Provided artifacts:
```
analytics-svc/
  proto/
    analytics.proto   (44 lines)
    common.proto      (22 lines)
```
common.proto:4    `message Timestamp { int64 unix_ms = 1; }`
common.proto:8    `message PageRequest { int32 page = 1; int32 page_size = 2; }`
analytics.proto:3 `import "common.proto";`
analytics.proto:8 `service AnalyticsService {`
analytics.proto:9 `  rpc RecordEvent (RecordRequest) returns (RecordResponse);`
analytics.proto:10 `  rpc QueryEvents (QueryRequest) returns (stream EventRecord);`
analytics.proto:14 `message RecordRequest { string event_type = 1; Timestamp occurred_at = 2; bytes payload = 3; }`
analytics.proto:20 `message QueryRequest { string event_type = 1; PageRequest paging = 2; Timestamp from = 3; }`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- Timestamp and PageRequest are defined in common.proto:4,8 — must cite common.proto, not analytics.proto, for those types.
- RecordEvent is unary; QueryEvents is server-streaming — must distinguish.
- bytes payload field must be noted (binary, not string).
Expected findings:
- Service: AnalyticsService (analytics.proto:8)
- RPC RecordEvent: unary, RecordRequest→RecordResponse (analytics.proto:9)
- RPC QueryEvents: server-streaming, QueryRequest→stream EventRecord (analytics.proto:10)
- RecordRequest.occurred_at type Timestamp: defined at common.proto:4, imported at analytics.proto:3
- QueryRequest.paging type PageRequest: defined at common.proto:8, imported at analytics.proto:3
- payload field: bytes (binary) — analytics.proto:14
Verify (mechanical):
- sut-profile.md cites common.proto for Timestamp and PageRequest types.
- Server-streaming flag on QueryEvents.
- bytes type noted for payload.
Rubric (graded):
- Citation discipline (0–10): cross-file types cite common.proto:line → 10; only analytics.proto cited → 0.
- Streaming accuracy (0–10): QueryEvents streaming noted → 10; missed → 0.
- Type detail (0–10): bytes noted as binary (not string) → 10; misidentified → 0.
Solution sketch: Parse common.proto for message definitions, parse analytics.proto for service/RPCs/messages, trace import for cross-file types, note streaming and bytes semantics.

---

### A-121: OpenAPI vs Code Drift — Multiple Endpoints
Tier: T4
Goal: Compare a multi-endpoint OpenAPI spec against the controller and identify all drifted, removed, or undocumented routes, producing sut-profile.md with drift section citing both spec and code.
Provided artifacts:
```
accounts-api/
  openapi.yaml                   (70 lines)
  Controllers/AccountsController.cs  (60 lines)
```
openapi.yaml:10   `GET /accounts → 200 AccountListDto`
openapi.yaml:18   `POST /accounts → 201 AccountDto`
openapi.yaml:26   `GET /accounts/{id} → 200 AccountDto, 404`
openapi.yaml:34   `PATCH /accounts/{id} → 200 AccountDto`
openapi.yaml:42   `DELETE /accounts/{id} → 204`
AccountsController.cs:10  `[HttpGet] public IActionResult List() => ...`
AccountsController.cs:18  `[HttpPost] public IActionResult Create([FromBody] CreateAccountDto dto) => ...`
AccountsController.cs:26  `[HttpGet("{id}")] public IActionResult GetById(Guid id) => ...`
AccountsController.cs:34  `// PATCH removed — use PUT instead`
AccountsController.cs:42  `[HttpPut("{id}")] public IActionResult Update(Guid id, [FromBody] UpdateAccountDto dto) => ...`
AccountsController.cs:52  `[HttpDelete("{id}")] public IActionResult Delete(Guid id) => ...`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- PATCH declared in spec but removed in code replaced by PUT — two findings: drift on PATCH + undocumented PUT.
- DELETE is aligned; must not be flagged.
- Must cite both spec:line and code:line for each drift item.
Expected findings:
- Aligned: GET /accounts (openapi.yaml:10, AccountsController.cs:10)
- Aligned: POST /accounts (openapi.yaml:18, AccountsController.cs:18)
- Aligned: GET /accounts/{id} (openapi.yaml:26, AccountsController.cs:26)
- DRIFT: PATCH /accounts/{id} — spec declares it (openapi.yaml:34), handler removed (AccountsController.cs:34 comment)
- UNDOCUMENTED: PUT /accounts/{id} — in code (AccountsController.cs:42), absent from spec
- Aligned: DELETE /accounts/{id} (openapi.yaml:42, AccountsController.cs:52)
Verify (mechanical):
- sut-profile.md drift section has exactly PATCH (drift) and PUT (undocumented).
- Both spec:line and code:line cited for PATCH.
- DELETE not flagged.
Rubric (graded):
- Citation discipline (0–10): dual-citation on PATCH drift → 10; single source → 5.
- Drift detection (0–10): both PATCH drift and PUT undocumented detected → 10; missing either → 5.
- No false positives (0–10): DELETE and GET not flagged → 10; false positive → 5 each.
Solution sketch: Enumerate spec routes, cross-reference each to controller methods, flag PATCH as absent in code, flag PUT as absent in spec, confirm DELETE alignment.

---

### A-122: Feature-Flag-Gated Endpoint with Toggle Source
Tier: T4
Goal: Identify all feature-flag-gated routes, extract flag names, toggle sources (env var / config file / remote), and default states, marking gated routes as conditional in sut-profile.md.
Provided artifacts:
```
experiments-api/
  Program.cs                 (34 lines)
  Features/FeatureManager.cs (28 lines)
  appsettings.json           (20 lines)
```
Program.cs:12  `if (featureManager.IsEnabled("new-checkout")) { app.MapPost("/checkout/v2", CheckoutHandler.V2); }`
Program.cs:14  `app.MapPost("/checkout/v1", CheckoutHandler.V1);`
Program.cs:16  `if (featureManager.IsEnabled("loyalty-rewards")) { app.MapGet("/rewards", RewardsHandler.Get); }`
FeatureManager.cs:8   `private IConfiguration _config;`
FeatureManager.cs:12  `public bool IsEnabled(string flag) => _config[$"FeatureFlags:{flag}"] == "true";`
appsettings.json:10   `"FeatureFlags": { "new-checkout": "false", "loyalty-rewards": "true" }`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- Toggle source is IConfiguration, which reads from appsettings.json; must trace FeatureManager→IConfiguration→appsettings.json, not just read Program.cs.
- new-checkout default=false → route unreachable by default; must flag.
- loyalty-rewards default=true → route reachable by default; different risk.
Expected findings:
- GET (POST) /checkout/v2: CONDITIONAL, flag=new-checkout, default=false → unreachable by default (Program.cs:12, appsettings.json:10)
- POST /checkout/v1: unconditional (Program.cs:14)
- GET /rewards: CONDITIONAL, flag=loyalty-rewards, default=true → reachable by default (Program.cs:16, appsettings.json:10)
- Toggle source: IConfiguration reading FeatureFlags:{flag} (FeatureManager.cs:12)
Verify (mechanical):
- sut-profile.md marks /checkout/v2 as CONDITIONAL with "unreachable by default".
- /rewards marked CONDITIONAL with "reachable by default".
- Toggle source traced to appsettings.json with citation.
Rubric (graded):
- Citation discipline (0–10): each route cites Program.cs:line + appsettings.json:line → 10.
- Default-reachability accuracy (0–10): new-checkout=false flagged as unreachable, loyalty-rewards=true as reachable → 10; either wrong → 5.
- Toggle-source tracing (0–10): path FeatureManager.cs:12→IConfiguration→appsettings.json traced → 10; only Program.cs cited → 3.
Solution sketch: Read Program.cs for conditional Map*, trace FeatureManager.IsEnabled to _config lookup, read appsettings.json FeatureFlags section for defaults, classify each flag's default reachability.

---

### A-123: Readiness and Liveness Probe Semantics
Tier: T4
Goal: Extract readiness and liveness probe configurations from a Kubernetes deployment, map them to SUT endpoint behavior, and note any timing implications for test warm-up.
Provided artifacts:
```
k8s/
  deployment.yaml   (56 lines)
```
deployment.yaml:30  `livenessProbe: { httpGet: { path: /health/live, port: 8080 }, initialDelaySeconds: 10, periodSeconds: 15, failureThreshold: 3 }`
deployment.yaml:38  `readinessProbe: { httpGet: { path: /health/ready, port: 8080 }, initialDelaySeconds: 5, periodSeconds: 10, failureThreshold: 2 }`
deployment.yaml:46  `startupProbe: { httpGet: { path: /health/start, port: 8080 }, failureThreshold: 30, periodSeconds: 3 }`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- Three probe types have different semantics; must distinguish liveness (restart trigger) vs readiness (traffic gate) vs startup (startup budget).
- Warm-up calculation: startupProbe max wait = failureThreshold × periodSeconds = 90s — relevant to test session initialDelaySeconds configuration.
- Must note that /health/live, /health/ready, /health/start must be functional endpoints in the SUT.
Expected findings:
- Liveness probe: GET /health/live:8080, initialDelay=10s, period=15s, threshold=3 (deployment.yaml:30)
- Readiness probe: GET /health/ready:8080, initialDelay=5s, period=10s, threshold=2 (deployment.yaml:38)
- Startup probe: GET /health/start:8080, max budget=90s (30×3) (deployment.yaml:46)
- Test timing note: allow ≥90s for startup before test traffic; readiness gate adds ≥5s
- Three probe endpoints must exist in SUT; cross-reference with sut-profile.md
Verify (mechanical):
- runtime-config.md lists all 3 probes with paths, ports, and timing parameters.
- 90s startup budget calculation present.
- Cross-reference note present.
Rubric (graded):
- Citation discipline (0–10): each probe cites deployment.yaml:line → 10.
- Timing calculation (0–10): 90s budget calculated and noted → 10; omitted → 0.
- Semantic distinction (0–10): liveness vs readiness vs startup purposes distinguished → 10; all called "health checks" → 0.
Solution sketch: Read deployment.yaml probe blocks, extract path/port/timing params per probe type, calculate startup max budget, emit test-timing note and cross-reference requirement.

---

### A-124: Resource Limits Affecting Test Timing
Tier: T4
Goal: Extract CPU and memory limits and requests from a deployment, identify resource-constrained scenarios that could cause test timeouts, and annotate runtime-config.md with timing risk notes.
Provided artifacts:
```
k8s/
  deployment.yaml   (60 lines)
  hpa.yaml          (22 lines)
```
deployment.yaml:34  `resources: { requests: { cpu: "100m", memory: "128Mi" }, limits: { cpu: "250m", memory: "256Mi" } }`
deployment.yaml:36  `# Heavy computation endpoint POST /analyze may need ≥500m CPU`
hpa.yaml:8          `minReplicas: 1`
hpa.yaml:10         `maxReplicas: 4`
hpa.yaml:12         `targetCPUUtilizationPercentage: 70`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- CPU limit 250m is below the comment's noted requirement for POST /analyze — must flag this as a timing risk, not ignore the comment.
- HPA minReplicas=1 means scale-out is possible but not guaranteed; single-replica tests may be CPU-throttled.
- Must not invent SUT behavior; timing risk note must reference the comment at deployment.yaml:36.
Expected findings:
- CPU request=100m, limit=250m (deployment.yaml:34)
- Memory request=128Mi, limit=256Mi (deployment.yaml:34)
- TIMING RISK: POST /analyze may require >250m CPU per comment (deployment.yaml:36); test timeouts possible under limit
- HPA: scales 1→4 replicas at 70% CPU (hpa.yaml:8,10,12); tests may see variable latency during scale events
- Recommendation: increase test session timeout for POST /analyze; consider disabling HPA for isolated test runs
Verify (mechanical):
- runtime-config.md lists resource limits with citation.
- TIMING RISK note present referencing deployment.yaml:36.
- HPA scale range noted.
Rubric (graded):
- Citation discipline (0–10): resources cite deployment.yaml:34, HPA cites hpa.yaml lines → 10.
- Risk identification (0–10): CPU throttle risk on POST /analyze flagged → 10; omitted → 0.
- No invention (0–10): timing risk tied to deployment.yaml:36 comment, not invented → 10; invented endpoint behavior → 0.
Solution sketch: Read deployment.yaml resources block + comment, read hpa.yaml for replica range and target, cross-reference CPU limit vs comment threshold, emit timing risk and recommendation.

---

### A-125: Python Worker Message Schema Extraction
Tier: T4
Goal: Extract message schema and queue configuration from a Python Celery worker and produce sut-profile.md publish/consume section with file:line citations.
Provided artifacts:
```
ml-worker/
  tasks.py          (44 lines)
  config.py         (18 lines)
  models/job.py     (24 lines)
```
config.py:6       `CELERY_BROKER_URL = os.environ.get("CELERY_BROKER", "redis://localhost:6379/0")`
config.py:8       `CELERY_RESULT_BACKEND = os.environ.get("CELERY_BACKEND", "redis://localhost:6379/1")`
tasks.py:8        `@app.task(name="ml_worker.run_inference", queue="inference-queue")`
tasks.py:10       `def run_inference(job_id: str, payload: dict) -> dict:`
tasks.py:22       `@app.task(name="ml_worker.cleanup", queue="cleanup-queue")`
tasks.py:24       `def cleanup(job_id: str) -> None:`
job.py:5          `class Job: job_id: str; model_name: str; input_data: dict; priority: int = 1`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- Python uses dynamic typing; must note `dict` fields are untyped and schema is open question unless models/job.py is read.
- Two queues (inference-queue and cleanup-queue) have different task signatures — must not conflate.
- CELERY_BROKER default is Redis, not RabbitMQ — must note Redis as broker.
Expected findings:
- Broker: Redis (default redis://localhost:6379/0, from CELERY_BROKER env — config.py:6)
- Task ml_worker.run_inference: queue=inference-queue, params=(job_id:str, payload:dict) (tasks.py:8,10)
- Task ml_worker.cleanup: queue=cleanup-queue, params=(job_id:str) → None (tasks.py:22,24)
- Job schema: job_id:str, model_name:str, input_data:dict, priority:int=1 (job.py:5)
- Open question #1: CELERY_BROKER env var in production — default may be overridden
Verify (mechanical):
- sut-profile.md lists both tasks with queue names and parameter types.
- Redis noted as default broker with env-var override note.
- Open question for production broker value.
Rubric (graded):
- Citation discipline (0–10): each task cites tasks.py:line, config cites config.py:line → 10.
- Broker accuracy (0–10): Redis identified (not RabbitMQ) from config.py:6 → 10; wrong broker → 0.
- Schema completeness (0–10): Job schema from job.py with all fields including default → 10; partial → 5.
Solution sketch: Read config.py for broker URL and env var, read tasks.py for @app.task decorators, read job.py for Job class fields, emit topology with open question for production override.

---

### A-126: Existing QaaS YAML Repair Gap Analysis
Tier: T4
Goal: Identify QaaS YAML tests that contain known doc-drift traps (wrong assertion keys, missing output-count guards, leading-slash routes) and classify each as "repair", producing coverage-gaps.md.
Provided artifacts:
```
tests/
  create-user.qaas.yaml    (32 lines)
  delete-user.qaas.yaml    (28 lines)
  list-users.qaas.yaml     (24 lines)
```
create-user.qaas.yaml:18   `HttpStatus: { ExpectedStatus: 201, OutputName: "resp" }`
delete-user.qaas.yaml:12   `Route: /users/{id}`
list-users.qaas.yaml:20    `HttpStatus: { StatusCode: 200, OutputNames: [lresp] }`
list-users.qaas.yaml:22    `# no HermeticByExpectedOutputCount guard`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s09, s13
Hard because:
- create-user uses outdated keys ExpectedStatus and OutputName (singular) — these are Drift Table entries #4; model must identify as repair.
- delete-user has leading slash on Route (Drift Table entry #5) — must flag as repair.
- list-users has correct assertion keys but missing hermetic output-count guard (Drift Table entry #12) — must flag as repair with specific rule.
Expected findings:
- create-user.qaas.yaml REPAIR: ExpectedStatus→StatusCode, OutputName→OutputNames (drift #4, create-user.qaas.yaml:18)
- delete-user.qaas.yaml REPAIR: Route leading slash must be removed (drift #5, delete-user.qaas.yaml:12)
- list-users.qaas.yaml REPAIR: missing HermeticByExpectedOutputCount guard — HttpStatus passes vacuously on zero outputs (list-users.qaas.yaml:20,22)
- No "create" gaps: all surfaces have tests, they just need repair
Verify (mechanical):
- coverage-gaps.md ## Repair section has 3 entries.
- Each entry references the specific drift trap number.
- ## Create section is empty or absent.
Rubric (graded):
- Citation discipline (0–10): each repair cites test file:line → 10.
- Drift-trap identification (0–10): all 3 specific drift traps identified → 10; any missed → 3.
- Classification accuracy (0–10): all 3 classified as "repair" not "create" → 10; wrong class → 0.
Solution sketch: Read each YAML file, check HttpStatus keys against Fact Base drift table #4, check Route for leading slash per drift #5, check for output-count guard per drift #12, emit repair entries.

---

### A-127: Multi-Env Values Override Analysis
Tier: T4
Goal: Given three Helm values files (base, staging, production), compute the effective configuration for each environment and produce a runtime-config.md with per-environment columns and citations.
Provided artifacts:
```
helm/
  values.yaml             (26 lines)
  values-staging.yaml     (18 lines)
  values-production.yaml  (20 lines)
```
values.yaml:6       `replicaCount: 1`
values.yaml:8       `image: { tag: "latest", pullPolicy: IfNotPresent }`
values.yaml:12      `env: { API_URL: "http://localhost:8080", LOG_LEVEL: "debug", DB_POOL: "5" }`
values-staging.yaml:5  `image: { tag: "staging-1.2.0" }`
values-staging.yaml:8  `env: { API_URL: "http://api.staging.internal", LOG_LEVEL: "info" }`
values-production.yaml:5  `replicaCount: 3`
values-production.yaml:7  `image: { tag: "1.2.0", pullPolicy: Always }`
values-production.yaml:10 `env: { API_URL: "http://api.prod.internal", LOG_LEVEL: "warn", DB_POOL: "20" }`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- Staging overrides tag but not pullPolicy — effective pullPolicy in staging is IfNotPresent from base.
- DB_POOL: staging does not override — effective staging value is "5" from base; production overrides to "20".
- Must produce per-environment columns, not just list overrides.
Expected findings:
- Staging: tag=staging-1.2.0 (values-staging.yaml:5), pullPolicy=IfNotPresent (values.yaml:8), API_URL=http://api.staging.internal (values-staging.yaml:8), LOG_LEVEL=info, DB_POOL=5 (base)
- Production: replicaCount=3 (values-production.yaml:5), tag=1.2.0, pullPolicy=Always (values-production.yaml:7), API_URL=http://api.prod.internal, LOG_LEVEL=warn, DB_POOL=20 (values-production.yaml:10)
- CAUTION: rendered without helm template — overlay values may differ
Verify (mechanical):
- runtime-config.md has 3-column table (key | staging | production).
- Each cell cites source file:line.
- DB_POOL staging=5 with base citation, not overriding file.
Rubric (graded):
- Citation discipline (0–10): each effective value cites exact file:line → 10.
- Inherited-base accuracy (0–10): staging DB_POOL=5 from values.yaml:12, not invented → 10; wrong source → 0.
- CAUTION discipline (0–10): CAUTION present → 10; absent → 0.
Solution sketch: Read all 3 values files, build per-key resolution table applying override order (env-specific > base), emit 3-column table, add CAUTION.

---

### A-128: Test Data Lineage Analysis
Tier: T4
Goal: Trace where test input data originates in existing QaaS YAML sessions (inline fixture, file datasource, generator) and document lineage in test-inventory.md.
Provided artifacts:
```
tests/
  order-pipeline.qaas.yaml   (58 lines)
  fixtures/
    orders.json              (14 lines)
```
order-pipeline.qaas.yaml:8   `DataSourceNames: [order-data]`
order-pipeline.qaas.yaml:12  `Storages: [ - FileSystem: { Path: ./fixtures } ]`
order-pipeline.qaas.yaml:16  `Sessions:`
order-pipeline.qaas.yaml:20  `  Generators: [ { JsonFileGenerator: { FileName: orders.json } } ]`
order-pipeline.qaas.yaml:28  `  Generators: [ { StaticGenerator: { Value: "{\"action\":\"cancel\"}" } } ]`
orders.json:3                `[ {"orderId": "ORD-001", "amount": 100.00, "currency": "USD"}, {"orderId": "ORD-002", "amount": 250.00, "currency": "EUR"} ]`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s09, s13
Hard because:
- Two sessions use different data sources (file vs static inline); must distinguish per session.
- DataSourceNames links YAML to storage path; must trace FileSystem:Path + FileName together.
- orders.json schema must be extracted (2 records) without inventing additional fields.
Expected findings:
- Session 1: data from JsonFileGenerator → ./fixtures/orders.json (order-pipeline.qaas.yaml:12,20)
- orders.json schema: orderId:string, amount:number, currency:string, 2 records (orders.json:3)
- Session 2: data from StaticGenerator inline JSON {action:cancel} (order-pipeline.qaas.yaml:28)
- DataSourceNames: [order-data] links storage mount (order-pipeline.qaas.yaml:8)
- Lineage: session-1 input traces to fixtures/orders.json; session-2 input is self-contained
Verify (mechanical):
- test-inventory.md data-lineage column distinguishes file-sourced vs inline-static per session.
- orders.json schema listed with 2 records noted.
- DataSourceNames traced to FileSystem path.
Rubric (graded):
- Citation discipline (0–10): each lineage entry cites YAML:line and fixture:line → 10.
- Source distinction (0–10): file vs inline-static clearly distinguished → 10; merged → 0.
- Schema completeness (0–10): all 3 orders.json fields extracted → 10; missing any → 3.
Solution sketch: Read YAML DataSourceNames + Storages + Generators blocks per session, read orders.json for schema, trace full lineage path, emit per-session lineage rows.

---

### A-129: C# Inheritance DTO + Polymorphic Discriminator
Tier: T4
Goal: Extract a polymorphic DTO hierarchy using [JsonDerivedType] discriminators, document the discriminator key and all subtypes, and produce sut-profile.md DTO section.
Provided artifacts:
```
notifications-api/
  Models/
    NotificationBase.cs   (16 lines)
    EmailNotification.cs  (18 lines)
    PushNotification.cs   (16 lines)
    SmsNotification.cs    (14 lines)
```
NotificationBase.cs:4  `[JsonPolymorphic(TypeDiscriminatorPropertyName = "type")]`
NotificationBase.cs:5  `[JsonDerivedType(typeof(EmailNotification), "email")]`
NotificationBase.cs:6  `[JsonDerivedType(typeof(PushNotification), "push")]`
NotificationBase.cs:7  `[JsonDerivedType(typeof(SmsNotification), "sms")]`
NotificationBase.cs:8  `public abstract class NotificationBase { public Guid Id { get; set; } public string RecipientId { get; set; } }`
EmailNotification.cs:6 `public class EmailNotification : NotificationBase { public string ToAddress { get; set; } public string Subject { get; set; } public string Body { get; set; } }`
PushNotification.cs:6  `public class PushNotification : NotificationBase { public string DeviceToken { get; set; } public string Title { get; set; } }`
SmsNotification.cs:6   `public class SmsNotification : NotificationBase { public string PhoneNumber { get; set; } public string Message { get; set; } }`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- Discriminator property name is "type" from JsonPolymorphic attribute — must extract from NotificationBase.cs:4, not invent.
- Each subtype discriminator value ("email", "push", "sms") is defined on the base class, not the subtype.
- Inherited fields (Id, RecipientId) must be listed on all concrete subtypes.
Expected findings:
- Base (abstract): NotificationBase, discriminator property="type" (NotificationBase.cs:4-8)
- email → EmailNotification: Id, RecipientId (inherited), ToAddress, Subject, Body (EmailNotification.cs:6, base NotificationBase.cs:8)
- push → PushNotification: Id, RecipientId (inherited), DeviceToken, Title (PushNotification.cs:6)
- sms → SmsNotification: Id, RecipientId (inherited), PhoneNumber, Message (SmsNotification.cs:6)
- Discriminator values from base: email/push/sms (NotificationBase.cs:5,6,7)
Verify (mechanical):
- sut-profile.md lists all 3 concrete types with inherited + declared fields.
- Discriminator key "type" and values cited from NotificationBase.cs.
- Abstract base noted as not directly instantiable.
Rubric (graded):
- Citation discipline (0–10): discriminator values cite NotificationBase.cs:5,6,7 → 10; from subtype files → 3.
- Inheritance completeness (0–10): Id and RecipientId present on all 3 concrete types → 10; missing on any → 3.
- Discriminator accuracy (0–10): property name "type" correct, values correct per subtype → 10; any wrong → 0.
Solution sketch: Read NotificationBase.cs for JsonPolymorphic and JsonDerivedType attributes, read each subtype for declared fields, compose full per-type field list including inherited, document discriminator map.

---

### A-130: Kubernetes ConfigMap Env Resolution
Tier: T4
Goal: Resolve all environment variables injected via a Kubernetes ConfigMap (both envFrom and selective valueFrom.configMapKeyRef) and produce runtime-config.md with each value's effective source cited.
Provided artifacts:
```
k8s/
  configmap-app.yaml    (24 lines)
  configmap-feature.yaml (14 lines)
  deployment.yaml       (52 lines)
```
configmap-app.yaml:6    `data: { SERVER_PORT: "9090", LOG_FORMAT: "json", MAX_CONNECTIONS: "100" }`
configmap-feature.yaml:5 `data: { FEATURE_A: "enabled", FEATURE_B: "disabled" }`
deployment.yaml:22      `envFrom: [ { configMapRef: { name: configmap-app } } ]`
deployment.yaml:26      `env:`
deployment.yaml:27      `  - name: FEATURE_A  valueFrom: { configMapKeyRef: { name: configmap-feature, key: FEATURE_A } }`
deployment.yaml:30      `  - name: MAX_CONNECTIONS  value: "200"`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- deployment.yaml:30 sets MAX_CONNECTIONS=200 via literal env — overrides the configmap-app value of 100 per K8s explicit-env-overrides-envFrom rule.
- FEATURE_A: sourced from configmap-feature.yaml, not configmap-app — must cite correct configmap.
- FEATURE_B: not selected via valueFrom — not injected at all unless envFrom includes configmap-feature (it doesn't); must flag as NOT injected.
Expected findings:
- SERVER_PORT: 9090 (configmap-app.yaml:6, injected via deployment.yaml:22 envFrom)
- LOG_FORMAT: json (configmap-app.yaml:6, envFrom)
- MAX_CONNECTIONS: 200 (deployment.yaml:30 explicit literal, overrides configmap-app.yaml:6 value 100)
- FEATURE_A: enabled (configmap-feature.yaml:5, via deployment.yaml:27 valueFrom)
- FEATURE_B: NOT INJECTED — configmap-feature not in envFrom, no valueFrom for FEATURE_B (configmap-feature.yaml:5 vs deployment.yaml:22,26)
Verify (mechanical):
- runtime-config.md has 5 env var entries (4 injected + 1 not-injected).
- MAX_CONNECTIONS shows override with both values cited.
- FEATURE_B explicitly marked NOT INJECTED.
Rubric (graded):
- Citation discipline (0–10): each injected var cites source configmap:line + deployment:line → 10.
- Override accuracy (0–10): MAX_CONNECTIONS=200 correctly overrides 100 per K8s rule → 10; wrong value → 0.
- Not-injected discipline (0–10): FEATURE_B explicitly listed as not injected, not silently omitted → 10; omitted → 0.
Solution sketch: Read both configmaps' data blocks, read deployment.yaml envFrom and env sections, apply K8s explicit-env-overrides-envFrom rule for MAX_CONNECTIONS, trace FEATURE_A to configmap-feature, flag FEATURE_B as not injected.

---

### A-131: 3-Repo Polyglot + Umbrella Chart + OpenAPI/Code Drift + Feature Flag
Tier: T5
Goal: Given three repos (C# API, Node.js sidecar, Python ETL worker) plus an umbrella Helm chart, produce: (1) unified effective-config table, (2) full surface catalog, (3) coverage-gap diff — every row file:line cited; flag one feature-flag-hidden route and one OpenAPI/code drift.
Provided artifacts:
```
order-platform/ (umbrella)
  helm/
    Chart.yaml                   (12 lines) [deps: order-api, notify-svc]
    values.yaml                  (30 lines)
    values-production.yaml       (22 lines)
    charts/order-api/values.yaml (18 lines)
    charts/notify-svc/values.yaml(16 lines)
  order-api/ (C# ASP.NET)
    Program.cs                   (38 lines)
    openapi.yaml                 (60 lines)
    Controllers/OrdersController.cs (52 lines)
    Features/FeatureGate.cs      (16 lines)
    appsettings.json             (20 lines)
  notify-svc/ (Node.js)
    index.js                     (26 lines)
    routes/notify.js             (22 lines)
  etl-worker/ (Python Celery)
    tasks.py                     (36 lines)
    config.py                    (14 lines)
```
values.yaml:8         `global: { dbHost: "db.prod.internal" }`
values.yaml:12        `order-api: { env: { DB_HOST: "order-db.prod", ORDER_TIMEOUT: "30" } }`
values-production.yaml:6  `order-api: { env: { ORDER_TIMEOUT: "60" } }`
charts/order-api/values.yaml:5  `env: { DB_HOST: "localhost", ORDER_TIMEOUT: "10" }`
Program.cs:14   `app.MapGet("/orders", OrdersController.List);`
Program.cs:15   `app.MapPost("/orders", OrdersController.Create);`
Program.cs:16   `if (featureGate.IsEnabled("bulk-import")) { app.MapPost("/orders/bulk", OrdersController.BulkImport); }`
FeatureGate.cs:8  `bool IsEnabled(string f) => _config[$"Features:{f}"] == "true";`
appsettings.json:14  `"Features": { "bulk-import": "false" }`
openapi.yaml:18  `POST /orders/bulk → 200 BulkResult`
openapi.yaml:26  `DELETE /orders/{id} → 204`
OrdersController.cs:40  `// DELETE removed in v3 — see migration guide`
notify-svc/routes/notify.js:6  `router.post('/send', (req, res) => ...)`
etl-worker/tasks.py:8  `@app.task(name="etl.import_orders", queue="etl-import")`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- Production effective ORDER_TIMEOUT: values-production.yaml:6 overrides umbrella values.yaml:12 (=60), not subchart default (=10); three-layer resolution required.
- /orders/bulk: declared in OpenAPI (openapi.yaml:18) AND gated by feature flag default=false (Program.cs:16, appsettings.json:14) — both DRIFT and CONDITIONAL.
- DELETE: OpenAPI claims 204 (openapi.yaml:26), code says removed (OrdersController.cs:40) — code wins; must not plan test.
Expected findings:
- ORDER_TIMEOUT effective (production): 60 (values-production.yaml:6 overrides umbrella:12 overrides subchart:5)
- DB_HOST effective: order-db.prod (umbrella values.yaml:12, overrides subchart default localhost)
- Surface: GET /orders, POST /orders (Program.cs:14,15) — unconditional
- Surface CONDITIONAL: POST /orders/bulk — flag=bulk-import default=false → unreachable by default (Program.cs:16, appsettings.json:14, openapi.yaml:18 — but spec is aspirational given flag)
- DRIFT: DELETE /orders/{id} — spec 204 (openapi.yaml:26), code removed (OrdersController.cs:40) — do not test
- Surface: POST /notify/send (notify-svc/routes/notify.js:6)
- Surface: Celery task etl.import_orders on queue etl-import (etl-worker/tasks.py:8)
Verify (mechanical):
- sut-profile.md has all 5 reachable surfaces + 1 dead + 1 conditional.
- runtime-config.md has ORDER_TIMEOUT=60 with 3-layer provenance chain.
- coverage-gaps.md section noting DELETE must not be tested.
Rubric (graded):
- Citation discipline (0–10): every row in every deliverable cites file:line; layer citations for ORDER_TIMEOUT trace all 3 files → 10; any uncited → 0.
- Config resolution accuracy (0–10): ORDER_TIMEOUT=60 correct with provenance; DB_HOST=order-db.prod correct → 10; wrong final value → 0.
- Drift + flag dual detection (0–10): /orders/bulk flagged as BOTH conditional AND OpenAPI-aspirational; DELETE flagged as dead code-wins → 10; either missed → 5.
Solution sketch: Resolve umbrella values 3-layer for each env var, extract all routes from 3 repos, classify each as unconditional/conditional/dead, emit effective-config table + surface catalog + gap diff.

---

### A-132: Two-Service Integration Surface Derivation
Tier: T5
Goal: Given service A (C# HTTP producer) and service B (C# HTTP consumer), derive the integration surface (shared endpoint contract, request/response schema, error paths) and produce sut-profile.md with cross-repo citations.
Provided artifacts:
```
service-a/ (producer)
  HttpClients/ServiceBClient.cs  (38 lines)
  Models/EnrichmentRequest.cs    (16 lines)
  Models/EnrichmentResponse.cs   (14 lines)
service-b/ (consumer / server)
  Controllers/EnrichController.cs (44 lines)
  Models/EnrichRequestDto.cs      (16 lines)
  Models/EnrichResponseDto.cs     (12 lines)
```
ServiceBClient.cs:12   `_http.PostAsJsonAsync("/api/enrich", request)`
ServiceBClient.cs:18   `// retries 3× with 500ms backoff on 503`
EnrichmentRequest.cs:5 `public record EnrichmentRequest(string EntityId, string[] Tags, bool Async);`
EnrichmentResponse.cs:5 `public record EnrichmentResponse(string EntityId, string EnrichedData, bool Success);`
EnrichController.cs:8  `[HttpPost("api/enrich")]`
EnrichController.cs:12 `public async Task<IActionResult> Enrich([FromBody] EnrichRequestDto dto)`
EnrichController.cs:28 `return dto.Async ? Accepted() : Ok(enrichedResponse);`
EnrichRequestDto.cs:5  `public record EnrichRequestDto(string EntityId, string[] Tags, bool Async);`
EnrichResponseDto.cs:5 `public record EnrichResponseDto(string EntityId, string EnrichedData, bool IsSuccess);`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- Schema drift between caller and server: EnrichmentResponse.Success vs EnrichResponseDto.IsSuccess — field names differ; must flag as potential serialization mismatch.
- Dual-response path (Accepted vs Ok) on same endpoint based on Async flag — both must be documented.
- Retry policy (ServiceBClient.cs:18) is a test-relevant behavioral fact; must be extracted.
Expected findings:
- Integration surface: POST /api/enrich (service-a/ServiceBClient.cs:12, service-b/EnrichController.cs:8)
- Request schema: EntityId:string, Tags:string[], Async:bool (service-a/EnrichmentRequest.cs:5 ≈ service-b/EnrichRequestDto.cs:5 — aligned)
- Response DRIFT: service-a expects Success:bool (EnrichmentResponse.cs:5), service-b returns IsSuccess:bool (EnrichResponseDto.cs:5) — potential deserialization failure
- Dual response: Async=true → 202 Accepted, Async=false → 200 Ok (EnrichController.cs:28)
- Retry policy: 3× with 500ms backoff on 503 (ServiceBClient.cs:18)
Verify (mechanical):
- sut-profile.md has schema drift entry with both file:line citations.
- Dual response path documented.
- Retry policy noted with ServiceBClient.cs:18 citation.
Rubric (graded):
- Citation discipline (0–10): schema drift cites both service-a and service-b files → 10; single-service → 5.
- Drift detection (0–10): Success vs IsSuccess field-name mismatch flagged → 10; missed → 0.
- Behavioral completeness (0–10): dual response + retry policy both present → 10; either missing → 5.
Solution sketch: Read both request/response model pairs, compare field names, read EnrichController for conditional return, read ServiceBClient for retry policy, emit integration surface with drift annotation.

---

### A-133: Complex Env-Var Resolution Chain with Secrets
Tier: T5
Goal: Resolve the full env-var chain (code defaults → appsettings → Helm values → K8s ConfigMap → K8s Secret) for a single service and produce runtime-config.md with each layer cited and secrets emitted as numbered questions.
Provided artifacts:
```
payment-gateway/
  src/appsettings.json              (22 lines)
  helm/values.yaml                  (24 lines)
  helm/values-production.yaml       (16 lines)
  k8s/configmap.yaml                (18 lines)
  k8s/deployment.yaml               (58 lines)
```
appsettings.json:6       `"GatewayUrl": "https://sandbox.gateway.io", "Timeout": 15, "MaxRetries": 3`
helm/values.yaml:8       `env: { GATEWAY_URL: "https://staging.gateway.io", TIMEOUT: "30" }`
helm/values-production.yaml:6  `env: { GATEWAY_URL: "https://prod.gateway.io", MAX_RETRIES: "5" }`
k8s/configmap.yaml:6     `data: { GATEWAY_URL: "https://blue.prod.gateway.io", LOG_LEVEL: "warn" }`
k8s/deployment.yaml:22   `envFrom: [{ configMapRef: { name: payment-config } }]`
k8s/deployment.yaml:26   `env: [{ name: GATEWAY_URL, valueFrom: { configMapKeyRef: { name: payment-config, key: GATEWAY_URL } } }]`
k8s/deployment.yaml:30   `- name: STRIPE_KEY  valueFrom: { secretKeyRef: { name: payment-secret, key: stripe_api_key } }`
k8s/deployment.yaml:32   `- name: WEBHOOK_SECRET valueFrom: { secretKeyRef: { name: payment-secret, key: webhook_secret } }`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- GATEWAY_URL appears in 5 different places; final effective value is k8s/configmap.yaml:6 (blue.prod.gateway.io) per K8s explicit-env-overrides-envFrom rule applied on top of Helm injection.
- TIMEOUT: set in helm/values.yaml:8 (=30); not in production overlay or configmap — effective = 30; not 15 from appsettings (runtime env overrides).
- MAX_RETRIES: production Helm overlay=5; not in configmap; effective=5; must not default to appsettings:3.
Expected findings:
- GATEWAY_URL effective: https://blue.prod.gateway.io (configmap.yaml:6 → deployment.yaml:26, overrides all prior layers)
- TIMEOUT effective: 30 (helm/values.yaml:8, overrides appsettings:15 at runtime)
- MAX_RETRIES effective: 5 (helm/values-production.yaml:6, not overridden by configmap)
- LOG_LEVEL effective: warn (configmap.yaml:6, envFrom)
- Open question #1: STRIPE_KEY — secretKeyRef payment-secret/stripe_api_key (deployment.yaml:30)
- Open question #2: WEBHOOK_SECRET — secretKeyRef (deployment.yaml:32)
- CAUTION: rendered without helm template
Verify (mechanical):
- runtime-config.md shows 5-layer provenance for GATEWAY_URL.
- TIMEOUT and MAX_RETRIES effective values correct with source citation.
- Both secrets emitted as numbered questions, not invented.
Rubric (graded):
- Citation discipline (0–10): GATEWAY_URL provenance chain traces all 5 files with lines → 10; any layer skipped → 2 off each.
- Precedence accuracy (0–10): all 4 non-secret vars have correct final values → 10; any wrong → 0.
- Never-fill-gaps (0–10): both secrets as open questions → 10; any invented → 0.
Solution sketch: Build 5-layer resolution table (appsettings → Helm base → Helm prod → ConfigMap envFrom → explicit env), apply K8s override rules, trace GATEWAY_URL through all layers, emit secrets as questions.

---

### A-134: Deep Broker Topology — Dead Letter Queues and Retry Exchanges
Tier: T5
Goal: Extract the complete RabbitMQ topology including dead-letter exchanges (DLX), retry queues, and TTL settings from code, producing sut-profile.md with full topology map and file:line citations.
Provided artifacts:
```
order-processor/
  Infrastructure/
    BrokerTopology.cs  (82 lines)
    RetryPolicy.cs     (28 lines)
```
BrokerTopology.cs:12  `channel.ExchangeDeclare("orders.main", ExchangeType.Direct, durable: true);`
BrokerTopology.cs:18  `channel.ExchangeDeclare("orders.dlx", ExchangeType.Fanout, durable: true);`
BrokerTopology.cs:24  `channel.ExchangeDeclare("orders.retry", ExchangeType.Direct, durable: true);`
BrokerTopology.cs:30  `var args = new Dictionary<string,object> { {"x-dead-letter-exchange","orders.dlx"}, {"x-message-ttl", 30000} };`
BrokerTopology.cs:36  `channel.QueueDeclare("orders.process", durable: true, arguments: args);`
BrokerTopology.cs:42  `channel.QueueDeclare("orders.dead", durable: true);`
BrokerTopology.cs:48  `channel.QueueBind("orders.dead", "orders.dlx", "");`
BrokerTopology.cs:54  `channel.QueueDeclare("orders.retry-1", durable: true, arguments: new() { {"x-dead-letter-exchange","orders.main"}, {"x-message-ttl",5000} });`
RetryPolicy.cs:10     `// After 3 NACK, message routed to orders.dlx automatically`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- DLX routing: orders.process → orders.dlx (Fanout) → orders.dead; model must trace the full path.
- Retry queue orders.retry-1 has DLX pointing back to orders.main — creates retry loop; must note this semantics.
- TTL values (30000ms, 5000ms) are test-timing-relevant; must extract and note in ms.
Expected findings:
- Exchange orders.main: Direct, durable (BrokerTopology.cs:12)
- Exchange orders.dlx: Fanout, durable (BrokerTopology.cs:18)
- Exchange orders.retry: Direct, durable (BrokerTopology.cs:24)
- Queue orders.process: DLX=orders.dlx, TTL=30000ms (BrokerTopology.cs:30,36)
- Queue orders.dead: bound to orders.dlx (BrokerTopology.cs:42,48)
- Queue orders.retry-1: DLX=orders.main (retry loop), TTL=5000ms (BrokerTopology.cs:54)
- Retry note: after 3 NACKs → orders.dlx (RetryPolicy.cs:10)
Verify (mechanical):
- sut-profile.md has full topology diagram (text) covering all 3 exchanges + 3 queues.
- Retry loop noted on orders.retry-1.
- TTL values in ms with citations.
Rubric (graded):
- Citation discipline (0–10): each exchange/queue/binding/TTL cites BrokerTopology.cs:line → 10.
- Retry-loop detection (0–10): orders.retry-1 DLX→orders.main loop identified → 10; missed → 0.
- TTL extraction (0–10): both TTL values (30000, 5000) extracted with units → 10; missing → 5.
Solution sketch: Read BrokerTopology.cs sequentially, map ExchangeDeclare→exchange attrs, QueueDeclare→queue attrs including x-dead-letter-exchange and x-message-ttl, QueueBind→bindings, RetryPolicy.cs for NACK count, compose topology narrative.

---

### A-135: Full Coverage-Gap Analysis with Create/Repair/Update
Tier: T5
Goal: Given an existing mixed test suite (QaaS YAML + NUnit) and a 6-surface SUT profile, classify every gap as create/repair/update with rationale and produce coverage-gaps.md with per-gap file:line citations.
Provided artifacts:
```
tests/
  api-tests/
    orders-happy.qaas.yaml    (42 lines)
    orders-error.qaas.yaml    (36 lines)
  unit-tests/
    OrderValidatorTests.cs    (58 lines)
qaas-analysis/
  sut-profile.md  (6 surfaces: POST /orders, GET /orders/{id}, DELETE /orders/{id}, queue order.events, gRPC PlaceOrder, GET /health)
```
orders-happy.qaas.yaml:4      `Name: CreateOrder_Returns201`
orders-happy.qaas.yaml:18     `HttpStatus: { ExpectedStatus: 201, OutputName: "r" }`
orders-error.qaas.yaml:4      `Name: CreateOrder_InvalidBody_Returns400`
orders-error.qaas.yaml:18     `HttpStatus: { StatusCode: 400, OutputNames: ["r"] }`
orders-error.qaas.yaml:22     `# no output-count guard`
OrderValidatorTests.cs:12     `[Test] public void Validate_MissingCustomerId_ReturnsError()`
OrderValidatorTests.cs:26     `[Test] public void Validate_NegativeAmount_ReturnsError()`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s09, s10, s13
Hard because:
- orders-happy.qaas.yaml uses drift-trap keys ExpectedStatus + OutputName (singular) → repair.
- orders-error.qaas.yaml has correct keys but missing output-count guard → repair.
- NUnit tests cover internal validator, not HTTP surface → do not map to GET/DELETE surfaces.
- 4 surfaces (GET /orders/{id}, DELETE /orders/{id}, queue order.events, gRPC PlaceOrder) have zero test coverage → create.
Expected findings:
- REPAIR: CreateOrder_Returns201 — ExpectedStatus→StatusCode, OutputName→OutputNames drift (#4) (orders-happy.qaas.yaml:18)
- REPAIR: CreateOrder_InvalidBody_Returns400 — missing HermeticByExpectedOutputCount guard (orders-error.qaas.yaml:22)
- CREATE: GET /orders/{id} — no test
- CREATE: DELETE /orders/{id} — no test
- CREATE: queue order.events — no test
- CREATE: gRPC PlaceOrder — no test
- COVERED: GET /health — open question (no test found but surface listed; classify as create)
Verify (mechanical):
- coverage-gaps.md ## Repair has 2 entries, ## Create has 5 entries.
- Each repair entry references specific drift trap.
- NUnit tests correctly not mapped to HTTP surfaces.
Rubric (graded):
- Citation discipline (0–10): every gap entry cites file:line → 10; any uncited → 0.
- Drift-trap specificity (0–10): repair entries name specific drift-table entry number → 10; vague → 5.
- Gap completeness (0–10): all 5 create gaps identified → 10; any missed → 2 off each.
Solution sketch: Read both QaaS YAML files for assertion key checks vs Fact Base drift table, check for output-count guard presence, read NUnit tests and confirm they test internal logic only, diff 6-surface catalog, classify all gaps.

---

### A-136: Polyglot SUT — gRPC + HTTP + RabbitMQ Surface Extraction
Tier: T5
Goal: Extract all three protocol surfaces (gRPC, HTTP REST, RabbitMQ) from a single C# service, unify them into one sut-profile.md, and annotate which ports each protocol occupies.
Provided artifacts:
```
fulfillment-svc/
  Program.cs                (44 lines)
  proto/fulfillment.proto   (36 lines)
  Controllers/FulfillController.cs  (46 lines)
  Messaging/FulfillConsumer.cs      (32 lines)
  Messaging/BrokerSetup.cs          (28 lines)
```
Program.cs:12  `app.MapGrpcService<FulfillmentServiceImpl>(); // gRPC on port 5001`
Program.cs:14  `app.MapControllers(); // HTTP on port 8080`
Program.cs:16  `// RabbitMQ consumer started via IHostedService`
fulfillment.proto:6   `service FulfillmentService { rpc Fulfill (FulfillRequest) returns (FulfillResponse); }`
FulfillController.cs:8  `[HttpGet("api/fulfillments")] public IActionResult List()`
FulfillController.cs:16 `[HttpPost("api/fulfillments")] public IActionResult Create([FromBody] FulfillDto dto)`
BrokerSetup.cs:10       `channel.ExchangeDeclare("fulfill.events", ExchangeType.Direct);`
BrokerSetup.cs:16       `channel.QueueDeclare("fulfill.requests", durable: true);`
BrokerSetup.cs:20       `channel.QueueBind("fulfill.requests", "fulfill.events", "fulfill.request");`
FulfillConsumer.cs:8    `channel.BasicConsume("fulfill.requests", autoAck: false, consumer: this);`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- Three protocols on two ports; HTTP on 8080 and gRPC on 5001 must be separated in sut-profile.md.
- RabbitMQ consumer runs as IHostedService — not a direct registration; model must infer from BrokerSetup + FulfillConsumer.
- All three surfaces need separate reachability statements.
Expected findings:
- gRPC port 5001: service FulfillmentService, rpc Fulfill (Program.cs:12, fulfillment.proto:6)
- HTTP port 8080: GET /api/fulfillments, POST /api/fulfillments (FulfillController.cs:8,16)
- RabbitMQ: exchange fulfill.events Direct, queue fulfill.requests, routing key fulfill.request, consumer autoAck=false (BrokerSetup.cs:10,16,20; FulfillConsumer.cs:8)
- REACHABILITY: no real endpoint provided — MOCK_REQUIRED for all three surfaces (analysis note)
Verify (mechanical):
- sut-profile.md has three ## Protocols subsections (gRPC / HTTP / RabbitMQ).
- Each subsection cites correct source files and line numbers.
- Port numbers noted per protocol.
Rubric (graded):
- Citation discipline (0–10): all 3 surfaces cite correct file:line → 10.
- Protocol separation (0–10): gRPC and HTTP on different ports clearly separated → 10; merged → 0.
- Broker completeness (0–10): exchange, queue, binding, routing key, and autoAck all present → 10; missing any → 2 off each.
Solution sketch: Read Program.cs for protocol registrations + ports, read fulfillment.proto for gRPC service, grep FulfillController for HTTP routes, read BrokerSetup + FulfillConsumer for full RabbitMQ topology.

---

### A-137: Umbrella Helm Chart — Global vs Subchart Value Precedence + Secret Gap
Tier: T5
Goal: For an umbrella chart with two subcharts, resolve all env vars applying global/subchart precedence rules, identify all secret references, and produce runtime-config.md with precedence chain and numbered questions for secrets.
Provided artifacts:
```
platform-helm/
  Chart.yaml                        (14 lines) [deps: auth, catalog]
  values.yaml                       (34 lines)
  values-production.yaml            (20 lines)
  charts/auth/values.yaml           (22 lines)
  charts/auth/templates/deployment.yaml    (50 lines)
  charts/catalog/values.yaml        (20 lines)
  charts/catalog/templates/deployment.yaml (48 lines)
```
values.yaml:6         `global: { redisHost: "redis.shared", dbHost: "db.shared" }`
values.yaml:12        `auth: { env: { DB_HOST: "auth-db.prod", SESSION_TTL: "3600" } }`
values.yaml:18        `catalog: { env: { DB_HOST: "catalog-db.prod" } }`
values-production.yaml:5 `auth: { env: { SESSION_TTL: "7200" } }`
charts/auth/values.yaml:6  `env: { DB_HOST: "localhost", SESSION_TTL: "1800", REDIS_HOST: "" }`
charts/catalog/values.yaml:5 `env: { DB_HOST: "localhost", CACHE_TTL: "300" }`
auth/templates/deployment.yaml:22  `- name: DB_HOST value: {{ .Values.env.DB_HOST }}`
auth/templates/deployment.yaml:24  `- name: REDIS_HOST value: {{ .Values.global.redisHost }}`
auth/templates/deployment.yaml:26  `- name: JWT_SECRET valueFrom: { secretKeyRef: { name: auth-secret, key: jwt_secret } }`
catalog/templates/deployment.yaml:20 `- name: DB_HOST value: {{ .Values.env.DB_HOST }}`
catalog/templates/deployment.yaml:24 `- name: API_KEY valueFrom: { secretKeyRef: { name: catalog-secret, key: api_key } }`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- auth SESSION_TTL: values-production.yaml:5 (=7200) overrides umbrella values.yaml:12 (=3600) overrides subchart (=1800) — three-layer chain.
- auth REDIS_HOST: template reads .Values.global.redisHost (deployment.yaml:24) → values.yaml:6 global.redisHost=redis.shared; subchart has empty default but global wins.
- Two secrets (JWT_SECRET, API_KEY) across two subcharts — must both be open questions.
Expected findings:
- auth DB_HOST effective: auth-db.prod (values.yaml:12 overrides charts/auth/values.yaml:6)
- auth SESSION_TTL effective (production): 7200 (values-production.yaml:5 > values.yaml:12 > charts/auth/values.yaml:6)
- auth REDIS_HOST effective: redis.shared (values.yaml:6 global via auth/templates/deployment.yaml:24)
- catalog DB_HOST effective: catalog-db.prod (values.yaml:18 overrides charts/catalog/values.yaml:5)
- catalog CACHE_TTL effective: 300 (charts/catalog/values.yaml:5, no override)
- Open question #1: JWT_SECRET — secretKeyRef auth-secret/jwt_secret (auth/templates/deployment.yaml:26)
- Open question #2: API_KEY — secretKeyRef catalog-secret/api_key (catalog/templates/deployment.yaml:24)
Verify (mechanical):
- runtime-config.md has per-subchart tables with 3-layer chain for SESSION_TTL.
- REDIS_HOST traces to global scope.
- Both secrets in open-questions section.
Rubric (graded):
- Citation discipline (0–10): each effective value traces full provenance chain → 10; any layer missing → 2 off.
- Global precedence (0–10): REDIS_HOST correctly sourced from global → 10; from subchart default → 0.
- Never-fill-gaps (0–10): both secrets as open questions → 10; any invented → 0.
Solution sketch: Build 3-layer resolution table per subchart, apply Helm parent-overrides-subchart rule, trace .Values.global.* references in templates, emit secrets as numbered questions.

---

### A-138: Feature Flag Tree Analysis with Dead-Code Detection
Tier: T5
Goal: Map a multi-flag tree (flags that depend on other flags being enabled), detect routes that are unreachable regardless of any single flag due to compound conditions, and produce sut-profile.md with reachability analysis.
Provided artifacts:
```
marketplace-api/
  Program.cs             (46 lines)
  Config/Flags.cs        (28 lines)
  appsettings.json       (24 lines)
```
Program.cs:12  `app.MapGet("/marketplace/search", SearchHandler.Search);`
Program.cs:14  `if (flags.Enabled("marketplace-v2")) { app.MapGet("/marketplace/v2/search", SearchHandler.SearchV2); }`
Program.cs:16  `if (flags.Enabled("marketplace-v2") && flags.Enabled("recommendations")) { app.MapGet("/marketplace/v2/recommend", RecommendHandler.Get); }`
Program.cs:20  `if (flags.Enabled("admin-tools") && !flags.Enabled("readonly-mode")) { app.MapPost("/admin/actions", AdminHandler.Execute); }`
Program.cs:24  `// readonly-mode is always true in production per Flags.cs`
Flags.cs:8    `Defaults = new() { {"marketplace-v2","false"}, {"recommendations","true"}, {"admin-tools","true"}, {"readonly-mode","true"} };`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- /marketplace/v2/recommend requires BOTH marketplace-v2=true AND recommendations=true; with marketplace-v2=false by default, this compound route is unreachable by default even though recommendations=true.
- /admin/actions requires admin-tools=true AND NOT readonly-mode; Flags.cs:8 shows readonly-mode=true always → this route is DEAD by default configuration (never reachable without overriding readonly-mode).
- Program.cs:24 comment confirms readonly-mode always true — must cite comment.
Expected findings:
- GET /marketplace/search: unconditional (Program.cs:12)
- GET /marketplace/v2/search: CONDITIONAL — marketplace-v2 default=false → unreachable by default (Program.cs:14, Flags.cs:8)
- GET /marketplace/v2/recommend: COMPOUND CONDITIONAL — requires marketplace-v2=true AND recommendations=true; marketplace-v2=false → unreachable by default (Program.cs:16, Flags.cs:8)
- POST /admin/actions: EFFECTIVELY DEAD — admin-tools=true but readonly-mode=true always (Program.cs:20,24, Flags.cs:8); do not test without config override
Verify (mechanical):
- sut-profile.md has EFFECTIVELY DEAD classification for /admin/actions with dual citation.
- COMPOUND CONDITIONAL noted for /marketplace/v2/recommend.
- Comment at Program.cs:24 cited in findings.
Rubric (graded):
- Citation discipline (0–10): all 4 routes cite Program.cs:line + Flags.cs:8 → 10.
- Compound-condition analysis (0–10): /v2/recommend flagged as compound (not just single-flag) → 10; oversimplified → 5.
- Dead-code accuracy (0–10): /admin/actions flagged as effectively dead due to always-true readonly-mode → 10; missed → 0.
Solution sketch: Read Program.cs for all conditional registrations, extract compound conditions, read Flags.cs defaults for each flag, evaluate reachability per compound expression, flag /admin/actions as effectively dead citing Program.cs:24 comment.

---

### A-139: Cross-Repo DTO Schema Drift Detection
Tier: T5
Goal: Compare DTOs shared between two repos (producer and consumer) to detect field name, type, or nullability mismatches that would cause runtime serialization failures, and produce sut-profile.md drift section.
Provided artifacts:
```
order-producer/
  Models/OrderCreatedEvent.cs  (20 lines)
consumer-service/
  Models/OrderCreatedMessage.cs (22 lines)
  Models/OrderItemDto.cs        (14 lines)
order-producer/Models/OrderItemModel.cs  (16 lines)
```
OrderCreatedEvent.cs:5    `public record OrderCreatedEvent(Guid OrderId, string CustomerId, List<OrderItemModel> Items, decimal TotalAmount, DateTimeOffset CreatedAt);`
OrderCreatedMessage.cs:5  `public record OrderCreatedMessage(Guid OrderId, string CustomerId, List<OrderItemDto> Items, decimal? TotalAmount, DateTime CreatedAt);`
OrderItemModel.cs:4       `public record OrderItemModel(string Sku, int Quantity, decimal UnitPrice);`
OrderItemDto.cs:4         `public record OrderItemDto(string Sku, int Quantity, decimal UnitPrice, string? Description);`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- TotalAmount: producer=decimal (non-nullable), consumer=decimal? (nullable) — serialization compatible but semantic mismatch (consumer may silently ignore missing value).
- CreatedAt: producer=DateTimeOffset, consumer=DateTime — type mismatch; potential UTC/timezone deserialization failure.
- OrderItemDto has extra field Description:string? not present in producer — consumer silently receives null; must note.
Expected findings:
- DRIFT: TotalAmount — producer decimal (OrderCreatedEvent.cs:5) vs consumer decimal? (OrderCreatedMessage.cs:5); consumer may accept null silently
- DRIFT: CreatedAt — producer DateTimeOffset (OrderCreatedEvent.cs:5) vs consumer DateTime (OrderCreatedMessage.cs:5); UTC offset information lost on deserialization
- EXTRA FIELD: Description in OrderItemDto (OrderItemDto.cs:4) not in OrderItemModel (OrderItemModel.cs:4); consumer receives null
- ALIGNED: OrderId, CustomerId, Sku, Quantity, UnitPrice — matched across both repos
Verify (mechanical):
- sut-profile.md drift section has 3 entries with both-sides citations.
- DateTimeOffset vs DateTime mismatch noted with timezone risk.
- ALIGNED fields listed.
Rubric (graded):
- Citation discipline (0–10): each drift entry cites both producer and consumer file:line → 10; single-side → 5.
- Type-mismatch detection (0–10): DateTimeOffset vs DateTime flagged with serialization risk → 10; missed → 0.
- Extra-field detection (0–10): Description extra field noted → 10; missed → 0.
Solution sketch: Read all 4 model files, align fields by name across producer/consumer pairs, compare types and nullability, flag mismatches with dual-repo citations, list aligned fields.

---

### A-140: Comprehensive README Contract for Finished Test Project
Tier: T5
Goal: Read a completed QaaS test project directory and produce a README.md that documents the test goals, SUT surface covered, runner/mocker versions, how to run, expected outputs, and known limitations — all facts file:line cited from project files.
Provided artifacts:
```
tests/user-registration-suite/
  user-reg.qaas.yaml       (55 lines)
  user-reg.mocker.yaml     (48 lines)
  fixtures/users.json      (18 lines)
  user-reg.csproj          (22 lines)
```
user-reg.qaas.yaml:3    `Name: UserRegistration_HappyPath`
user-reg.qaas.yaml:8    `DataSourceNames: [user-data]`
user-reg.qaas.yaml:24   `HttpStatus: { StatusCode: 201, OutputNames: [reg-resp] }`
user-reg.qaas.yaml:26   `HermeticByExpectedOutputCount: { ExpectedCount: 1, OutputName: reg-resp }`
user-reg.mocker.yaml:6  `Servers: [ { Name: RegMocker, Port: 7100 } ]`
user-reg.mocker.yaml:14 `Route: api/register`
user-reg.mocker.yaml:20 `ProcessorConfiguration: { StatusCode: 201, Body: "..." }`
user-reg.csproj:8       `<PackageReference Include="QaaS.Runner" Version="4.5.1" />`
user-reg.csproj:10      `<PackageReference Include="QaaS.Mocker" Version="2.4.1" />`
fixtures/users.json:3   `[{"username":"alice","email":"alice@test.com"},{"username":"bob","email":"bob@test.com"}]`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s09, s13
Hard because:
- README must note that mocker serves on port 7100 and the runner must be configured to hit that port — test-specific detail extracted from YAML, not generic knowledge.
- Version alignment check: Runner 4.5.1 and Mocker 2.4.1 match Fact Base §9 current versions — must confirm and cite.
- HermeticByExpectedOutputCount guard present — must document in README that vacuous-pass protection is in place.
Expected findings:
- Test name: UserRegistration_HappyPath, covers POST /api/register → 201 (user-reg.qaas.yaml:3,24)
- Mocker: RegMocker on port 7100, stub route api/register, responds 201 (user-reg.mocker.yaml:6,14,20)
- Versions: Runner 4.5.1, Mocker 2.4.1 — aligned with current versions per FB §9 (user-reg.csproj:8,10)
- Fixtures: 2 users (alice, bob) from fixtures/users.json:3
- Output guard present: HermeticByExpectedOutputCount ExpectedCount=1 (user-reg.qaas.yaml:26)
- Run command: `dotnet test` from project directory
Verify (mechanical):
- README.md contains sections: Goal, SUT Surface, Mocker Config, Versions, How to Run, Fixtures, Output Guard, Known Limitations.
- Port 7100 documented with user-reg.mocker.yaml:6 citation.
- Version alignment confirmed against FB §9.
Rubric (graded):
- Citation discipline (0–10): all README facts cite source file:line → 10; any uncited → 0.
- Version alignment check (0–10): versions confirmed against FB §9 with explicit note → 10; not checked → 0.
- Output-guard documentation (0–10): HermeticByExpectedOutputCount documented with rationale → 10; omitted → 0.
Solution sketch: Read all 4 project files, extract test name/surface/assertions/guard, read csproj for versions, compare to FB §9, read fixtures for count, compose README sections with per-fact citations.

---

### A-141: Polyglot Kafka Topology (C# + Node + Python)
Tier: T5
Goal: Extract the full Kafka topic topology (topics, consumer groups, partitions, offsets) across three services (C# producer, Node.js transformer, Python consumer) and produce a unified sut-profile.md topology map.
Provided artifacts:
```
data-platform/
  ingestor/ (C# Confluent.Kafka)
    Producers/EventProducer.cs   (36 lines)
    appsettings.json             (14 lines)
  transformer/ (Node.js kafkajs)
    index.js                     (32 lines)
    consumer.js                  (28 lines)
  aggregator/ (Python confluent-kafka)
    consumer.py                  (30 lines)
    config.py                    (16 lines)
```
EventProducer.cs:12  `_producer.Produce("raw-events", new Message<string,string> { Key = evt.SourceId, Value = JsonSerializer.Serialize(evt) });`
EventProducer.cs:18  `// partition count: 8 (set via Kafka admin, not in code)`
appsettings.json:6   `"KafkaBroker": "kafka.prod.internal:9092"`
consumer.js:8        `const consumer = kafka.consumer({ groupId: "transformer-group" });`
consumer.js:12       `await consumer.subscribe({ topic: "raw-events", fromBeginning: false });`
consumer.js:20       `await producer.send({ topic: "transformed-events", messages: [...] });`
consumer.py:6        `consumer = Consumer({ "group.id": "aggregator-group", "auto.offset.reset": "latest" })`
consumer.py:10       `consumer.subscribe(["transformed-events"])`
config.py:5          `KAFKA_BROKER = os.environ.get("KAFKA_BROKER", "localhost:9092")`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- Three different Kafka client libraries (Confluent.Kafka, kafkajs, confluent-kafka-python); must extract topology uniformly despite API differences.
- Partition count (8) is in a code comment, not in client config — must extract from comment with caveat.
- Python default broker is localhost:9092 from config.py:5 — different from C# broker; open question for production value.
Expected findings:
- Topic raw-events: C# producer (EventProducer.cs:12), Node transformer consumer groupId=transformer-group (consumer.js:8,12)
- Topic transformed-events: Node transformer producer (consumer.js:20), Python aggregator consumer groupId=aggregator-group (consumer.py:10)
- Partition count: 8 per comment (EventProducer.cs:18) — caveat: set via admin, not in code
- C# broker: kafka.prod.internal:9092 (appsettings.json:6)
- Python broker default: localhost:9092 — open question #1: KAFKA_BROKER production value (config.py:5)
Verify (mechanical):
- sut-profile.md has unified topology with both topics and 3 services cited.
- Partition comment caveat present.
- Open question for Python broker.
Rubric (graded):
- Citation discipline (0–10): each topic/consumer-group/broker cites language-specific file:line → 10.
- Cross-language uniformity (0–10): all 3 services represented in single topology map → 10; any service missing → 3.
- Comment-caveat discipline (0–10): partition count sourced from comment with caveat → 10; treated as code fact → 3.
Solution sketch: Read EventProducer.cs for produce call + comment, read consumer.js for subscribe + groupId + produce, read consumer.py for subscribe + groupId + offset reset, read both config files for broker settings, compose unified topology.

---

### A-142: Multi-Layer Helm Chart with Global Secrets and Per-Subchart Config
Tier: T5
Goal: Resolve effective configuration for three subcharts across four value layers (subchart defaults → umbrella base → umbrella prod → runtime env), identify all secrets, and produce runtime-config.md.
Provided artifacts:
```
ops-platform/
  Chart.yaml                          (16 lines) [deps: gateway, worker, scheduler]
  values.yaml                         (40 lines)
  values-production.yaml              (28 lines)
  charts/gateway/values.yaml          (20 lines)
  charts/worker/values.yaml           (18 lines)
  charts/scheduler/values.yaml        (16 lines)
  charts/gateway/templates/deploy.yaml (54 lines)
  charts/worker/templates/deploy.yaml  (50 lines)
```
values.yaml:6    `global: { logLevel: "info", metricsPort: 9090 }`
values.yaml:12   `gateway: { env: { RATE_LIMIT: "100", TIMEOUT: "30" } }`
values.yaml:18   `worker: { env: { QUEUE_SIZE: "50", WORKER_THREADS: "4" } }`
values.yaml:24   `scheduler: { env: { CRON_INTERVAL: "60" } }`
values-production.yaml:6   `gateway: { env: { RATE_LIMIT: "500", TIMEOUT: "10" } }`
values-production.yaml:12  `worker: { env: { WORKER_THREADS: "16" } }`
charts/gateway/values.yaml:5   `env: { RATE_LIMIT: "10", TIMEOUT: "60", AUTH_MODE: "basic" }`
charts/worker/values.yaml:5    `env: { QUEUE_SIZE: "10", WORKER_THREADS: "1", REDIS_URL: "redis://localhost" }`
gateway/templates/deploy.yaml:22  `- name: LOG_LEVEL value: {{ .Values.global.logLevel }}`
gateway/templates/deploy.yaml:26  `- name: DB_PASS valueFrom: { secretKeyRef: { name: gw-secret, key: db_pass } }`
worker/templates/deploy.yaml:24   `- name: REDIS_URL value: {{ .Values.env.REDIS_URL }}`
worker/templates/deploy.yaml:28   `- name: WORKER_KEY valueFrom: { secretKeyRef: { name: worker-secret, key: api_key } }`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- gateway AUTH_MODE: subchart default (charts/gateway/values.yaml:5), no umbrella or production override — effective=basic; model must not apply umbrella gateway block to AUTH_MODE.
- worker REDIS_URL: subchart default redis://localhost — not overridden at any umbrella level; effective=localhost; but production REDIS_URL should be an open question.
- scheduler CRON_INTERVAL: only in umbrella values.yaml:24 — no production override; effective=60.
Expected findings:
- gateway RATE_LIMIT: 500 (values-production.yaml:6 overrides values.yaml:12 overrides subchart:10)
- gateway TIMEOUT: 10 (values-production.yaml:6 overrides values.yaml:12 override subchart:60)
- gateway AUTH_MODE: basic (charts/gateway/values.yaml:5, no umbrella override)
- gateway LOG_LEVEL: info (values.yaml:6 global via gateway/templates/deploy.yaml:22)
- worker WORKER_THREADS: 16 (values-production.yaml:12 overrides values.yaml:18 overrides subchart:1)
- worker REDIS_URL: redis://localhost (charts/worker/values.yaml:5) — open question #1: production value
- scheduler CRON_INTERVAL: 60 (values.yaml:24, no override)
- Open question #2: DB_PASS — gw-secret/db_pass; Open question #3: WORKER_KEY — worker-secret/api_key
Verify (mechanical):
- runtime-config.md has 3-subchart table with production effective values.
- AUTH_MODE and REDIS_URL traced to subchart defaults.
- 3 open questions for secrets/unknown prod values.
Rubric (graded):
- Citation discipline (0–10): each effective value traces full layer chain → 10; any gap → 2 off.
- Subchart-default accuracy (0–10): AUTH_MODE and REDIS_URL correctly sourced from subchart defaults → 10; overridden incorrectly → 0.
- Open-question completeness (0–10): all 3 open questions emitted → 10; missing any → 3.
Solution sketch: Build 4-layer table per subchart, apply parent-overrides-subchart rule, trace global.* references via templates, flag subchart defaults not overridden at umbrella level, emit secrets as questions.

---

### A-143: OpenAPI Contradicts Code + Feature Flag Hides Route
Tier: T5
Goal: Identify all OpenAPI/code drifts AND feature-flag-hidden routes in one pass, classify each route's true status (aligned/drifted/conditional/dead), and produce sut-profile.md + surface catalog.
Provided artifacts:
```
search-api/
  openapi.yaml                   (72 lines)
  Program.cs                     (40 lines)
  Controllers/SearchController.cs (58 lines)
  Controllers/AdminController.cs  (36 lines)
  Config/FeatureFlags.cs          (20 lines)
  appsettings.json                (22 lines)
```
openapi.yaml:10   `GET /search → 200 SearchResultDto`
openapi.yaml:18   `POST /search/index → 202 (accepted for indexing)`
openapi.yaml:26   `GET /search/suggest → 200 SuggestionDto`
openapi.yaml:34   `DELETE /admin/index → 204`
Program.cs:14     `app.MapControllers();`
Program.cs:16     `if (flags.Enabled("semantic-search")) app.MapGet("/search/semantic", SearchController.Semantic);`
SearchController.cs:8    `[HttpGet("search")] public IActionResult Search()`
SearchController.cs:18   `[HttpPost("search/index")] public IActionResult Index()`
SearchController.cs:28   `// GET /search/suggest removed in v2 — endpoint deleted`
AdminController.cs:8     `[HttpDelete("admin/index")] public IActionResult DeleteIndex()`
AdminController.cs:16    `// Only enabled when admin-tools flag is true`
FeatureFlags.cs:8        `Defaults = new() { {"semantic-search","false"}, {"admin-tools","false"} };`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- /search/suggest: in OpenAPI but removed in code (SearchController.cs:28) — code wins, drift.
- /search/semantic: NOT in OpenAPI, conditional in code behind semantic-search=false — undocumented AND unreachable by default.
- AdminController: registered by MapControllers but comment says flag-gated (SearchController.cs isn't the right file) — AdminController.cs:16 note; must cross-check against FeatureFlags.cs.
Expected findings:
- GET /search: ALIGNED (openapi.yaml:10, SearchController.cs:8)
- POST /search/index: ALIGNED (openapi.yaml:18, SearchController.cs:18)
- GET /search/suggest: DRIFT — spec 200 (openapi.yaml:26), handler removed (SearchController.cs:28) — do not test
- DELETE /admin/index: CONDITIONAL — in spec (openapi.yaml:34) and code (AdminController.cs:8) but comment-gated by admin-tools=false (AdminController.cs:16, FeatureFlags.cs:8) — unreachable by default
- GET /search/semantic: UNDOCUMENTED + CONDITIONAL — in code behind semantic-search=false (Program.cs:16, FeatureFlags.cs:8), absent from spec
Verify (mechanical):
- sut-profile.md has 5 route entries with distinct statuses.
- /search/suggest has code-wins ruling.
- /search/semantic flagged as undocumented AND conditional.
Rubric (graded):
- Citation discipline (0–10): every route entry cites both relevant files → 10; single source → 5.
- Dual-status detection (0–10): /search/semantic correctly classified as both undocumented and conditional → 10; either status missing → 5.
- Drift ruling (0–10): /search/suggest code-wins ruling with correct citation → 10; spec-wins ruling → 0.
Solution sketch: Enumerate 5 OpenAPI routes, grep SearchController + AdminController for each, check Program.cs conditional registrations, cross-check FeatureFlags.cs defaults, classify each route status.

---

### A-144: Complete SUT Profile for Microservices System
Tier: T5
Goal: Produce a unified sut-profile.md for a 3-service system (API gateway, order service, notification service) covering all protocols, schemas, broker topology, and env config, with every fact file:line cited.
Provided artifacts:
```
platform/
  gateway/ (C# Ocelot)
    ocelot.json              (34 lines)
    Program.cs               (20 lines)
  order-svc/ (C# ASP.NET)
    Controllers/OrderController.cs  (48 lines)
    Models/OrderRequest.cs          (14 lines)
    Messaging/OrderPublisher.cs     (28 lines)
    BrokerSetup.cs                  (24 lines)
  notification-svc/ (Node.js)
    index.js                        (24 lines)
    subscribers/orderSubscriber.js  (26 lines)
```
ocelot.json:8    `{ "UpstreamPathTemplate": "/api/orders/{everything}", "DownstreamPathTemplate": "/orders/{everything}", "DownstreamHostAndPorts": [{"Host":"order-svc","Port":8080}] }`
ocelot.json:18   `{ "UpstreamPathTemplate": "/api/notify/{everything}", "DownstreamPathTemplate": "/notify/{everything}", "DownstreamHostAndPorts": [{"Host":"notify-svc","Port":3000}] }`
OrderController.cs:8   `[HttpPost("orders")] public IActionResult Create([FromBody] OrderRequest req)`
OrderController.cs:18  `[HttpGet("orders/{id}")] public IActionResult Get(string id)`
OrderRequest.cs:5      `public record OrderRequest(string CustomerId, decimal Total, string[] Items);`
OrderPublisher.cs:12   `channel.BasicPublish("order.events", "order.created", body: Encoding.UTF8.GetBytes(json));`
BrokerSetup.cs:8       `channel.ExchangeDeclare("order.events", ExchangeType.Topic, durable: true);`
BrokerSetup.cs:14      `channel.QueueDeclare("order.notifications", durable: true);`
BrokerSetup.cs:18      `channel.QueueBind("order.notifications", "order.events", "order.*");`
orderSubscriber.js:6   `channel.consume("order.notifications", (msg) => { ... })`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- Gateway rewrites paths: external /api/orders/* → internal /orders/* — must document both external and internal paths.
- order.* routing key pattern (Topic exchange) matches all order.* keys including order.created; model must note wildcard semantics.
- Notification service consumes directly from queue (not exchange) — important distinction.
Expected findings:
- External: POST /api/orders, GET /api/orders/{id} (ocelot.json:8) → internal: POST /orders, GET /orders/{id} (OrderController.cs:8,18)
- OrderRequest schema: CustomerId:string, Total:decimal, Items:string[] (OrderRequest.cs:5)
- Exchange order.events: Topic, durable (BrokerSetup.cs:8); routing key order.created published (OrderPublisher.cs:12)
- Queue order.notifications: bound to order.events with key pattern order.* (BrokerSetup.cs:14,18)
- Node consumer: consumes order.notifications (orderSubscriber.js:6)
Verify (mechanical):
- sut-profile.md has gateway rewrite table with external/internal path columns.
- Topic exchange wildcard pattern noted.
- All 3 services represented with their surfaces.
Rubric (graded):
- Citation discipline (0–10): every surface entry cites source file:line from correct service → 10.
- Gateway rewrite accuracy (0–10): path rewrite documented with before/after from ocelot.json → 10; rewrite missed → 0.
- Wildcard semantics (0–10): order.* pattern noted on Topic exchange binding → 10; omitted → 0.
Solution sketch: Read ocelot.json for route rewrites, read OrderController for internal routes, read OrderRequest for schema, read BrokerSetup + OrderPublisher for topology, read orderSubscriber for consumer, compose unified 3-service profile.

---

### A-145: Dead Code and Unreachable Endpoint Multi-Pattern Detection
Tier: T5
Goal: Identify multiple patterns of unreachable endpoints (dead DI, feature-flag-off, OpenAPI-only, route-typo) in one SUT and produce sut-profile.md with DEAD/CONDITIONAL/DRIFT classification for each.
Provided artifacts:
```
catalog-platform/
  Program.cs                       (50 lines)
  Controllers/
    ProductController.cs           (44 lines)
    LegacyProductController.cs     (30 lines)
    InternalController.cs          (28 lines)
  Startup/ServiceRegistration.cs   (22 lines)
  openapi.yaml                     (66 lines)
  Config/Flags.cs                  (18 lines)
```
Program.cs:12   `app.MapControllers();`
Program.cs:14   `if (flags.Enabled("internal-api")) { app.MapControllers(); } // double-register bug — internal routes added only if flag true`
ServiceRegistration.cs:10  `// LegacyProductController deliberately excluded from DI`
ProductController.cs:8     `[HttpGet("products")] public IActionResult List()`
ProductController.cs:16    `[HttpPost("products")] public IActionResult Create()`
LegacyProductController.cs:8  `[HttpGet("products/legacy")] public IActionResult Legacy()`
InternalController.cs:8    `[HttpGet("internal/status")] public IActionResult Status()`
openapi.yaml:10  `GET /products → 200`
openapi.yaml:18  `POST /products → 201`
openapi.yaml:26  `GET /products/legacy → 200`
openapi.yaml:34  `GET /internal/status → 200`
Flags.cs:8       `Defaults = new() { {"internal-api","false"} };`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- LegacyProductController: excluded from DI (ServiceRegistration.cs:10) so routes are dead despite being in OpenAPI (openapi.yaml:26) — two-source dead-code finding.
- InternalController: registered via MapControllers (Program.cs:12) but then also re-registered conditionally (Program.cs:14) — the first MapControllers already registers it; flag does not affect InternalController reachability. However Program.cs:14 comment is a note, not an accurate gating. Must reason carefully.
- /internal/status: InternalController is registered by the unconditional MapControllers at Program.cs:12 — reachable always; the conditional block at Program.cs:14 is the double-register bug, not a gate.
Expected findings:
- GET /products: REACHABLE — ProductController (Program.cs:12, ProductController.cs:8)
- POST /products: REACHABLE — ProductController (Program.cs:12, ProductController.cs:16)
- GET /products/legacy: DEAD — LegacyProductController excluded from DI (ServiceRegistration.cs:10); OpenAPI spec incorrect (openapi.yaml:26) — do not test
- GET /internal/status: REACHABLE — InternalController registered by unconditional MapControllers (Program.cs:12); Program.cs:14 is a bug note, not an actual gate
- BUG NOTED: Program.cs:14 double-registration if internal-api flag enabled — may cause duplicate route registration errors
Verify (mechanical):
- sut-profile.md classifies all 4 routes with citations.
- /products/legacy marked DEAD with both ServiceRegistration.cs:10 and openapi.yaml:26 cited.
- /internal/status marked REACHABLE with reasoning about double-register bug.
Rubric (graded):
- Citation discipline (0–10): each route classification cites its evidence file:line → 10.
- Dead-code detection (0–10): LegacyProductController dead route identified with DI exclusion evidence → 10; missed → 0.
- Reasoning accuracy (0–10): /internal/status correctly identified as reachable via unconditional registration → 10; incorrectly flagged as conditional → 0.
Solution sketch: Read ServiceRegistration.cs for DI exclusions, read Program.cs for MapControllers calls and conditional blocks, reason about which controllers are registered by which call, read OpenAPI for all declared routes, classify each with evidence.

---

### A-146: README Contract for a Finished Multi-Session Test Project
Tier: T5
Goal: Read a complex QaaS test project with multiple sessions, a custom hook, and a mocker, then produce README.md documenting goals, sessions, hook contracts, run commands, expected output counts, and known limitations.
Provided artifacts:
```
tests/checkout-e2e/
  checkout-e2e.qaas.yaml       (72 lines)
  checkout-e2e.mocker.yaml     (55 lines)
  Hooks/
    CheckoutValidator.cs       (44 lines)
  fixtures/
    products.json              (20 lines)
    coupons.json               (14 lines)
  checkout-e2e.csproj          (26 lines)
```
checkout-e2e.qaas.yaml:3   `Name: Checkout_Happy_Path`
checkout-e2e.qaas.yaml:8   `DataSourceNames: [products, coupons]`
checkout-e2e.qaas.yaml:28  `Processors: [ { CustomProcessor: CheckoutValidator } ]`
checkout-e2e.qaas.yaml:35  `HermeticByExpectedOutputCount: { ExpectedCount: 3, OutputName: checkout-resp }`
checkout-e2e.qaas.yaml:48  `Name: Checkout_Coupon_Applied`
checkout-e2e.qaas.yaml:62  `HttpStatus: { StatusCode: 200, OutputNames: [coupon-resp] }`
checkout-e2e.mocker.yaml:8  `Servers: [ { Name: PaymentMocker, Port: 7200 } ]`
checkout-e2e.mocker.yaml:20 `Route: payments/charge`
checkout-e2e.mocker.yaml:30 `ProcessorConfiguration: { StatusCode: 200, Body: "{\"transactionId\":\"{{guid}}\"}" }`
CheckoutValidator.cs:8      `public record CheckoutValidatorConfiguration(string RequiredField, bool StrictMode);`
CheckoutValidator.cs:14     `public ValidationResult Process(CheckoutOutput output, CheckoutValidatorConfiguration config)`
checkout-e2e.csproj:8       `<PackageReference Include="QaaS.Runner" Version="4.5.1" />`
checkout-e2e.csproj:10      `<PackageReference Include="QaaS.Mocker" Version="2.4.1" />`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s09, s13
Hard because:
- Two test sessions (Happy_Path and Coupon_Applied) have different assertion patterns; README must document both.
- CheckoutValidator is a custom processor hook; README must document its configuration contract (RequiredField, StrictMode) from CheckoutValidator.cs:8.
- products.json and coupons.json are two separate data sources; both must be documented with their paths.
Expected findings:
- Session 1: Checkout_Happy_Path, 3 expected outputs, custom processor CheckoutValidator (checkout-e2e.qaas.yaml:3,35,28)
- Session 2: Checkout_Coupon_Applied, HttpStatus 200 (checkout-e2e.qaas.yaml:48,62)
- Mocker: PaymentMocker port 7200, stub route payments/charge → 200 with guid template (checkout-e2e.mocker.yaml:8,20,30)
- Hook contract: CheckoutValidatorConfiguration(RequiredField:string, StrictMode:bool) (CheckoutValidator.cs:8)
- Data sources: products.json (2 lines = fixtures/products.json), coupons.json (fixtures/coupons.json)
- Versions: Runner 4.5.1, Mocker 2.4.1 per FB §9 (checkout-e2e.csproj:8,10)
Verify (mechanical):
- README.md has sections for both sessions, mocker config, hook contract, data sources, versions.
- CheckoutValidator config fields documented from CheckoutValidator.cs:8.
- Port 7200 cited from mocker YAML.
Rubric (graded):
- Citation discipline (0–10): all README facts cite source file:line → 10; any uncited → 0.
- Hook-contract documentation (0–10): RequiredField and StrictMode params documented with types → 10; omitted → 0.
- Multi-session accuracy (0–10): both sessions with distinct assertion details → 10; merged or missing one → 5.
Solution sketch: Read both YAML sessions, read mocker YAML for stub config, read CheckoutValidator.cs for hook record, read csproj for versions, compose README with per-fact citations for all sections.

---

### A-147: Integration Surface Between Two Services with Shared Contract Repo
Tier: T5
Goal: Derive the integration surface between two services that share a contracts NuGet package, identify schema versions in use, flag any version mismatches, and produce sut-profile.md integration surface section.
Provided artifacts:
```
service-a/ (producer)
  ServiceA.csproj            (18 lines)
  Publishers/EventPublisher.cs (28 lines)
service-b/ (consumer)
  ServiceB.csproj            (18 lines)
  Consumers/EventConsumer.cs  (26 lines)
shared-contracts/ (NuGet package)
  src/
    Events/OrderShippedEvent.cs  (16 lines)
    Events/OrderCancelledEvent.cs (14 lines)
```
ServiceA.csproj:10           `<PackageReference Include="Shared.Contracts" Version="2.1.0" />`
ServiceB.csproj:10           `<PackageReference Include="Shared.Contracts" Version="2.0.0" />`
EventPublisher.cs:10         `_bus.Publish(new OrderShippedEvent { OrderId = id, ShippedAt = DateTimeOffset.UtcNow, CarrierId = carrier });`
EventConsumer.cs:8           `public class EventConsumer : IConsumer<OrderShippedEvent>`
OrderShippedEvent.cs:5       `public record OrderShippedEvent(Guid OrderId, DateTimeOffset ShippedAt, string CarrierId, string? TrackingUrl);`
OrderCancelledEvent.cs:5     `public record OrderCancelledEvent(Guid OrderId, DateTimeOffset CancelledAt, string Reason);`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s13, s16
Hard because:
- Service A uses contracts v2.1.0, Service B uses v2.0.0 — version mismatch; if v2.1.0 added TrackingUrl field, B's v2.0.0 consumer may not have that field — must flag.
- TrackingUrl:string? in OrderShippedEvent is nullable — if added in v2.1.0, B consumer silently receives null; must note.
- OrderCancelledEvent: published by A? — not evident from Publisher.cs; open question.
Expected findings:
- Integration surface: OrderShippedEvent via broker (EventPublisher.cs:10, EventConsumer.cs:8)
- Schema: OrderId:Guid, ShippedAt:DateTimeOffset, CarrierId:string, TrackingUrl:string? (OrderShippedEvent.cs:5)
- VERSION MISMATCH: ServiceA uses Shared.Contracts 2.1.0 (ServiceA.csproj:10), ServiceB uses 2.0.0 (ServiceB.csproj:10) — potential field-missing deserialization issue for TrackingUrl
- Open question #1: is TrackingUrl new in 2.1.0? — check contracts changelog
- Open question #2: does ServiceA publish OrderCancelledEvent? — not found in EventPublisher.cs
Verify (mechanical):
- sut-profile.md has version mismatch entry with both csproj citations.
- TrackingUrl nullable noted with deserialization risk.
- Open questions section with ≥2 entries.
Rubric (graded):
- Citation discipline (0–10): version mismatch cites both ServiceA.csproj:10 and ServiceB.csproj:10 → 10.
- Version-mismatch detection (0–10): mismatch flagged with risk assessment → 10; missed → 0.
- Open-question discipline (0–10): changelog and OrderCancelledEvent questions emitted → 10; answers invented → 0.
Solution sketch: Read both csproj files for Shared.Contracts version, read OrderShippedEvent for fields, compare versions, note nullable field risk, read EventPublisher/Consumer to confirm which events are used, emit open questions.

---

### A-148: Test Data Lineage Across Multiple Sessions and Fixtures
Tier: T5
Goal: Trace test data from fixture files through DataSourceNames/Storages/Generators for a multi-session QaaS YAML and document the complete data lineage for each session in test-inventory.md.
Provided artifacts:
```
tests/billing-suite/
  billing.qaas.yaml       (85 lines)
  fixtures/
    invoices.json         (22 lines)
    customers.csv         (16 lines)
    adjustment-template.json (10 lines)
```
billing.qaas.yaml:6     `DataSourceNames: [invoices, customers]`
billing.qaas.yaml:10    `Storages: [ - FileSystem: { Path: ./fixtures } ]`
billing.qaas.yaml:18    `Name: GenerateInvoice_Session`
billing.qaas.yaml:22    `Generators: [ { JsonFileGenerator: { FileName: invoices.json } } ]`
billing.qaas.yaml:30    `Name: ApplyAdjustment_Session`
billing.qaas.yaml:36    `Generators: [ { JsonFileGenerator: { FileName: adjustment-template.json } } ]`
billing.qaas.yaml:44    `Name: CustomerLookup_Session`
billing.qaas.yaml:50    `Generators: [ { CsvFileGenerator: { FileName: customers.csv, Delimiter: "," } } ]`
billing.qaas.yaml:62    `HermeticByExpectedOutputCount: { ExpectedCount: 4, OutputName: inv-resp }`
invoices.json:3         `[{"invoiceId":"INV-001","amount":500.00},{"invoiceId":"INV-002","amount":250.00},{"invoiceId":"INV-003","amount":750.00},{"invoiceId":"INV-004","amount":125.00}]`
customers.csv:1         `customerId,name,tier`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s09, s13
Hard because:
- Three sessions use three different fixture files via different generators (JsonFileGenerator x2, CsvFileGenerator); lineage per session must be distinct.
- invoices.json has 4 records → HermeticByExpectedOutputCount=4 is consistent; model must verify and note.
- DataSourceNames lists [invoices, customers] but adjustment-template.json is a third fixture not in DataSourceNames — must flag as open question (is it a named source?).
Expected findings:
- Session GenerateInvoice: data from invoices.json (4 records), JsonFileGenerator (billing.qaas.yaml:22, invoices.json:3)
- Session ApplyAdjustment: data from adjustment-template.json, JsonFileGenerator (billing.qaas.yaml:36); open question #1: not listed in DataSourceNames
- Session CustomerLookup: data from customers.csv, CsvFileGenerator, delimiter=, (billing.qaas.yaml:50)
- HermeticByExpectedOutputCount=4 matches invoices.json record count (billing.qaas.yaml:62, invoices.json:3)
- DataSourceNames: [invoices, customers] — adjustment-template not listed (billing.qaas.yaml:6)
Verify (mechanical):
- test-inventory.md data-lineage column has distinct entry per session.
- Record count 4 noted with cross-reference to invoices.json.
- Open question for adjustment-template.json DataSourceNames status.
Rubric (graded):
- Citation discipline (0–10): each session cites YAML:line + fixture:line → 10.
- Count verification (0–10): 4-record count traced from invoices.json:3 to HermeticByExpectedOutputCount=4 → 10; not verified → 0.
- Open-question discipline (0–10): adjustment-template DataSourceNames gap noted as open question → 10; silently ignored → 0.
Solution sketch: Read billing.qaas.yaml session blocks, identify generator type + filename per session, read invoices.json for record count, verify against output guard, check DataSourceNames for completeness, emit per-session lineage rows.

---

### A-149: Mixed Assertion Repair + New Test Creation Plan
Tier: T5
Goal: For an existing QaaS YAML with both broken assertions and uncovered surfaces, produce coverage-gaps.md that precisely separates repair items (citing the specific drift trap) from create items (citing the missing surface from sut-profile.md).
Provided artifacts:
```
tests/
  products-suite.qaas.yaml  (65 lines)
  search-test.qaas.yaml     (40 lines)
qaas-analysis/
  sut-profile.md  (surfaces: GET /products, POST /products, DELETE /products/{id}, GET /products/search, queue product.events, gRPC StreamProducts)
```
products-suite.qaas.yaml:18  `HttpStatus: { ExpectedStatus: 200, OutputName: "plist" }`
products-suite.qaas.yaml:28  `HttpStatus: { StatusCode: 201, OutputNames: ["pcreate"] }`
products-suite.qaas.yaml:34  `# no HermeticByExpectedOutputCount on create session`
products-suite.qaas.yaml:45  `Route: /products`
search-test.qaas.yaml:10     `Route: products/search`
search-test.qaas.yaml:24     `HttpStatus: { StatusCode: 200, OutputNames: ["sres"] }`
search-test.qaas.yaml:30     `HermeticByExpectedOutputCount: { ExpectedCount: 5, OutputName: sres }`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s09, s13
Hard because:
- products-suite line 18: ExpectedStatus + OutputName (singular) — drift trap #4 → repair.
- products-suite line 45: leading slash on Route → drift trap #5 → repair.
- products-suite line 34: missing output guard on POST session → drift trap #12 → repair.
- search-test correctly uses StatusCode + OutputNames + guard → covered.
- DELETE, queue, gRPC surfaces have no tests → create.
Expected findings:
- REPAIR: products-suite line 18 — ExpectedStatus→StatusCode, OutputName→OutputNames (drift #4, products-suite.qaas.yaml:18)
- REPAIR: products-suite line 45 — leading slash on Route (drift #5, products-suite.qaas.yaml:45)
- REPAIR: products-suite line 34 — missing output-count guard on POST session (drift #12, products-suite.qaas.yaml:28,34)
- CREATE: DELETE /products/{id} — no test exists
- CREATE: queue product.events — no test
- CREATE: gRPC StreamProducts — no test
- COVERED: GET /products (after repair), GET /products/search (search-test.qaas.yaml:10)
Verify (mechanical):
- coverage-gaps.md ## Repair has 3 entries each with drift trap number.
- ## Create has 3 entries.
- ## Covered has 2 entries.
Rubric (graded):
- Citation discipline (0–10): every gap entry cites file:line → 10; any uncited → 0.
- Drift-trap specificity (0–10): each repair entry names drift trap # → 10; vague description only → 3 each.
- Create/covered accuracy (0–10): search-test correctly in Covered (not Repair) → 10; misclassified → 0.
Solution sketch: Read products-suite.qaas.yaml line by line checking assertion keys, Route leading slash, and output guards against drift table; classify each violation; diff 6-surface catalog against covered tests; emit repair/create/covered sections.

---

### A-150: Full Polyglot 3-Repo Analysis — Effective Config + Surface Catalog + Gap Diff
Tier: T5
Goal: Given three repos (C# API, Go service, Python worker) plus Helm chart, produce: (1) effective-config table for all services, (2) complete surface catalog across all repos and protocols, (3) coverage gap diff against an existing partial test suite — every row file:line cited.
Provided artifacts:
```
enterprise-platform/
  helm/
    Chart.yaml                   (14 lines) [deps: api, go-svc, py-worker]
    values.yaml                  (36 lines)
    values-production.yaml       (24 lines)
  api/ (C# ASP.NET)
    Program.cs                   (34 lines)
    Controllers/EntryController.cs (46 lines)
    proto/entry.proto             (28 lines)
    Models/EntryDto.cs            (18 lines)
  go-svc/ (Go net/http)
    main.go                      (40 lines)
    handlers/transform.go        (32 lines)
  py-worker/ (Python Celery/RabbitMQ)
    worker.py                    (36 lines)
    topology.py                  (22 lines)
  tests/
    entry-smoke.qaas.yaml        (48 lines)
    entry-error.qaas.yaml        (35 lines)
```
values.yaml:8           `api: { env: { DB_HOST: "api-db.prod", GRPC_PORT: "5001" } }`
values-production.yaml:6 `api: { env: { DB_HOST: "api-db-ha.prod" } }`
values.yaml:14          `go-svc: { env: { TRANSFORM_WORKERS: "4", UPSTREAM_URL: "http://api:8080" } }`
values.yaml:20          `py-worker: { env: { RABBIT_HOST: "rabbitmq.prod", QUEUE: "entries.process" } }`
Program.cs:14   `app.MapGrpcService<EntryServiceImpl>(); // port 5001`
Program.cs:16   `app.MapControllers(); // port 8080`
EntryController.cs:8   `[HttpPost("api/entries")] public IActionResult Create([FromBody] EntryDto dto)`
EntryController.cs:18  `[HttpGet("api/entries/{id}")] public IActionResult Get(string id)`
entry.proto:6   `service EntryService { rpc StreamEntries (StreamRequest) returns (stream EntryRecord); }`
main.go:14      `http.HandleFunc("/transform", transformHandler)`
transform.go:8  `func transformHandler(w http.ResponseWriter, r *http.Request) { // POST only`
worker.py:8     `@app.task(name="worker.process_entry", queue="entries.process")`
topology.py:8   `channel.ExchangeDeclare("entries.exchange", "direct")`
topology.py:12  `channel.QueueBind("entries.process", "entries.exchange", "entry.process")`
entry-smoke.qaas.yaml:4   `Name: CreateEntry_Happy`
entry-smoke.qaas.yaml:18  `HttpStatus: { ExpectedStatus: 201, OutputName: "er" }`
entry-error.qaas.yaml:4   `Name: CreateEntry_Invalid`
entry-error.qaas.yaml:18  `HttpStatus: { StatusCode: 400, OutputNames: ["er"] }`
entry-error.qaas.yaml:24  `HermeticByExpectedOutputCount: { ExpectedCount: 1, OutputName: er }`
MOCK_REQUIRED: n/a (analysis)
FB slices: s00, s09, s13, s16
Hard because:
- Three different languages require separate grep approaches; model must read Go handler to confirm POST-only.
- entry-smoke uses drift-trap keys (ExpectedStatus + OutputName singular) → repair; entry-error has correct keys and guard → covered.
- Production DB_HOST for api: values-production.yaml:6 (api-db-ha.prod) overrides values.yaml:8 (api-db.prod); GRPC_PORT not overridden — effective 5001 from values.yaml:8.
Expected findings:
- api DB_HOST effective (production): api-db-ha.prod (values-production.yaml:6 overrides values.yaml:8)
- api GRPC_PORT: 5001 (values.yaml:8, not overridden)
- Surface: POST /api/entries, GET /api/entries/{id} (EntryController.cs:8,18) port 8080
- Surface: gRPC StreamEntries server-streaming (entry.proto:6, Program.cs:14) port 5001
- Surface: Go POST /transform (main.go:14, transform.go:8) with UPSTREAM_URL=http://api:8080 (values.yaml:14)
- Surface: Celery task worker.process_entry, queue entries.process (worker.py:8, topology.py:8,12)
- REPAIR: entry-smoke ExpectedStatus→StatusCode, OutputName→OutputNames (drift #4, entry-smoke.qaas.yaml:18)
- COVERED (after repair): POST /api/entries; CREATE: GET /api/entries/{id}, gRPC, Go /transform, queue
Verify (mechanical):
- sut-profile.md has all 4 services/surfaces with per-language citations.
- runtime-config.md has api DB_HOST with 2-layer provenance, GRPC_PORT from base layer.
- coverage-gaps.md has 1 repair + 4 create + 1 covered (after repair).
Rubric (graded):
- Citation discipline (0–10): every row in all three deliverables cites file:line from correct language → 10; any uncited → 0.
- Config resolution accuracy (0–10): DB_HOST=api-db-ha.prod correct; GRPC_PORT=5001 from base layer → 10; wrong → 0.
- Gap completeness + drift specificity (0–10): repair entry names drift #4; 4 create gaps all present → 10; any missed → 2 off each.
Solution sketch: Resolve Helm 2-layer config per service, extract routes from all 3 languages, extract RabbitMQ topology from topology.py, check both YAML test files against drift table, diff 5-surface catalog, emit all three deliverables with per-fact citations.
