---
name: scaffold-mocker-project
version: 1.0.0
description: Scaffold a QaaS Mocker project with correct csproj, Dockerfile (aspnet:10.0), and YAML copy settings.
when_to_use: Sprint needs a configurable HTTP/gRPC/Socket mock server alongside the runner project.
inputs:
  - project_name: e.g. MyServiceMock
  - nuget_feed_url: Artifactory feed URL (or local path for dev)
outputs:
  - <project_name>/<project_name>.csproj
  - <project_name>/NuGet.config
  - <project_name>/mocker.qaas.yaml (scaffold default)
  - <project_name>/Program.cs
  - <project_name>/Dockerfile
fact_base_slices: [s01, s06, s13, s14]
references: []
contract:
  done_rubric:
    - 'dotnet build -c Release in project dir exits 0'
    - 'dotnet run -- template mocker.qaas.yaml exits 0'
    - 'Dockerfile base image is aspnet:10.0 (not runtime:10.0)'
  failure_modes:
    - 'Dockerfile uses runtime:10.0 -> container fails: Microsoft.AspNetCore.App not found (FB s13#7)'
    - 'Missing QaaS.Common.Processors PackageReference -> FTL + exit -532462766 (FB s13#8)'
    - 'CopyToOutputDirectory absent on mocker.qaas.yaml -> config file not found (FB s01)'
    - 'Templates not on nuget.org (FB s01)'
  escalation: 'NEEDS_CLARIFICATION: nuget_feed_url not provided | BLOCKED: .NET 10 SDK not installed'
---

## When to use

Creates the mocker project before authoring `mocker.qaas.yaml`. The mocker hosts HTTP/gRPC/Socket
servers and serves stubs. Required whenever the runner's sessions call a local mock endpoint.

## Steps

### 1. Install the template (FB s01)

```powershell
# Templates NOT on nuget.org — local path or Artifactory:
dotnet new install <local-template-path>\QaaS.Mocker.Template

# Or from configured Artifactory feed:
dotnet new install QaaS.Mocker.Template
```

### 2. Scaffold the project (FB s01)

```powershell
dotnet new qaas-mocker -n <project_name>
cd <project_name>
```

Scaffold produces: `NuGet.config`, `<project_name>.csproj`, `Program.cs`,
`mocker.qaas.yaml`, `Dockerfile`, and a scaffold `HealthProcessor`.

### 3. Fix csproj — required shape (FB s01, FB s13#8)

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="QaaS.Mocker" Version="2.4.1" />

    <!-- Built-in processors MUST be referenced explicitly (FB s13#8) -->
    <!-- StaticResponseProcessor, ConditionProcessor, etc. live here (version is 1.5.1, NOT 2.4.1): -->
    <PackageReference Include="QaaS.Common.Processors" Version="1.5.1" />
  </ItemGroup>

  <!-- REQUIRED: the mocker config must be in the output dir (FB s01). Mocker files are named -->
  <!-- either `mocker.qaas.yaml` or `<svc>.mocker.yaml` depending on convention, so copy all yaml. -->
  <ItemGroup>
    <None Include="*.yaml" CopyToOutputDirectory="PreserveNewest" />
  </ItemGroup>
</Project>
```

**Version rule (FB s01) — VERIFIED, versions are INDEPENDENT:** `QaaS.Mocker`=`2.4.1`,
`QaaS.Common.Processors`=`1.5.1`. **Do NOT put `2.4.1` on `QaaS.Common.Processors`** — it does not
exist at that version (`error NU1102 ... (>= 2.4.1)`; nearest is `1.5.1`).

### 4. Fix Dockerfile — CRITICAL: aspnet not runtime (FB s13#7, LAB L5)

Scaffold ships `mcr.microsoft.com/dotnet/runtime:10.0` — this **FAILS** at container start
because the mocker hosts an HTTP server requiring `Microsoft.AspNetCore.App`.

**Correct Dockerfile (FB s14.6 verbatim):**

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
ENTRYPOINT ["dotnet", "<project_name>.dll", "mocker.qaas.yaml"]
```

Build args for Artifactory feed (docs deployMock.md):
`QAAS_NUGET_SOURCE_NAME`, `QAAS_NUGET_SOURCE_URL` — set as `--build-arg` if NuGet.config
uses env-var substitution pattern.

### 5. Verify Program.cs bootstrap (FB s01)

```csharp
QaaS.Mocker.Bootstrap.New(args).Run();
```

### 6. NuGet.config — same single-feed pattern as runner (FB s01)

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="Artifactory" value="<FEED_URL>/api/nuget/v3/index.json" />
  </packageSources>
</configuration>
```

### 7. Done-gate (LAB L5)

```powershell
cd <project_name>
dotnet build -c Release          # exit 0
dotnet run -- template mocker.qaas.yaml   # exit 0; schema oracle

# Optional: Docker build verify
docker build -t <project_name_lower>:test .
docker run -d -p 8080:8080 <project_name_lower>:test
Start-Sleep 3
curl.exe -s -o NUL -w "%{http_code}" http://127.0.0.1:8080/health   # 200
```

Expected boot log (LAB L5):
```
Built 4 transaction stub(s) including default not-found and internal-error stubs
Resolved runtime graph with 0 data source(s), 4 stub(s), 1 server(s) [Http], and controller enabled: False
```

## Citations

- FB s01 (templates, csproj shape, CopyToOutputDirectory, Program.cs)
- FB s13#7 (Dockerfile aspnet fix — LAB-verified)
- FB s13#8 (QaaS.Common.Processors mandatory for built-in stubs)
- FB s13#9 (real versions: Mocker 2.4.1, .NET 10.0.203)
- FB s14.6 (golden Dockerfile — verbatim)
- LAB L5 (docker build+run verified, runtime:10.0 failure reproduced)

## Traps

- **s13#7** — scaffold Dockerfile uses `runtime:10.0`; replace with `aspnet:10.0` immediately;
  failure message: `Framework 'Microsoft.AspNetCore.App' ... No frameworks were found`
- **s13#8** — `QaaS.Common.Processors` must be a PackageReference; missing → FTL + exit `-532462766`
- **FB s01** — `CopyToOutputDirectory` absent on `mocker.qaas.yaml` → `config file not found`
- **Templates not on nuget.org** — `dotnet new install <local-path>` required in airgap
