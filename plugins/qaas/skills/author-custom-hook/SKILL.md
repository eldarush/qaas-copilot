---
name: author-custom-hook
version: 1.0.0
description: Write a QaaS custom hook (Generator, Assertion, Probe, or TransactionProcessor) with correct base-class signatures and config records.
when_to_use: When a task requires a custom C# hook that extends QaaS beyond built-in generators/assertions/processors.
inputs:
  - name: hook_kind
    example: "Generator | Assertion | Probe | TransactionProcessor"
  - name: class_name
    example: "JsonArrayGenerator"
  - name: config_fields
    example: "Count: uint (required), NumberOfItemsPerArray: uint (required)"
outputs:
  - path: "<Project>/<ClassName>.cs"
fact_base_slices: [s04, s13, s14]
references:
  - references/namespaces.md
contract:
  done_rubric:
    - "dotnet build => exit 0"
    - "dotnet run -- run <cfg>.qaas.yaml log contains 'Found I<Kind> hook instance <ClassName>'"
  failure_modes:
    - "Hook not found → FTL + exit -532462766 (FB s04, s13#8)"
    - "Configuration accessed in constructor → NullReferenceException (FB s04)"
    - "Probe uses Task.Run → async deadlock (FB s04)"
    - "Processor has mutable instance state → race conditions (FB s04)"
    - "Config record not a C# record → config not bound (FB s04)"
    - "Missing [Required] on nullable mandatory field → silent empty config (FB s04)"
  escalation: "NEEDS_CLARIFICATION: <field> | BLOCKED: <reason>"
---

## When to use

Use when a test or mocker needs logic not available in built-in hooks: custom data shapes (Generator),
custom validation (Assertion), side-effect probes (Probe), or custom HTTP response logic (TransactionProcessor).

## Steps

### 1. Choose base class and package

| Kind | Base class | Namespace | Package (csproj) |
|---|---|---|---|
| Generator | `BaseGenerator<T>` | `QaaS.Framework.SDK.Hooks.Generator` | Transitive via `QaaS.Runner` |
| Assertion | `BaseAssertion<T>` | `QaaS.Framework.SDK.Hooks.Assertion` | Transitive via `QaaS.Runner` |
| Probe | `BaseProbe<T>` | `QaaS.Framework.SDK.Hooks.Probe` | Transitive via `QaaS.Runner` |
| TransactionProcessor | `BaseTransactionProcessor<T>` | `QaaS.Framework.SDK.Hooks.Processor` | `QaaS.Mocker` (**mocker** project) |

All SDK namespaces arrive transitively — no extra PackageReference for runner hooks (FB s04, LAB L4).
A **TransactionProcessor is a mocker hook**: put it in the mocker project (references `QaaS.Mocker`),
**not** the runner project — `BaseTransactionProcessor<T>` will not resolve without `QaaS.Mocker`.

### 2. Write the config record
```csharp
public record JsonArrayConfig
{
    [Required] public uint? Count { get; set; }           // nullable + [Required] = mandatory (FB s04)
    [Required] public uint? NumberOfItemsPerArray { get; set; }
    public string? Label { get; set; } = "item";          // default via initializer (FB s04)
}
```
Rules (FB s04, LAB L4):
- Must be a C# `record` (not class).
- Mandatory fields: nullable type + `[Required]` (DataAnnotations).
- Defaults via property initializers.
- Use `object` as TConfiguration when no config is needed (`NoConfiguration` is NOT an SDK type → compile error CS0246).
- **`Configuration` is NULL in the constructor** — bound after `LoadAndValidateConfiguration`. Never touch it in ctor.

### 3. Required `using` header — copy verbatim (FB s04)

Put this **complete** header at the top of every runner hook file. `Data<T>` and `SessionData`
live in **two different namespaces** — you need **both**. Omitting `SessionDataObjects` is the #1
low-reasoning-model compile failure: `CS0246 'SessionData' not found` → cascading `CS0534 does not implement
inherited abstract member 'Assert(...)'` (the override signature can't resolve).
```csharp
using System;
using System.Collections.Immutable;
using System.ComponentModel.DataAnnotations;   // [Required]
using System.Text.Json;                         // JsonElement / JsonDocument (JSON assertions)
using QaaS.Framework.SDK.Hooks.Assertion;       // BaseAssertion<T>  (or .Generator / .Probe — processor uses .Processor, see §4)
using QaaS.Framework.SDK.Session.DataObjects;        // Data<T>
using QaaS.Framework.SDK.Session.SessionDataObjects; // SessionData   ← SEPARATE namespace, REQUIRED
using QaaS.Framework.SDK.DataSourceObjects;     // DataSource
using QaaS.Framework.SDK.Extensions;            // AsSingle(), GetOutputByName(), CastCommunicationData<T>()
```

### 4. Exact method signatures (FB s04)

**Generator** — `yield return` to stream items:
```csharp
public sealed class JsonArrayGenerator : BaseGenerator<JsonArrayConfig>
{
    public override IEnumerable<Data<object>> Generate(
        IImmutableList<SessionData> sessionDataList,
        IImmutableList<DataSource> dataSourceList)
    {
        for (int i = 0; i < Configuration!.Count; i++)
            yield return new Data<object> { Body = /* ... */ };
    }
}
```

**Assertion** — return false → failed; throw → broken:
```csharp
public sealed class LengthAssertion : BaseAssertion<LengthConfig>
{
    public override bool Assert(
        IImmutableList<SessionData> sessionDataList,
        IImmutableList<DataSource> dataSourceList)
    {
        var items = sessionDataList.AsSingle()
                        .GetOutputByName(Configuration!.OutputName)
                        .CastCommunicationData<JsonArray>();
        AssertionMessage = $"Length={items.Data.Count}, expected {Configuration.ExpectedLength}";
        AssertionTrace = "detail for allure";
        // AssertionAttachments.Add(new AssertionAttachment { Path="out.json", Data=items, SerializationType=SerializationType.Json });
        return items.Data.Count == Configuration.ExpectedLength;
    }
}
```

**Reading a JSON field from an HTTP response body** (very common). The body is **typed** by
`CastCommunicationData<JsonElement>()`; each `comm.Data[i].Body` is a `JsonElement` **struct**.
Use `TryGetProperty` / `ValueKind` / `GetString()`. **Never** apply `?.` to it (`CS0023`) and
**never** pattern-match it against `byte[]` or `string` (`CS8121`) — those are the classic traps.
```csharp
public sealed class JsonFieldAssertion : BaseAssertion<JsonFieldConfig>
{
    public override bool Assert(
        IImmutableList<SessionData> sessionDataList,
        IImmutableList<DataSource> dataSourceList)
    {
        var comm = sessionDataList.AsSingle()
                       .GetOutputByName(Configuration!.OutputName!)
                       .CastCommunicationData<JsonElement>();
        if (comm == null || comm.Data.Count == 0)        // hermetic guard: no outputs → fail, don't throw
        {
            AssertionMessage = "No outputs for " + Configuration.OutputName;
            return false;
        }
        JsonElement root = comm.Data[0].Body;            // struct — no ?. , no `is byte[]`/`is string`
        if (!root.TryGetProperty(Configuration!.JsonField!, out JsonElement prop))
        {
            AssertionMessage = $"Field '{Configuration.JsonField}' missing";
            return false;
        }
        string? actual = prop.ValueKind == JsonValueKind.String ? prop.GetString() : prop.ToString();
        AssertionMessage = $"{Configuration.JsonField}='{actual}' expected '{Configuration.ExpectedValue}'";
        return string.Equals(actual, Configuration.ExpectedValue, StringComparison.Ordinal);
    }
}
```

**Probe** — synchronous, no Task.Run:
```csharp
public sealed class PrintCurrentTimeProbe : BaseProbe<object>
{
    public override void Run(
        IImmutableList<SessionData> sessionDataList,
        IImmutableList<DataSource> dataSourceList)
    { /* synchronous only — do NOT call Task.Run (FB s04) */ }
}
```

**TransactionProcessor** — a **mocker** hook (mocker project, references `QaaS.Mocker`). It uses a
**different** `using` header from runner hooks (§3 does NOT apply): `BaseTransactionProcessor<T>` is in
`...Hooks.Processor`, and the response types `MetaData`/`Http` are in `...Session.MetaDataObjects`.
Copy this header verbatim:
```csharp
using System.Collections.Immutable;
using QaaS.Framework.SDK.DataSourceObjects;        // DataSource, GetDataSourceByName
using QaaS.Framework.SDK.Hooks.Processor;          // BaseTransactionProcessor<T>
using QaaS.Framework.SDK.Session.DataObjects;      // Data<T>
using QaaS.Framework.SDK.Session.MetaDataObjects;  // MetaData, Http  (response StatusCode/headers)

public class HealthProcessor : BaseTransactionProcessor<object>   // use `object` for a no-config processor; `NoConfiguration` is NOT an SDK type (compile error CS0246). For a configurable processor use a `public record XxxConfig` (see custom-authoring docs).
{
    public override Data<object> Process(
        IImmutableList<DataSource> dataSourceList, Data<object> requestData) =>
        new()
        {
            Body = "OK"u8.ToArray(),
            MetaData = new MetaData { Http = new Http { StatusCode = 200 } }
        };
}
```
Processor instances are **shared across requests** — no mutable per-request state (FB s04, LAB L5).
Read request bytes via `requestData.Body`; pull seeded responses via
`dataSourceList.GetDataSourceByName("X").Retrieve()`.

### 5. YAML wiring (simple class name — FB s04, LAB L4)
```yaml
DataSources:
  - Name: 10Samples
    Generator: JsonArrayGenerator           # simple class name
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
Mocker stub wiring: `Processor: HealthProcessor` + `ProcessorConfiguration: {}` in Stubs entry (FB s14#5).

### 6. Discovery verification
Successful discovery log (FB s04, LAB L4):
```
Found IGenerator hook instance JsonArrayGenerator in provided assembly HookLab, Version=...
Found IProbe hook instance PrintCurrentTimeProbe in provided assembly HookLab, Version=...
Found IAssertion hook instance LengthAssertion in provided assembly HookLab, Version=...
```
Missing hook log then crash:
```
FTL ... IGenerator hook instance X not found in any of the provided assemblies
```
Process exit: `-532462766` (FB s04, LAB L2).

### 7. Full namespace table (FB s04, LAB L4)
See references/namespaces.md.

## Traps
| Trap | Fix |
|---|---|
| `Configuration` accessed in ctor → null crash | Never touch Configuration in ctor (FB s04) |
| Class not a `record` | Must be `record` for binding to work (FB s04) |
| Probe calls `Task.Run` | Must be synchronous (FB s04) |
| Processor mutates instance field | Instances shared; use only local variables or static (FB s04) |
| Hook assembly not referenced | Add as ProjectReference or QaaS.Common.* PackageReference (FB s13#8) |
| `CS0246 SessionData not found` + `CS0534 does not implement Assert(...)` | Add **both** `using ...Session.DataObjects;` (Data<T>) **and** `using ...Session.SessionDataObjects;` (SessionData). Missing the second breaks the override signature (FB s04) |
| `CS8121` / `CS0023` on a JSON body | `comm.Data[i].Body` from `CastCommunicationData<JsonElement>()` is a `JsonElement` **struct**: use `TryGetProperty`/`ValueKind`/`GetString()`; never `?.`, never `is byte[]`/`is string` (FB s04) |
| `CS0246 BaseTransactionProcessor not found` (or `MetaData`/`Http`) | Processor is a **mocker** hook: project must reference `QaaS.Mocker`; use `using QaaS.Framework.SDK.Hooks.Processor;` (base) **and** `using QaaS.Framework.SDK.Session.MetaDataObjects;` (MetaData/Http). It will not resolve in a runner-only project (FB s04, s14#5) |

## Citations
- FB s04 (signatures, config rules, namespaces), FB s13#8 (missing hook), FB s14#4/#5 (golden hook trio)
