## 14. GOLDEN EXAMPLES (verbatim, LAB-green)

### 14.1 hello.qaas.yaml (Runner; HTTP smoke) — LAB-corrected, GREEN [LAB L3]
```yaml
MetaData:
  Team: Smoke
  System: HelloWorld

Storages:
  - FileSystem:
      Path: ./session-data

DataSources:
  - Name: HelloData
    Generator: FromFileSystem
    GeneratorConfiguration:
      DataArrangeOrder: AsciiAsc
      FileSystem: { Path: TestData }

Sessions:
  - Name: HelloSession
    Transactions:
      - Name: CallHello
        TimeoutMs: 5000
        DataSourceNames: [HelloData]      # REQUIRED for transactions
        Http:
          BaseAddress: http://127.0.0.1
          Port: 8080
          Route: hello                    # NO leading slash
          Method: Get

Assertions:
  - Name: ReturnedOk
    Assertion: HttpStatus
    SessionNames: [HelloSession]
    AssertionConfiguration:
      StatusCode: 200                     # NOT ExpectedStatus
      OutputNames: [CallHello]            # list; matches transaction Name
```
Run: `dotnet run --project Runner -- run hello.qaas.yaml` → exit 0; `act` then `assert` works with
mocker stopped (offline re-assert). Requires `QaaS.Common.Generators` + `QaaS.Common.Assertions`.

> NOTE: docs quickstart `helloWorldHttp.md` shows the pre-drift form (Storages Name/Type,
> ExpectedStatus/OutputName, `Route:/hello`, mocker `TransactionData`). That form is **broken** — use
> the above.

### 14.2 hello.mocker.yaml (Mocker) — LAB-corrected, GREEN [LAB L3, r07]
```yaml
Servers:
  - Http:
      Port: 8080
      Endpoints:
        - Path: /hello
          Actions:
            - Name: HelloOk
              Method: Get
              TransactionStubName: HelloStub

Stubs:
  - Name: HelloStub
    Processor: StaticResponseProcessor
    ProcessorConfiguration:               # NOT TransactionData
      Body: hello
      StatusCode: 200
      ContentType: text/plain; charset=utf-8
```
Start: `dotnet run --project Mocker -- run hello.mocker.yaml`. Requires `QaaS.Common.Processors`.

### 14.3 RabbitMQ DummyApp test.qaas.yaml (docs sample, LAB-green w/ real broker+relay) [LAB L1]
```yaml
MetaData:
  Team: Smoke
  System: DummyApp

DataSources:
  - Name: FromFileSystemTestData
    Generator: FromFileSystem
    GeneratorConfiguration:
      DataArrangeOrder: AsciiAsc
      FileSystem: { Path: TestData }

Sessions:
  - Name: RabbitMqExchangeWithFromFileSystemTestData
    Publishers:
      - Name: Publisher
        DataSourceNames: [FromFileSystemTestData]
        Policies:
          - LoadBalance: { Rate: 50 }
        RabbitMq:
          Host: 127.0.0.1
          Username: admin
          Password: admin
          Port: 5672
          ExchangeName: dummy-app-tests-input
          RoutingKey: /
    Consumers:
      - Name: Consumer
        TimeoutMs: 5000
        RabbitMq:
          Host: 127.0.0.1
          Username: admin
          Password: admin
          Port: 5672
          ExchangeName: dummy-app-tests-output
          RoutingKey: /
        Deserialize: { Deserializer: Json }

Assertions:
  - Name: HermeticByInputOutputPercentage
    Assertion: HermeticByInputOutputPercentage
    SessionNames: [RabbitMqExchangeWithFromFileSystemTestData]
    AssertionConfiguration:
      OutputNames: [Consumer]
      InputNames: [Publisher]
      ExpectedPercentage: 100
  - Name: DelayByChunks
    Assertion: DelayByChunks
    SessionNames: [RabbitMqExchangeWithFromFileSystemTestData]
    AssertionConfiguration:
      Output: { Name: Consumer, ChunkSize: 1 }
      Input:  { Name: Publisher, ChunkSize: 1 }
      MaximumDelayMs: 10000
```
- TestData/input.json: `[{"id":1,"message":"hello from DummyAppTests"}]`.
- DummyApp RabbitMQ pattern [LAB]: publish to `dummy-app-tests-input`; a relay (work\lab\relay.ps1)
  taps the input exchange via the management API and republishes to `dummy-app-tests-output`; consumer
  reads output. GREEN: `Aggregated exit code: 0`, `Runner completed. ExitCode=0`. Stop the relay →
  exit 1, DelayByChunks "No output items...", Hermetic% 0.

### 14.4 HookLab — 3 custom hooks (GREEN, exit 0) [LAB L4, 08]
YAML wiring:
```yaml
DataSources:
  - Name: 10Samples
    Generator: JsonArrayGenerator
    GeneratorConfiguration: { Count: 10, NumberOfItemsPerArray: 5 }
Sessions:
  - Name: S
    Probes:
      - Probe: PrintCurrentTimeProbe
        Name: GetCurrentTime
Assertions:
  - Name: LengthAssertion
    Assertion: LengthAssertion
    SessionNames: [S]
    AssertionConfiguration: { OutputName: Consumer, ExpectedLength: 5 }
```
Hook classes (signatures verified to compile+run):
```csharp
public sealed class JsonArrayGenerator : BaseGenerator<JsonArrayConfig>   // record JsonArrayConfig { [Required] public uint? Count {get;set;} ... }
{
    public override IEnumerable<Data<object>> Generate(
        IImmutableList<SessionData> sessionDataList, IImmutableList<DataSource> dataSourceList)
    { /* yield return new Data<object>{ Body = ... }; */ }
}

public sealed class LengthAssertion : BaseAssertion<LengthConfig>
{
    public override bool Assert(
        IImmutableList<SessionData> sessionDataList, IImmutableList<DataSource> dataSourceList)
    {
        var arr = sessionDataList.AsSingle().GetOutputByName(Configuration.OutputName)
                                 .CastCommunicationData<JsonArray>();
        AssertionMessage = "...";    // set before return; throw → broken; false → failed
        return /* arr length == Configuration.ExpectedLength */;
    }
}

public sealed class PrintCurrentTimeProbe : BaseProbe<object>   // no-config: use object
{
    public override void Run(
        IImmutableList<SessionData> sessionDataList, IImmutableList<DataSource> dataSourceList)
    { /* synchronous; do NOT Task.Run */ }
}
```

### 14.5 Custom Mocker Processor (scaffold shape, verified) [LAB L4/L5, 08]
A custom processor is a **mocker** hook: the project references `QaaS.Mocker` (not QaaS.Runner).
Copy this `using` header verbatim — `BaseTransactionProcessor` is in `...Hooks.Processor`, and
`MetaData`/`Http` (the response status/headers) are in `...Session.MetaDataObjects`.
```csharp
using System.Collections.Immutable;
using QaaS.Framework.SDK.DataSourceObjects;        // DataSource, GetDataSourceByName
using QaaS.Framework.SDK.Hooks.Processor;          // BaseTransactionProcessor<T>
using QaaS.Framework.SDK.Session.DataObjects;      // Data<T>
using QaaS.Framework.SDK.Session.MetaDataObjects;  // MetaData, Http

public class HealthProcessor : BaseTransactionProcessor<object>   // no-config processor: use `object` (NoConfiguration is NOT an SDK type → CS0246). Configurable? use a `public record XxxConfig`.
{
    public override Data<object> Process(
        IImmutableList<DataSource> dataSourceList, Data<object> requestData) =>
        new()
        {
            Body = "OK"u8.ToArray(),
            MetaData = new MetaData { Http = new Http { StatusCode = 200 } }
        };
}
// Wire: Stubs: - Name: HealthStub / Processor: HealthProcessor / ProcessorConfiguration: {}
```
**Body contract (LAB H132, s13#25)**: `requestData.Body` arrives as raw `byte[]` — read JSON with
`string reqJson = Encoding.UTF8.GetString((byte[])requestData.Body);` (NEVER `JsonSerializer.Serialize`
the byte[] — silent base64). The returned `Body` MUST be `byte[]`: use
`JsonSerializer.SerializeToUtf8Bytes(new { ... })` for JSON responses.

### 14.6 Dockerfile for a custom mocker image (aspnet fix) [LAB L5]
```dockerfile
# build
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY . .
RUN dotnet restore --configfile NuGet.config
RUN dotnet publish -c Release -o /app

# runtime — MUST be aspnet (mocker hosts an HTTP server); dotnet/runtime:10.0 FAILS at start
FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /app .
ENTRYPOINT ["dotnet", "HelloMocker.dll", "mocker.qaas.yaml"]
```
Build/run: `docker build -t hellomocker:lab .` ; `docker run -d -p 8080:8080 hellomocker:lab`.
Startup logs: `Building transaction stub 'HealthStub' with processor 'HealthProcessor'`,
`Built 4 transaction stub(s) including default not-found and internal-error stubs`,
`Resolved runtime graph with 0 data source(s), 4 stub(s), 1 server(s) [Http], and controller enabled:
False`. `curl /health` → 200 (custom), `curl /hello` → 200 "hello". HelloRunner `run` against the
container → exit 0.
- Build args for feed (docs deployMock.md): `QAAS_NUGET_SOURCE_NAME`, `QAAS_NUGET_SOURCE_URL`; some
  scaffolds use `ENTRYPOINT ["sh","-c","exec dotnet DummyAppMock.dll \"$QAAS_MOCKER_CONFIG\""]`.

### 14.7 Controller staged stub-swap (Runner MockerCommands + Mocker Controller via Redis) — GREEN [LAB L6]
Redis: `docker run -d -p 6379:6379 redis:7-alpine`. Mocker adds:
```yaml
Controller:
  ServerName: HelloMocker        # must byte-match Runner MockerCommands[].ServerName
  Redis: {Host: 127.0.0.1:6379}  # single "host:port" string
# + second stub HelloFail (StaticResponseProcessor, StatusCode 503)
```
Runner (controller.qaas.yaml) — staged: Transaction CallHelloOk `Stage: 1`, MockerCommand `Stage: 2`,
Transaction CallHelloAfterSwap `Stage: 3`:
```yaml
    MockerCommands:
      - Name: SwapToFailure
        ServerName: HelloMocker
        Stage: 2
        Redis: {Host: 127.0.0.1:6379}
        Command:
          ChangeActionStub: {ActionName: HelloOk, StubName: HelloFail}
Assertions:  # FirstCallOk expects 200 on CallHelloOk; SecondCallFailed expects 503 on CallHelloAfterSwap
```
Verified: first call 200 → swap (`Applying ChangeActionStub command for action 'HelloOk' -> stub 'HelloFail'`,
status 'Succeeded') → second call 503 → exit 0. Protocol: runner pings `runner-to-mocker:ping:<servername-lower>`,
gets instance id, commands on `runner-to-mocker:command:<servername-lower>:<instanceid>`.

### 14.8 Variables + anchors + overwrite + cases — GREEN [LAB L7]
```yaml
variables:           # lowercase section
  mocker: {host: "http://127.0.0.1", port: 9999}
anchors:
  helloHttpAnchor: &helloHttpAnchor
    BaseAddress: ${variables:mocker:host}
    Port: ${variables:mocker:port}
    Method: Get
# ... Http: {<<: *helloHttpAnchor, Route: hello}
```
- `Variables\local.yaml` = `variables:\n  mocker:\n    port: 8080` → run `-w Variables/local.yaml` overrides port.
- `Cases\helloRoute.yaml` = `Sessions:0:Transactions:0:Http:Route: hello` (path notation); run `-c Cases`
  → one execution per case file, allure suite label = `Cases\helloRoute.yaml`.
- ⚠️ Always include the hermetic guard (see drift #13):
```yaml
  - Name: ExactlyOneOutput
    Assertion: HermeticByExpectedOutputCount
    SessionNames: [HelloSession]
    AssertionConfiguration: {OutputNames: [CallHello], ExpectedCount: 1}   # field is ExpectedCount!
```

---

### 14.9 Live e2e gate — mocker + runner in ONE command, PORT CONTRACT [LAB L6]
The runner→mocker live run must start the mocker in the background, wait for its port, run the runner,
capture the exit code, and stop the mocker — **all in ONE command** (two `verify[]` steps don't share the
background process, FB s13#15). **PORT CONTRACT (FB s13#16):** the probe port, the mocker
`Servers.Http.Port`, and the runner `Http.Port` are the **same single literal** (8080 below). A probe on a
port the mocker never binds loops 40× then `exit 9 'MOCKER NEVER READY'` and the runner never runs.
```powershell
# CWD = Runner project; mocker at ..\Mocker; 8080 == mocker Servers.Http.Port == runner Http.Port
$m = Start-Process dotnet -ArgumentList 'run','-c','Release','--','run','hello.mocker.yaml' -WorkingDirectory '..\Mocker' -PassThru
$ok=$false; foreach($i in 1..40){ try{ (New-Object Net.Sockets.TcpClient('127.0.0.1',8080)).Close(); $ok=$true; break }catch{ Start-Sleep 2 } }
if(-not $ok){ Stop-Process -Id $m.Id -Force -ErrorAction SilentlyContinue; Write-Output 'MOCKER NEVER READY'; exit 9 }
dotnet run -c Release -- run hello.qaas.yaml; $code=$LASTEXITCODE
Stop-Process -Id $m.Id -Force -ErrorAction SilentlyContinue; exit $code
```
Success → runner prints `ExitCode=0`; whole cmd exits 0. Do NOT write the port as a `#` comment inside a
single-line verify `cmd` (trips FB s13#14) — state the contract in the task `description`/`rubric`.
