---
name: scaffold-runner-project
version: 1.0.0
description: Scaffold a QaaS Runner project with correct csproj, NuGet.config, and YAML copy settings.
when_to_use: Task requires a new QaaS Runner project (first task in any sprint, before authoring YAML).
inputs:
  - project_name: e.g. MyServiceTests
  - nuget_feed_url: Artifactory feed URL (or local path for dev)
  - qaas_runner_version: e.g. 4.5.1
outputs:
  - <project_name>/<project_name>.csproj
  - <project_name>/NuGet.config
  - <project_name>/test.qaas.yaml (scaffold default)
  - <project_name>/Program.cs
fact_base_slices: [s01, s06, s13]
references: []
contract:
  done_rubric:
    - 'dotnet build -c Release in project dir exits 0'
    - 'test.qaas.yaml present with CopyToOutputDirectory PreserveNewest'
  failure_modes:
    - 'Missing QaaS.Common.Generators / QaaS.Common.Assertions PackageReference -> FTL exit -532462766 (FB s13#8)'
    - 'CopyToOutputDirectory absent -> config file not found at runtime (FB s01)'
    - 'Run dotnet run from solution dir not project dir -> CouldNotFindConfigurationException (LAB L6)'
    - 'Templates not on nuget.org -> dotnet new install must use local path or Artifactory (FB s01)'
    - 'Wrong .NET SDK version -> SDK 10.0 mandatory (FB s01)'
  escalation: 'NEEDS_CLARIFICATION: nuget_feed_url not provided | BLOCKED: .NET 10 SDK not installed'
---

## When to use

First task of any sprint. Creates the .csproj, NuGet.config, Program.cs, and scaffold YAML.
Always precedes `author-runner-yaml`.

## Steps

### 1. Install the template (FB s01)

Templates are **NOT on nuget.org** — use local path or Artifactory in airgap:

```powershell
# From local path:
dotnet new install <local-template-path>\QaaS.Runner.Template

# Or from Artifactory (if nuget source is configured):
dotnet new install QaaS.Runner.Template
```

### 2. Scaffold the project (FB s01)

```powershell
dotnet new qaas-runner -n <project_name>
cd <project_name>
```

Scaffold produces: `NuGet.config`, `<project_name>.csproj`, `Program.cs`,
`test.qaas.yaml`, Rider launch profile.

### 3. Fix csproj — required shape (FB s01, FB s13#8, FB s13#9)

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <ItemGroup>
    <!-- Core runner — hook SDK namespaces arrive transitively (FB s01) -->
    <PackageReference Include="QaaS.Runner" Version="4.5.1" />

    <!-- SCAFFOLD DEFAULT: a standard runner test uses a built-in generator + built-in -->
    <!-- assertions, so include BOTH families now (you scaffold before writing the YAML). -->
    <!-- Versions are INDEPENDENT, NOT 4.5.1 (FB s01). Omitting one still builds, then -->
    <!-- crashes at template/run with exit -532462766 (FB s13#8). -->
    <PackageReference Include="QaaS.Common.Generators" Version="3.5.1" />
    <PackageReference Include="QaaS.Common.Assertions" Version="3.5.1" />
    <!-- <PackageReference Include="QaaS.Common.Probes" Version="1.5.1" />  (only if using a probe) -->
  </ItemGroup>

  <!-- REQUIRED: config not found without this (FB s01) -->
  <ItemGroup>
    <None Update="*.qaas.yaml">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </None>
    <None Update="TestData\**\*">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </None>
  </ItemGroup>
</Project>
```

**Version rule (FB s01) — VERIFIED, versions are INDEPENDENT:** `QaaS.Runner`=`4.5.1`,
`QaaS.Common.Assertions`=`3.5.1`, `QaaS.Common.Generators`=`3.5.1`, `QaaS.Common.Probes`=`1.5.1`.
**Never copy `QaaS.Runner`'s `4.5.1` onto a `QaaS.Common.*` package** — that yields
`error NU1102: Unable to find package ... (>= 4.5.1)`. If unsure of a version and you cannot query
the feed, emit `NEEDS_CONTEXT: <package> version`.

**Hook package rule (FB s13#8) — SCAFFOLD DEFAULT is inclusive:** you create the `.csproj` before
the YAML exists, so look ahead at the sprint goal and add the families the test will use. A standard
HTTP test → `QaaS.Common.Generators` (`FromFileSystem`) + `QaaS.Common.Assertions`
(`HttpStatus`/`Hermetic*`/`Delay*`). Add `QaaS.Common.Probes` only if a probe is used. Drop a family
only when you are certain no built-in hook of it is used. Missing package → builds clean, then crashes
at `template`/`run` with `FTL ... hook instance X not found` / DI crash **exit `-532462766`**.

### 4. Configure NuGet.config (FB s01, LAB env facts)

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="Artifactory" value="<FEED_URL>/api/nuget/v3/index.json" />
  </packageSources>
</configuration>
```

Single-feed pattern: `<clear />` prevents fallback to nuget.org (airgap-safe).
For env-var override pattern: set `QAAS_NUGET_SOURCE_URL` (FB s01, docs deployMock.md).

### 5. Verify Program.cs bootstrap (FB s01)

```csharp
QaaS.Runner.Bootstrap.New(args).Run();
```

Scaffold generates this; do not change the signature.

### 6. Run from PROJECT directory (LAB L6)

```powershell
# CORRECT: cd into the project folder
cd <project_name>
dotnet run -- template test.qaas.yaml   # schema oracle; exit 0 if config valid

# WRONG: run from solution dir -> CouldNotFindConfigurationException
# dotnet run --project <project_name> -- run test.qaas.yaml   ← config resolves vs CWD
```

Config paths (YAML, TestData) resolve relative to **CWD at runtime**, not the project dir.
Always `cd` into the project before running.

### 7. Done-gate

```powershell
cd <project_name>
dotnet build -c Release   # expect exit 0
dotnet run -- template test.qaas.yaml   # expect exit 0
```

## Citations

- FB s01 (templates, csproj shape, CopyToOutputDirectory, Program.cs)
- FB s13#8 (hook package refs mandatory)
- FB s13#9 (real versions: Runner 4.5.1, .NET 10.0.203)
- LAB L6 (CWD trap: run from project dir)
- LAB env facts (NuGet.config single-feed, template not on nuget.org)

## Traps

- **s13#8** — built-in hook families (`Generators`, `Assertions`, `Probes`) need explicit
  `PackageReference`; missing → FTL + exit `-532462766`
- **FB s01** — `CopyToOutputDirectory` absent → `config file not found` at runtime
- **LAB L6** — `dotnet run --project X -- run cfg.yaml` from solution dir resolves
  `cfg.yaml` against solution CWD → `CouldNotFindConfigurationException`
- **Templates not on nuget.org** — airgap installs must use `dotnet new install <local-path>` (FB s01)
