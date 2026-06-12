# QaaS Copilot — Airgap Deployment & Runbook

How to deploy and operate the **QaaS Copilot plugin** inside a fully airgapped environment
with local models and private package mirrors.

---

## 1. Architecture Overview

In an airgapped environment, you have access to:

1. **A local LLM** behind Claude Code (any model your provider gateway exposes).
2. **A private package repository**: JFrog Artifactory, Sonatype Nexus, or a file-based folder
   acting as your NuGet feed.
3. **A docs mirror**: a local copy of the QaaS documentation site (including `llms.txt` and
   `llms-full.txt`).
4. **This plugin**: copied to the airgapped host and installed into Claude Code from the local
   path.

```
+---------------------------------------------------------------------------------+
|                               AIRGAPPED LAN                                     |
|                                                                                 |
|  +--------------------+      +--------------------+      +--------------------+ |
|  |     Local LLM      |      | Private Artifactory|      |    Docs Mirror     | |
|  |  (your gateway)    |      |  (QaaS NuGet Feed) |      | (QAAS_DOCS_URL)    | |
|  +---------+----------+      +---------+----------+      +---------+----------+ |
|            ^                           ^                           ^            |
|            |                           |                           |            |
|  +---------+---------------------------+---------------------------+----------+ |
|  | WORKSTATION                                                                | |
|  |                                                                            | |
|  |   +--------------------+       +--------------------+                      | |
|  |   |  QaaS Copilot      | ----> |  Claude Code CLI   |                      | |
|  |   |  (plugin)          |       |                    |                      | |
|  |   +--------------------+       +---------+----------+                      | |
|  |                                          |                                 | |
|  |                                          v                                 | |
|  |                                +---------+----------+                      | |
|  |                                | Local Testbed (e2e)|                      | |
|  |                                | (Runner / Docker)  |                      | |
|  |                                +--------------------+                      | |
|  +----------------------------------------------------------------------------+ |
+---------------------------------------------------------------------------------+
```

---

## 2. Plug-and-Play Setup with Claude Code (One Button)

The plugin makes Claude Code an expert in planning, authoring, running, and debugging QaaS
tests while honoring local docs and airgap boundaries. **The only value you change for a new
environment is `QAAS_DOCS_URL`.**

### 2.1 Install the plugin (airgapped)

On a connected machine, clone this repo and copy the folder to your airgapped host (USB,
internal git, artifact share). Then, inside Claude Code on the host, add the marketplace from
the **local path** and install:

```
/plugin marketplace add /opt/qaas-copilot
/plugin install qaas@qaas-copilot
```

(Connected machine? Use `/plugin marketplace add eldarush/qaas-copilot` instead. Or open the
repo itself — the committed `.claude/settings.json` auto-enables the plugin with zero
commands.) Full matrix: [INSTALL.md](./INSTALL.md).

### 2.2 Point it at your internal docs mirror (the one knob)

```bash
export QAAS_DOCS_URL="http://docs.internal.example.com"     # Linux/macOS
# setx QAAS_DOCS_URL "http://docs.internal.example.com"     # Windows (new shells)
```

That is the entire configuration. The plugin bundles 20 skills, 4 subagents, 5 commands, and
the full offline Fact Base, so it works even when the docs server is unreachable.

### 2.3 What you get natively in Claude Code

* The **QaaS Test-Authoring Constitution** and **29 doc-drift traps** auto-load every session
  (via the `qaas-overview` skill + SessionStart hook) — so common schema mistakes never happen.
* **19 task skills** invoked automatically by description (plan, analyze SUT repos / Helm /
  existing tests, scaffold, author YAML, hooks, run, diagnose, build mocker images, offline
  packaging, validate-compatibility, verify-done, document).
* **4 subagents**: `qaas-planner`, `qaas-test-author`, `qaas-debugger`, `qaas-analyst`.
* **Slash commands**: `/qaas:docs <path>` (curl-based live docs), `/qaas:fact <slice>` (offline
  Fact Base), `/qaas:new-test`, `/qaas:diagnose`, `/qaas:verify`.

### 2.4 Native docs fetching via curl (never WebFetch)

`/qaas:docs runner/configuration` shells out to `curl -fsSL` against `$QAAS_DOCS_URL` and
streams the text straight into context — no third-party dependencies, proxy-friendly,
airgap-safe. If the mirror is down, `/qaas:fact` serves the bundled, drift-corrected knowledge
offline.

---

## 3. Configuring Offline NuGet Feeds

Since the airgapped workstation cannot resolve `nuget.org`, you must feed your local package
server with the required QaaS binaries and tell your projects how to fetch them.

### 3.1 Pre-mirror QaaS packages

Mirror these core NuGet packages to your local Artifactory/Nexus feed:

* `QaaS.Runner` (v4.5.1+)
* `QaaS.Mocker` (v2.4.1+)
* `QaaS.Common.Assertions`
* `QaaS.Common.Generators`
* `QaaS.Common.Probes`
* `QaaS.Common.Processors`
* `QaaS.Framework.Core`
* `QaaS.Framework.Testing`

> Versions are **independent per package** (FB s13 trap #9) — never assume one shared version
> number across the QaaS package family.

### 3.2 Configure the NuGet.config template

To prevent dependency leakage or internet resolution hangs, the `scaffold-runner-project` and
`scaffold-mocker-project` skills inject a secured, clear-first `NuGet.config`.

Your environment-level variables dictate where these point. Set them globally in your session
or user profile:

```powershell
$env:QAAS_NUGET_SOURCE_NAME = "LocalArtifactory"
$env:QAAS_NUGET_SOURCE_URL  = "http://your-artifactory/artifactory/api/nuget/v3/qaas-nuget"
```

The resulting `NuGet.config` generated for your runner and mocker projects looks like this:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="%QAAS_NUGET_SOURCE_NAME%" value="%QAAS_NUGET_SOURCE_URL%" />
  </packageSources>
</configuration>
```

The `%QAAS_NUGET_SOURCE_NAME%` and `%QAAS_NUGET_SOURCE_URL%` tokens are fully expanded by
NuGet at restore-time using environment variables, avoiding hardcoded URLs in committed code.

### 3.3 Pre-install project templates offline

Since `dotnet new install QaaS.Runner.Template` normally queries nuget.org, install templates
offline:

1. Download the template `.nupkg` files (e.g. `QaaS.Runner.Template.x.y.z.nupkg` and
   `QaaS.Mocker.Template.x.y.z.nupkg`) on a connected machine.
2. Transfer them to your airgapped environment via secure media.
3. Install them directly from the local file path:

   ```powershell
   dotnet new install C:\packages\QaaS.Runner.Template.1.5.2.nupkg
   dotnet new install C:\packages\QaaS.Mocker.Template.1.5.2.nupkg
   ```

---

## 4. Local Containerization & Docker Setup

QaaS uses Docker for running mockers, stubs, and broker dependencies (RabbitMQ, Redis, Kafka)
locally and hermetically.

### 4.1 Import base Docker images

Ensure your private container registry hosts these required base images:

* `sdk:10.0` (Microsoft official SDK)
* `aspnet:10.0` (Microsoft official ASP.NET runtime — **crucial**: do *not* use generic
  `.NET Runtime` images; custom mockers host ASP.NET Web APIs)
* `rabbitmq:3-management` or `rabbitmq:4`
* `redis:7-alpine` or `redis:8`

### 4.2 Build custom mocker images locally

When building custom Docker mockers, the `build-mocker-image` skill generates a multi-stage
`Dockerfile`. Substitute your local registry endpoints:

```dockerfile
FROM your-private-registry/dotnet/sdk:10.0 AS build
WORKDIR /app
COPY *.csproj ./
RUN dotnet restore
COPY . ./
RUN dotnet publish -c Release -o out

FROM your-private-registry/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/out .
EXPOSE 8080
ENTRYPOINT ["dotnet", "CustomMocker.dll"]
```

---

## 5. Airgap Troubleshooting & Drifts

The most common failures encountered in airgapped environments and how the plugin addresses
them:

### A. NU1301: Failed to retrieve information from remote source

* **Cause**: NuGet is attempting to resolve an internet endpoint, or the workstation lacks
  access to your private Artifactory.
* **Resolution**: Ensure `QAAS_NUGET_SOURCE_URL` is set correctly and the host is reachable.
  Check proxy/credential settings in your `NuGet.config`.

### B. Unable to locate custom hook assembly

* **Cause**: The custom hook C# assembly wasn't compiled or wasn't placed in the scanned
  folder.
* **Resolution**: The `scaffold-runner-project` skill sets up assembly output parameters so
  custom hook DLLs land in the execution directory. Verify the build step completed
  successfully.

### C. Mocker container exits instantly or port conflict

* **Cause**: Custom mocker built on a base image without ASP.NET components, or port `8080`
  is already in use.
* **Resolution**: Check `docker logs <container_id>`. Verify the runtime base image is exactly
  `aspnet:10.0` and no duplicate containers bind the same port.

### D. Silent vacuous passes

* **Cause**: A test asserts `HttpStatus` without confirming any outputs actually arrived —
  zero outputs pass vacuously (FB s13 trap #13).
* **Resolution**: Always pair status/content assertions with a hermetic output-count guard
  (`HermeticByExpectedOutputCount` or `HermeticByInputOutputPercentage`) via the
  `pick-assertion` skill.

