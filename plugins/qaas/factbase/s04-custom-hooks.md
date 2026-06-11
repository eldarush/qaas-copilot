## 4. TASK: Custom hooks (4 base classes) (08, 05, [LAB] L4)

Discovery = **assembly scanning** (entry asm, loaded AppDomain asms, base-dir DLLs). Success log:
`Found IGenerator hook instance JsonArrayGenerator in provided assembly HookLab, Version=...`
(same for IProbe/IAssertion/ITransactionProcessor). YAML references by **simple class name**.
**Missing hook → `FTL ... I<X> hook instance <Name> not found in any of the provided assemblies`
then DI crash, process exit `-532462766`.** [LAB L2/L4]

### Exact signatures (all generic over a TConfiguration)
```csharp
// QaaS.Framework.SDK.Hooks.Generator
public override IEnumerable<Data<object>> Generate(
    IImmutableList<SessionData> sessionDataList, IImmutableList<DataSource> dataSourceList)   // yield return; stream

// QaaS.Framework.SDK.Hooks.Assertion
public override bool Assert(
    IImmutableList<SessionData> sessionDataList, IImmutableList<DataSource> dataSourceList)   // false→failed; throw→broken

// QaaS.Framework.SDK.Hooks.Probe
public override void Run(
    IImmutableList<SessionData> sessionDataList, IImmutableList<DataSource> dataSourceList)   // SYNCHRONOUS; do NOT Task.Run

// QaaS.Framework.SDK.Hooks.Processor  (BaseTransactionProcessor; MOCKER hook — project must reference QaaS.Mocker)
public override Data<object> Process(
    IImmutableList<DataSource> dataSourceList, Data<object> requestData)
```

### Config record rules [LAB L4, 08]
- TConfiguration **must be a C# `record`** using `System.ComponentModel.DataAnnotations`
  (`[Required]`, `[Range]`, `[Description]`). Mandatory fields = nullable + `[Required]`
  (e.g. `[Required] public uint? Count { get; set; }`). Defaults via property initializers.
- Use `object` as TConfiguration when no config is needed (`NoConfiguration` is NOT an SDK type → compile error CS0246).
- **`Configuration` is NULL in the constructor** (bound after LoadAndValidateConfiguration). Never
  touch it in ctor.
- Processor instances are **shared across requests** → no mutable per-request instance fields; reuse
  a `static HttpClient`.

### Assertion API extras
- Set `AssertionMessage` (one-liner) + `AssertionTrace` (detail) before returning; optional
  `AssertionStatus` override (Passed/Failed/Broken).
- `AssertionAttachments.Add(new AssertionAttachment { Path="x/y.json", Data=obj,
  SerializationType = SerializationType.Json })` (`QaaS.Framework.Serialization`). Relative path with
  filename; runner rejects duplicate paths in one result.
- Helpers (`QaaS.Framework.SDK.Extensions`): `sessionDataList.AsSingle()`, `.GetOutputByName(name)`,
  `.CastCommunicationData<JsonArray>()` → typed `.Data[].Body`. [LAB]

### Namespaces (all transitive via QaaS.Runner) [LAB]
```
QaaS.Framework.SDK.DataSourceObjects            // DataSource
QaaS.Framework.SDK.Hooks.Generator              // BaseGenerator
QaaS.Framework.SDK.Hooks.Assertion              // BaseAssertion, AssertionAttachment
QaaS.Framework.SDK.Hooks.Probe                  // BaseProbe
QaaS.Framework.SDK.Hooks.Processor              // BaseTransactionProcessor (MOCKER hook; project must ref QaaS.Mocker)
QaaS.Framework.SDK.Session.DataObjects          // Data<T>
QaaS.Framework.SDK.Session.SessionDataObjects   // SessionData
QaaS.Framework.SDK.Session.MetaDataObjects      // MetaData, Http (processor response StatusCode/headers)
QaaS.Framework.SDK.Extensions                   // AsSingle/GetOutputByName/CastCommunicationData/GetDataSourceByName
QaaS.Framework.Serialization                    // SerializationType
```
- Custom hooks live **in the test/mocker project itself** (no separate package); reference the
  assembly and use the simple name. (08, [LAB])
- **Runner hooks** (Generator/Assertion/Probe) compile with just the `QaaS.Runner` reference (SDK is
  transitive). A **custom mocker processor** (`BaseTransactionProcessor<T>`) lives in a **mocker**
  project and needs the `QaaS.Mocker` reference — it will NOT resolve in a runner-only project. [LAB]

---

