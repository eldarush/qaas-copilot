---
name: offline-packaging
version: 1.0.0
description: Configure a QaaS project to restore packages and install templates from a local Artifactory feed with no internet access.
when_to_use: When working in an airgapped environment — no nuget.org, no github, only a local Artifactory or folder feed.
inputs:
  - name: artifactory_url
    example: "https://artifactory.example.com/nuget/v3/index.json"
  - name: feed_name
    example: "QaaS"
outputs:
  - path: "NuGet.config"
  - path: "Runner/<project>.csproj (version pins)"
  - path: "Mocker/Dockerfile (registry-prefixed base images)"
fact_base_slices: [s08, s13]
references:
  - references/nuget-config-template.md
contract:
  done_rubric:
    - "dotnet restore --configfile NuGet.config => exit 0 against local feed"
    - "No external URLs (nuget.org, github.com) in any config file"
  failure_modes:
    - "nuget.org still in sources → restore succeeds in lab, fails airgap (FB s08)"
    - "templates not installed locally → dotnet new qaas-runner fails (FB s08)"
    - "docker base images missing from private registry → docker build fails (FB s08)"
    - "Version='*' pulls latest → non-deterministic in airgap (FB s08)"
  escalation: "NEEDS_CLARIFICATION: Artifactory URL | BLOCKED: feed not available"
---

## When to use

Use when all NuGet packages, dotnet templates, and Docker images must come from local sources only.

## Steps

### 1. NuGet.config — single feed with `<clear/>` (FB s08, LAB env)
```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />                                  <!-- block nuget.org and all defaults (FB s08) -->
    <add key="QaaS" value="https://artifactory.example.com/nuget/v3/index.json" />
  </packageSources>
</configuration>
```
Place in project root alongside the `.csproj`. Restore with:
```powershell
dotnet restore --configfile NuGet.config
```
**`<clear/>`** is mandatory — without it, nuget.org remains as a fallback and fails in airgap (FB s08).

### 2. Env-var override pattern (FB s08, docs deployMock.md)
Scaffolds support `QAAS_NUGET_SOURCE_NAME` / `QAAS_NUGET_SOURCE_URL` env vars:
```powershell
$env:QAAS_NUGET_SOURCE_NAME = "QaaS"
$env:QAAS_NUGET_SOURCE_URL  = "https://artifactory.example.com/nuget/v3/index.json"
dotnet restore --configfile NuGet.config
```
In CI/Docker pass as `--build-arg` or environment variables (see build-mocker-image skill).

### 3. Version pinning
Avoid `Version="*"` (pulls latest → non-deterministic, may not exist in feed):
```xml
<!-- DO NOT use: -->
<PackageReference Include="QaaS.Runner" Version="*" />

<!-- USE explicit version: -->
<PackageReference Include="QaaS.Runner" Version="4.5.1" />
<PackageReference Include="QaaS.Mocker" Version="2.4.1" />
```
Current verified versions: Runner 4.5.1, Mocker 2.4.1, .NET 10.0.203 (FB s13#9).
Pin `QaaS.Common.Generators`, `QaaS.Common.Assertions`, `QaaS.Common.Processors` to matching versions.

### 4. dotnet new templates — local install (FB s08, LAB env)
Templates `qaas-runner` / `qaas-mocker` are **not on nuget.org** (FB s08):
```powershell
# From local folder (template project):
dotnet new install C:\path\to\qaas-runner-template

# Or from Artifactory (nupkg):
dotnet new install QaaS.Templates --nuget-source https://artifactory.example.com/nuget/v3/index.json

# Verify installation:
dotnet new list | Select-String qaas
```

### 5. Pre-mirror required packages (FB s08)
The following must exist in Artifactory before any restore:
- `QaaS.Runner`, `QaaS.Mocker`
- `QaaS.Common.Generators`, `QaaS.Common.Assertions`, `QaaS.Common.Processors`
- `QaaS.Framework.*` transitive dependencies
- All `.NET 10.0` SDK/runtime/aspnet transitive packages

Built-in hook families use assembly scanning — the assembly DLL must be resolvable at runtime.
Mirror each `QaaS.Common.*` package so assembly scanning finds them (FB s08).

### 6. Docker base images — private registry (FB s08, FB s13#7)
```dockerfile
# Replace public MCR references with private registry:
FROM private-registry.example.com/dotnet/sdk:10.0 AS build
# ...
FROM private-registry.example.com/dotnet/aspnet:10.0   # MUST be aspnet, not runtime (FB s13#7)
```
Pre-pull and push to private registry:
```powershell
docker pull mcr.microsoft.com/dotnet/sdk:10.0
docker pull mcr.microsoft.com/dotnet/aspnet:10.0
docker tag mcr.microsoft.com/dotnet/sdk:10.0    private-registry.example.com/dotnet/sdk:10.0
docker tag mcr.microsoft.com/dotnet/aspnet:10.0 private-registry.example.com/dotnet/aspnet:10.0
docker push private-registry.example.com/dotnet/sdk:10.0
docker push private-registry.example.com/dotnet/aspnet:10.0
```

### 7. Docs mirror (FB s00)
In airgap the only reference root is the local docs mirror. No nuget.org, no github.com, no internet.
All skill citations (`docs/...`) resolve against the local mirror path.

### 8. Verify no external URLs
```powershell
Select-String -Path "NuGet.config","**\*.csproj","Dockerfile" -Pattern "nuget\.org|github\.com|raw\.githubusercontent"
# Must return no matches
```

## Traps
| Trap | Fix |
|---|---|
| Missing `<clear/>` in NuGet.config | nuget.org leaks through; add `<clear/>` first (FB s08) |
| `Version="*"` | Pin to explicit version; airgap feed may not have latest (FB s08) |
| `runtime:10.0` Docker base | Must be `aspnet:10.0` (FB s13#7) |
| Templates not installed | `dotnet new install <path>` from local folder (FB s08) |

## Citations
- FB s08 (airgap packaging), FB s13#7 (aspnet base), FB s13#9 (versions), LAB env facts
