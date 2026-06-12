# Batch R — Advanced Runner-YAML Scenarios (R-101..R-150)
# Category: runner-yaml | MOCK_REQUIRED: no (all scenarios)
# Tier mix: T3×10 (R-101..110), T4×20 (R-111..130), T5×20 (R-131..150)
# Generated against FB s02 + s13 | .NET 10.0.203 / Runner 4.5.1

### R-101: Sequential Two-Session HTTP Chain
Tier: T3
Goal: Runner YAML chains two sessions where session-2 uses FileSystem storage written by session-1 to assert a derived value.
SUT: Static HTTP echo service on port 8110; POST /echo returns request body; GET /last returns last posted body.
MOCK_REQUIRED: no
FB slices: s02 §2.4, §2.6
Trap mines: s13#2 (Storages shape), s13#3 (DataSourceNames required)
Hard because:
- Must use correct FileSystem storage shape (not outdated Name/StorageConfiguration form)
- Session-2 act must read same Storage path session-1 act wrote; case subfolder rules apply
Verify (mechanical):
- `dotnet run -- template Storages` output matches `- FileSystem: {Path: ...}` shape
- e2e run ExitCode=0; session-data folder contains two subdirs
Rubric (graded):
- Storages declared with correct FileSystem shape (not legacy Name: form) [4 pts]
- Session-2 DataSourceNames references session-1 output correctly [3 pts]
- HermeticByExpectedOutputCount guard present on both sessions [3 pts]
Solution sketch: Use `Storages: - FileSystem: {Path: ./session-data}` (s02§2.4); session-2 Generator: FromFileSystem reading ./session-data/session-1-name; add count-guard assertion.

### R-102: Environment Overwrite File (-w flag)
Tier: T3
Goal: Author a runner YAML + two overwrite files (local.yaml, staging.yaml) varying BaseAddress and port; demonstrate correct -w flag invocation.
SUT: HTTP health endpoint; different hosts per environment.
MOCK_REQUIRED: no
FB slices: s02 §2.11
Trap mines: s13#12 (typo keys silently ignored in overwrite)
Hard because:
- Overwrite files must use plain `.yaml` extension (not `.qaas.yaml`)
- Anchors do NOT work across overwrite files
- Key typo in overwrite silently ignored → wrong value used without error
Verify (mechanical):
- Run with `-w Variables/local.yaml` → BaseAddress resolves to localhost value
- Run with `-w Variables/staging.yaml` → BaseAddress resolves to staging value
Rubric (graded):
- Overwrite files use correct path-key notation (e.g., `Sessions:0:Transactions:0:Http:BaseAddress`) [4 pts]
- Both files correct extension `.yaml` [3 pts]
- No anchors used across overwrite boundary [3 pts]
Solution sketch: Per s02§2.11, overwrite files use path-key notation; declare variables section in main YAML with `${variables:host}` placeholder; supply actual values in overwrite files.

### R-103: Cases Matrix for Status-Code Testing (-c flag)
Tier: T3
Goal: Use -c cases folder to drive three HTTP transactions (200/400/500 routes) from separate case YAML files.
SUT: HTTP service with /ok (200), /bad (400), /fail (500) routes.
MOCK_REQUIRED: no
FB slices: s02 §2.11
Trap mines: s13#4 (HttpStatus fields StatusCode/OutputNames), s13#5 (leading slash)
Hard because:
- Cases override DataSources and route variables; path-key notation must be exact
- HttpStatus assertion uses `StatusCode:` + `OutputNames:` (list), not outdated `ExpectedStatus:` + `OutputName:`
Verify (mechanical):
- Three case runs visible in Allure; each shows correct HTTP status
- No case shows vacuous pass (0 outputs)
Rubric (graded):
- Case files use correct path-key override syntax [4 pts]
- HttpStatus assertion uses `StatusCode:` + `OutputNames:` (not outdated form) [3 pts]
- Each case has HermeticByExpectedOutputCount guard [3 pts]
Solution sketch: Create cases/ folder with 200.yaml/400.yaml/500.yaml each overriding `Sessions:0:Transactions:0:Http:Route` and `Assertions:0:AssertionConfiguration:StatusCode`; run with `-c cases`.

### R-104: HermeticByExpectedOutputCount Boundary Math
Tier: T3
Goal: Prove understanding of hermetic count guard by authoring a YAML where Iterations=5 and count guard expects exactly 5.
SUT: HTTP GET /item/{id} returning JSON; 5 requests expected.
MOCK_REQUIRED: no
FB slices: s02 §2.5, §2.9
Trap mines: s13#13 (vacuous pass), s13#3 (DataSourceNames required)
Hard because:
- Must set Iterations=5 on transaction AND guard with HermeticByExpectedOutputCount{ExpectedCount:5}
- DataSourceNames required on Transaction even with single datasource
Verify (mechanical):
- e2e run shows 5 outputs in session data
- Guard assertion passes with count=5; fails if connection drops (0 outputs)
Rubric (graded):
- HermeticByExpectedOutputCount with ExpectedCount matching Iterations [4 pts]
- Transaction DataSourceNames populated (not omitted) [3 pts]
- Assertion SessionNames references correct session [3 pts]
Solution sketch: DataSource with FromFileSystem providing 5 input files; Transaction Iterations:5 DataSourceNames:[ds]; Assertion HermeticByExpectedOutputCount ExpectedCount:5.

### R-105: FileSystem Storage Act/Assert Session Pair
Tier: T3
Goal: Author act session that writes to FileSystem storage and assert session that reads from it using FromFileSystem generator.
SUT: HTTP POST /process endpoint that writes a result.
MOCK_REQUIRED: no
FB slices: s02 §2.4, §2.5
Trap mines: s13#2 (Storages shape legacy vs correct)
Hard because:
- Case subfolder appended to storage path; assert DataSource must target same subfolder path
- Storages required at top level (not inside session)
Verify (mechanical):
- After act run, ./session-data/ contains expected files
- Assert run reads files, assertion passes
Rubric (graded):
- Storages section uses `- FileSystem: {Path: ./session-data}` shape [4 pts]
- Assert session DataSource points to same path act session wrote [4 pts]
- Both sessions have SaveData:true [2 pts]
Solution sketch: Top-level `Storages: - FileSystem: {Path: ./session-data}`; act session Transaction with InputDataFilter; assert session DataSource Generator:FromFileSystem Path:./session-data; use HermeticByExpectedOutputCount.

### R-106: Metadata and Observability Links
Tier: T3
Goal: Author a runner YAML with full MetaData block (System, Team, ExtraLabels) plus per-assertion Grafana and Prometheus Links.
SUT: HTTP monitoring endpoint returning Prometheus-format metrics.
MOCK_REQUIRED: no
FB slices: s02 §2.1, §2.10
Trap mines: s13#12 (unknown Link keys silently ignored)
Hard because:
- Link types have distinct required fields: Grafana needs DashboardId; Prometheus needs Expressions[]
- MetaData ExtraLabels is a dict (not list)
Verify (mechanical):
- `dotnet run -- template MetaData` shows System/Team/ExtraLabels shape
- Allure report contains deep links in assertion detail
Rubric (graded):
- MetaData has System (req), Team (req), ExtraLabels as dict [3 pts]
- Grafana link has Url + DashboardId (req fields) [4 pts]
- Prometheus link has Url + Expressions[] (list) [3 pts]
Solution sketch: Per s02§2.10, Links[] array under Assertions entry; Grafana: {Url:..., DashboardId:..., Variables:[]}; Prometheus: {Url:..., Expressions:[...]}.

### R-107: Large DataSource Fan-Out with AsciiAsc Order
Tier: T3
Goal: Configure FromFileSystem datasource with DataArrangeOrder:AsciiAsc over 20+ test files; verify deterministic processing order.
SUT: HTTP POST /ingest accepting numbered JSON payloads.
MOCK_REQUIRED: no
FB slices: s02 §2.5
Trap mines: s13#3 (DataSourceNames required on Transaction)
Hard because:
- AsciiAsc ordering: files processed A→Z lexicographically; numeric prefix `01_` to `20_` required for correct sort
- Lazy:false (default) loads all upfront; Lazy:true streams; choose correctly for large sets
Verify (mechanical):
- Runner logs show inputs processed in AsciiAsc order (01_→20_)
- Allure shows 20 transaction inputs
Rubric (graded):
- DataArrangeOrder:AsciiAsc declared in GeneratorConfiguration [4 pts]
- Test files named with zero-padded prefixes for correct ASCII sort [3 pts]
- Transaction Iterations matches file count OR Loop:true with Count policy [3 pts]
Solution sketch: FromFileSystem with DataArrangeOrder:AsciiAsc; files named 01_payload.json..20_payload.json; Transaction DataSourceNames:[ds] Iterations:20.

### R-108: Timing Windows with TimeoutBeforeSessionMs/TimeoutAfterSessionMs
Tier: T3
Goal: Author a three-session YAML using TimeoutBeforeSessionMs and TimeoutAfterSessionMs to space out load phases.
SUT: HTTP rate-limited API that needs 2s cooldown between bursts.
MOCK_REQUIRED: no
FB slices: s02 §2.6
Trap mines: none (timing fields documented correctly)
Hard because:
- TimeoutBeforeSessionMs and TimeoutAfterSessionMs are session-level fields (not top-level)
- Stage field controls ordering; same Stage → parallel; different Stage → sequential
Verify (mechanical):
- Total run time > sum of configured timeouts (3s+2s minimum)
- Sessions execute in declared stage order
Rubric (graded):
- TimeoutBeforeSessionMs/TimeoutAfterSessionMs on each session [4 pts]
- Stage values ensure sequential ordering [3 pts]
- All sessions produce outputs (not timed out) [3 pts]
Solution sketch: Session-1 Stage:1 TimeoutAfterSessionMs:2000; Session-2 Stage:2 TimeoutBeforeSessionMs:1000; Session-3 Stage:3; all transactions with correct DataSourceNames.

### R-109: Route Case Trap — Uppercase Route Yields 404
Tier: T3
Goal: Demonstrate and fix the uppercase-route trap: show that `Route: getUserProfile` → 404 while `Route: getuserprofile` → 200.
SUT: HTTP service with lowercase route `/getuserprofile`.
MOCK_REQUIRED: no
FB slices: s02 §2.6
Trap mines: s13#5b (route case)
Hard because:
- s13#5b: mocker lowercases Path but runner sends Route verbatim; case-sensitive match → 404
- HttpStatus assertion passes vacuously on 0 outputs without count guard
- Trap is invisible without count guard: 404 silently drops output
Verify (mechanical):
- Wrong version (Route: getUserProfile): HttpStatus passes vacuously with 0 outputs
- Fixed version (Route: getuserprofile): ExitCode=0, count=1
Rubric (graded):
- Route uses all-lowercase [4 pts]
- HermeticByExpectedOutputCount guard present [3 pts]
- Explanation in scenario notes that uppercase route → 404 → vacuous pass [3 pts]
Solution sketch: Per s13#5b, set `Route: getuserprofile` (all lowercase); add `HermeticByExpectedOutputCount ExpectedCount:1`; without count guard the 404 scenario appears to pass.

### R-110: Vacuous Pass Trap Demonstration with HttpStatus
Tier: T3
Goal: Show the vacuous-pass failure mode in HttpStatus assertion when SUT is unreachable (0 outputs) and how to fix with count guard.
SUT: HTTP service on port 9999 (intentionally wrong port to simulate unreachable).
MOCK_REQUIRED: no
FB slices: s02 §2.9
Trap mines: s13#13 (vacuous pass), s13#6 (missing output → null reference)
Hard because:
- HttpStatus with 0 outputs prints "All configured outputs arrived with status 200" → false pass
- Without count guard, CI shows green even when SUT is down
Verify (mechanical):
- Without count guard: run exits 0 even when SUT unreachable
- With HermeticByExpectedOutputCount ExpectedCount:1: run exits non-zero
Rubric (graded):
- Identifies vacuous pass as the failure mode [4 pts]
- Adds HermeticByExpectedOutputCount alongside HttpStatus [3 pts]
- Alternatively uses HermeticByInputOutputPercentage 100% [3 pts]
Solution sketch: Author YAML with HttpStatus assertion only first; observe vacuous pass; add `HermeticByExpectedOutputCount: {ExpectedCount: 1}` assertion in same Assertions block; re-run confirms failure when SUT is down.

### R-111: Five-Session Staged HTTP Load Test
Tier: T4
Goal: Author a 5-session YAML where sessions execute in 5 distinct stages, each hitting a different API route, with per-session hermetic guards and a shared storage.
SUT: HTTP API with routes /auth, /search, /cart, /checkout, /confirm — sequential business flow.
MOCK_REQUIRED: no
FB slices: s02 §2.6, §2.4, §2.9
Trap mines: s13#2 (Storages shape), s13#3 (DataSourceNames), s13#5 (leading slash)
Hard because:
- 5 sessions × 5 routes; each route must be lowercase, no leading slash
- Shared Storages section must use correct FileSystem shape
- Stage ordering ensures sequential execution; same Stage runs parallel
- Each session needs its own hermetic count guard
Verify (mechanical):
- `dotnet run -- template Sessions` confirms session-level fields
- All 5 sessions show ExitCode=0 in Allure with non-zero output counts
- Allure shows 5 separate sessions in test report
Rubric (graded):
- All 5 sessions have distinct Stage:1..5 values [3 pts]
- All routes lowercase, no leading slash [3 pts]
- Each session has independent HermeticByExpectedOutputCount [2 pts]
- Storages uses correct FileSystem shape [2 pts]
Solution sketch: Five sessions with Stage:1..5, each Transaction targeting a distinct lowercase route; top-level Storages with FileSystem; Assertions array with 5 hermetic count assertions each scoped via SessionNames:[sessionN].

### R-112: HermeticByInputOutputPercentage Edge Math
Tier: T4
Goal: Configure HermeticByInputOutputPercentage with 80% threshold where 4/5 transactions succeed; verify pass/fail boundary behavior.
SUT: HTTP /process endpoint that fails every 5th request (429 Too Many Requests).
MOCK_REQUIRED: no
FB slices: s02 §2.9
Trap mines: s13#13 (vacuous pass if 0 outputs), s13#4 (HttpStatus field names)
Hard because:
- Percentage assertion: 4 outputs / 5 inputs = 80% = exactly at threshold; must understand floor/ceil semantics
- Combining percentage guard with HttpStatus means 1 failure output is expected → HttpStatus must filter by OutputNames
- Zero-output edge: if all 5 fail, percentage assertion passes vacuously (0/0 undefined)
Verify (mechanical):
- With 4/5 success and Percentage:80 → assertion passes
- With 3/5 success and Percentage:80 → assertion fails
- Separate HermeticByExpectedOutputCount guards against zero-output trap
Rubric (graded):
- HermeticByInputOutputPercentage with correct Percentage value [4 pts]
- Separate HermeticByExpectedOutputCount as belt-and-suspenders guard [3 pts]
- HttpStatus uses StatusCode:/OutputNames: (not deprecated fields) [3 pts]
Solution sketch: DataSource with 5 items; Transaction Iterations:5; Assertions: HermeticByInputOutputPercentage{Percentage:80} + HermeticByExpectedOutputCount{ExpectedCount:4} + HttpStatus{StatusCode:200,OutputNames:[tx]}.

### R-113: Weighted Distribution Generator
Tier: T4
Goal: Use WeightedDistribution (or equivalent weighted generator from catalog) to send 70% JSON-A payloads and 30% JSON-B payloads in a single transaction stream.
SUT: HTTP POST /classify endpoint that categorizes request bodies.
MOCK_REQUIRED: no
FB slices: s02 §2.5
Trap mines: s13#3 (DataSourceNames required), s13#9 (generator package ref required)
Hard because:
- Generator name must be exact (from catalog §10); wrong name → FTL exit -532462766
- QaaS.Common.Generators package ref required in .csproj
- WeightedDistribution configuration keys must be character-exact (s13#12 silent ignore)
Verify (mechanical):
- Build exit 0 with QaaS.Common.Generators reference
- Run shows ~70% typeA / ~30% typeB distribution in inputs
- Allure input breakdown confirms weight ratio
Rubric (graded):
- Generator simple name matches catalog exactly [4 pts]
- QaaS.Common.Generators package referenced in .csproj [3 pts]
- GeneratorConfiguration keys character-exact (validated via template) [3 pts]
Solution sketch: DataSource Name:WeightedData Generator:WeightedDistribution GeneratorConfiguration with weight mappings; Transaction DataSourceNames:[WeightedData]; verify via `dotnet run -- template DataSources`.

### R-114: Unicode Boundary Payload Transactions
Tier: T4
Goal: Send HTTP transactions with Unicode payloads (emoji, RTL Arabic, CJK characters, null byte sequences) and assert body round-trips correctly.
SUT: HTTP POST /echo returning request body verbatim; UTF-8 encoding.
MOCK_REQUIRED: no
FB slices: s02 §2.5, §2.8
Trap mines: s13#3 (DataSourceNames required), s13#12 (body assertion config keys)
Hard because:
- Test data files must be UTF-8 encoded; Windows default encoding traps
- Body assertion must compare byte-exact; wrong deserializer loses Unicode
- InputSerialize:Json may mangle raw UTF-8 bytes; choose Binary or leave unset
Verify (mechanical):
- Input files saved as UTF-8 BOM-free; verify with `[System.Text.Encoding]::UTF8.GetPreamble()`
- Body assertion passes for all Unicode variants including null sequences
Rubric (graded):
- Test data files are UTF-8 encoded [3 pts]
- Appropriate serializer chosen (Binary/Json) preserving byte fidelity [4 pts]
- Body assertion keys character-exact from catalog [3 pts]
Solution sketch: TestData/ folder with 4 UTF-8 payload files; DataSource Generator:FromFileSystem; Transaction no InputSerialize (raw bytes); Assertion body comparison; HermeticByExpectedOutputCount:4.

### R-115: Large Payload (1MB) Transaction Stress
Tier: T4
Goal: Configure runner to send a 1MB JSON payload via HTTP POST and assert the response body length assertion passes.
SUT: HTTP POST /large-payload; echoes body; no size limit configured.
MOCK_REQUIRED: no
FB slices: s02 §2.5, §2.6, §2.9
Trap mines: s13#3 (DataSourceNames), s13#6 (null if output missing)
Hard because:
- TimeoutMs on Transaction must be increased (default may expire for large payload)
- Body length assertion requires correct config key (not Size/Length but catalog-exact name)
- 1MB file: runner reads from FileSystem; Lazy:false loads all to memory upfront
Verify (mechanical):
- Input file is ≥1MB (verify `(Get-Item file.json).Length -ge 1048576`)
- Transaction TimeoutMs:30000 or higher
- Allure shows 1 output with body length ≥ 1MB
Rubric (graded):
- TimeoutMs adequately sized for large payload (≥10000ms) [4 pts]
- DataSourceNames populated [3 pts]
- Body/length assertion uses catalog-exact configuration keys [3 pts]
Solution sketch: Generate 1MB JSON file in TestData/; DataSource Generator:FromFileSystem; Transaction TimeoutMs:30000 DataSourceNames:[ds]; assertion verifying response body length or status.

### R-116: Empty Body Boundary Transaction
Tier: T4
Goal: Send HTTP POST with empty body and assert server returns 400 Bad Request; guard against vacuous pass with count guard.
SUT: HTTP POST /validate; returns 400 for empty body, 200 otherwise.
MOCK_REQUIRED: no
FB slices: s02 §2.6, §2.9
Trap mines: s13#4 (HttpStatus fields), s13#13 (vacuous pass on 0 outputs)
Hard because:
- Empty body may cause HTTP client to omit Content-Length header → unexpected server behavior
- HttpStatus with StatusCode:400 still passes vacuously if 0 outputs
- InputSerialize on empty body → serializer may produce non-empty bytes (e.g., Json → `null`)
Verify (mechanical):
- Input file contains empty JSON `{}` or zero bytes; server returns 400
- HermeticByExpectedOutputCount:1 fails if SUT down
Rubric (graded):
- HttpStatus uses StatusCode:400 + OutputNames:[tx] [4 pts]
- HermeticByExpectedOutputCount:1 present [3 pts]
- InputSerialize choice documented with reasoning [3 pts]
Solution sketch: TestData/empty.json with `{}` or empty file; Transaction InputSerialize:Binary (preserve empty); HttpStatus{StatusCode:400,OutputNames:[TxName]}; HermeticByExpectedOutputCount{ExpectedCount:1}.

### R-117: Cases Matrix with DataSources Override
Tier: T4
Goal: Use -c cases to override DataSources path-key across 4 case files, sending different payload sets to the same endpoint.
SUT: HTTP POST /process; validates payload schema.
MOCK_REQUIRED: no
FB slices: s02 §2.11, §2.5
Trap mines: s13#11 (key typos silently ignored in cases), s13#3 (DataSourceNames on Transaction)
Hard because:
- Cases path-key for DataSources: `DataSources:0:GeneratorConfiguration:FileSystem:Path`
- Typo in path-key → case override silently ignored; all cases run same data
- All 4 cases must share same Transaction name but different data
Verify (mechanical):
- 4 case folders in Allure with distinct input counts
- Changing one case file to typo key → same data used (negative test for key precision)
Rubric (graded):
- Cases use correct path-key notation for DataSources override [4 pts]
- Transaction DataSourceNames references same DS name across cases [3 pts]
- Each case produces distinct output set in Allure [3 pts]
Solution sketch: Main YAML with DataSources[0] pointing to TestData/default; 4 case YAML files each overriding `DataSources:0:GeneratorConfiguration:FileSystem:Path: TestData/caseN`; run with `-c cases`.

### R-118: Variables Default Value Syntax
Tier: T4
Goal: Demonstrate `${variables:key??defaultValue}` fallback syntax where overwrite file absent → default used; overwrite file present → override value used.
SUT: HTTP GET endpoint; URL built from variable.
MOCK_REQUIRED: no
FB slices: s02 §2.2
Trap mines: s13#12 (key typo in variables silently ignored → default used incorrectly)
Hard because:
- Syntax is `${variables:key??default}` (double question mark); single `?` is JSON path operator
- Default must be a non-logical value (not a computed expression)
- Variable key is camelCase; mismatch between declaration and usage → always uses default
Verify (mechanical):
- Run without -w → default BaseAddress used; transaction targets default host
- Run with -w local.yaml → overridden BaseAddress used
Rubric (graded):
- Variables section uses camelCase keys [3 pts]
- Syntax `${variables:key??default}` correct (double ??) [4 pts]
- Overwrite file supplies non-default value and -w invocation confirmed [3 pts]
Solution sketch: `variables: {baseAddress: "http://default-host:8080"}` in main YAML; Transaction BaseAddress:`${variables:baseAddress??http://localhost:8080}`; local.yaml overrides `variables:0:baseAddress`.

### R-119: YAML Anchors for Shared Transaction Configuration
Tier: T4
Goal: Use YAML anchors (&, *, <<:) under anchors: section to share HTTP connection config across 3 transactions, then show anchor failure across overwrite files.
SUT: HTTP API with 3 routes sharing same BaseAddress and auth headers.
MOCK_REQUIRED: no
FB slices: s02 §2.3
Trap mines: s13#12 (anchor typo → silently broken merge)
Hard because:
- Anchors must be declared under `anchors:` key (not floating at top level)
- `<<: *name` merge only works within same YAML file; overwrite files cannot consume base-file anchors
- YAML merge does not override explicitly set keys → order matters
Verify (mechanical):
- Single-file anchors: all 3 transactions share BaseAddress from anchor
- Overwrite file attempting to override anchor target → anchor value used (not overwrite)
Rubric (graded):
- Anchors declared under `anchors:` section [4 pts]
- Merge `<<: *name` used correctly in each transaction [3 pts]
- Demonstrates anchors-don't-cross-files limitation in solution notes [3 pts]
Solution sketch: `anchors: - &httpBase {BaseAddress: "http://api:8080", Port: 8080}`; each Transaction `<<: *httpBase` to inherit connection; note in comments that overwrite files cannot override anchored values.

### R-120: Allure Artifact Verification and Save Flags
Tier: T4
Goal: Author runner YAML configuring per-assertion Save* flags (SaveSessionData, SaveLogs, SaveTemplate, SaveAttachments, DisplayTrace) and verify Allure output artifacts.
SUT: HTTP GET /data returning JSON; one session, one assertion.
MOCK_REQUIRED: no
FB slices: s02 §2.9
Trap mines: s13#10 (Reporters block not LAB-verified; use per-assertion Save* flags instead)
Hard because:
- s13#10: top-level `Reporters:` block is NOT LAB-verified; correct approach is per-assertion Save* flags
- SaveTemplate:true requires template output file; must reference correct assertion
- DisplayTrace:true adds trace to Allure annotation; key must be on Assertion entry (not AssertionConfiguration)
Verify (mechanical):
- Allure output folder contains session-data/, logs/, template/ subdirs per assertion
- DisplayTrace artifacts visible in Allure trace tab
Rubric (graded):
- Save* flags on Assertion entry (not top-level Reporters block) [4 pts]
- SaveSessionData:true + SaveLogs:true + SaveTemplate:true + SaveAttachments:true all declared [3 pts]
- No top-level Reporters: block used [3 pts]
Solution sketch: Assertion entry with Name/Assertion/SessionNames plus SaveData:true SaveSessionData:true SaveLogs:true SaveTemplate:true SaveAttachments:true DisplayTrace:true; run allure generate; verify subdirs exist.

### R-121: Overwrite File for Port Configuration (-w flag)
Tier: T4
Goal: Extract port numbers into overwrite file so same YAML runs against local (8080), docker (8081), and k8s (80) without editing main YAML.
SUT: HTTP API varying port per environment.
MOCK_REQUIRED: no
FB slices: s02 §2.11
Trap mines: s13#16 (PORT CONTRACT: probe port, mocker port, runner port must match), s13#12 (silent key ignore)
Hard because:
- Port appears in Transaction Http:Port; overwrite path-key must be `Sessions:0:Transactions:0:Http:Port`
- If port also appears in a Probe (TCP readiness), that must be overwritten too or s13#16 applies
- Port is an integer in YAML; overwrite file value must be integer type (not string)
Verify (mechanical):
- Run with `-w envs/local.yaml` → Transaction uses port 8080
- Run with `-w envs/docker.yaml` → Transaction uses port 8081
Rubric (graded):
- Port path-key exact: `Sessions:0:Transactions:0:Http:Port` [4 pts]
- Probe port overwritten in same overwrite file if probe present [3 pts]
- Port type is integer in overwrite YAML (not quoted string) [3 pts]
Solution sketch: Main YAML Transaction Http:Port:`${variables:port??8080}`; three overwrite files each setting `variables:0:port`; run with `-w envs/local.yaml`; run with `-w envs/docker.yaml`.

### R-122: Parallel Sessions Within Same Stage
Tier: T4
Goal: Configure two sessions at Stage:1 (parallel execution) hitting independent endpoints; verify both run concurrently by comparing wall-clock time.
SUT: HTTP /fast (50ms response) and HTTP /slow (500ms response) endpoints.
MOCK_REQUIRED: no
FB slices: s02 §2.6
Trap mines: s13#3 (DataSourceNames required on both sessions' transactions)
Hard because:
- Same Stage → parallel; different Stage → sequential; must set Stage:1 on both sessions
- Wall-clock time for parallel should be ~500ms not ~550ms
- Each parallel session needs independent DataSource with unique Name
Verify (mechanical):
- Total run time < 600ms (parallel) vs > 550ms (sequential with different stages)
- Both sessions output visible in Allure simultaneously
Rubric (graded):
- Both sessions have Stage:1 [4 pts]
- Both transactions DataSourceNames populated [3 pts]
- Independent hermetic count guards per session [3 pts]
Solution sketch: Session-fast Stage:1 Transaction:fast-tx; Session-slow Stage:1 Transaction:slow-tx; both at same Stage causes concurrent execution; measure wall time to confirm parallelism.

### R-123: LoadBalance Policy Rate Control
Tier: T4
Goal: Apply LoadBalance{Rate:10, TimeIntervalMs:1000} to a transaction to cap throughput at 10 req/s over a 3-second window.
SUT: HTTP POST /rate-limited accepting up to 15 req/s.
MOCK_REQUIRED: no
FB slices: s02 §2.7
Trap mines: s13#3 (DataSourceNames), s13#12 (Policy config key spelling)
Hard because:
- LoadBalance Rate and TimeIntervalMs are on Policies sub-object, not on Transaction directly
- Must use Loop:true with Timeout policy or large Iterations to sustain rate over 3s window
- Rate × TimeIntervalMs / 1000 = requests per second math must be correct
Verify (mechanical):
- Allure shows ~30 inputs over 3s window (10 req/s × 3s)
- Run duration ≥ 3000ms (LoadBalance enforces timing)
Rubric (graded):
- Policies: LoadBalance with Rate and TimeIntervalMs fields [4 pts]
- Loop:true or sufficient Iterations to sustain over time window [3 pts]
- HermeticByInputOutputPercentage used (not fixed count due to timing variability) [3 pts]
Solution sketch: Transaction Loop:true DataSourceNames:[ds] Policies: LoadBalance{Rate:10,TimeIntervalMs:1000}; combined with Timeout policy TimeoutMs:3000 to stop after 3 seconds.

### R-124: IncreasingLoadBalance Ramp-Up Test
Tier: T4
Goal: Use IncreasingLoadBalance to ramp from 2 req/s to 20 req/s over 5 steps, testing an auto-scaling endpoint.
SUT: HTTP GET /scale that auto-scales latency based on load.
MOCK_REQUIRED: no
FB slices: s02 §2.7
Trap mines: s13#3 (DataSourceNames required), s13#12 (field name precision)
Hard because:
- IncreasingLoadBalance fields: StartRate, MaxRate, RateIncrease(1), RateIncreaseIntervalMs(1000), TimeIntervalMs(1000)
- Total requests = sum of rates across all increase steps; math required
- HermeticByInputOutputPercentage preferred over fixed count due to variable request total
Verify (mechanical):
- Allure shows increasing input rate across time buckets
- MaxRate:20 reached before run ends
Rubric (graded):
- IncreasingLoadBalance with all required fields [4 pts]
- StartRate < MaxRate; RateIncrease > 0 [3 pts]
- HermeticByInputOutputPercentage (not fixed count) [3 pts]
Solution sketch: Transaction Loop:true DataSourceNames:[ds] Policies: IncreasingLoadBalance{StartRate:2,MaxRate:20,RateIncrease:2,RateIncreaseIntervalMs:1000,TimeIntervalMs:1000}; Timeout policy to cap total duration.

### R-125: Count Policy Capping Transaction Count
Tier: T4
Goal: DataSource has 100 items; use Count{Count:10} policy to process only first 10, verify exactly 10 outputs.
SUT: HTTP POST /item processing individual items.
MOCK_REQUIRED: no
FB slices: s02 §2.7
Trap mines: s13#3 (DataSourceNames required), s13#13 (vacuous pass)
Hard because:
- Count policy caps actions, not DataSource items; DS still provides 100 items but only 10 sent
- Must verify exactly 10 outputs (not 100); HermeticByExpectedOutputCount:10 required
- Loop:false (default) with Iterations:100 and Count:10 → stops at 10
Verify (mechanical):
- Allure shows exactly 10 transaction inputs (not 100)
- HermeticByExpectedOutputCount:10 passes
Rubric (graded):
- Policies: Count{Count:10} declared on Transaction [4 pts]
- HermeticByExpectedOutputCount{ExpectedCount:10} (not 100) [4 pts]
- DataSource has ≥100 items to prove cap behavior [2 pts]
Solution sketch: DataSource with 100 files; Transaction Iterations:1 Loop:true DataSourceNames:[ds] Policies: Count{Count:10}; Assertion HermeticByExpectedOutputCount{ExpectedCount:10}.

### R-126: Timeout Policy Stopping Long-Running Consumer
Tier: T4
Goal: Consumer with Timeout{TimeoutMs:5000} policy stops consuming after 5 seconds regardless of messages available.
SUT: RabbitMQ queue with continuous message flow (simulated by pre-seeded queue).
MOCK_REQUIRED: no
FB slices: s02 §2.7, §2.6
Trap mines: s13#17 (RabbitMQ topology must pre-exist)
Hard because:
- RabbitMQ exchange/queue must pre-exist; requires CreateRabbitMqExchanges probe at Stage:0
- Consumer TimeoutMs (last-message timeout) vs Timeout policy (wall-clock cap) are different
- Without topology probe, Consumer gets classId=40 NOT_FOUND error → 0 outputs → vacuous pass
Verify (mechanical):
- Stage:0 topology probe runs first (CreateRabbitMqExchanges)
- Consumer stops after ~5000ms (Timeout policy)
- Allure shows outputs consumed within 5s window
Rubric (graded):
- CreateRabbitMqExchanges probe at Stage:0 [4 pts]
- Consumer Timeout policy TimeoutMs:5000 declared under Policies [3 pts]
- Consumer TimeoutMs (last-message) separate from Timeout policy [3 pts]
Solution sketch: Session with Probe:CreateRabbitMqExchanges at Stage:0; Publisher at Stage:1 seeding queue; Consumer at Stage:0 (same session, different session) with Policies:Timeout{TimeoutMs:5000}.

### R-127: MockerCommand ChangeActionStub at Runtime
Tier: T4
Goal: Author runner YAML with MockerCommands session that dynamically switches a mocker stub mid-test using ChangeActionStub command.
SUT: Pre-deployed mocker with two stubs (stub-200 and stub-500) for same action.
MOCK_REQUIRED: no
FB slices: s02 §2.6
Trap mines: s13#11 (ServerName must byte-match mocker Controller.ServerName)
Hard because:
- MockerCommands require Redis; Controller.ServerName in runner must exactly match mocker config
- Redis connection in MockerCommands uses host:port format (not just host)
- If Redis unreachable, commands silently timeout (no error); test appears to work but stub not changed
Verify (mechanical):
- Stage:1 transactions get stub-200 response; Stage:3 MockerCommand switches to stub-500; Stage:4 transactions get 500
- Allure shows two transaction groups with different status codes
Rubric (graded):
- MockerCommands ChangeActionStub{ActionName,StubName} correct fields [4 pts]
- ServerName byte-matches mocker Controller.ServerName [3 pts]
- Redis host:port format (not just hostname) [3 pts]
Solution sketch: Session-1 Stage:1 Transaction → 200; Session-2 Stage:3 MockerCommand{ChangeActionStub{ActionName:HelloAction,StubName:stub-500}}; Session-3 Stage:4 Transaction → 500; verify with HttpStatus assertions.

### R-128: S3 Storage Configuration
Tier: T4
Goal: Configure S3 Storages block with all required fields (AccessKey, SecretKey, ServiceURL, StorageBucket) and write act/assert sessions using S3 storage.
SUT: MinIO S3-compatible service on port 9000.
MOCK_REQUIRED: no
FB slices: s02 §2.4
Trap mines: s13#2 (Storages shape — S3 uses same top-level pattern), s13#12 (S3 field typos silently ignored)
Hard because:
- S3 storage fields: AccessKey, SecretKey, ServiceURL, StorageBucket all required
- ForcePathStyle:true required for MinIO (not AWS-style virtual-hosted)
- Prefix/Delimiter optional but affects file listing ordering
Verify (mechanical):
- `dotnet run -- template Storages` shows S3 shape with required fields
- Act session writes to S3 bucket; assert session reads from same bucket
Rubric (graded):
- Storages: - S3: with AccessKey/SecretKey/ServiceURL/StorageBucket [4 pts]
- ForcePathStyle:true for MinIO compatibility [3 pts]
- Act and assert DataSources reference same S3 path [3 pts]
Solution sketch: `Storages: - S3: {AccessKey:minio,SecretKey:minio123,ServiceURL:http://localhost:9000,StorageBucket:test-bucket,ForcePathStyle:true}`; act writes via Transaction SaveData; assert reads via FromFileSystem equivalent over S3.

### R-129: Prometheus Collector with CollectionRange
Tier: T4
Goal: Configure a Prometheus Collector with CollectionRange{StartTimeMs:0,EndTimeMs:30000} and Expression query; assert metric value threshold.
SUT: Prometheus endpoint at http://localhost:9090 with custom counter metric.
MOCK_REQUIRED: no
FB slices: s02 §2.6
Trap mines: s13#12 (Prometheus Collector config keys character-exact)
Hard because:
- Collector Url must be base URL (no route); Expression is a query_range PromQL query
- CollectionRange is relative to session start (not wall clock time)
- Prometheus matrix response format: `{metric{__name__,label}, value:[epochSec,"str"]}` must be understood for body assertion
Verify (mechanical):
- Collector output contains Prometheus matrix JSON
- Body assertion verifies metric value above threshold
Rubric (graded):
- Collector Url (base, no route) + Expression (valid PromQL) + SampleIntervalMs [4 pts]
- CollectionRange.StartTimeMs/EndTimeMs relative to session start [3 pts]
- Assertion on Collector output (not Transaction output) [3 pts]
Solution sketch: Session Collectors:[{Name:MetricCollector,Protocol:Prometheus{Url:http://localhost:9090,Expression:rate(http_requests_total[1m]),SampleIntervalMs:5000},CollectionRange:{StartTimeMs:0,EndTimeMs:30000}}]; body assertion checks value > threshold.

### R-130: Template Oracle Workflow Validation
Tier: T4
Goal: Use `dotnet run -- template <ConfigSection>` as schema oracle to validate every major YAML section before writing the final YAML; surface one unknown-property warning.
SUT: HTTP GET /status; simple health check.
MOCK_REQUIRED: no
FB slices: s02 §2.1..2.11, s13 row 1-12
Trap mines: s13#1 (ProcessorConfiguration not TransactionData), s13#2 (Storages shape), s13#4 (HttpStatus fields)
Hard because:
- Template oracle must be run for each section: MetaData, Storages, DataSources, Sessions, Assertions
- Unknown property in AssertionConfiguration silently ignored; template output is the only way to detect
- s13 says trust `dotnet run -- template` over docs when in doubt
Verify (mechanical):
- `dotnet run -- template Assertions` output matches HttpStatus{StatusCode:,OutputNames:[]} (not deprecated fields)
- `dotnet run -- template Storages` confirms FileSystem shape
- Final YAML build+run: ExitCode=0, no unknown-property warnings
Rubric (graded):
- Template oracle invoked for ≥3 sections before writing YAML [4 pts]
- All deprecated doc-drift fields replaced with template-confirmed correct fields [3 pts]
- Final run ExitCode=0 with ≥1 output (not vacuous pass) [3 pts]
Solution sketch: Sequence of `dotnet run -- template MetaData`, `template Storages`, `template DataSources`, `template Sessions`, `template Assertions`; build YAML from template output; add count guard; run end-to-end.

### R-131: Six-Session Hermetic-Percentage Choreography with Mixed Delays (T5)
Tier: T5
Goal: Six-session YAML: sessions 1-4 succeed at 100%, sessions 5-6 intentionally fail (wrong port → 0 outputs); HermeticByInputOutputPercentage across all 6 sessions proves partial pass; Allure artifacts confirm 2 broken sessions.
SUT: HTTP API on port 8200 (sessions 1-4) and port 9999 (sessions 5-6, unreachable).
MOCK_REQUIRED: no
FB slices: s02 §2.6, §2.7, §2.9, §2.4
Trap mines: s13#13 (vacuous pass), s13#6 (broken assertion on null output), s13#3 (DataSourceNames), s13#4 (HttpStatus fields)
Hard because:
- Sessions 5-6 produce 0 outputs; HttpStatus on them would vacuously pass without count guard
- Percentage assertion across all 6 sessions: (4×N)/(6×N) = 66.7%; threshold must be ≤66
- Sessions must have controlled TimeoutBeforeSessionMs delays to space execution
- Exit-code interpretation: run exits non-zero if any assertion fails; must capture and interpret
Verify (mechanical):
- Sessions 1-4 show ExitCode=0 in Allure; sessions 5-6 show broken/failed with 0 outputs
- HermeticByInputOutputPercentage{Percentage:60} passes; Percentage:70 fails
- Allure shows 6 sessions; 2 marked failed/broken
- `dotnet run` exit code ≠ 0 when Percentage threshold > 66
Rubric (graded):
- All 6 sessions declared with distinct stages and delays [3 pts]
- HermeticByInputOutputPercentage covering all 6 sessions (SessionNames: all 6) [3 pts]
- Sessions 5-6 guarded with HermeticByExpectedOutputCount{ExpectedCount:0} to detect vacuous pass [2 pts]
- Allure SaveSessionData:true on all assertions for artifact verification [2 pts]
Solution sketch: Sessions 1-4 Stage:1..4 Transaction Port:8200; sessions 5-6 Stage:5..6 Transaction Port:9999 TimeoutMs:2000; Assertion HermeticByInputOutputPercentage{SessionNames:[all6],Percentage:60}; separate HermeticByExpectedOutputCount per failing session.

### R-132: Five-Session Kafka+HTTP Mixed Protocol Hermetic Test (T5)
Tier: T5
Goal: Three HTTP sessions and two Kafka consumer sessions in one YAML; hermetic percentage assertion across all five; FileSystem storage captures HTTP outputs for Kafka consumer correlation.
SUT: HTTP POST /event (port 8210) publishes to Kafka; separate consumer reads from topic.
MOCK_REQUIRED: no
FB slices: s02 §2.6, §2.4, §2.5, §2.9
Trap mines: s13#2 (Storages), s13#3 (DataSourceNames), s13#13 (vacuous pass), s13#17 (topology must pre-exist for Kafka)
Hard because:
- Kafka consumer TimeoutMs must exceed end-to-end processing latency; too short → 0 outputs
- FileSystem storage saves HTTP outputs; Kafka consumer session reads same path via FromFileSystem
- Five-session hermetic percentage: (3 HTTP × N + 2 Kafka × M) / total inputs; math requires knowing exact input counts
- Kafka topic must pre-exist or be created via CreateKafkaTopic probe at Stage:0
Verify (mechanical):
- HTTP sessions: 3 sessions each with 5 outputs = 15 total
- Kafka consumers: 2 sessions each consuming ≥ 5 messages = 10 total
- HermeticByInputOutputPercentage{Percentage:80} passes (25/25 = 100%)
- Allure shows 5 sessions, all passed
Rubric (graded):
- Kafka Consumer TimeoutMs sufficiently large (e.g., 15000ms) [3 pts]
- Storages FileSystem shape correct for HTTP→Kafka correlation [3 pts]
- Hermetic percentage assertion covers all 5 sessions [2 pts]
- Kafka topic creation probe at Stage:0 if not guaranteed pre-existing [2 pts]
Solution sketch: Stage:0 CreateKafkaTopic probe; Stage:1..3 HTTP Transaction sessions; Stage:4..5 KafkaTopic Consumer sessions with TimeoutMs:15000; top-level Storages FileSystem; Assertions HermeticByInputOutputPercentage{Percentage:80,SessionNames:[all5]}.

### R-133: Dynamic Cases × Overwrite Matrix (12 Combinations) (T5)
Tier: T5
Goal: Combine 4 case files × 3 overwrite files to produce 12 test variants; each variant targets a different endpoint route and environment; prove all 12 produce non-vacuous results.
SUT: HTTP API with 4 routes across 3 environments (dev/staging/prod).
MOCK_REQUIRED: no
FB slices: s02 §2.11
Trap mines: s13#12 (silent key ignore), s13#5 (route leading slash), s13#5b (route case), s13#13 (vacuous pass)
Hard because:
- 12 combinations require systematic case×env matrix; path-key precision critical
- Route must be lowercase in all 12 cases; any mixed-case route → 404 → vacuous pass
- Overwrite file for BaseAddress combined with case file for Route → both path-keys must be exact
- Allure must show 12 groups with distinct inputs; any duplication signals silent path-key failure
Verify (mechanical):
- `allure serve` shows 12 distinct test groups (4 cases × 3 envs)
- Zero cases have 0-output vacuous passes
- Any route uppercase in one case → that case shows broken assertion
Rubric (graded):
- Cases path-key `Sessions:0:Transactions:0:Http:Route` lowercase values [3 pts]
- Overwrite path-key `Sessions:0:Transactions:0:Http:BaseAddress` per environment [3 pts]
- HermeticByExpectedOutputCount:1 in all cases [2 pts]
- Route values in all 12 combinations are all-lowercase [2 pts]
Solution sketch: 4 case files (route:alpha, route:beta, route:gamma, route:delta all lowercase); 3 overwrite files (dev/staging/prod BaseAddress); run 12 times with `-c cases -w envs/X.yaml`; verify no vacuous passes in any combination.

### R-134: AdvancedLoadBalance Multi-Stage Rate Profile (T5)
Tier: T5
Goal: Use AdvancedLoadBalance with 4 stages (warmup/peak/sustain/cooldown) to model a realistic load profile; assert that output count falls within expected range using HermeticByInputOutputPercentage.
SUT: HTTP POST /api/batch accepting load; auto-throttles at peak.
MOCK_REQUIRED: no
FB slices: s02 §2.7
Trap mines: s13#3 (DataSourceNames), s13#12 (AdvancedLoadBalance.Stages field names), s13#13 (vacuous pass at warmup)
Hard because:
- AdvancedLoadBalance.Stages[] each has Rate(req), Amount(opt), TimeIntervalMs(1000), TimeoutMs(opt)
- Total requests = sum(Rate×Duration/TimeIntervalMs) across stages; complex math
- Warmup stage at Rate:2 may produce very few outputs; count guard must be low enough to pass
- HermeticByInputOutputPercentage preferred over fixed count due to variable total
Verify (mechanical):
- Total run duration = sum of stage TimeoutMs values
- Allure shows rate profile in input timestamps (visible as clusters)
- Percentage assertion passes at 85%
Rubric (graded):
- AdvancedLoadBalance.Stages[] with 4 stage objects, each with Rate + TimeoutMs [4 pts]
- Loop:true on Transaction to sustain across stages [3 pts]
- HermeticByInputOutputPercentage{Percentage:85} (not fixed count) [3 pts]
Solution sketch: Transaction Loop:true DataSourceNames:[ds] Policies: AdvancedLoadBalance{Stages:[{Rate:2,TimeoutMs:2000},{Rate:20,TimeoutMs:3000},{Rate:15,TimeoutMs:3000},{Rate:5,TimeoutMs:2000}]}; total ~123 requests; Percentage:80 guard.

### R-135: Exit Code Interpretation Matrix Across 5 Session Outcomes (T5)
Tier: T5
Goal: Design 5 sessions each expected to produce a specific run exit code (0/1/-532462766/non-zero from broken assertion); runner YAML + verification script parses exit codes correctly.
SUT: HTTP endpoints: /pass (200), /fail (500), /timeout (delays 30s), /empty (no body), /badroute (404 via wrong route).
MOCK_REQUIRED: no
FB slices: s02 §2.6, §2.9
Trap mines: s13#9 (exit -532462766 = missing package), s13#5 (route → 404), s13#13 (vacuous pass exit 0 even on failure), s13#14 (verify cmd starting with # → instant exit 0)
Hard because:
- Exit code -532462766 specifically means missing NuGet package reference (FTL); must recognize this
- Vacuous pass yields exit 0 even when all requests fail; only count guard reveals true failure
- Broken assertion (null output) yields exit different from failed assertion
- Verify script must NOT start with # (s13#14 comments out entire command)
Verify (mechanical):
- Session with missing package: exit -532462766; adding package ref → exit changes to 0 or 1
- Session with count guard on 0 outputs: exit non-zero
- Session with no guard on 0 outputs (vacuous): exit 0 (false pass demonstrated)
Rubric (graded):
- Each of 5 sessions maps to correct expected exit code [3 pts]
- Count guards present on all sessions susceptible to vacuous pass [3 pts]
- Verify script does not start with # (s13#14) [2 pts]
- Missing-package scenario identifies -532462766 and adds correct NuGet ref [2 pts]
Solution sketch: 5 separate runner YAMLs each targeting one SUT behavior; verify script captures `$LASTEXITCODE` after each run; maps to expected code; uses `if ($code -ne $expected) { throw }`.

### R-136: RunUntilStage Partial Execution with Stage Skipping (T5)
Tier: T5
Goal: Use RunUntilStage field to run sessions only up to Stage:2 in one invocation, then Stage:3..5 in a second invocation against updated SUT state.
SUT: HTTP stateful workflow: /init (Stage 1), /process (Stage 2), /finalize (Stage 3..5).
MOCK_REQUIRED: no
FB slices: s02 §2.6
Trap mines: s13#3 (DataSourceNames on all transaction-bearing sessions), s13#2 (Storages for cross-invocation state)
Hard because:
- RunUntilStage stops execution after specified stage; sessions beyond that stage are skipped
- Cross-invocation state must be persisted via FileSystem storage (written in first run, read in second)
- DataSources in second invocation must point to storage written by first invocation
- Stage numbering must be intentional; sessions without explicit Stage use default (array index)
Verify (mechanical):
- First run with RunUntilStage:2: only sessions 1-2 executed; session-data written
- Second run without RunUntilStage: sessions 3-5 read from first-run storage; finalize succeeds
Rubric (graded):
- RunUntilStage:2 on relevant session(s) for first invocation [4 pts]
- FileSystem storage path consistent across both invocations [3 pts]
- Second invocation DataSources reads first-run output path [3 pts]
Solution sketch: Session-1 Stage:1 RunUntilStage:2; sessions 1-2 write to `./session-data/run1`; second YAML (or overwrite) reads from `./session-data/run1`; stages 3-5 finalize.

### R-137: StorageMetaData FullPath vs RelativePath in FromFileSystem (T5)
Tier: T5
Goal: Demonstrate difference between StorageMetaData:FullPath, RelativePath(default), ItemName, None — show how wrong choice breaks path-based assertions.
SUT: HTTP POST /store accepting file path metadata in header; asserts path metadata in response.
MOCK_REQUIRED: no
FB slices: s02 §2.5
Trap mines: s13#12 (StorageMetaData key must be exact)
Hard because:
- StorageMetaData defaults to RelativePath; FullPath includes absolute disk path (environment-specific)
- Using FullPath breaks portability across machines (CI vs dev)
- ItemName gives only filename without path; body assertion may fail if full path expected
- None strips metadata entirely; if assertion checks path field → broken
Verify (mechanical):
- RelativePath: path in metadata starts relative to DataSource root
- FullPath: path is absolute (contains C:\ or /home/...)
- ItemName: only filename without directory component
Rubric (graded):
- StorageMetaData field name exact in GeneratorConfiguration [3 pts]
- RelativePath chosen for portability (not FullPath) [4 pts]
- Demonstrates that FullPath breaks in CI (different base path) [3 pts]
Solution sketch: DataSource with StorageMetaData:RelativePath; assertion checks relative path in response header; show that StorageMetaData:FullPath fails assertion when base path changes across machines.

### R-138: JwtAuth Transaction with Custom Claims (T5)
Tier: T5
Goal: Configure Transaction with JwtAuth block using HierarchicalClaims, HMACSHA256Algorithm, and Bearer scheme; send to JWT-protected endpoint; assert 200 (not 401).
SUT: HTTP /protected endpoint requiring valid JWT with sub and role claims.
MOCK_REQUIRED: no
FB slices: s02 §2.6
Trap mines: s13#5 (route leading slash), s13#5b (route case), s13#4 (HttpStatus fields), s13#3 (DataSourceNames)
Hard because:
- JwtAuth.HierarchicalClaims is a nested dict; flat Claims is a simple key-value dict
- BuildJwtConfig:true required to auto-build JWT from config; false → JWT from datasource
- HttpAuthScheme:Bearer (default) vs JWT/ApiKey/Token — must match server expectation
- HermeticByExpectedOutputCount required; 401 response still produces output but HttpStatus fails
Verify (mechanical):
- Without JwtAuth: HttpStatus 401 assertion passes (server returns 401)
- With JwtAuth: HttpStatus 200 assertion passes (valid JWT accepted)
Rubric (graded):
- JwtAuth block with Secret, BuildJwtConfig:true, HttpAuthScheme:Bearer [4 pts]
- Claims or HierarchicalClaims populated matching server's expected claims [3 pts]
- HttpStatus{StatusCode:200,OutputNames:[tx]} + HermeticByExpectedOutputCount:1 [3 pts]
Solution sketch: Transaction Http JwtAuth{Secret:mysecret,BuildJwtConfig:true,Claims:{sub:testuser,role:admin},HttpAuthScheme:Bearer}; route lowercase; HermeticByExpectedOutputCount:1; HttpStatus StatusCode:200.

### R-139: Deserializer Chain — JSON Transaction Output + MessagePack Consumer (T5)
Tier: T5
Goal: HTTP Transaction with OutputDeserialize:Json and a second session consuming MessagePack-serialized Kafka messages; both sessions share FileSystem storage; cross-format body assertion.
SUT: HTTP /api returns JSON; publishes MessagePack to Kafka topic.
MOCK_REQUIRED: no
FB slices: s02 §2.8, §2.6, §2.4
Trap mines: s13#3 (DataSourceNames on Transaction), s13#6 (missing output → null deref in assertion)
Hard because:
- OutputDeserialize on Transaction: {Deserializer:Json}; Consumer Deserialize: {Deserializer:MessagePack}
- SpecificType required for MessagePack if typed deserialization needed: TypeFullName + AssemblyName
- Cross-format comparison via FileSystem: HTTP JSON saved, Kafka MessagePack output saved to same storage
- Body assertion must compare across formats (extract field from both)
Verify (mechanical):
- Transaction output shows deserialized JSON object (not raw bytes)
- Consumer output shows deserialized MessagePack object
- Body assertion comparing field values across both passes
Rubric (graded):
- Transaction OutputDeserialize{Deserializer:Json} [3 pts]
- Consumer Deserialize{Deserializer:MessagePack} with SpecificType if needed [3 pts]
- FileSystem storage bridges HTTP→Kafka outputs for cross-session assertion [4 pts]
Solution sketch: Session-1 Transaction OutputDeserialize:{Deserializer:Json}; Session-2 Consumer Deserialize:{Deserializer:MessagePack,SpecificType:{TypeFullName:MyApp.Events.OrderEvent}}; FileSystem storage shared; assertion compares OrderId field.

### R-140: Parallel Publisher + Consumer with Stage Ordering (T5)
Tier: T5
Goal: Publisher at Stage:1 sends 20 messages to RabbitMQ; Consumer at Stage:0 (different session, same stage as default) — author correctly so Consumer starts BEFORE Publisher; hermetic percentage validates all 20 received.
SUT: RabbitMQ broker; exchange and queue pre-seeded by probe.
MOCK_REQUIRED: no
FB slices: s02 §2.6, §2.7
Trap mines: s13#17 (topology must pre-exist), s13#13 (vacuous pass if Consumer TimeoutMs too short)
Hard because:
- Consumer default Stage:0 starts before Publisher default Stage:1; must be in SEPARATE sessions or same session with explicit Stage
- If Consumer and Publisher are in same session at Stage:0, Consumer may drain before Publisher sends
- CreateRabbitMqExchanges probe in a preliminary session at Stage:0 before Publisher session
- Consumer InitialTimeoutMs must be set to wait for Publisher to finish sending
Verify (mechanical):
- Topology probe session executes first
- Consumer starts before Publisher (Stage ordering verified in logs)
- All 20 messages received; HermeticByInputOutputPercentage{Percentage:100} passes
Rubric (graded):
- Topology probe at Stage:0 in Session-1 [3 pts]
- Consumer at Stage:0 in Session-2 (before Publisher Stage:1 in Session-3) [3 pts]
- Consumer InitialTimeoutMs large enough for Publisher to finish [2 pts]
- HermeticByInputOutputPercentage{Percentage:100} or HermeticByExpectedOutputCount:20 [2 pts]
Solution sketch: Session-1 Stage:0 Probe CreateRabbitMqExchanges; Session-2 Stage:0 Consumer RabbitMq InitialTimeoutMs:5000 TimeoutMs:3000; Session-3 Stage:1 Publisher RabbitMq Iterations:20; Assertion Percentage:100.

### R-141: Seven-Session Orchestration with Category Filters (-I flag) (T5)
Tier: T5
Goal: Seven sessions with Category labels (smoke/regression/perf); use -I flag to run only regression category (3 sessions); prove remaining 4 sessions skipped; hermetic assertions scoped to regression sessions only.
SUT: HTTP API with 7 distinct routes across categories.
MOCK_REQUIRED: no
FB slices: s02 §2.6, §2.9
Trap mines: s13#3 (DataSourceNames), s13#13 (vacuous pass on skipped sessions), s13#5b (route case)
Hard because:
- Category field on Session filters via `-I Category:regression`; wrong Category value → session skipped silently
- Assertions must reference only the 3 regression SessionNames; including skipped session → null ref → broken
- Skipped sessions don't write SessionData; FileSystem storage paths may be missing
- All routes must be lowercase across all 7 sessions
Verify (mechanical):
- Run with `-I Category:regression`: only 3 sessions execute; Allure shows 3
- Run without -I: all 7 execute; Allure shows 7
- Assertions reference only SessionNames from active category
Rubric (graded):
- Category field on each session matches one of smoke/regression/perf [3 pts]
- Assertions SessionNames contain only regression session names (not all 7) [3 pts]
- All 7 routes lowercase [2 pts]
- HermeticByExpectedOutputCount per session (not across all 7) [2 pts]
Solution sketch: Sessions 1-3 Category:smoke; Sessions 4-6 Category:regression; Session 7 Category:perf; Assertions SessionNames:[session4,session5,session6]; run `-I Category:regression`; verify 3 sessions in Allure.

### R-142: Chunk Publisher with ChunkSize and Consumer Correlation (T5)
Tier: T5
Goal: Publisher with Chunk{ChunkSize:5} sending batches of 5 messages; Consumer reads and correlates batches; assert that output count = input count / ChunkSize.
SUT: RabbitMQ with chunked message processing; consumer processes full chunks.
MOCK_REQUIRED: no
FB slices: s02 §2.6
Trap mines: s13#17 (topology), s13#13 (vacuous pass), s13#3 (DataSourceNames)
Hard because:
- Chunk{ChunkSize:5} publishes messages in groups of 5; consumer receives aggregated chunks
- Output count = input count / 5 (not input count); hermetic math must reflect chunking
- Topology probe required; chunk size affects Consumer InitialTimeoutMs (larger chunks take longer)
- DataFilter on Publisher may be needed to tag chunk boundaries
Verify (mechanical):
- Publisher sends 20 messages (4 chunks of 5); Consumer receives 4 chunk outputs
- HermeticByExpectedOutputCount{ExpectedCount:4} passes
Rubric (graded):
- Publisher Chunk{ChunkSize:5} correct field name [4 pts]
- HermeticByExpectedOutputCount matches chunk math (inputs/5) [3 pts]
- Topology probe at Stage:0 [3 pts]
Solution sketch: Session-1 Stage:0 CreateRabbitMqExchanges probe; Session-2 Stage:1 Publisher Iterations:20 Chunk{ChunkSize:5}; Session-3 Stage:0 (same session 2, different stage) Consumer InitialTimeoutMs:10000 TimeoutMs:5000; Assertion ExpectedCount:4.

### R-143: DataFilter Body + MetaData Transformation (T5)
Tier: T5
Goal: Apply DataFilter{Body:..., MetaData:..., Timestamp:...} on Publisher to transform message before sending; apply InputDataFilter on Transaction to strip headers; verify filtered output assertions.
SUT: HTTP /filtered endpoint that validates body schema; RabbitMQ consumer validates metadata.
MOCK_REQUIRED: no
FB slices: s02 §2.6
Trap mines: s13#3 (DataSourceNames), s13#12 (DataFilter sub-keys must be exact)
Hard because:
- DataFilter applies JSONPath/JMESPath expressions (docs-dependent); wrong expression → empty body
- Publisher DataFilter.Body modifies outgoing message; must be docs-verified expression syntax
- Transaction InputDataFilter strips request before sending; OutputDataFilter transforms response
- Timestamp filter modifies message timestamp in SessionData (not in HTTP body)
Verify (mechanical):
- Publisher output in SessionData shows filtered body (not original)
- Transaction output shows filtered response (headers stripped)
- Body assertion on filtered output passes
Rubric (graded):
- DataFilter.Body expression syntactically valid and docs-sourced [4 pts]
- Publisher DataFilter vs Transaction InputDataFilter/OutputDataFilter used correctly [3 pts]
- Assertion on filtered SessionData (not raw output) [3 pts]
Solution sketch: Publisher DataFilter{Body:"$.orderId",MetaData:{}}; Transaction InputDataFilter{Body:"$.requestId"}; OutputDataFilter{Body:"$.result"}; assertion checks filtered orderId/result fields via body comparison assertion.

### R-144: Serialize/Deserialize Round-Trip with SpecificType (T5)
Tier: T5
Goal: Publisher sends Protobuf-serialized message; Consumer deserializes with SpecificType{TypeFullName,AssemblyName}; body assertion verifies field equality after round-trip.
SUT: RabbitMQ with Protobuf message format; consumer app parses proto messages.
MOCK_REQUIRED: no
FB slices: s02 §2.8, §2.6
Trap mines: s13#3 (DataSourceNames), s13#17 (topology), s13#9 (QaaS.Common.Generators package for Serialize support)
Hard because:
- Publisher Serialize{Serializer:ProtobufMessage}; Consumer Deserialize{Deserializer:ProtobufMessage,SpecificType:{TypeFullName:full.type.name,AssemblyName:MyAssembly}}
- AssemblyName optional (defaults to entry assembly) but required if type in external assembly
- SpecificType.TypeFullName must be fully qualified (namespace.ClassName); simple name → deserialization fails silently
- Proto schema must match sender and receiver
Verify (mechanical):
- Publisher SessionData input shows serialized (non-readable) bytes
- Consumer SessionData output shows deserialized object with correct field values
- Body assertion comparing publisher field vs consumer field passes
Rubric (graded):
- Publisher Serialize{Serializer:ProtobufMessage} [3 pts]
- Consumer Deserialize{Deserializer:ProtobufMessage,SpecificType{TypeFullName:...,AssemblyName:...}} [4 pts]
- Body assertion on deserialized consumer output (not raw bytes) [3 pts]
Solution sketch: Topology probe; Publisher Serialize{Serializer:ProtobufMessage}; Consumer Deserialize{Deserializer:ProtobufMessage,SpecificType{TypeFullName:MyApp.Protos.OrderEvent,AssemblyName:MyApp}}; assertion OrderId field match.

### R-145: Three-Overwrite-File Environment Promotion Test (T5)
Tier: T5
Goal: Author YAML that runs identically across dev/staging/prod using 3 overwrite files; each env has different BaseAddress, port, JWT secret, and storage path; one assertion YAML covers all envs.
SUT: HTTP /api/v1/health in dev/staging/prod with different base URLs and auth.
MOCK_REQUIRED: no
FB slices: s02 §2.11, §2.2, §2.4
Trap mines: s13#12 (silent ignore on overwrite key typo), s13#16 (port contract across probe/mocker/runner), s13#14 (verify cmd starts with #)
Hard because:
- Five distinct overwrite path-keys: BaseAddress, Port, JwtAuth:Secret, Storages path, MetaData:System
- Each must be independently verified; typo → uses main YAML value silently
- JWT secret different per environment; must appear in overwrite not main YAML (security)
- Storage path per env: dev writes to ./dev-data, staging to ./staging-data; assert session reads correct path
Verify (mechanical):
- Run with `-w envs/dev.yaml`: all connections go to dev endpoints
- Run with `-w envs/prod.yaml`: JWT secret changes; prod endpoint used
- Allure MetaData shows correct environment label per run
Rubric (graded):
- All 5 overwrite path-keys correct and verified via template oracle [3 pts]
- JWT secret in overwrite file (not main YAML) [3 pts]
- Storage path overridden per environment [2 pts]
- MetaData ExtraLabels includes environment label [2 pts]
Solution sketch: Main YAML uses `${variables:*}` placeholders for all env-specific values; 3 overwrite files each supply all 5 keys; verify by running all 3 envs and checking Allure labels.

### R-146: Hermetic Percentage + Fixed Count Double Guard on 10-Session YAML (T5)
Tier: T5
Goal: Ten sessions; HermeticByInputOutputPercentage{Percentage:90} as primary guard; HermeticByExpectedOutputCount per-session as secondary guard; one session intentionally produces 0 outputs to prove secondary guard fires while primary passes.
SUT: HTTP API; session-10 targets wrong route (intentional 0 outputs).
MOCK_REQUIRED: no
FB slices: s02 §2.9, §2.6
Trap mines: s13#13 (vacuous pass), s13#6 (broken assertion on null output), s13#4 (HttpStatus fields)
Hard because:
- 10 sessions × 1 input each; session-10 produces 0 outputs; total = 9/10 = 90%; exactly at threshold
- Primary percentage guard at 90% just passes; secondary count guard on session-10 fires (0 ≠ 1)
- HttpStatus on session-10 passes vacuously → proves vacuous pass without count guard
- Ten sessions require distinct stages or explicit Stage values; duplicate stages run parallel
Verify (mechanical):
- HermeticByInputOutputPercentage{Percentage:90} passes (9/10 = 90%)
- HermeticByExpectedOutputCount{ExpectedCount:1} on session-10 fails (0 outputs)
- Removing count guard on session-10 → only percentage assertion → false green
Rubric (graded):
- Percentage:90 at exactly the threshold (9/10) [3 pts]
- Per-session count guards on all 10 sessions [3 pts]
- Demonstrates that percentage guard alone is insufficient [2 pts]
- Session-10 wrong route lowercase (not uppercase) to confirm s13#5b trap [2 pts]
Solution sketch: Sessions 1-9 correct routes; Session-10 wrong route (but lowercase, e.g., /wrongroute); Assertions: HermeticByInputOutputPercentage{Percentage:90,SessionNames:[all10]} + 10× HermeticByExpectedOutputCount per session.

### R-147: Allure Links + StatusesToReport Filtering (T5)
Tier: T5
Goal: Assertions with StatusesToReport:[Failed,Broken] to suppress Passed results from Allure; add Kibana and Grafana links per assertion; verify Allure only shows failed/broken items.
SUT: HTTP API; most requests pass (200), one route returns 500.
MOCK_REQUIRED: no
FB slices: s02 §2.9, §2.10
Trap mines: s13#12 (Link field typos silently ignored), s13#4 (HttpStatus fields)
Hard because:
- StatusesToReport:[Failed,Broken] filters assertion output; Passed results hidden in Allure
- Kibana Link requires Url + DataViewId + KqlQuery + TimestampField(@timestamp); missing field → link broken
- Grafana Link requires Url + DashboardId (req); Variables[] optional
- Links can be at assertion level or top-level; assertion-level overrides top-level
Verify (mechanical):
- Allure shows only the failed 500 assertion (not the passing 200 ones)
- Kibana link appears in failed assertion detail
- Grafana link with DashboardId present
Rubric (graded):
- StatusesToReport:[Failed,Broken] on passing assertions (suppresses noise) [3 pts]
- Kibana Link with Url/DataViewId/KqlQuery/TimestampField [4 pts]
- Grafana Link with Url/DashboardId [3 pts]
Solution sketch: Assertion-1 for /ok route: StatusesToReport:[Failed,Broken]; Assertion-2 for /fail route: StatusesToReport:[Failed,Broken] + Links:[Kibana{...},Grafana{...}]; Allure shows only failing assertion.

### R-148: CLI -r Overwrite-Argument Runtime Value (T5)
Tier: T5
Goal: Use `-r MetaData:Environment=qa` and `-r Sessions:0:Transactions:0:Http:Port=9090` runtime argument overrides; no overwrite files needed; prove both values applied in one command.
SUT: HTTP API; port configurable at runtime.
MOCK_REQUIRED: no
FB slices: s02 §2.11
Trap mines: s13#12 (path-key typo silent), s13#16 (port contract)
Hard because:
- `-r` format: `Path:To:Key=Value` (colon-separated path, equals value); colon in value must be escaped
- Integer values in YAML vs string in `-r`; port must be parsed as integer
- Multiple -r arguments: separate `-r` flags (not comma-separated)
- Value with spaces or colons: quoting required in shell
Verify (mechanical):
- Run with `-r MetaData:Environment=qa`: Allure label shows "qa"
- Run with `-r Sessions:0:Transactions:0:Http:Port=9090`: transaction connects to port 9090
- `dotnet run -- template MetaData` confirms Environment is a valid ExtraLabels key
Rubric (graded):
- `-r Path:Key=Value` format correct (colon path, equals value) [4 pts]
- Multiple -r arguments as separate flags [3 pts]
- Port value parsed as integer by runner (not string) [3 pts]
Solution sketch: `dotnet run -- run mytest.qaas.yaml -r MetaData:System=MySystem -r MetaData:Team=QA -r Sessions:0:Transactions:0:Http:Port=9090`; verify Allure labels and transaction port.

### R-149: Parallel Datasource Iteration with Parallel{Parallelism:N} (T5)
Tier: T5
Goal: Configure Transaction with Parallel{Parallelism:5} to send 5 concurrent HTTP requests per iteration; 20 total iterations → 100 concurrent requests; hermetic percentage at 95% tolerating 5 failures.
SUT: HTTP POST /async accepting concurrent requests; returns 200 or 503 under load.
MOCK_REQUIRED: no
FB slices: s02 §2.6
Trap mines: s13#3 (DataSourceNames), s13#13 (vacuous pass at high concurrency if SUT overloaded)
Hard because:
- Parallel{Parallelism:5} within a single iteration sends N concurrent requests; combines with Iterations:20 for 100 total
- At high concurrency, SUT may return 503; HermeticByInputOutputPercentage must be set below 100%
- Total inputs = Iterations × Parallelism; total outputs ≤ Iterations × Parallelism
- TimeoutMs must be large enough for concurrent requests to complete
Verify (mechanical):
- Allure shows 100 inputs (20 iterations × 5 parallel)
- HermeticByInputOutputPercentage{Percentage:95} passes if ≥95 of 100 succeed
- Run duration shows concurrency benefit vs sequential (100 sequential >> 20 iterations parallel)
Rubric (graded):
- Transaction Parallel{Parallelism:5} correct field [4 pts]
- HermeticByInputOutputPercentage{Percentage:95} (not fixed count) [3 pts]
- TimeoutMs sufficient for concurrent load (≥5000ms) [3 pts]
Solution sketch: Transaction Iterations:20 Parallel{Parallelism:5} DataSourceNames:[ds] TimeoutMs:10000; DataSource with 100 files (20 iterations × 5 consumed per); Assertions HermeticByInputOutputPercentage{Percentage:95}.

### R-150: Full Regression Harness — 8-Session, 3-Protocol, 4-Assertion, 2-Overwrite (T5)
Tier: T5
Goal: Capstone scenario: 8 sessions (3 HTTP, 2 RabbitMQ, 1 Kafka, 1 Prometheus Collector, 1 MockerCommand), 4 assertions (HttpStatus, body compare, hermetic percentage, hermetic count), 2 overwrite files, allure artifacts; all wired correctly with exact field names from s02/s13.
SUT: Full microservice stack: HTTP API, RabbitMQ broker, Kafka cluster, Prometheus exporter.
MOCK_REQUIRED: no
FB slices: s02 §2.1..2.11, s13 (all rows)
Trap mines: s13#2 (Storages), #3 (DataSourceNames), #4 (HttpStatus), #5/#5b (routes), #12 (silent typos), #13 (vacuous pass), #17 (RabbitMQ topology), #9 (package versions)
Hard because:
- All 19 s13 trap rows relevant; any one misfire breaks the run
- MockerCommand requires Redis + exact ServerName byte-match
- Prometheus Collector Url must be base (no route); Expression valid PromQL
- 4 assertions must each have correct SessionNames (not cross-contaminated)
- Both overwrite files must supply all env-specific values; template oracle required for each section
- Package versions must be: Runner 4.5.1, Common.Assertions 3.5.1, Common.Generators 3.5.1, Common.Probes 1.5.1 (not uniform version)
Verify (mechanical):
- Build exit 0 with all correct package versions
- All 8 sessions produce non-zero outputs (Collector ≥1 matrix point; MockerCommand ≥1 command executed)
- All 4 assertions pass in Allure
- Both overwrite files produce distinct Allure labels (env differentiation)
Rubric (graded):
- All 8 sessions declared with correct protocols, stages, and DataSourceNames [3 pts]
- All 4 assertions use docs-correct field names (not drift-left-column) [3 pts]
- Package versions all correct per s13#9 (not uniform version) [2 pts]
- Both overwrite files tested; Allure shows correct env labels [2 pts]
Solution sketch: MetaData System/Team/ExtraLabels; Storages FileSystem; DataSources with AsciiAsc; 8 sessions with stages 0-7; MockerCommand Redis host:port + ServerName exact; Prometheus Collector Url no-route; 4 assertions with SessionNames lists; 2 overwrite files (dev/prod); verify with template oracle for each section.
