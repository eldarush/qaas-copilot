## 1. TASK: Scaffold a project

### Prereqs (docs/qaas/quickStart/installation.md)
- .NET SDK **10.0** mandatory. Global `NuGet.Config` with the feed. Allure CLI optional (reports).
- Packages: `QaaS.Runner` (required) + optional `QaaS.Common.Assertions`, `QaaS.Common.Generators`,
  `QaaS.Common.Probes`, `QaaS.Common.Processors` (mocker).
- **VERSIONS ARE INDEPENDENT — DO NOT assume they match `QaaS.Runner`.** Each package has its own
  version line. Using `QaaS.Runner`'s `4.5.1` on a `QaaS.Common.*` package gives `error NU1102:
  Unable to find package ... version (>= 4.5.1)`. Verified compatible matrix (LAB — restores+builds
  on .NET 10.0.203, latest stable as of writing):

  | Package | Version | Used by |
  |---|---|---|
  | `QaaS.Runner` | `4.5.1` | runner project (required) |
  | `QaaS.Mocker` | `2.4.1` | mocker project (required) |
  | `QaaS.Common.Assertions` | `3.5.1` | runner — any built-in assertion (`HttpStatus`, `Hermetic*`, …) |
  | `QaaS.Common.Generators` | `3.5.1` | runner — any built-in generator (`FromFileSystem`, …) |
  | `QaaS.Common.Probes` | `1.5.1` | runner — any built-in probe |
  | `QaaS.Common.Processors` | `1.5.1` | mocker — any built-in processor (`StaticResponseProcessor`, …) |

  **SCAFFOLD DEFAULT (CRITICAL — scaffold for the WHOLE test, not the empty project).** You scaffold
  the `.csproj` BEFORE you author the YAML, so you must look ahead at the sprint goal and include every
  built-in hook family the test will use. A standard QaaS test almost always uses built-ins, so DEFAULT to:
  - **Runner** → `QaaS.Runner` + `QaaS.Common.Generators` + `QaaS.Common.Assertions` (a generator feeds
    the session and `HttpStatus`/`Hermetic*` assert it — nearly every runner test needs both). Add
    `QaaS.Common.Probes` only if the sprint uses a probe.
  - **Mocker** → `QaaS.Mocker` + `QaaS.Common.Processors` (every stub uses a processor).

  Drop a `Common.*` family ONLY when you are certain the test uses no built-in hook of that family
  (e.g. a custom-hook-only project, or a mocker that relies solely on default NotFound/InternalError stubs).

  **WHY THIS MATTERS — silent until runtime.** A missing `Common.*` package still **builds fine**
  (`dotnet build` exit 0). It crashes only later at `template`/`run` with **exit `-532462766`** and an
  Autofac `HookProvider…ResolveSupportedHookType` stack trace — the single hardest weak-model trap to
  diagnose. Including the family up-front is free (an unused `Common.*` ref is harmless). See §13 row 8.

  If you do not know a package's exact version and have no feed to query, emit
  `NEEDS_CONTEXT: <package> version` — never guess a version.

### Templates (NOT on nuget.org — install from local path/Artifactory in airgap) [LAB]
```bash
dotnet new install QaaS.Runner.Template      # or: dotnet new install <local-template-path>
dotnet new qaas-runner -n MyServiceTests     # runner scaffold: NuGet.config + test.qaas.yaml + Program.cs + Rider profile
dotnet new qaas-mocker -n MyMock             # mocker scaffold: mocker.qaas.yaml + Program.cs + Dockerfile + HealthProcessor [LAB]
```
- Minimal `Program.cs`: `QaaS.Runner.Bootstrap.New(args).Run();` (mocker:
  `QaaS.Mocker.Bootstrap.New(args).Run();`). (docs/qaas/quickStart/writeTestYaml.md, r07)
- **`*.qaas.yaml` must be copied to output** or you get "config file not found":
  add `<CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>`. (docs debugTestFailure.md)
- Hook SDK namespaces arrive **transitively with QaaS.Runner** — no extra PackageReference needed to
  write custom hooks; but **built-in hook *families* must be referenced explicitly** (see §13/§8). [LAB]
- **Runner `.csproj`** (COMPLETE FILE — emit exactly this shape; `OutputType=Exe` is MANDATORY or the
  one-line `Program.cs` fails with `error CS8805: Program using top-level statements must be an executable`):
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="QaaS.Runner" Version="4.5.1" />
    <PackageReference Include="QaaS.Common.Generators" Version="3.5.1" />
    <PackageReference Include="QaaS.Common.Assertions" Version="3.5.1" />
    <!-- add only if the test uses a built-in probe: -->
    <!-- <PackageReference Include="QaaS.Common.Probes" Version="1.5.1" /> -->
  </ItemGroup>
  <ItemGroup>
    <None Include="*.qaas.yaml" CopyToOutputDirectory="PreserveNewest" />
    <None Include="TestData\**\*" CopyToOutputDirectory="PreserveNewest" />
  </ItemGroup>
</Project>
```
- **Mocker `.csproj`** (COMPLETE FILE — `OutputType=Exe` mandatory; copy `*.mocker.yaml`, NOT `*.qaas.yaml`):
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="QaaS.Mocker" Version="2.4.1" />
    <PackageReference Include="QaaS.Common.Processors" Version="1.5.1" />
  </ItemGroup>
  <ItemGroup>
    <None Include="*.mocker.yaml" CopyToOutputDirectory="PreserveNewest" />
  </ItemGroup>
</Project>
```

### IDE schema (docs/qaas/quickStart/ide.md)
- Map runner JSON schema to `test.qaas.yaml` (VS Code `yaml.schemas`; Rider JSON Schema Mappings,
  **per project**). Gives completion + validation.

---

