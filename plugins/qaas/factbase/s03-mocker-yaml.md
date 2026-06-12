## 3. TASK: Author Mocker YAML (docs/mocker/**, r07, [LAB] L5)

Blocks: `Servers` (plural; `Server` singular is mutually exclusive — use plural for multi-server),
`Stubs`, `DataSources`, optional `Controller`. (r07)

### Servers / Endpoints / Actions
- Http server: `Port`(req, unique across all servers — dup = fail-fast), CertificatePath/Password,
  `IsLocalhost`(false → binds 0.0.0.0; true → 127.0.0.1 only, container-scoped in Docker).
- Endpoints[]: `Path`, `Actions[]`: `Name`, `Method`(Get/Post/Put/Delete/Head/Options/Patch/Trace/
  Connect), `TransactionStubName` → links to a Stub.
- Grpc: Port, Services, RpcNames. Socket: ProtocolType/AddressFamily/SocketType + Collect/Broadcast.
- Server types are protocol-exclusive (not mixed in one server).

### Stubs (processor binding)
- `Name`, `Processor`(hook simple name), optional **`ProcessorConfiguration`** (NOT `TransactionData`
  — see §13), optional `DataSourceNames[]`. **9 processors catalog → §12.** Built-ins ship in
  **`QaaS.Common.Processors`** (must be referenced in the mocker csproj). [LAB L3, r07]
- Runtime builds extra default stubs: not-found + internal-error (`Built 4 transaction stub(s)
  including default not-found and internal-error stubs`). [LAB L5]

### Controller (optional Redis control plane)
- `Controller.ServerName` must equal Runner `MockerCommands[].ServerName` byte-for-byte. When omitted:
  `Controller startup skipped because 'Controller.ServerName' is not configured`; servers still run. [LAB]

### Mocker CLI (r07)
- `run <config>` (stays attached in console; serves until Ctrl+C; `--run-locally` keeps console),
  `template <config>` (resolved config = schema oracle). Flags: `-w/--overwrite-files`,
  `-l/--logger-level`, `-o/--output-folder`, `--no-env`.
- Startup log: `HTTP Server started. Listening on http://0.0.0.0:8080`. [LAB]

### COMPLETE copy-ready example (LAB-verified, returns 200) — copy this shape exactly
```yaml
Servers:
  - Http:
      Port: 8090                          # unique per mocker; match the runner's target + PORT CONTRACT
      Endpoints:
        - Path: /hello                     # endpoint Path KEEPS its leading slash (NOT a stub field); ALL-LOWERCASE (§13#5b)
          Actions:
            - Name: HelloOk
              Method: Get
              TransactionStubName: HelloStub   # links this route to the stub below
Stubs:
  - Name: HelloStub
    Processor: StaticResponseProcessor     # the processor TYPE (a string) — the REQUIRED field
    ProcessorConfiguration:                 # the config block (NOT TransactionData — §13#1)
      Body: hello
      StatusCode: 200
      ContentType: text/plain; charset=utf-8
```
TRAPS the validator enforces (FTL → exit non-zero): a stub MUST have `Processor:` (`The Processor
field is required`); routing is ONLY via `Servers…Endpoints…Actions…TransactionStubName` — a
stub-level `Route:` is rejected (`Property Route … not found in TransactionStubConfig`); do NOT nest
`ProcessorType`/`Configuration` inside `ProcessorConfiguration` (put `Processor:` at stub level and
the response fields directly under `ProcessorConfiguration`); server and endpoint entries have **NO
`Name:` property** (ServerConfig/HttpEndpointConfig reject it — a server entry begins directly with
`Http:`, an endpoint with `Path:`/`Actions:`; only Actions and Stubs are named — s13#21).
Runner-side control plane: the full `MockerCommands[]` schema (required `Command`, `Redis`,
`ServerName`, plus ChangeActionStub/TriggerAction/Consume command shapes) lives in **s02
§MockerCommands** — read it before authoring any controller-driven session.

---

