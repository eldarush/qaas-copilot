# Batch X — Advanced Failure-Forensics (X-101..X-150)
# Tier mix: 10×T3 (X-101–110), 20×T4 (X-111–130), 20×T5 (X-131–150)
# Theme: multi-bug stacks, vacuous-pass forensics, silent drift-trap composites
# MOCK_REQUIRED: n/a (all diagnosis scenarios)
# Generated per eval/scenarios-v3 spec

### X-101: TransactionData + Missing DataSourceNames Double Fault
Tier: T3
Goal: Identify two simultaneous schema errors—deprecated stub key AND missing required transactions field—from a single FTL line.
Evidence:
```
FTL Runner execution configuration is invalid
  Sessions:0:Transactions:0: DataSourceNames or DataSourcePatterns must be provided
  [template] Property TransactionData in path Stubs:0 - not found in TransactionStubConfig object
exit code: 1
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §7, §13
Trap mines: s13#1 (TransactionData→ProcessorConfiguration), s13#3 (DataSourceNames required)
Hard because:
- Two independent errors surface in one run; fixing only one leaves exit 1
- Log mixes config-validation path (Sessions) with template-warn path (Stubs)
- Model may assume one root cause
Expected root cause:
- Mocker YAML uses `TransactionData:` instead of `ProcessorConfiguration:` (s13#1)
- Runner YAML Transaction block missing `DataSourceNames:` or `DataSourcePatterns:` (s13#3)
- Both must be fixed; neither fix alone produces exit 0
Verify (mechanical): answer names both broken fields with exact correct replacements; no extra changes.
Rubric (graded):
- 3: both fixes named, exact key replacements given, explanation cites s13#1 + s13#3
- 2: one fix correct, other vague or partially wrong
- 1: only one fix or blames wrong file
Solution sketch: Replace `TransactionData:` with `ProcessorConfiguration:` in mocker stub AND add `DataSourceNames: [src.csv]` to the runner Transaction block.

---

### X-102: Runtime Image Mocker Crash on HTTP Start
Tier: T3
Goal: Identify wrong Dockerfile base image as the sole cause of mocker container failing to serve HTTP requests.
Evidence:
```
Framework 'Microsoft.AspNetCore.App', version '10.0.0' was not found.
  The following frameworks were found:
    Microsoft.NETCore.App  10.0.0  at [/usr/share/dotnet/shared/Microsoft.NETCore.App]
You must install or update .NET to run this application.
exit code: 139
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §7, §13
Trap mines: s13#7 (runtime→aspnet)
Hard because:
- Exit 139 (SIGSEGV on Linux) may mislead toward memory bug
- Docker layer output shows successful build; crash only at container start
- Dockerfile line looks plausible (`dotnet/runtime:10.0`)
Expected root cause:
- Mocker Dockerfile uses `mcr.microsoft.com/dotnet/runtime:10.0` instead of `dotnet/aspnet:10.0`
- `runtime` image omits ASP.NET shared framework; HTTP middleware fails at startup
- Build succeeds; error is 100% at container start, not in test logic
Verify (mechanical): answer names `dotnet/aspnet:10.0` as the fix; confirms build vs run distinction.
Rubric (graded):
- 3: names aspnet fix, explains missing ASP.NET framework, no extra changes
- 2: names aspnet fix but conflates build vs runtime
- 1: suggests rebuild/code change instead of base image
Solution sketch: Change `FROM mcr.microsoft.com/dotnet/runtime:10.0` to `FROM mcr.microsoft.com/dotnet/aspnet:10.0` in the final stage of the Dockerfile.

---

### X-103: HttpStatus Vacuous Pass — Zero Outputs
Tier: T3
Goal: Detect a false-green run where HttpStatus passes on zero captured outputs.
Evidence:
```
[INFO] Output Source 'ApiResponse' Contains 0 Outputs
[INFO] HttpStatus assertion: All configured outputs arrived with status 200 (0 outputs checked)
[PASS] HttpStatus
exit code: 0
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §7, §13
Trap mines: s13#13 (vacuous HttpStatus pass)
Hard because:
- Exit code is 0 and assertion shows PASS; run appears green
- No failure signal in stdout; requires reading "0 outputs checked" as the anomaly
- Model must know to call this vacuous and prescribe a guard
Expected root cause:
- Transaction is capturing zero HTTP outputs (SUT/route unreachable or stub mis-matched)
- HttpStatus assertion passes vacuously on empty output set (s13#13)
- No hermetic-count guard prevents the false green
Verify (mechanical): answer identifies vacuous pass, prescribes HermeticByExpectedOutputCount or HermeticByInputOutputPercentage guard alongside HttpStatus.
Rubric (graded):
- 3: names vacuous-pass pattern, prescribes count guard, explains why exit 0 is wrong
- 2: notes zero outputs but misses guard prescription
- 1: accepts run as passing
Solution sketch: Add `HermeticByExpectedOutputCount` with `ExpectedCount: <N>` alongside the HttpStatus assertion to force failure when no outputs arrive.

---

### X-104: Leading-Slash Route 404
Tier: T3
Goal: Diagnose HTTP 404 caused by leading slash on runner `Route:` field.
Evidence:
```
[WARN] GET //health returned 404 (DefaultNotFound)
assertion broken: "Value cannot be null. (Parameter 'source')"
Output 'HealthOut' Contains 0 Outputs
exit code: 1
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §7, §13
Trap mines: s13#5 (leading slash), s13#6 (missing output → null)
Hard because:
- Double-slash `//health` in log is subtle; model may not notice
- `Value cannot be null` message seems like a code bug, not a config typo
- Two symptoms (404 + null assertion) share one root cause
Expected root cause:
- Runner YAML has `Route: /health` (with leading slash); mocker sees request as `//health` → no match → 404
- Zero outputs reach assertion; `(Parameter 'source')` null-ref is the downstream symptom (s13#6)
- Fix is removing the leading slash: `Route: health`
Verify (mechanical): answer names s13#5, shows `Route: health`, explains null-ref as downstream effect.
Rubric (graded):
- 3: names leading-slash cause, `Route: health` fix, explains null-ref as downstream
- 2: names leading slash but also blames assertion config
- 1: focuses only on null-ref without identifying the route
Solution sketch: Change `Route: /health` to `Route: health` in the runner YAML transaction block.

---

### X-105: Missing QaaS.Common.Assertions Package → FTL
Tier: T3
Goal: Trace exit -532462766 to missing NuGet reference for built-in assertion family.
Evidence:
```
FTL I1 hook instance 0 not found in any of the provided assemblies
  Requested: QaaS.Common.Assertions.ContainsBodyAssertion
exit code: -532462766
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §7, §13
Trap mines: s13#8 (built-in hooks need explicit refs), s13#9 (independent versions)
Hard because:
- Error message says "assembly" not "package"; may mislead toward project reference
- Model must know the correct package name and version (3.5.1 for Common.Assertions)
- Wrong version guess (e.g. 4.5.1) produces NU1102
Expected root cause:
- Runner `.csproj` is missing `<PackageReference Include="QaaS.Common.Assertions" Version="3.5.1" />`
- Built-in hooks are not bundled in the Runner package; each family needs explicit ref (s13#8)
- Using Runner version (4.5.1) on Common.Assertions gives NU1102 (s13#9)
Verify (mechanical): answer names `QaaS.Common.Assertions` at version `3.5.1`; no other package changes.
Rubric (graded):
- 3: exact package name + correct version 3.5.1, explains independent version rule
- 2: correct package name, wrong version
- 1: suggests adding a project reference or assembly copy
Solution sketch: Add `<PackageReference Include="QaaS.Common.Assertions" Version="3.5.1" />` to the runner `.csproj`.

---

### X-106: CWD Trap — Config File Not Found
Tier: T3
Goal: Diagnose "YAML configuration file was not found" error caused by running dotnet from the wrong directory.
Evidence:
```
CouldNotFindConfigurationException: YAML configuration file was not found.
  Resolved local path: C:\workspace\run.yaml
  (actual file is at C:\workspace\MyRunner\run.yaml)
exit code: 1
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §7, §13
Trap mines: s13 (CWD resolution documented in s07 error table)
Hard because:
- Error shows a path; model may assume file is missing/misnamed
- Fix is `cd` not a file rename
- CWD context not always obvious from a short log snippet
Expected root cause:
- `dotnet run -- run run.yaml` executed from `C:\workspace` instead of `C:\workspace\MyRunner`
- QaaS resolves config path relative to CWD; resolves to wrong directory
- Fix: `cd MyRunner` before `dotnet run -- run run.yaml`
Verify (mechanical): answer prescribes `cd` into project directory; does not suggest renaming or moving the YAML.
Rubric (graded):
- 3: identifies CWD cause, prescribes `cd` fix, cites error-signature table
- 2: suggests moving file instead of changing directory
- 1: suggests absolute path in YAML or ignores CWD issue
Solution sketch: Run `cd C:\workspace\MyRunner` then `dotnet run -- run run.yaml` so the YAML resolves correctly.

---

### X-107: Redis Controller Not Configured — MockerCommands Timeout
Tier: T3
Goal: Diagnose mocker-command timeout when Controller block or ServerName is absent.
Evidence:
```
[WARN] MockerCommands timeout after 30000ms waiting for mocker acknowledgment
[INFO] Initialized Redis controller for server '' with instance id 'abc123'
exit code: 1
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §7, §13
Trap mines: s13#11 (real controller log format), s13 (Redis / ServerName unset)
Hard because:
- Controller appears to initialize (log line present) but ServerName is empty string
- Timeout message does not name Redis as the cause
- Model must cross-reference runner ServerName vs mocker Controller ServerName
Expected root cause:
- Mocker `Controller.ServerName` is blank or missing; runner sends commands on a non-matching channel
- Runner never receives acknowledgment → timeout
- Fix: set identical `ServerName` in both runner and mocker Controller blocks
Verify (mechanical): answer identifies mismatched ServerName as root cause; prescribes matching literal value in both files.
Rubric (graded):
- 3: names ServerName mismatch, shows both files need same literal, no extra changes
- 2: blames Redis connectivity without checking ServerName
- 1: suggests raising timeout value
Solution sketch: Set `Controller: ServerName: mocker-ctrl` (same literal) in both the mocker YAML and the runner's MockerCommands block.

---

### X-108: Verify Step Commented Out — Vacuous Exit 0
Tier: T3
Goal: Identify verify step that always exits 0 because the command starts with `#`.
Evidence:
```yaml
verify:
  - description: Run the test
    cmd: "# dotnet run -- run test.qaas.yaml"
```
```
[verify] exit 0
(no allure-results produced)
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §13
Trap mines: s13#14 (leading # comments out cmd in PowerShell)
Hard because:
- YAML looks like a valid verify step; the `#` is subtle
- Exit 0 with no artifacts is not an obvious error signal
- Model must know PowerShell treats `# ...` as a comment string → instant exit 0
Expected root cause:
- Verify `cmd` starts with `#`; PowerShell `-Command "# dotnet run..."` treats the whole string as a comment → exits 0 immediately
- No test executes; no allure artifacts produced; scenario always appears to pass
- Fix: move intent to `description`; begin `cmd` with the actual executable
Verify (mechanical): answer identifies s13#14, removes `#` from cmd, no other changes.
Rubric (graded):
- 3: names s13#14, shows corrected cmd without `#`, explains PowerShell comment behavior
- 2: removes `#` but doesn't explain why it matters
- 1: suggests adding a separate cmd line or ignores the issue
Solution sketch: Change `cmd: "# dotnet run -- run test.qaas.yaml"` to `cmd: "dotnet run -- run test.qaas.yaml"`.

---

### X-109: Port Contract Violation — Probe on Different Port Than Mocker
Tier: T3
Goal: Diagnose MOCKER NEVER READY timeout because probe monitors a port the mocker never binds.
Evidence:
```
[verify] Waiting for port 8090 to open (TCP probe)...
[verify] MOCKER NEVER READY after 60s — exit 9
(mocker logs show: Listening on http://0.0.0.0:8080)
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §13
Trap mines: s13#16 (port contract: probe/mocker/runner must share one literal)
Hard because:
- Mocker is actually running; the wait-gate just checks the wrong port
- Exit 9 from the probe suggests mocker failure, but mocker is healthy
- Runner never executes so no test failure evidence is visible
Expected root cause:
- TCP probe is polling port 8090; mocker binds to 8080
- Port contract violation (s13#16): probe, mocker `Servers.Http.Port`, and runner `Http.Port` must all use the same literal
- Fix: align all three to the same port value (e.g. 8080)
Verify (mechanical): answer identifies three-way port contract, prescribes single literal across probe/mocker/runner; no other changes.
Rubric (graded):
- 3: names all three places needing the same port, cites s13#16, minimal fix
- 2: fixes probe port only, ignores runner Http.Port
- 1: suggests changing mocker port to 8090 without checking runner
Solution sketch: Set port `8080` in the TCP probe cmd, mocker `Servers: - Http: Port: 8080`, and runner `Http: Port: 8080`.

---

### X-110: RabbitMQ Topology Missing — No Exchange Found
Tier: T3
Goal: Identify missing exchange setup probe as the cause of Publisher outputs=0 and exit 1.
Evidence:
```
NOT_FOUND - no exchange 'orders' in vhost '/'
  AMQP classId=40, methodId=10
Output Source 'OrderOut' Contains 0 Outputs
exit code: 1
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §7, §13
Trap mines: s13#17 (Publisher/Consumer don't create topology)
Hard because:
- Error says "not found" which looks like a connection or vhost config issue
- Model may suggest fixing host/vhost instead of adding setup probe
- AMQP class ID numbers are obscure; model must know to read "no exchange" as topology missing
Expected root cause:
- Publisher cannot connect to exchange `orders` because it was never created
- QaaS Publisher/Consumer do not auto-create topology (s13#17)
- Fix: add `CreateRabbitMqExchanges` probe at Stage 0 to declare the exchange before the Publisher runs
Verify (mechanical): answer prescribes CreateRabbitMqExchanges probe at Stage 0; no other changes.
Rubric (graded):
- 3: names missing topology, prescribes CreateRabbitMqExchanges at Stage 0, cites s13#17
- 2: suggests correct probe but wrong stage or wrong probe name
- 1: suggests fixing vhost config or host address
Solution sketch: Add a Stage-0 `CreateRabbitMqExchanges` probe declaring exchange `orders` before the Publisher Transaction.

---

### X-111: Mixed-Case Route 404 + Vacuous HttpStatus Green
Tier: T4
Goal: Diagnose a run that exits 0 with PASS but never hits the mocker, due to case-sensitive route mismatch and vacuous HttpStatus.
Evidence:
```yaml
# runner
Route: getUserData
# mocker
Path: /getuserdata
```
```
[INFO] GET /getUserData returned 404
[INFO] Output Source 'UserOut' Contains 0 Outputs
[PASS] HttpStatus: All configured outputs arrived with status 200 (0 outputs checked)
exit code: 0
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §7, §13
Trap mines: s13#5b (route case-sensitivity), s13#13 (vacuous HttpStatus)
Hard because:
- Run exits 0 with PASS; appears green
- Route differs by case only — subtle diff between `getUserData` and `getuserdata`
- Two independent defects both required to explain the false green
Expected root cause:
- Mocker lowercases `Path` to `getuserdata` and builds case-sensitive regex; runner sends `getUserData` → 404 (s13#5b)
- HttpStatus passes vacuously on 0 outputs (s13#13); no guard present
- Fix: lowercase runner Route to `getuserdata` AND add hermetic count guard
Verify (mechanical): answer names both s13#5b (case) and s13#13 (vacuous); prescribes lowercase route + count guard.
Rubric (graded):
- 3: both defects named with correct fix for each; cites both s13 rows
- 2: fixes one defect only
- 1: accepts run as passing or blames SUT
Solution sketch: Change `Route: getUserData` to `Route: getuserdata` in runner YAML and add `HermeticByExpectedOutputCount` guard.

---

### X-112: Silent Key Typo in AssertionConfiguration
Tier: T4
Goal: Identify a silently-ignored typo (`ExpectedOutputCount` vs `ExpectedCount`) causing assertion to apply no constraint.
Evidence:
```yaml
assertions:
  - Assertion: HermeticByExpectedOutputCount
    AssertionConfiguration:
      ExpectedOutputCount: 5   # typo — real key is ExpectedCount
      OutputNames: [Out1]
```
```
[PASS] HermeticByExpectedOutputCount: All configured outputs arrived (0 outputs checked)
exit code: 0
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §9, §13
Trap mines: s13#12 (typo keys silently ignored), s13#13 (vacuous pass follows)
Hard because:
- Assertion is the correct type; only one character-group wrong in the config key
- PASS with 0 outputs looks like vacuous HttpStatus but here the guard IS the hermetic assertion
- No error or warning line; purely silent failure
Expected root cause:
- `ExpectedOutputCount` is silently ignored; the real key is `ExpectedCount` (s13#12)
- With no effective constraint, assertion passes vacuously on 0 outputs
- Fix: rename `ExpectedOutputCount:` to `ExpectedCount:` exactly
Verify (mechanical): answer names the exact typo, provides corrected key `ExpectedCount`, cites s13#12.
Rubric (graded):
- 3: exact typo identified, correct key given, explains silent-ignore behavior
- 2: names wrong key but attributes to wrong cause
- 1: blames assertion type or adds a second assertion
Solution sketch: Rename `ExpectedOutputCount:` to `ExpectedCount:` in AssertionConfiguration; no other changes.

---

### X-113: Version Mis-Alignment — NU1102 on Common.Generators
Tier: T4
Goal: Trace NU1102 build error to using Runner's version (4.5.1) on a QaaS.Common.Generators reference.
Evidence:
```
error NU1102: Unable to find package QaaS.Common.Generators with version (>= 4.5.1)
  - Found versions: 3.5.1, 3.4.0, 3.3.2
MSBuild: Build FAILED.
exit code: 1
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §1, §13
Trap mines: s13#9 (independent per-package versions)
Hard because:
- NU1102 looks like a feed/network problem; model may suggest fixing NuGet.Config
- Version 4.5.1 is correct for the Runner itself; model must know it doesn't apply to Common.*
- Fix is a version change, not a feed change
Expected root cause:
- `.csproj` has `QaaS.Common.Generators` at version `4.5.1`; correct version is `3.5.1` (s13#9)
- QaaS packages have INDEPENDENT versions: Runner 4.5.1, Common.* 3.5.1
- Fix: change version to `3.5.1`; do not modify NuGet.Config
Verify (mechanical): answer changes version to `3.5.1`, explains independent versioning, does not modify feed config.
Rubric (graded):
- 3: correct version (3.5.1), explains independent version rule, no feed changes
- 2: correct version but suggests feed config change too
- 1: suggests clearing NuGet cache or adding a new feed
Solution sketch: Change `Version="4.5.1"` to `Version="3.5.1"` for the QaaS.Common.Generators PackageReference.

---

### X-114: Split Verify Steps — Mocker Dead Before Runner Runs
Tier: T4
Goal: Identify split verify-steps pattern causing mocker to terminate before runner connects.
Evidence:
```yaml
verify:
  - description: Start mocker
    cmd: "docker run -d --name mocker mymocker:latest"
  - description: Run runner
    cmd: "dotnet run -- run test.qaas.yaml"
```
```
[verify step 1] exit 0
[verify step 2] Connection refused localhost:8080
exit code: 1
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §13
Trap mines: s13#15 (split verify steps don't share background process), s13#16 (port contract)
Hard because:
- Two-step design looks logical; start mocker, then run runner
- `docker run -d` detaches but the next step may race the mocker startup
- Model must know s13#15: separate verify entries do NOT share a background process
Expected root cause:
- Two separate `verify[]` entries: first starts mocker (`-d` detach), second runs runner (s13#15)
- Between steps, container may not yet be ready; runner sees connection refused
- Fix: combine into one `cmd`—start mocker, wait-for-port, run runner, stop mocker—all inline
Verify (mechanical): answer merges both into one cmd with wait-for-port step; cites s13#15.
Rubric (graded):
- 3: merges into one cmd, includes wait-for-port, cites s13#15
- 2: adds sleep between steps rather than merging
- 1: suggests Docker restart or network config
Solution sketch: Merge into single cmd: start mocker in background, poll port, run runner, capture exit code, stop mocker.

---

### X-115: Dockerfile Trailing Comment on FROM → Parse Error
Tier: T4
Goal: Diagnose Docker build failure caused by inline comment on a FROM instruction line.
Evidence:
```
dockerfile parse error line 1: FROM requires either one or three arguments
Dockerfile:
  FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final  # production image
```
```
exit code: 1 (docker build)
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §13
Trap mines: s13#18 (trailing comments on Dockerfile instructions not allowed)
Hard because:
- `FROM ... AS final` is valid; only the `# production image` suffix breaks it
- Error message ("one or three arguments") is cryptic; `# production image` looks like 2 extra args
- Model must know Docker parses the comment as instruction arguments
Expected root cause:
- Trailing `# production image` on the FROM line is parsed as extra arguments (s13#18)
- Docker does not support inline comments on instruction lines
- Fix: move comment to its own line before FROM
Verify (mechanical): answer moves comment to own line before FROM; no other Dockerfile changes.
Rubric (graded):
- 3: moves comment to own line, cites s13#18, minimal change
- 2: deletes comment entirely (acceptable but loses intent)
- 1: suggests different base image or FROM syntax
Solution sketch: Move `# production image` to its own preceding line; leave `FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final` alone.

---

### X-116: Internal Dependency Port Collision — Compose Bind Failure
Tier: T4
Goal: Diagnose docker compose failure because a Redis port is mapped to host, colliding with existing Redis instance.
Evidence:
```yaml
services:
  redis:
    image: redis:7
    ports:
      - "6379:6379"
  mocker:
    image: mymocker:latest
    ports:
      - "8080:8080"
```
```
Error response from daemon: driver failed programming external connectivity
  Bind for 0.0.0.0:6379 failed: port is already allocated
exit code: 1
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §13
Trap mines: s13#19 (internal dependency port should not be published to host)
Hard because:
- Port mapping looks correct; 6379 is standard Redis
- Error at compose-up time, not at test time; may seem like an infra issue
- Fix is removing a port mapping, not a QaaS config change
Expected root cause:
- Redis service publishes 6379 to host; a Redis instance already occupies that host port (s13#19)
- Internal deps (Redis/RabbitMQ) don't need host port mapping; services reach them by service name inside compose network
- Fix: remove `ports: ["6379:6379"]` from the redis service; keep mocker host port
Verify (mechanical): answer removes redis host port mapping; explains internal-service-name access; no other changes.
Rubric (graded):
- 3: removes redis ports block, explains service-name access, cites s13#19
- 2: suggests changing port to an unused one (works but not minimal)
- 1: stops existing Redis on host without removing compose mapping
Solution sketch: Delete the `ports:` section under the `redis` service in docker-compose.yml.

---

### X-117: BOM in YAML Config — Silent Parse Failure
Tier: T4
Goal: Identify UTF-8 BOM at start of YAML file as the cause of "config file not found" or unexpected parse error.
Evidence:
```
[ERROR] YamlException: (Line 1, Col 1): expected 'MappingStart', got 'Scalar' (BOM marker)
  Path: test.qaas.yaml
exit code: 1
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §7
Trap mines: (encoding trap, not a named s13 row — tests model's general QaaS diagnosis depth)
Hard because:
- Error line/column points to the very start of the file; model may suspect YAML syntax
- BOM is invisible in most editors; file looks correct when opened
- Fix is re-saving without BOM, not editing YAML content
Expected root cause:
- YAML file was saved with UTF-8 BOM (EF BB BF prefix); YAML parser rejects BOM as invalid token
- File content is otherwise correct; fixing YAML fields will not help
- Fix: re-save file as UTF-8 without BOM (e.g. `Get-Content | Set-Content -Encoding utf8NoBOM`)
Verify (mechanical): answer identifies BOM encoding issue; prescribes re-save without BOM; does not suggest YAML edits.
Rubric (graded):
- 3: names BOM, prescribes utf8NoBOM re-save, no YAML content changes
- 2: names encoding issue but suggests wrong fix (e.g. add YAML header)
- 1: edits YAML content or suggests recreating file with same BOM
Solution sketch: Re-save `test.qaas.yaml` with PowerShell: `Get-Content test.qaas.yaml | Set-Content -Encoding utf8NoBOM test.qaas.yaml`.

---

### X-118: CRLF Line Endings in Container Shell Script — Crash on Start
Tier: T4
Goal: Diagnose container entrypoint crash caused by Windows CRLF line endings in a shell script.
Evidence:
```
standard_init_linux.go:228: exec user process caused: no such file or directory
  (entrypoint: /app/start.sh)
Container exit code: 127
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §7
Trap mines: (CRLF-in-sh trap — tests advanced container knowledge)
Hard because:
- "no such file or directory" seems like a missing file; the file clearly exists in the COPY
- Exit 127 is "command not found" — confusing when file is present
- Root cause requires knowing Linux rejects `\r\n` in shebang line
Expected root cause:
- `start.sh` was authored on Windows with CRLF line endings; Linux shell interprets `\r` as part of the interpreter path in the shebang line → "interpreter not found"
- File exists but is unexecutable due to invisible `\r` characters
- Fix: convert line endings to LF (`dos2unix start.sh` or `.gitattributes` with `* text=auto eol=lf`)
Verify (mechanical): answer names CRLF/shebang issue, prescribes LF conversion; does not suggest reinstalling shell.
Rubric (graded):
- 3: names CRLF-in-shebang, prescribes dos2unix or gitattributes LF, explains exec error
- 2: names CRLF but prescribes wrong fix (chmod +x alone)
- 1: suggests the file is missing or path is wrong
Solution sketch: Run `dos2unix start.sh` before building the Docker image, or add `*.sh text eol=lf` to `.gitattributes`.

---

### X-119: Multi-Bug: Wrong Storage Shape + Missing DataSourceNames
Tier: T4
Goal: Identify two YAML schema errors—outdated Storages shape AND missing DataSourceNames—in a single runner config.
Evidence:
```yaml
Storages:
  - Name: local
    StorageConfiguration:
      Type: Local
      Path: ./data
Transactions:
  - Name: Tx1
    Action: Transaction
    Http:
      Port: 8080
      Route: api
```
```
FTL Runner execution configuration is invalid
  Sessions:0:Storages:0: Property StorageConfiguration not found in Storage object
  Sessions:0:Transactions:0: DataSourceNames or DataSourcePatterns must be provided
exit code: 1
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §2, §7, §13
Trap mines: s13#2 (Storages shape), s13#3 (DataSourceNames required)
Hard because:
- Two independent schema errors in the same FTL block
- Old Storages format looks exactly like the docs; model must know the new shape
- Fixing storage alone leaves DataSourceNames error; model must address both
Expected root cause:
- Storages uses outdated `StorageConfiguration: {Type:Local, Path:..}` shape; correct is `- FileSystem: {Path: ./data}` (s13#2)
- Transaction block missing `DataSourceNames: [src]` (s13#3)
- Both must be corrected; either fix alone produces exit 1
Verify (mechanical): answer shows both corrected YAML blocks; no extra fields changed.
Rubric (graded):
- 3: both fixes correct and minimal, cites s13#2 + s13#3
- 2: one fix correct, other partially wrong
- 1: only one fix provided
Solution sketch: Replace `StorageConfiguration: {Type:Local,Path:..}` with `FileSystem: {Path: ./data}` and add `DataSourceNames: [src.csv]` to the Transaction.

---

### X-120: Hook Compiled But Not Discovered — Wrong Assembly in csproj
Tier: T4
Goal: Diagnose custom hook that builds successfully but causes FTL because it's defined in a referenced assembly that QaaS doesn't scan.
Evidence:
```
FTL I1 hook instance 0 not found in any of the provided assemblies
  Requested: MyCompany.QaaS.Hooks.CustomBodyAssertion
exit code: -532462766
(Build succeeded; MyCompany.QaaS.Hooks.dll present in output)
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §4, §7, §13
Trap mines: s13#8 (assembly scanning), s13 (hook discovery)
Hard because:
- Build succeeds; DLL is present; error is at runtime hook-discovery
- Model must know QaaS scans only assemblies listed in the runner config or the entry assembly
- Fix is adding the assembly reference in the runner YAML, not in csproj
Expected root cause:
- Custom hook DLL is built and copied to output but runner YAML does not reference the assembly for scanning
- QaaS hook discovery scans only declared assemblies; omitting the external DLL → FTL
- Fix: add `Assemblies: [MyCompany.QaaS.Hooks.dll]` (or equivalent) to runner config
Verify (mechanical): answer identifies missing assembly declaration in runner config; prescribes adding Assemblies entry; no csproj changes.
Rubric (graded):
- 3: names assembly-declaration gap, shows Assemblies config fix, distinguishes from package ref issue
- 2: suggests adding another PackageReference (wrong layer)
- 1: suggests rebuilding or clearing bin/obj
Solution sketch: Add `Assemblies: [MyCompany.QaaS.Hooks.dll]` to the runner YAML configuration so QaaS scans the custom hook assembly.

---

### X-121: Hermetic Guard on Wrong OutputName — Passes Despite No Real Traffic
Tier: T4
Goal: Identify a hermetic guard asserting on a non-existent OutputName, which vacuously passes and masks a real routing failure.
Evidence:
```yaml
assertions:
  - Assertion: HermeticByExpectedOutputCount
    AssertionConfiguration:
      ExpectedCount: 3
      OutputNames: [ResponseX]   # typo: real output is 'Response'
  - Assertion: HttpStatus
    AssertionConfiguration:
      StatusCode: 200
      OutputNames: [Response]
```
```
[INFO] Output 'ResponseX' Contains 0 Outputs
[PASS] HermeticByExpectedOutputCount: All configured outputs arrived (0/3 checked — vacuous)
[PASS] HttpStatus: All configured outputs arrived with status 200
exit code: 0
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §7, §9, §13
Trap mines: s13#12 (typo keys ignored), s13#13 (vacuous pass), s13#6 (missing output → broken assertion when not vacuous)
Hard because:
- Both assertions show PASS; exit 0; no warning
- The guard is present and correctly typed from a syntax standpoint — the bug is the OutputName value
- Model must notice `ResponseX` ≠ `Response` and know that a guard on a missing output vacuously passes
Expected root cause:
- `OutputNames: [ResponseX]` references an output that doesn't exist; hermetic guard gets 0 outputs → vacuous PASS
- HttpStatus on `Response` also passes vacuously (0 real outputs due to routing issue)
- Fix: correct `ResponseX` to `Response` in the hermetic guard's OutputNames
Verify (mechanical): answer identifies OutputName typo in hermetic guard; corrects to `Response`; explains vacuous-pass chain.
Rubric (graded):
- 3: names OutputName typo, corrects it, explains both assertions were vacuous
- 2: corrects typo but doesn't explain why HttpStatus also vacuously passed
- 1: only blames routing without fixing the guard OutputName
Solution sketch: Change `OutputNames: [ResponseX]` to `OutputNames: [Response]` in the HermeticByExpectedOutputCount assertion.

---

### X-122: NuGet Feed with Unresolved %VAR% Environment Variable
Tier: T4
Goal: Diagnose NU1301 feed error caused by unexpanded `%ARTIFACTORY_URL%` placeholder in NuGet.Config.
Evidence:
```xml
<packageSources>
  <add key="Artifactory" value="%ARTIFACTORY_URL%/nuget/v3/index.json" />
</packageSources>
```
```
error NU1301: Unable to load the service index for source
  http://%ARTIFACTORY_URL%/nuget/v3/index.json
exit code: 1
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §8, §13
Trap mines: s13 (airgap/feed forensics — %VAR% not expanded by NuGet)
Hard because:
- Environment variable syntax looks correct; %VAR% is standard Windows env syntax
- NuGet.Config does NOT expand environment variables in `value` attributes
- Fix: set literal URL or use `$(ARTIFACTORY_URL)` MSBuild property if on CI
Expected root cause:
- NuGet.Config `value` attribute does not expand `%VAR%` style environment variables
- Feed URL is literally `%ARTIFACTORY_URL%/...` → NU1301 unreachable source
- Fix: replace with the literal URL, or set it via `dotnet nuget add source --name` which does expand env vars at call time
Verify (mechanical): answer explains NuGet.Config doesn't expand env vars; prescribes literal URL or CLI-based source addition.
Rubric (graded):
- 3: names NuGet env-var-no-expand behavior, prescribes literal URL, no other config changes
- 2: suggests setting the env var (won't help for NuGet.Config value)
- 1: blames network or credentials
Solution sketch: Replace `%ARTIFACTORY_URL%` with the literal Artifactory base URL in NuGet.Config, or add the source via `dotnet nuget add source`.

---

### X-123: Template Version Mismatch — Scaffold Produces Outdated csproj
Tier: T4
Goal: Identify that the scaffold template installed at an old version emits wrong package versions, causing NU1102 at restore.
Evidence:
```
(scaffolded .csproj shows QaaS.Runner Version="2.0.0")
error NU1102: Unable to find package QaaS.Runner with version (>= 2.0.0)
  Found versions: 4.5.1, 4.4.0, ...
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §1, §13
Trap mines: s13#9 (correct versions: Runner 4.5.1)
Hard because:
- NU1102 usually means the version is too new; here 2.0.0 is too old (not on any configured feed)
- Scaffold appeared to succeed; problem surfaces only at restore
- Model must know `dotnet new` template caches need updating, and correct version is 4.5.1
Expected root cause:
- Installed `qaas-runner` dotnet template is stale (version 2.0.0 era); emits outdated PackageReference version
- QaaS.Runner 2.0.0 is no longer available on configured feeds; minimum available is 4.x
- Fix: update the template with `dotnet new install QaaS.Templates` then re-scaffold, or manually bump version to `4.5.1`
Verify (mechanical): answer prescribes version bump to `4.5.1`; optionally mentions template update; no feed changes.
Rubric (graded):
- 3: names stale template, prescribes 4.5.1, explains template update path
- 2: prescribes 4.5.1 but doesn't explain template staleness
- 1: suggests clearing NuGet cache or re-installing .NET SDK
Solution sketch: Edit the scaffolded `.csproj` to set `Version="4.5.1"` for QaaS.Runner, or reinstall the template then re-scaffold.

---

### X-124: Mocker Stub TransactionData + Probe Wrong Port — Two-Bug Stack
Tier: T4
Goal: Diagnose a run that fails with both a mocker startup schema error and a probe timeout, requiring two independent fixes.
Evidence:
```
[mocker] Property TransactionData in path Stubs:0 - not found in TransactionStubConfig object
[verify] Waiting for port 9090... MOCKER NEVER READY (exit 9)
(mocker Servers.Http.Port: 8080; probe polls 9090)
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §3, §7, §13
Trap mines: s13#1 (TransactionData), s13#16 (port contract)
Hard because:
- Mocker schema error causes it to start degraded but still bind port 8080
- Probe polls 9090 (a second port contract violation); exit 9 masks the schema error in logs
- Model must identify both bugs; fixing only the port would expose the stub error, and vice versa
Expected root cause:
- Mocker YAML uses `TransactionData:` instead of `ProcessorConfiguration:` (s13#1); stub is misconfigured
- TCP probe polls port 9090; mocker binds 8080 → port contract violation (s13#16)
- Fix both: rename stub key AND align port to 8080 in probe
Verify (mechanical): answer names both bugs; provides both fixes; no other changes.
Rubric (graded):
- 3: both fixes correct and minimal, cites s13#1 + s13#16
- 2: one fix correct, other partially addressed
- 1: only fixes port or only fixes stub key
Solution sketch: Replace `TransactionData:` with `ProcessorConfiguration:` in mocker stub; change probe port from 9090 to 8080.

---

### X-125: allure-results Missing — Verify Cmd Not Copying Output Directory
Tier: T4
Goal: Identify why allure-results directory is empty: runner ran successfully but CWD mismatch placed artifacts in a different directory.
Evidence:
```
[verify] dotnet run -- run test.qaas.yaml
exit code: 0
[grader] allure-results/ not found at C:\workspace\allure-results
(allure-results actually at C:\workspace\MyRunner\allure-results)
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §6, §7
Trap mines: s13 (CWD affects both config resolution and artifact output path)
Hard because:
- Runner exits 0; test appears to pass; artifacts just aren't where grader looks
- CWD affects both config resolution and artifact destination
- Fix: either run from project dir, or explicitly pass `--output` flag pointing to expected location
Expected root cause:
- Runner was invoked from `C:\workspace` instead of `C:\workspace\MyRunner`; allure-results written relative to CWD → `C:\workspace\MyRunner\allure-results`
- Grader looks in `C:\workspace\allure-results` → not found
- Fix: `cd` into project dir before invoking runner, or add `--output C:\workspace\allure-results`
Verify (mechanical): answer identifies CWD-relative artifact path; prescribes `cd` or `--output` flag.
Rubric (graded):
- 3: names CWD artifact placement, prescribes `cd` or `--output`, no other changes
- 2: prescribes moving allure-results manually (post-hoc, not a fix)
- 1: blames runner or says test didn't run
Solution sketch: Either `cd C:\workspace\MyRunner` before running, or add `--output C:\workspace\allure-results` to the dotnet run command.

---

### X-126: RabbitMQ Auth Failure — Wrong vhost in Runner Config
Tier: T4
Goal: Identify AMQP authentication/vhost error as the cause of Consumer outputs=0 and assertion failure.
Evidence:
```
ACCESS_REFUSED - Login was refused using authentication mechanism PLAIN
  vhost: /staging, user: 'guest'
Output Source 'MsgOut' Contains 0 Outputs
assertion failed: HermeticByExpectedOutputCount expected 2, got 0
exit code: 1
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §2, §7
Trap mines: (RabbitMQ auth/vhost — advanced connection forensics)
Hard because:
- Error says "Login refused" but the mechanism and user are correct; the issue is the vhost
- `guest` user in RabbitMQ is restricted to the default vhost `/`; `/staging` vhost requires a dedicated user
- Model must distinguish auth failure from vhost access control
Expected root cause:
- Runner config specifies `VirtualHost: /staging`; RabbitMQ `guest` user is only allowed on vhost `/`
- AMQP reports this as AUTH failure (not a "vhost not found" error)
- Fix: either change VirtualHost to `/` or configure a non-guest user with access to `/staging`
Verify (mechanical): answer identifies vhost restriction for guest user; prescribes vhost `/` or a dedicated user.
Rubric (graded):
- 3: names guest-vhost restriction, prescribes correct vhost or new user, distinguishes from password error
- 2: names vhost issue but suggests wrong fix (changing password)
- 1: blames network or broker availability
Solution sketch: Change `VirtualHost: /staging` to `VirtualHost: /` in the RabbitMQ connection config, or provision a user with access to the staging vhost.

---

### X-127: HttpStatus + Wrong OutputNames List — Assertion Broken on Null
Tier: T4
Goal: Identify that HttpStatus `OutputNames` lists an output that doesn't exist, causing a broken (null-ref) assertion instead of failure.
Evidence:
```yaml
- Assertion: HttpStatus
  AssertionConfiguration:
    StatusCode: 200
    OutputNames: [ApiResponseX]   # output is named 'ApiResponse'
```
```
assertion broken: "Value cannot be null. (Parameter 'source')"
Output 'ApiResponseX' Contains 0 Outputs
exit code: 1
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §7, §9, §13
Trap mines: s13#6 (missing output → null-ref broken), s13#4 (HttpStatus uses OutputNames list)
Hard because:
- "Value cannot be null" looks like a framework bug, not a config typo
- Broken status vs failed status requires knowing s13#6
- OutputName typo `ApiResponseX` vs `ApiResponse` is a one-character difference
Expected root cause:
- `OutputNames: [ApiResponseX]` references a non-existent output; assertion engine gets null for the output set (s13#6)
- This produces `broken` status (exception), not `failed` status
- Fix: change `ApiResponseX` to `ApiResponse` in OutputNames
Verify (mechanical): answer identifies OutputName typo, corrects it, explains broken-vs-failed distinction.
Rubric (graded):
- 3: names output name typo, explains null-ref broken status, minimal fix
- 2: names typo but conflates broken and failed statuses
- 1: suggests assertion type change or framework version upgrade
Solution sketch: Change `OutputNames: [ApiResponseX]` to `OutputNames: [ApiResponse]` in the HttpStatus assertion.

---

### X-128: Exit -532462766 from Missing Common.Probes Package
Tier: T4
Goal: Diagnose FTL exit -532462766 from a missing QaaS.Common.Probes reference when using a built-in probe type.
Evidence:
```
FTL I1 hook instance 0 not found in any of the provided assemblies
  Requested: QaaS.Common.Probes.TcpConnectProbe
exit code: -532462766
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §7, §11, §13
Trap mines: s13#8 (probes need explicit package ref), s13#9 (Common.Probes version 1.5.1)
Hard because:
- Same error signature as missing Assertions package; model must distinguish by the namespace
- Correct version for Common.Probes is `1.5.1`, not 3.5.1 (different from Common.Assertions)
- Model may apply the wrong version if it doesn't know independent versioning
Expected root cause:
- `.csproj` missing `<PackageReference Include="QaaS.Common.Probes" Version="1.5.1" />`
- Common.Probes has its own version (1.5.1), not shared with Assertions (3.5.1) (s13#9)
- Fix: add the correct package reference
Verify (mechanical): answer names `QaaS.Common.Probes` at version `1.5.1`; no other package changes.
Rubric (graded):
- 3: exact package name + version 1.5.1, explains independent versioning
- 2: correct package name, wrong version (e.g. 3.5.1 or 4.5.1)
- 1: adds wrong package (e.g. Common.Assertions) or project reference
Solution sketch: Add `<PackageReference Include="QaaS.Common.Probes" Version="1.5.1" />` to the runner `.csproj`.

---

### X-129: Redis Container Mapped to Host — Bind Collision + Mocker Unreachable
Tier: T4
Goal: Diagnose compose failure where Redis port collision prevents mocker from starting, leaving runner with no mocker to connect to.
Evidence:
```yaml
services:
  redis: { image: redis:7, ports: ["6379:6379"] }
  mocker: { image: mymocker:latest, depends_on: [redis], ports: ["8080:8080"] }
```
```
Error: Bind for 0.0.0.0:6379 failed: port is already allocated
mocker container never started
[runner] Connection refused localhost:8080
exit code: 1
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §13
Trap mines: s13#19 (internal dep port collision), s13#16 (mocker unreachable → port contract cascade)
Hard because:
- Two symptoms: compose fails + runner connection refused; model must see one root cause
- Cascade: Redis bind failure → mocker never starts → runner can't connect
- Fix is removing redis host port; mocker reaches Redis by service name internally
Expected root cause:
- Redis `ports: ["6379:6379"]` collides with host Redis → compose aborts → mocker never starts (s13#19)
- Runner sees connection refused because mocker never started (cascade)
- Fix: remove redis host port mapping; mocker uses `redis:6379` via compose network
Verify (mechanical): answer removes redis port mapping, explains cascade, does not add host port for Redis; mocker port stays.
Rubric (graded):
- 3: removes redis ports, explains cascade, mentions service-name internal access
- 2: removes redis ports but misses cascade explanation
- 1: tries to change Redis port to avoid conflict (doesn't fix cascade)
Solution sketch: Delete `ports: ["6379:6379"]` from the redis service; mocker communicates with Redis via `redis:6379` in the compose network.

---

### X-130: Log Says "Controller Ready" But Real Log Format Differs — False Confidence
Tier: T4
Goal: Identify that a verify script waiting for "Controller channel ready" in mocker logs never fires because the real log line uses a different format.
Evidence:
```yaml
# verify cmd polls mocker logs for "Controller channel ready: HelloMocker"
cmd: |
  docker logs mocker 2>&1 | Select-String "Controller channel ready" -Quiet
  if (-not $?) { throw "Mocker not ready" }
```
```
[verify] Mocker not ready after 30s
(actual mocker log: "Initialized Redis controller for server 'HelloMocker' with instance id '...'")
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §13
Trap mines: s13#11 (real controller log format differs from docs)
Hard because:
- Script logic is correct; the wait condition is wrong
- Docs explicitly show "Controller channel ready" which is the trap
- Real log format (s13#11) is never matched → wait always times out
Expected root cause:
- Verify script searches for "Controller channel ready: HelloMocker" — the docs claim this text (s13#11)
- Real mocker log is `Initialized Redis controller for server 'HelloMocker' with instance id '...'`
- Fix: change the poll string to match the actual log text
Verify (mechanical): answer names s13#11, prescribes polling for `Initialized Redis controller for server` instead.
Rubric (graded):
- 3: names s13#11, provides corrected poll string, no other changes
- 2: names log mismatch but uses a different wrong search string
- 1: suggests increasing wait timeout instead of fixing poll string
Solution sketch: Change `Select-String "Controller channel ready"` to `Select-String "Initialized Redis controller for server"` in the verify cmd.

---

### X-131: Triple Silent Failure — Vacuous HttpStatus + Typo'd Hermetic Key + Wrong OutputName
Tier: T5
Goal: Prove a GREEN run is wrong by identifying three stacked silent failures: vacuous HttpStatus, silently-ignored hermetic key typo, and OutputName mismatch.
Evidence:
```yaml
assertions:
  - Assertion: HttpStatus
    AssertionConfiguration:
      StatusCode: 200
      OutputNames: [TxOut]
  - Assertion: HermeticByExpectedOutputCount
    AssertionConfiguration:
      ExpectedOutputCount: 5    # typo: should be ExpectedCount
      OutputNames: [TxOutX]    # wrong: real output is TxOut
```
```
[INFO] Output 'TxOut' Contains 0 Outputs
[INFO] Output 'TxOutX' Contains 0 Outputs
[PASS] HttpStatus: All configured outputs arrived with status 200 (0 outputs checked)
[PASS] HermeticByExpectedOutputCount: All configured outputs arrived (0 outputs checked)
exit code: 0
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §7, §9, §13
Trap mines: s13#12 (silently ignored key), s13#13 (vacuous pass), s13#6 (missing output)
Hard because:
- All assertions show PASS; exit 0; no warnings — run appears perfectly green
- Three independent defects each contribute to the false green; any two without the third would still yield a false green
- Model must reason that PASS + 0 outputs is always suspicious and trace each silent failure
Expected root cause:
- HttpStatus passes vacuously: `TxOut` exists in config but receives 0 real outputs (s13#13)
- `ExpectedOutputCount` is silently ignored (s13#12); real key is `ExpectedCount`; hermetic guard has no constraint
- `OutputNames: [TxOutX]` references a non-existent output; hermetic guard gets 0 outputs vacuously
- Fix: correct both key typo AND OutputName; investigate why TxOut receives 0 outputs
Verify (mechanical): answer names all three defects, corrects `ExpectedOutputCount`→`ExpectedCount`, corrects `TxOutX`→`TxOut`, and identifies zero-output root cause.
Rubric (graded):
- 3: all three defects named with correct fixes; explains stacked vacuous-pass chain
- 2: two defects named correctly, one missed or fix wrong
- 1: one defect or accepts run as passing
Solution sketch: Fix `ExpectedOutputCount` → `ExpectedCount`; fix `OutputNames: [TxOutX]` → `[TxOut]`; then diagnose why TxOut captures 0 outputs (route/stub issue).

---

### X-132: Vacuous HttpStatus + Count Guard on Orphaned Output + Route Double-Slash
Tier: T5
Goal: Identify three stacked defects: leading-slash 404, vacuous HttpStatus, and hermetic guard referencing an output name that also gets 0 outputs.
Evidence:
```yaml
# runner
Route: /orders
# mocker Path: /orders
assertions:
  - Assertion: HttpStatus
    AssertionConfiguration: { StatusCode: 200, OutputNames: [OrderOut] }
  - Assertion: HermeticByExpectedOutputCount
    AssertionConfiguration: { ExpectedCount: 3, OutputNames: [OrderOut] }
```
```
[WARN] GET //orders returned 404
[INFO] Output 'OrderOut' Contains 0 Outputs
[PASS] HttpStatus: 0 outputs checked
[PASS] HermeticByExpectedOutputCount: 0/3 checked — vacuous
exit code: 0
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §7, §9, §13
Trap mines: s13#5 (leading slash), s13#13 (vacuous HttpStatus), s13#13 (vacuous hermetic when outputs=0)
Hard because:
- The hermetic guard IS present, but vacuously passes because the root cause (leading slash) produces 0 outputs
- Three symptoms (404, vacuous HttpStatus, vacuous hermetic) all share one root cause (leading slash)
- Model must distinguish: fixing the route fixes all three; the guard is structurally correct
Expected root cause:
- `Route: /orders` has a leading slash; mocker sees `//orders` → 404 (s13#5)
- 0 outputs → both HttpStatus and hermetic guard pass vacuously (s13#13)
- Fix: remove leading slash (`Route: orders`); both assertions then fire on real traffic
Verify (mechanical): answer identifies leading slash as root cause; removes it; explains why both assertions vacuously passed.
Rubric (graded):
- 3: names leading slash, removes it, explains vacuous-pass cascade from 0 outputs
- 2: names leading slash and fixes it, but doesn't explain both assertions' vacuous behavior
- 1: adds a second route or changes mocker Path
Solution sketch: Change `Route: /orders` to `Route: orders`; the hermetic guard is structurally correct and will work once traffic flows.

---

### X-133: Mixed-Case Route + Vacuous Hermetic + Silently-Ignored Processor Key
Tier: T5
Goal: Identify three co-present defects: case-sensitive 404, vacuous hermetic guard, and mocker stub using deprecated `TransactionData` key.
Evidence:
```yaml
# runner Route: processOrder  (mocker Path: /processorder)
# mocker stub: TransactionData: {Body: ok, StatusCode: 200}
assertions:
  - Assertion: HermeticByInputOutputPercentage
    AssertionConfiguration:
      ExpectedPercentage: 100
      OutputNames: [ProcOut]
```
```
[WARN] GET /processOrder returned 404
Property TransactionData in path Stubs:0 - not found in TransactionStubConfig object
[INFO] Output 'ProcOut' Contains 0 Outputs
[PASS] HermeticByInputOutputPercentage: 0/0 = vacuous
exit code: 0
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §3, §7, §9, §13
Trap mines: s13#5b (case-sensitive route), s13#1 (TransactionData), s13#13 (vacuous hermetic)
Hard because:
- Two independent bugs (case route, deprecated stub key) both produce 0 outputs; hermetic guard vacuously passes all three
- Template warning for TransactionData appears but doesn't prevent the run from starting
- Model must enumerate all three defects; fixing only the route still leaves stub misconfigured
Expected root cause:
- `Route: processOrder` mismatches mocker `Path: /processorder` (case-sensitive regex → 404) (s13#5b)
- Mocker stub uses `TransactionData:` instead of `ProcessorConfiguration:` (s13#1); stub would fail even if routed correctly
- 0 outputs → `HermeticByInputOutputPercentage` vacuously passes (s13#13)
- Fix: lowercase route to `processorder`; replace `TransactionData:` with `ProcessorConfiguration:`
Verify (mechanical): answer names all three defects with correct fixes; explains vacuous hermetic.
Rubric (graded):
- 3: all three defects with correct fixes, explains vacuous chain
- 2: two defects correctly fixed
- 1: one defect fixed or accepts run as passing
Solution sketch: Change `Route: processOrder` → `Route: processorder`; replace `TransactionData:` → `ProcessorConfiguration:` in stub; hermetic guard needs no change.

---

### X-134: Multi-Bug: FTL from Two Missing Packages + Vacuous Pass on Third Assertion
Tier: T5
Goal: Diagnose a run that FTLs from two missing packages, but also has a vacuous assertion that would have hidden a logic bug if the packages were present.
Evidence:
```
FTL I1 hook instance 0 not found: QaaS.Common.Assertions.ContainsBodyAssertion
FTL I2 hook instance 0 not found: QaaS.Common.Generators.RandomStringGenerator
exit code: -532462766
```
```yaml
# Also present in runner YAML:
- Assertion: HermeticByExpectedOutputCount
  AssertionConfiguration:
    ExpectedOutputCount: 3   # typo — should be ExpectedCount
    OutputNames: [Out1]
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §7, §10, §13
Trap mines: s13#8 (explicit refs needed), s13#9 (correct versions), s13#12 (silently ignored key)
Hard because:
- Two FTL errors require two separate package additions (different families, different versions)
- Even after fixing FTL, the hermetic key typo means the count guard never enforces — a latent bug
- Model must address both FTL fixes AND flag the latent vacuous guard
Expected root cause:
- Missing `QaaS.Common.Assertions 3.5.1` and `QaaS.Common.Generators 3.5.1` (s13#8/s13#9)
- After adding packages, `ExpectedOutputCount` is still silently ignored (s13#12); hermetic guard latently broken
- Fix: add both package refs at 3.5.1; also rename `ExpectedOutputCount` → `ExpectedCount`
Verify (mechanical): answer adds both packages at 3.5.1 AND corrects the typo; explains FTL exit code; names latent vacuous risk.
Rubric (graded):
- 3: both packages at 3.5.1, typo corrected, latent risk explained
- 2: both packages correct, typo missed; or one package wrong version
- 1: one package added or typo only
Solution sketch: Add `QaaS.Common.Assertions 3.5.1` and `QaaS.Common.Generators 3.5.1` to `.csproj`; correct `ExpectedOutputCount` → `ExpectedCount`.

---

### X-135: Hermetic Math Error — Percentage Guard Set to 0
Tier: T5
Goal: Identify a hermetic-percentage guard set to 0 that always passes regardless of actual output ratio.
Evidence:
```yaml
- Assertion: HermeticByInputOutputPercentage
  AssertionConfiguration:
    ExpectedPercentage: 0
    OutputNames: [Out1]
```
```
[INFO] Output 'Out1' Contains 0 Outputs (3 inputs sent)
[PASS] HermeticByInputOutputPercentage: 0/3 = 0% >= 0% — PASS
exit code: 0
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §9, §13
Trap mines: s13#13 (vacuous/trivial guards — zero-percent is always true)
Hard because:
- Assertion math is technically correct (0% >= 0%); assertion is not broken or failed
- Run exits 0 with no error signals; requires knowing 0% threshold is meaningless
- Model must identify the intent-vs-config gap: 0% accepts any failure rate including 100% loss
Expected root cause:
- `ExpectedPercentage: 0` means "allow 0% output rate" — always passes even if all traffic is lost
- Guard provides no protection; 0 outputs from 3 inputs is silently accepted
- Fix: set `ExpectedPercentage` to 95 or 100 (per use case)
Verify (mechanical): answer identifies 0% threshold as the defect; prescribes ≥95; explains always-true math.
Rubric (graded):
- 3: names 0%-always-true, prescribes meaningful threshold (95-100), explains guard intent
- 2: prescribes higher threshold but doesn't explain why 0% is always true
- 1: blames output count or SUT without identifying threshold
Solution sketch: Change `ExpectedPercentage: 0` to `ExpectedPercentage: 95` (or 100 for deterministic HTTP).

---

### X-136: RabbitMQ Exchange Missing + HttpStatus Vacuous + Port Contract Off-by-One
Tier: T5
Goal: Identify three simultaneous defects: missing exchange topology, vacuous HttpStatus (0 outputs), and probe port off by one.
Evidence:
```
NOT_FOUND - no exchange 'events' in vhost '/'
[verify] Waiting for port 8081 (TCP probe)... MOCKER NEVER READY
(mocker binds 8080)
[INFO] Output 'HttpOut' Contains 0 Outputs
[PASS] HttpStatus: 0 outputs — vacuous
exit code: 9 (from probe timeout; runner never executed)
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §7, §11, §13
Trap mines: s13#16 (port contract), s13#17 (exchange topology), s13#13 (vacuous HttpStatus)
Hard because:
- Exit 9 comes from probe; runner never ran; yet HttpStatus PASS is visible in partial mocker logs
- Three defects each in a different subsystem (RabbitMQ, Docker/probe, assertion)
- Partial fix reveals next bug in sequence
Expected root cause:
- TCP probe checks port 8081; mocker binds 8080 → probe times out → exit 9 (s13#16)
- If port fixed: runner would try to publish to `events` exchange which doesn't exist → 0 outputs (s13#17)
- If topology added: HttpStatus vacuous pass still present with no count guard (s13#13)
- Fix all three: align port to 8080, add CreateRabbitMqExchanges probe, add hermetic count guard
Verify (mechanical): answer names all three defects in order; prescribes port align + topology probe + count guard.
Rubric (graded):
- 3: all three defects named in order with correct fixes; understands partial-fix sequence
- 2: two defects named, one missed
- 1: one defect or accepts exit 9 as final answer
Solution sketch: Align probe to port 8080; add Stage-0 CreateRabbitMqExchanges; add HermeticByExpectedOutputCount alongside HttpStatus.

---

### X-137: Dockerfile Trailing Comment + Wrong Base Image — Build Fails Then Would Crash
Tier: T5
Goal: Diagnose a two-layer build defect: first a parse error from a trailing comment on FROM, then (if fixed naively) a startup crash from wrong base image.
Evidence:
```dockerfile
FROM mcr.microsoft.com/dotnet/runtime:10.0 AS final  # http mocker
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "MyMocker.dll"]
```
```
dockerfile parse error line 1: FROM requires either one or three arguments
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §13
Trap mines: s13#18 (trailing comment on FROM), s13#7 (runtime vs aspnet)
Hard because:
- Removing the comment fixes the parse error, but the remaining `runtime:10.0` base would cause an ASP.NET crash at startup
- Model must identify BOTH defects even though only the first produces an error right now
- Two-layer fix: move comment to own line AND change base to `aspnet:10.0`
Expected root cause:
- Trailing `# http mocker` comment on FROM line causes parse error (s13#18)
- Base image `dotnet/runtime:10.0` lacks ASP.NET; mocker would crash at HTTP startup after the parse fix (s13#7)
- Fix both: move comment to own line AND change `runtime` → `aspnet`
Verify (mechanical): answer provides both fixes; explains that removing comment alone yields a second crash.
Rubric (graded):
- 3: both fixes (comment + aspnet), explains two-stage failure
- 2: fixes comment only without flagging runtime→aspnet
- 1: only moves comment or changes image without addressing both
Solution sketch: Move `# http mocker` to its own preceding line; change `runtime:10.0` to `aspnet:10.0` in the FROM instruction.

---

### X-138: Silent Typo in ProcessorConfiguration Key + Missing DataSourceNames + Vacuous Hermetic
Tier: T5
Goal: Identify three bugs where the mocker stub is silently misconfigured, the runner transaction has no data source, and the hermetic guard vacuously passes.
Evidence:
```yaml
# mocker stub
ProcessorConfiguration:
  Boody: hello        # typo: should be Body
  StatusCode: 200
# runner transaction
Transactions:
  - Name: Tx1
    Http: { Port: 8080, Route: api }
# assertions
- Assertion: HermeticByExpectedOutputCount
  AssertionConfiguration:
    ExpectedCount: 2
    OutputNames: [ApiOut]
```
```
[INFO] Output 'ApiOut' Contains 0 Outputs
[PASS] HermeticByExpectedOutputCount: 0/2 checked — vacuous
exit code: 0
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §2, §3, §7, §13
Trap mines: s13#12 (silently ignored ProcessorConfiguration key), s13#3 (DataSourceNames required), s13#13 (vacuous hermetic)
Hard because:
- Hermetic guard is correctly keyed (`ExpectedCount: 2`) but vacuously passes on 0 outputs
- ProcessorConfiguration key typo `Boody` is silently ignored; stub responds with empty body (not a crash)
- Runner has no DataSourceNames; config validation might not flag it if route is the action source
Expected root cause:
- `Boody:` silently ignored (s13#12); stub responds but with no body (not necessarily 0 outputs, but wrong body)
- Runner Transaction missing `DataSourceNames`/`DataSourcePatterns` (s13#3); config is invalid
- `ApiOut` receives 0 outputs → hermetic guard passes vacuously (s13#13)
- Fix: correct `Boody` → `Body`; add `DataSourceNames: [data.csv]` to Transaction; investigate 0-output cause
Verify (mechanical): answer names all three defects; corrects Boody→Body; adds DataSourceNames; explains vacuous guard.
Rubric (graded):
- 3: all three defects, all three fixes; explains vacuous chain
- 2: two defects fixed, one missed
- 1: one fix or accepts vacuous pass
Solution sketch: Fix `Boody` → `Body` in ProcessorConfiguration; add `DataSourceNames: [data.csv]` to Transaction; hermetic guard is structurally sound.

---

### X-139: Compose Port Collision + Redis Controller Mismatch + Missing Package FTL
Tier: T5
Goal: Diagnose a three-layer failure: compose won't start due to Redis port collision, and if started, Redis controller ServerName mismatch and missing hook package would both trigger.
Evidence:
```yaml
# docker-compose.yml
redis: { ports: ["6379:6379"] }
# runner YAML: Controller: ServerName: runner-ctrl
# mocker YAML: Controller: ServerName: mocker-ctrl
# runner .csproj: no QaaS.Common.Processors ref
```
```
Error: Bind for 0.0.0.0:6379 failed: port is already allocated
exit code: 1 (docker compose up)
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §1, §7, §13
Trap mines: s13#19 (internal dep port publish), s13 (ServerName mismatch), s13#8 (missing hook package)
Hard because:
- All three bugs are latent behind the compose failure; fixing compose reveals controller mismatch, then fixing that reveals FTL
- Model must read all three config files and enumerate all defects without a running system
- No single fix produces a working test; three independent changes required
Expected root cause:
- Redis host port mapping collides → compose fails to start (s13#19); fix: remove redis ports
- Controller ServerNames differ (`runner-ctrl` vs `mocker-ctrl`) → mocker commands timeout; fix: align to same literal
- `QaaS.Common.Processors` missing from csproj → FTL exit -532462766 (s13#8); fix: add at version `1.5.1`
Verify (mechanical): answer names all three defects with correct fixes; explains cascade order.
Rubric (graded):
- 3: all three defects in cascade order with correct fixes
- 2: two defects correct
- 1: only fixes compose, misses controller and FTL
Solution sketch: Remove redis `ports`; align both Controller.ServerName to same literal; add `QaaS.Common.Processors 1.5.1` to `.csproj`.

---

### X-140: Stale Template + Wrong Storages Shape + Vacuous HttpStatus — Full Scaffold Forensics
Tier: T5
Goal: Identify a newly scaffolded project that has three simultaneous defects: stale package version, outdated Storages shape, and vacuous HttpStatus with no guard.
Evidence:
```yaml
# scaffolded runner.qaas.yaml
Storages:
  - Name: local
    StorageConfiguration: { Type: Local, Path: ./data }
# scaffolded .csproj
<PackageReference Include="QaaS.Runner" Version="2.0.0" />
# assertions
- Assertion: HttpStatus
  AssertionConfiguration: { StatusCode: 200, OutputNames: [Resp] }
```
```
error NU1102: Unable to find package QaaS.Runner with version (>= 2.0.0)
exit code: 1 (restore)
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §1, §2, §7, §13
Trap mines: s13#9 (Runner version 4.5.1), s13#2 (Storages shape), s13#13 (vacuous HttpStatus)
Hard because:
- Build fails before tests run; model must also identify the two other latent defects in the YAML
- Stale scaffold produces multiple wrong artifacts simultaneously
- If only version is fixed, the outdated Storages shape will produce FTL; and HttpStatus will still be vacuous
Expected root cause:
- QaaS.Runner version `2.0.0` not on feed; correct is `4.5.1` (s13#9)
- Storages shape uses outdated `StorageConfiguration: {Type:Local,...}`; correct is `- FileSystem: {Path: ./data}` (s13#2)
- HttpStatus has no hermetic count guard → will vacuously pass if traffic doesn't reach mocker (s13#13)
- Fix all three: bump version, fix Storages shape, add count guard
Verify (mechanical): answer names all three, provides corrected YAML for Storages, bumps version to 4.5.1, adds count guard.
Rubric (graded):
- 3: all three defects with correct fixes
- 2: two defects, one missed (any one of the three)
- 1: only fixes NU1102
Solution sketch: Set QaaS.Runner to `4.5.1`; replace Storages with `- FileSystem: {Path: ./data}`; add HermeticByExpectedOutputCount alongside HttpStatus.

---

### X-141: Four-Bug Stack — Leading Slash + Case Route + TransactionData + Vacuous Guard
Tier: T5
Goal: Identify four co-present defects in a single run that exits 0: leading slash, case mismatch, deprecated stub key, and vacuous hermetic guard.
Evidence:
```yaml
# runner Route: /SearchItem  (mocker Path: /searchitem)
# mocker stub: TransactionData: {Body: found, StatusCode: 200}
assertions:
  - Assertion: HermeticByExpectedOutputCount
    AssertionConfiguration:
      ExpectedCount: 1
      OutputNames: [SearchOut]
  - Assertion: HttpStatus
    AssertionConfiguration: { StatusCode: 200, OutputNames: [SearchOut] }
```
```
[WARN] GET //SearchItem returned 404
Property TransactionData in path Stubs:0 - not found in TransactionStubConfig object
[INFO] Output 'SearchOut' Contains 0 Outputs
[PASS] HermeticByExpectedOutputCount: 0/1 — vacuous
[PASS] HttpStatus: 0 outputs — vacuous
exit code: 0
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §3, §7, §9, §13
Trap mines: s13#5 (leading slash), s13#5b (case sensitivity), s13#1 (TransactionData), s13#13 (vacuous pass)
Hard because:
- Four independent defects; route has BOTH leading slash AND case issue (`/SearchItem` vs `/searchitem`)
- Even fixing route exposes stub key bug; fixing stub key reveals vacuous guard issue
- All four produce 0 outputs; hermetic guard and HttpStatus both vacuously pass
Expected root cause:
- `Route: /SearchItem` has leading slash (s13#5) AND mixed case vs mocker's lowercase (s13#5b); fix: `Route: searchitem`
- Stub uses `TransactionData:` instead of `ProcessorConfiguration:` (s13#1)
- 0 outputs → both hermetic and HttpStatus guards pass vacuously (s13#13)
- Fix all: `Route: searchitem`, `ProcessorConfiguration:`, then verify traffic actually flows
Verify (mechanical): answer names all four defects with exact fixes for each; explains vacuous-pass cascade.
Rubric (graded):
- 3: all four defects named and fixed; explains cascade from 0 outputs
- 2: three defects fixed (any combination)
- 1: one or two defects fixed
Solution sketch: Fix `Route: /SearchItem` → `Route: searchitem`; replace `TransactionData:` with `ProcessorConfiguration:`; after fixes, both guards will fire on real traffic.

---

### X-142: Allure-Results JSON Broken + Session Data Missing — Evidence of Null-Output Cascade
Tier: T5
Goal: Read and interpret allure-results JSON showing broken assertions and empty SessionsData to trace the complete null-output cascade.
Evidence:
```json
// allure-results/abc123-result.json
{
  "name": "ContainsBody",
  "status": "broken",
  "statusDetails": {
    "message": "Value cannot be null. (Parameter 'source')",
    "trace": "at QaaS.Runner.Assertions..."
  }
}
// allure-results/SessionsData/ts1/Session1.json
{ "Inputs": [{"Body": "..."}], "Outputs": [] }
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §7, §9, §13
Trap mines: s13#6 (null-ref from missing output), s13#5 or s13#5b (route mismatch produces 0 outputs)
Hard because:
- Two artifacts must be cross-referenced: result JSON (broken assertion) and session data (empty Outputs)
- Broken status + null-ref is the s13#6 pattern; but the cause is in the session data, not the assertion
- Model must trace from Outputs=[] in SessionsData back to a route or stub misconfiguration
Expected root cause:
- Session has inputs but zero outputs → mocker never responded (route/stub mismatch)
- ContainsBody assertion gets null output set → `Value cannot be null` broken status (s13#6)
- Most likely cause: route mismatch (leading slash or case) or stub misconfigured (TransactionData)
- Fix: diagnose why Outputs=[] (check route, check stub key); the assertion itself is correct
Verify (mechanical): answer cross-references both allure files; identifies Outputs=[] as the upstream cause; prescribes route/stub investigation.
Rubric (graded):
- 3: cross-references both files, names null-ref pattern (s13#6), prescribes route/stub investigation
- 2: identifies null-ref but doesn't use SessionsData evidence
- 1: tries to fix the assertion rather than the upstream cause
Solution sketch: Examine mocker logs for 404; check runner Route for leading slash or case mismatch; check stub for TransactionData key; fix the upstream, not the assertion.

---

### X-143: hermetic Guard ExpectedCount Correct But OutputNames Targets HttpStatus Output — Guard is Structural No-Op
Tier: T5
Goal: Identify a hermetic guard that is structurally correct but targets an output name belonging to a different assertion, making the cross-assertion guard a no-op.
Evidence:
```yaml
assertions:
  - Assertion: HttpStatus
    AssertionConfiguration:
      StatusCode: 200
      OutputNames: [HttpOut]
  - Assertion: ContainsBody
    AssertionConfiguration:
      ExpectedBody: hello
      OutputNames: [BodyOut]
  - Assertion: HermeticByExpectedOutputCount
    AssertionConfiguration:
      ExpectedCount: 5
      OutputNames: [HttpOut]   # should guard BodyOut, not HttpOut
```
```
[INFO] Output 'HttpOut' Contains 5 Outputs
[INFO] Output 'BodyOut' Contains 0 Outputs
[PASS] HttpStatus
[BROKEN] ContainsBody: Value cannot be null (BodyOut missing)
[PASS] HermeticByExpectedOutputCount: 5/5 — PASS
exit code: 1
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §7, §9, §13
Trap mines: s13#6 (null-ref from missing output), s13#12 (conceptual: guard targets wrong output)
Hard because:
- Run exits 1 but the hermetic guard passes; model must see the guard targets the wrong output
- HttpOut has traffic (guard passes), but BodyOut is missing (ContainsBody broken)
- The fix is changing the guard's OutputNames from `HttpOut` to `BodyOut`, not adding a new guard
Expected root cause:
- `HermeticByExpectedOutputCount` guards `HttpOut` (which has traffic) instead of `BodyOut` (which has none)
- `BodyOut` is never populated → ContainsBody gets null → broken (s13#6)
- Fix: change guard's OutputNames to `[BodyOut]` to guard the correct output; also investigate why BodyOut is empty
Verify (mechanical): answer identifies wrong OutputNames on guard; changes to `[BodyOut]`; explains broken ContainsBody.
Rubric (graded):
- 3: identifies guard targeting wrong output, corrects OutputNames, explains null-ref broken
- 2: identifies broken assertion but doesn't connect guard mis-targeting
- 1: suggests adding a second guard without fixing the existing one
Solution sketch: Change hermetic guard's `OutputNames: [HttpOut]` to `OutputNames: [BodyOut]`; then investigate why BodyOut has 0 outputs.

---

### X-144: Log-Says-Success-But-Assert-Failed Paradox — Mocker Returns 200 But Body Check Fails
Tier: T5
Goal: Explain why mocker logs show 200 responses yet ContainsBody assertion fails — stub body typo silently ignored.
Evidence:
```yaml
# mocker stub ProcessorConfiguration:
Boody: "expected-content"
StatusCode: 200
```
```
[mocker] GET /api → 200 OK (stub matched)
[INFO] Output 'ApiOut' Contains 3 Outputs
[FAILED] ContainsBody: body '{}' does not contain 'expected-content'
exit code: 1
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §3, §7, §13
Trap mines: s13#12 (silently ignored ProcessorConfiguration key), s13#1 (ProcessorConfiguration shape)
Hard because:
- Mocker logs show 200 + stub matched; assertion fails on CONTENT, not on count
- Apparent paradox: mocker works, test fails; requires knowing `Boody` is silently ignored
- Fix is a one-character rename, not a routing or package change
Expected root cause:
- `Boody: "expected-content"` is silently ignored (s13#12); stub sends an empty/default body
- Mocker correctly returns 200 but with no body content matching the assertion
- Fix: rename `Boody:` to `Body:`
Verify (mechanical): answer identifies `Boody` typo; renames to `Body`; explains silent-ignore behavior.
Rubric (graded):
- 3: names `Boody`→`Body` typo, explains silent-ignore, no other changes
- 2: suggests changing assertion expected value instead of fixing stub
- 1: blames route or SUT content
Solution sketch: Rename `Boody: "expected-content"` to `Body: "expected-content"` in the mocker stub's ProcessorConfiguration.

---

### X-145: Port Contract: Runner Uses Different Port Than Mocker, HttpStatus Vacuous
Tier: T5
Goal: Identify port contract violation between runner and mocker causing 0 outputs, plus vacuous HttpStatus masking the failure.
Evidence:
```yaml
# mocker: Servers: - Http: Port: 8080
# runner transaction: Http: Port: 9090
assertions:
  - Assertion: HttpStatus
    AssertionConfiguration: { StatusCode: 200, OutputNames: [Out1] }
```
```
[runner] Connection refused localhost:9090
[INFO] Output 'Out1' Contains 0 Outputs
[PASS] HttpStatus: All configured outputs arrived with status 200 (0 outputs checked)
exit code: 0
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §2, §3, §7, §13
Trap mines: s13#16 (port contract), s13#13 (vacuous HttpStatus)
Hard because:
- Runner exits 0 with HttpStatus PASS despite connection refused
- Port mismatch is the root cause; vacuous pass masks it completely
- Model must identify both: fix the port AND add a hermetic count guard
Expected root cause:
- Runner sends traffic to port 9090; mocker binds 8080 → connection refused (s13#16)
- 0 outputs → HttpStatus passes vacuously (s13#13); no hermetic guard to catch it
- Fix: align runner `Http.Port` to 8080 AND add HermeticByExpectedOutputCount
Verify (mechanical): answer changes runner port to 8080; adds count guard; cites both s13 rows.
Rubric (graded):
- 3: port fix + count guard, cites s13#16 + s13#13
- 2: port fix only, no guard addition
- 1: accepts run as passing
Solution sketch: Change runner `Http: Port: 9090` to `Port: 8080`; add `HermeticByExpectedOutputCount` with `ExpectedCount: <N>`.

---

### X-146: CWD Trap + Vacuous Hermetic + CRLF Verify Script — Three Environmental Failures
Tier: T5
Goal: Identify CWD config-resolution failure, vacuous hermetic guard in the YAML, and CRLF in the verify shell script as three co-present defects.
Evidence:
```
CouldNotFindConfigurationException: YAML configuration file was not found.
  Resolved local path: C:\ci\test.qaas.yaml  (file is at C:\ci\MyRunner\test.qaas.yaml)
exit code: 1
```
```yaml
# test.qaas.yaml (once found) has:
- Assertion: HermeticByInputOutputPercentage
  AssertionConfiguration:
    ExpectedPercentage: 0
    OutputNames: [Out1]
```
```bash
# verify.sh (used in docker verify step, has CRLF)
#!/bin/bash\r\n
dotnet run -- run test.qaas.yaml\r\n
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §7, §13
Trap mines: s13 (CWD), s13#13 (zero-percent always true), (CRLF shebang)
Hard because:
- Three defects from three different layers: filesystem/CWD, YAML assertion config, shell encoding
- CWD error is the visible one; the other two are latent if CWD is fixed
- Model must enumerate all three even though only CWD produces current evidence
Expected root cause:
- CWD is `C:\ci`; runner resolves config relative to CWD → not found; fix: `cd C:\ci\MyRunner`
- `ExpectedPercentage: 0` is a no-op guard (always true) (s13#13); fix: set to ≥95
- `verify.sh` has CRLF line endings; shebang `\r` causes "interpreter not found" in container; fix: dos2unix
Verify (mechanical): answer names all three defects with correct fixes; explains CWD resolution, zero-percent no-op, and CRLF shebang.
Rubric (graded):
- 3: all three named with correct fixes, explains each mechanism
- 2: two defects named correctly
- 1: only CWD or only one fix
Solution sketch: `cd C:\ci\MyRunner`; change `ExpectedPercentage: 0` → `95`; convert `verify.sh` to LF endings.

---

### X-147: Green Run Proven Wrong — HttpStatus Vacuous + Wrong StatusCode Key + Typo'd Output
Tier: T5
Goal: Prove a green run has three stacked defects: wrong HttpStatus config key (`ExpectedStatus` vs `StatusCode`), wrong OutputName, and vacuous pass from 0 outputs.
Evidence:
```yaml
- Assertion: HttpStatus
  AssertionConfiguration:
    ExpectedStatus: 200     # wrong key: should be StatusCode
    OutputNames: [ResOut]
- Assertion: HermeticByExpectedOutputCount
  AssertionConfiguration:
    ExpectedCount: 2
    OutputNames: [ResOutX]  # typo: real output is ResOut
```
```
[INFO] Output 'ResOut' Contains 0 Outputs
[INFO] Output 'ResOutX' Contains 0 Outputs
[PASS] HttpStatus: All configured outputs arrived (0 outputs checked)
[PASS] HermeticByExpectedOutputCount: 0/2 — vacuous
exit code: 0
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §7, §9, §13
Trap mines: s13#4 (HttpStatus uses StatusCode not ExpectedStatus), s13#12 (silently ignored key), s13#13 (vacuous pass)
Hard because:
- `ExpectedStatus` is silently ignored (s13#12 + s13#4); HttpStatus accepts any status code (vacuous)
- `ResOutX` wrong OutputName → hermetic guard vacuously passes on 0 outputs
- Even if traffic flows, HttpStatus won't check status code; even if routing fixed, guard guards wrong output
Expected root cause:
- `ExpectedStatus:` silently ignored (s13#4); correct key is `StatusCode:` (s13#12)
- `OutputNames: [ResOutX]` references non-existent output → hermetic guard vacuous (s13#13)
- `ResOut` also gets 0 outputs (likely a routing/stub issue that must be fixed separately)
- Fix: `ExpectedStatus` → `StatusCode`; `ResOutX` → `ResOut`; investigate 0-output root cause
Verify (mechanical): answer corrects both config keys, explains both vacuous-pass paths, flags need to investigate 0 outputs.
Rubric (graded):
- 3: both key corrections, explains both vacuous paths, flags 0-output investigation
- 2: both key corrections but no vacuous-pass explanation
- 1: one correction or accepts run as passing
Solution sketch: Change `ExpectedStatus:` → `StatusCode:`; change `OutputNames: [ResOutX]` → `[ResOut]`; then diagnose why ResOut gets 0 outputs.

---

### X-148: Compose Redis Internal Mapping + Controller ServerName Blank + Vacuous HttpStatus
Tier: T5
Goal: Identify Redis port collision causing compose abort, blank Controller ServerName causing command timeout if compose fixed, and vacuous HttpStatus as latent third defect.
Evidence:
```yaml
# docker-compose.yml
redis: { ports: ["6379:6379"] }
mocker: { depends_on: [redis] }
# mocker YAML: Controller: ServerName: ""
# runner assertions: HttpStatus only, no count guard
```
```
Error: Bind for 0.0.0.0:6379 failed: port is already allocated
exit code: 1 (compose)
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §3, §7, §13
Trap mines: s13#19 (Redis port publish), s13 (blank ServerName), s13#13 (vacuous HttpStatus)
Hard because:
- Only compose error is visible; other two defects are purely static analysis from the provided configs
- Blank ServerName produces the same timeout symptom as missing Redis (both look like controller issues)
- HttpStatus vacuous pass is a latent false-green waiting to happen after all fixes
Expected root cause:
- Redis port collision → compose abort (s13#19); fix: remove redis `ports:`
- `Controller: ServerName: ""` → mocker commands never delivered; fix: set a non-empty literal matching runner
- HttpStatus without count guard → will vacuously pass if traffic doesn't flow after fixes (s13#13)
Verify (mechanical): answer names all three; removes redis ports; prescribes non-empty ServerName; adds count guard.
Rubric (graded):
- 3: all three with correct fixes; blank ServerName identified from static analysis
- 2: compose + one other fix
- 1: compose fix only
Solution sketch: Remove redis `ports:`; set `Controller: ServerName: mocker-ctrl` in mocker YAML; add `HermeticByExpectedOutputCount` guard.

---

### X-149: NU1102 + Stale Storages + Missing Topology — Full Green-Field Failure Stack
Tier: T5
Goal: Diagnose a greenfield project with NU1102 on restore, outdated Storages shape, and missing RabbitMQ topology — three defects none of which is visible until the previous is fixed.
Evidence:
```
error NU1102: Unable to find package QaaS.Common.Generators with version (>= 4.5.1)
exit code: 1 (restore)
```
```yaml
# runner.qaas.yaml (once restore fixed)
Storages:
  - Name: store1
    StorageConfiguration: { Type: Local, Path: ./data }
Transactions:
  - Name: PubTx
    Action: Publisher
    DataSourceNames: [data.csv]
    RabbitMq: { Exchange: events, Queue: events-q }
```
```
# If Storages fixed, would produce:
NOT_FOUND - no exchange 'events' in vhost '/'
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §1, §2, §7, §11, §13
Trap mines: s13#9 (Common.Generators 3.5.1), s13#2 (Storages shape), s13#17 (topology not auto-created)
Hard because:
- Sequential reveals: NU1102 → Storages FTL → exchange not found; each fix reveals the next
- Model must identify all three from static code analysis without running the build chain
- Version trap (4.5.1 on Common.Generators) is the first defect; correct is 3.5.1
Expected root cause:
- `QaaS.Common.Generators` at `4.5.1` → NU1102; correct is `3.5.1` (s13#9)
- Storages uses outdated `StorageConfiguration: {Type:Local,...}` shape → FTL after restore (s13#2)
- Publisher will fail with no exchange → add `CreateRabbitMqExchanges` probe at Stage 0 (s13#17)
Verify (mechanical): answer names all three in fix order; provides version 3.5.1, correct Storages shape, Stage-0 probe.
Rubric (graded):
- 3: all three in order with correct fixes; explains sequential reveal
- 2: two defects in order
- 1: only NU1102
Solution sketch: Fix version to `3.5.1`; replace Storages with `- FileSystem: {Path: ./data}`; add `CreateRabbitMqExchanges` probe at Stage 0.

---

### X-150: Ultimate Green-Run Forensics — Five Stacked Silent Failures, Exit 0
Tier: T5
Goal: Prove a completely green run (exit 0, all PASS) is wrong by identifying five independent silent defects that together suppress all real test signal.
Evidence:
```yaml
# runner Route: /DataFetch  (mocker Path: /datafetch, case mismatch + leading slash)
# mocker stub: TransactionData: {Body: ok}   (deprecated key, silently ignored)
assertions:
  - Assertion: HttpStatus
    AssertionConfiguration:
      ExpectedStatus: 200     # wrong key (should be StatusCode), silently ignored
      OutputNames: [DataOut]
  - Assertion: HermeticByExpectedOutputCount
    AssertionConfiguration:
      ExpectedOutputCount: 3  # wrong key (should be ExpectedCount), silently ignored
      OutputNames: [DataOut]
  - Assertion: ContainsBody
    AssertionConfiguration:
      ExpectedBody: ok
      OutputNames: [DataOutX]  # typo: real output is DataOut — vacuous pass on null
```
```
[WARN] GET //DataFetch returned 404
[INFO] Output 'DataOut' Contains 0 Outputs
[INFO] Output 'DataOutX' Contains 0 Outputs
[PASS] HttpStatus: 0 outputs checked
[PASS] HermeticByExpectedOutputCount: 0 outputs checked
[PASS] ContainsBody: no items to check (vacuous)
exit code: 0
```
MOCK_REQUIRED: n/a (diagnosis)
FB slices: §3, §7, §9, §13
Trap mines: s13#5 (leading slash), s13#5b (case), s13#1 (TransactionData), s13#4 (ExpectedStatus→StatusCode), s13#12 (silently ignored keys), s13#13 (vacuous pass)
Hard because:
- Five independent defects: leading slash, case mismatch, deprecated stub key, two silently-ignored assertion keys, plus wrong OutputName on ContainsBody
- Every assertion vacuously passes; exit 0; no error signal anywhere in the log
- Model must enumerate all defects and explain why each one alone is insufficient to produce a real test
Expected root cause:
- `Route: /DataFetch` → leading slash (s13#5) AND case mismatch vs `datafetch` (s13#5b) → 404
- `TransactionData:` → silently ignored (s13#1); stub has no body even if routed correctly
- `ExpectedStatus:` → silently ignored (s13#4); HttpStatus applies no status constraint
- `ExpectedOutputCount:` → silently ignored (s13#12); hermetic guard applies no count constraint
- `OutputNames: [DataOutX]` → non-existent output; ContainsBody vacuously passes on null
- Fix all five: `Route: datafetch`; `ProcessorConfiguration:`; `StatusCode:`; `ExpectedCount:`; `OutputNames: [DataOut]`
Verify (mechanical): answer names all five defects with exact fixes; explains why exit 0 with all PASS is definitively wrong.
Rubric (graded):
- 3: all five defects named with exact fixes; explains vacuous-pass-on-every-assertion chain
- 2: four or three defects (partial credit proportional)
- 1: fewer than three or accepts run as green
Solution sketch: Fix Route to `datafetch`; swap `TransactionData:` → `ProcessorConfiguration:`; fix `ExpectedStatus:` → `StatusCode:`; fix `ExpectedOutputCount:` → `ExpectedCount:`; fix `DataOutX` → `DataOut`.

---
