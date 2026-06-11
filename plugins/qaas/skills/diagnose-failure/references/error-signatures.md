# Error Signatures — Full Table (FB s07, LAB)

Quick-reference for copy-paste matching against `statusDetails.message` or console output.

| Symptom | Cause | Fix |
|---|---|---|
| `FTL ... IGenerator hook instance X not found in any of the provided assemblies` | Generator hook class missing from assembly | Add `QaaS.Common.Generators` PackageReference or project asm ref |
| `FTL ... IAssertion hook instance X not found in any of the provided assemblies` | Assertion hook class missing | Add `QaaS.Common.Assertions` PackageReference |
| `FTL ... ITransactionProcessor hook instance X not found` | Processor hook class missing | Add `QaaS.Common.Processors` PackageReference (mocker csproj) |
| Exit -532462766 after any FTL hook-not-found | DI container crash | Fix the FTL hook ref first |
| `FTL Runner execution configuration is invalid` + numbered YAML paths | Schema validation failure | Fix each YAML path listed; check DataSourceNames on Transactions |
| `Property TransactionData in path Stubs:0 - not found in TransactionStubConfig object` | `TransactionData` key in mocker stub | Replace with `ProcessorConfiguration` |
| assertion `broken` + "Value cannot be null. (Parameter 'source')" | Named Output missing entirely | Fix Route or stub so the output is produced; OutputNames must match action Name |
| HTTP 404 from mocker | Double-slash: Runner `Route:/x` → `//x` | Remove leading slash: `Route: x` |
| `failed`: "No output items were found in the output Consumer..." | Consumer received zero items | Start SUT; raise TimeoutMs; verify broker/SUT connectivity |
| Hermetic% = 0, assertion failed | Zero outputs collected | Same as above |
| "config file not found" or `CopyToOutputDirectory` issue | YAML not present in output dir | Add `<CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>` to .csproj |
| Container: "Framework 'Microsoft.AspNetCore.App' ... No frameworks were found." | Mocker Dockerfile uses `dotnet/runtime:10.0` | Change to `mcr.microsoft.com/dotnet/aspnet:10.0` |
| `CouldNotFindConfigurationException: ...Resolved local path: <cwd>\x.yaml` | Running from wrong directory | `cd` into the project folder (not solution root) |
| Exit 0, HttpStatus passed, but zero actual HTTP traffic | Vacuous pass (FB s13#13) | Add `HermeticByExpectedOutputCount` with `ExpectedCount: N` alongside HttpStatus |
| Assertion fails "Sum of outputs X count is 1, expected" | Unknown config key silently ignored | Copy field names exactly from the hook's yamlView catalog; run `template` to verify |
| MockerCommands time out silently | Redis unreachable or Controller.ServerName unset/mismatched | Verify Redis is running; Controller.ServerName must byte-match MockerCommands[].ServerName |
| `RabbitMq.Host:127.0.0.1` in container resolves to container itself | Docker networking | Use `host.docker.internal` or a docker network alias |
| Publishers fire, consumers timeout | Channel/exchange name mismatch | Match exchange name to mocker's logged channel name |
| `flaky` result with `ExpectedPercentage:100` | At-least-once delivery fluctuation | Use `>=95` or add a deduplicated consumer |

## VACUOUS PASS detailed guard (FB s13#13, LAB L7)

Every HTTP session that uses `HttpStatus` MUST also include:
```yaml
- Name: ExactlyNOutputs
  Assertion: HermeticByExpectedOutputCount
  SessionNames: [<session>]
  AssertionConfiguration:
    OutputNames: [<ActionName>]   # matches Transaction Name
    ExpectedCount: <N>            # field is ExpectedCount, NOT ExpectedOutputCount (FB s13#12)
```
Without this, a connection-refused scenario produces exit 0 (false green).
