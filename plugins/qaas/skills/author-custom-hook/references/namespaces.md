# Namespaces (FB s04, LAB L4)

All arrive transitively via `QaaS.Runner` (runner project) or `QaaS.Mocker` (mocker project).

| Namespace | Contents |
|---|---|
| `QaaS.Framework.SDK.DataSourceObjects` | `DataSource` |
| `QaaS.Framework.SDK.Hooks.Generator` | `BaseGenerator<T>` |
| `QaaS.Framework.SDK.Hooks.Assertion` | `BaseAssertion<T>`, `AssertionAttachment` |
| `QaaS.Framework.SDK.Hooks.Probe` | `BaseProbe<T>` |
| `QaaS.Framework.SDK.Hooks.TransactionProcessor` | `BaseTransactionProcessor<T>` |
| `QaaS.Framework.SDK.Session.DataObjects` | `Data<T>` |
| `QaaS.Framework.SDK.Session.SessionDataObjects` | `SessionData` |
| `QaaS.Framework.SDK.Extensions` | `AsSingle()`, `GetOutputByName()`, `CastCommunicationData<T>()` |
| `QaaS.Framework.Serialization` | `SerializationType` |
| `System.ComponentModel.DataAnnotations` | `[Required]`, `[Range]`, `[Description]` |

Custom hooks live **in the test/mocker project itself** — no separate package (FB s04, LAB L4).

## AssertionAttachment example
```csharp
AssertionAttachments.Add(new AssertionAttachment
{
    Path = "details/output.json",        // relative path with filename; no duplicate paths in one result
    Data = someObject,
    SerializationType = SerializationType.Json   // QaaS.Framework.Serialization
});
```

## Helper chain example
```csharp
// sessionDataList.AsSingle() → single SessionData
// .GetOutputByName("CallHello") → named output
// .CastCommunicationData<JsonArray>() → typed body
var body = sessionDataList.AsSingle()
               .GetOutputByName(Configuration!.OutputName)
               .CastCommunicationData<JsonArray>();
```
